import Foundation

/// Polls `batt` for status and orchestrates top-up / calibration actions.
@MainActor
final class StatusMonitor: ObservableObject {
    static let shared = StatusMonitor()

    @Published private(set) var status: BattStatus?
    @Published var lastError: String?
    @Published private(set) var isToppingUp = false
    @Published var isCalibrating = false
    @Published var calibrationText: String?
    @Published private(set) var healthInfo: BatteryHealthInfo?
    @Published private(set) var topApps: [EnergyAppUsage] = []

    private var timer: Timer?

    /// True once `status` has told us charging control is unsupported (e.g. the
    /// current macOS-27-beta gap). PopoverView already shows a dedicated banner
    /// for that; suppress the redundant raw batt error in that case.
    private var isKnownUnsupported: Bool { status?.compatibility.chargingControl == false }

    private init() {}

    private func report(_ error: Error) {
        guard !isKnownUnsupported else { return }
        lastError = error.localizedDescription
    }

    func start() {
        Task { await refresh() }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    func refresh() async {
        do {
            let latest = try await BattController.status()
            status = latest
            lastError = nil
            if isToppingUp && latest.battery.currentChargePercent >= 99 {
                await applySavedRange()
                isToppingUp = false
            }
        } catch {
            lastError = error.localizedDescription
        }
        if isCalibrating {
            calibrationText = await BattController.calibrationStatusText()
        }
        async let health = SystemBatteryInfo.fetch()
        async let apps = TopEnergyApps.fetch()
        healthInfo = await health
        topApps = await apps
    }

    func applySavedRange() async {
        let settings = AppSettings.shared
        do {
            try await BattController.setRange(upper: settings.upperLimit, lowerDelta: settings.lowerDelta)
            lastError = nil
            await refresh()
        } catch {
            report(error)
        }
    }

    func topUp() async {
        do {
            try await BattController.topUpToFull()
            isToppingUp = true
            lastError = nil
            await refresh()
        } catch {
            report(error)
        }
    }

    func cancelTopUp() async {
        isToppingUp = false
        await applySavedRange()
    }

    func startCalibration() async {
        do {
            try await BattController.startCalibration()
            isCalibrating = true
            lastError = nil
            await refresh()
        } catch {
            report(error)
        }
    }

    func cancelCalibration() async {
        do {
            try await BattController.cancelCalibration()
            isCalibrating = false
            calibrationText = nil
            lastError = nil
            await refresh()
        } catch {
            report(error)
        }
    }
}
