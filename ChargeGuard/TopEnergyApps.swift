import Foundation

struct EnergyAppUsage: Identifiable {
    let id: Int  // pid
    let name: String
    let power: Double
}

/// Ranked energy-impact list via `top -o power`, the same live metric Activity
/// Monitor's Energy tab shows — no root required.
enum TopEnergyApps {
    static func fetch(limit: Int = 6) async -> [EnergyAppUsage] {
        guard let output = try? await run() else { return [] }
        let lines = output.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)

        // `top`'s power/energy-impact column is a rate that needs two samples to
        // compute a delta — a single sample reads all zeros. We ask for two
        // samples (see `run()`) and parse only the block after the LAST "PID"
        // header, i.e. the second (real) sample.
        guard let headerIndex = lines.lastIndex(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("PID") }) else {
            return []
        }

        var results: [EnergyAppUsage] = []
        for line in lines[(headerIndex + 1)...] {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.split(separator: " ").map(String.init)
            guard parts.count >= 3,
                  let pid = Int(parts.first!),
                  let power = Double(parts.last!) else { continue }
            let name = parts[1..<(parts.count - 1)].joined(separator: " ")

            results.append(EnergyAppUsage(id: pid, name: name, power: power))
            if results.count >= limit { break }
        }
        return results
    }

    private static func run() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/top")
            process.arguments = ["-l", "2", "-s", "1", "-o", "power", "-n", "10", "-stats", "pid,command,power"]
            let stdout = Pipe()
            process.standardOutput = stdout
            process.terminationHandler = { proc in
                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
