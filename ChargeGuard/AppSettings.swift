import Foundation
import Combine

/// UserDefaults-backed preferences for the charge range and sail mode.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var lowerLimit: Int { didSet { UserDefaults.standard.set(lowerLimit, forKey: "lowerLimit") } }
    @Published var upperLimit: Int { didSet { UserDefaults.standard.set(upperLimit, forKey: "upperLimit") } }
    @Published var sailMode: Bool { didSet { UserDefaults.standard.set(sailMode, forKey: "sailMode") } }
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            LaunchAtLogin.set(launchAtLogin)
        }
    }

    /// Delta passed to `batt lower-limit-delta`. Sail mode holds tight near the
    /// upper limit instead of ranging across the full lower...upper band.
    var lowerDelta: Int {
        sailMode ? 2 : max(1, upperLimit - lowerLimit)
    }

    private init() {
        let defaults = UserDefaults.standard
        lowerLimit = defaults.object(forKey: "lowerLimit") as? Int ?? 40
        upperLimit = defaults.object(forKey: "upperLimit") as? Int ?? 80
        sailMode = defaults.object(forKey: "sailMode") as? Bool ?? false
        launchAtLogin = defaults.object(forKey: "launchAtLogin") as? Bool ?? LaunchAtLogin.isEnabled
    }
}
