import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // ChargeGuard has no windows, so macOS's Automatic Termination can quit
        // it as an idle background process — power-source changes (e.g.
        // unplugging) are a common trigger. This app's whole job is to keep
        // monitoring/enforcing in the background, so opt out.
        ProcessInfo.processInfo.disableAutomaticTermination("Monitors and enforces battery charge range in the background")
        StatusMonitor.shared.start()
    }
}

@main
struct ChargeGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var monitor = StatusMonitor.shared
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(monitor)
                .environmentObject(settings)
        } label: {
            MenuBarIcon(status: monitor.status, hasError: monitor.lastError != nil)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Icon-only menu bar label; color/glyph reflect current charge state.
struct MenuBarIcon: View {
    let status: BattStatus?
    let hasError: Bool

    var body: some View {
        Image(systemName: symbolName)
            .foregroundStyle(tint)
    }

    private var symbolName: String {
        guard let status else { return "exclamationmark.triangle" }
        // "bolt.batteryblock.fill" is a different glyph family (looks like a car
        // battery); "battery.100percent.bolt" is the traditional battery outline
        // with a charging bolt, matching macOS's own menu bar battery icon.
        if status.battery.state == "charging" { return "battery.100percent.bolt" }
        switch status.battery.currentChargePercent {
        case ..<10: return "battery.0percent"
        case ..<35: return "battery.25percent"
        case ..<60: return "battery.50percent"
        case ..<85: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    private var tint: Color {
        if hasError || status == nil { return .red }
        if status?.compatibility.chargingControl == false { return .orange }
        return .primary
    }
}
