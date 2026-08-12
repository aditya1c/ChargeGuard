import Foundation

/// Battery health, cycle count, and adapter details — all readable without root
/// via ioreg, independent of `batt`/SMC control support.
struct BatteryHealthInfo {
    let cycleCount: Int
    let designCapacityMah: Int
    let fullChargeCapacityMah: Int
    let healthPercent: Int
    let adapterWatts: Int?
    let adapterName: String?
    /// nil when the Mac/macOS build doesn't expose a live temperature key
    /// (confirmed absent on this machine — see chargeguard-project memory).
    let temperatureCelsius: Double?
}

enum SystemBatteryInfo {
    static func fetch() async -> BatteryHealthInfo? {
        guard let data = try? await runIOReg(),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [[String: Any]],
              let dict = plist.first else { return nil }

        let cycleCount = dict["CycleCount"] as? Int ?? 0
        let batteryData = dict["BatteryData"] as? [String: Any] ?? [:]
        let design = batteryData["DesignCapacity"] as? Int ?? 0
        let full = batteryData["FullChargeCapacity"] as? Int ?? 0
        let health = design > 0 ? Int((Double(full) / Double(design) * 100).rounded()) : 0

        let adapter = dict["AdapterDetails"] as? [String: Any]

        // Centi-Celsius when present (e.g. 2912 == 29.12°C).
        let temperature = (dict["Temperature"] as? Int).map { Double($0) / 100.0 }

        return BatteryHealthInfo(
            cycleCount: cycleCount,
            designCapacityMah: design,
            fullChargeCapacityMah: full,
            healthPercent: health,
            adapterWatts: adapter?["Watts"] as? Int,
            adapterName: adapter?["Name"] as? String,
            temperatureCelsius: temperature
        )
    }

    private static func runIOReg() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
            process.arguments = ["-c", "AppleSmartBattery", "-r", "-a", "-x"]
            let stdout = Pipe()
            process.standardOutput = stdout
            process.terminationHandler = { proc in
                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                if proc.terminationStatus == 0 {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: BattError.commandFailed("ioreg failed"))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
