import Foundation

/// Decoded shape of `batt status --json` (batt 0.8.0).
struct BattStatus: Decodable {
    struct Charging: Decodable { let useAdapter: Bool; let pluggedIn: Bool }
    struct Battery: Decodable {
        let currentChargePercent: Int
        let state: String
        let chargeRateWatts: Double
    }
    struct Configuration: Decodable {
        let enabled: Bool
        let upperLimitPercent: Int
        let lowerLimitPercent: Int
    }
    struct Compatibility: Decodable {
        let chargingControl: Bool
        let chargeControlMode: String
        let adapterControl: Bool
        let calibration: Bool
    }

    let charging: Charging
    let battery: Battery
    let configuration: Configuration
    let compatibility: Compatibility
}

enum BattError: Error, LocalizedError {
    case daemonNotFound
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .daemonNotFound:
            return "batt is not installed. Install it with:\nbrew install batt && sudo brew services start batt"
        case .commandFailed(let message):
            return message
        }
    }
}

/// Thin wrapper around the `batt` CLI (github.com/charlie0129/batt), which owns
/// all privileged SMC/charging control via its own root launchd daemon.
enum BattController {
    private static let binaryPath = "/opt/homebrew/bin/batt"

    private static func run(_ arguments: [String]) async throws -> String {
        guard FileManager.default.isExecutableFile(atPath: binaryPath) else {
            throw BattError.daemonNotFound
        }
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binaryPath)
            process.arguments = arguments
            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr
            process.terminationHandler = { proc in
                let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                let errData = stderr.fileHandleForReading.readDataToEndOfFile()
                if proc.terminationStatus == 0 {
                    continuation.resume(returning: String(data: outData, encoding: .utf8) ?? "")
                } else {
                    let message = String(data: errData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(throwing: BattError.commandFailed(message?.isEmpty == false ? message! : "batt \(arguments.joined(separator: " ")) failed"))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: BattError.commandFailed(error.localizedDescription))
            }
        }
    }

    static var isInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: binaryPath)
    }

    static func status() async throws -> BattStatus {
        let output = try await run(["status", "--json"])
        return try JSONDecoder().decode(BattStatus.self, from: Data(output.utf8))
    }

    /// Sets the charge range. `lowerDelta` is how far below `upper` charging resumes
    /// (batt's hysteresis band) — smaller delta ("sail mode") holds closer to flat.
    static func setRange(upper: Int, lowerDelta: Int) async throws {
        _ = try await run(["limit", String(upper)])
        _ = try await run(["lower-limit-delta", String(lowerDelta)])
    }

    /// Temporarily lifts the limit so the battery charges to 100%. batt restores the
    /// saved range automatically after `duration` even if ChargeGuard isn't running;
    /// the app also polls and restores proactively once near full (see AppSettings/PopoverView).
    static func topUpToFull(duration: String = "6h") async throws {
        _ = try await run(["disable", "--for=\(duration)"])
    }

    /// Cancels an in-progress top-up early by re-applying the saved range now.
    static func restoreRange(upper: Int, lowerDelta: Int) async throws {
        try await setRange(upper: upper, lowerDelta: lowerDelta)
    }

    static func startCalibration() async throws {
        _ = try await run(["calibrate", "start"])
    }

    static func cancelCalibration() async throws {
        _ = try await run(["calibrate", "cancel"])
    }

    /// No `--json` support for this subcommand; returns batt's plain-text status report.
    static func calibrationStatusText() async -> String? {
        try? await run(["calibrate", "status"])
    }
}
