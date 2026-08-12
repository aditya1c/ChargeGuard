import SwiftUI

struct PopoverView: View {
    @EnvironmentObject private var monitor: StatusMonitor
    @EnvironmentObject private var settings: AppSettings
    @State private var detailsExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let error = monitor.lastError {
                warningBanner(error)
            } else if let status = monitor.status, !status.compatibility.chargingControl {
                warningBanner("Charge control isn't supported yet on this macOS version (\(status.compatibility.chargeControlMode)). Your range will apply automatically once batt adds support — no action needed here.")
            }

            Divider()

            rangeControls
            Toggle("Sail mode (hold near upper limit)", isOn: $settings.sailMode)
                .onChange(of: settings.sailMode) { _, _ in apply() }

            Divider()

            actions

            Divider()

            DisclosureGroup("Battery Details", isExpanded: $detailsExpanded) {
                details
            }
            .font(.caption)

            Divider()

            Toggle("Launch at login", isOn: $settings.launchAtLogin)

            Divider()

            Button("Quit ChargeGuard") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 300)
        .task { apply(silently: true) }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if let status = monitor.status {
                    Text("\(status.battery.currentChargePercent)%")
                        .font(.system(size: 28, weight: .semibold))
                    Text(status.battery.state.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("ChargeGuard")
                        .font(.headline)
                    Text(BattController.isInstalled ? "Waiting for status…" : "batt not installed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private func warningBanner(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var rangeControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Stepper(value: $settings.lowerLimit, in: 5...(settings.upperLimit - 5), step: 5) {
                Text("Lower limit: \(settings.lowerLimit)%")
            }
            .onChange(of: settings.lowerLimit) { _, _ in apply() }

            Stepper(value: $settings.upperLimit, in: (settings.lowerLimit + 5)...100, step: 5) {
                Text("Upper limit: \(settings.upperLimit)%")
            }
            .onChange(of: settings.upperLimit) { _, _ in apply() }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 8) {
            if monitor.isToppingUp {
                Button("Cancel Top-Up") { Task { await monitor.cancelTopUp() } }
            } else {
                Button("Top Up to 100%") { Task { await monitor.topUp() } }
            }

            if monitor.isCalibrating {
                Button("Cancel Calibration") { Task { await monitor.cancelCalibration() } }
                if let text = monitor.calibrationText, !text.isEmpty {
                    Text(text)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                }
            } else {
                Button("Start Calibration") { Task { await monitor.startCalibration() } }
            }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let health = monitor.healthInfo {
                Text("Health: \(health.healthPercent)% · \(health.cycleCount) cycles")
                Text(health.adapterWatts.map { "Adapter: \(health.adapterName ?? "Unknown") (\($0)W)" } ?? "Adapter: not connected")
                Text(health.temperatureCelsius.map { String(format: "Temperature: %.1f°C", $0) } ?? "Temperature: unavailable on this Mac")
            } else {
                Text("Loading…")
            }

            if !monitor.topApps.isEmpty {
                Text("Top Energy Use")
                    .fontWeight(.semibold)
                    .padding(.top, 4)
                ForEach(monitor.topApps) { app in
                    HStack {
                        Text(app.name).lineLimit(1)
                        Spacer()
                        Text(String(format: "%.1f", app.power))
                    }
                }
            }
        }
        .foregroundStyle(.secondary)
        .padding(.top, 4)
    }

    private func apply(silently: Bool = false) {
        Task {
            await monitor.applySavedRange()
        }
    }
}
