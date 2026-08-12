import ServiceManagement

/// Registers/unregisters the app as a login item via SMAppService.
/// SMAppService is the source of truth, so we read `.status` directly.
enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else {
                if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            }
        } catch {
            NSLog("[ChargeGuard] LaunchAtLogin error: \(error.localizedDescription)")
        }
    }
}
