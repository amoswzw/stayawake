import AppKit
import Combine
import Foundation

@MainActor
final class AppCoordinator: ObservableObject {
    static let shared = AppCoordinator()
    private static let manualUntilOffCheckInterval: TimeInterval = 300
    private static let systemEventRefreshDelay: TimeInterval = 3

    @Published private(set) var lastContext: Context = .empty
    @Published private(set) var lastSignal: TaskSignal = TaskSignal(
        hasActiveProcess: false,
        isResourceBusy: false,
        hasForegroundWork: false,
        fullscreenActive: false,
        audioActive: false,
        isUserIdle: false,
        hasRecentUserInput: false,
        hasUncertainSignals: false
    )
    @Published private(set) var lastAction: Action = .noChange
    @Published private(set) var isAwake: Bool = false
    @Published private(set) var assertionReason: String?
    @Published private(set) var keepAwakeTiming: String?
    @Published private(set) var manualOverride: ManualOverride?

    private let collector = SignalCollector()
    private let power = PowerAssertionManager()
    private let config = ConfigStore.shared
    private let log = EventLog.shared

    private var timer: Timer?
    private var configObserver: NSObjectProtocol?
    private var systemEventObservers: [(NotificationCenter, NSObjectProtocol)] = []
    private var pendingSystemEventTimer: Timer?
    private var currentSampleInterval: TimeInterval?
    private var lastAssertionFailureReason: String?
    private var nextAutomaticCheckAt: Date?

    private struct KeepAwakeMetadata {
        let note: String?
        let until: Date?
        let duration: String?
    }

    func start() {
        log.resetDecisionTracking()
        EventLog.shared.record(action: "START", reason: L10n.s("event.app_started"))
        observeConfigChanges()
        observeSystemEvents()
        tick()
        scheduleTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        pendingSystemEventTimer?.invalidate()
        pendingSystemEventTimer = nil
        if let configObserver {
            NotificationCenter.default.removeObserver(configObserver)
            self.configObserver = nil
        }
        for (center, token) in systemEventObservers {
            center.removeObserver(token)
        }
        systemEventObservers.removeAll()
        power.release()
        EventLog.shared.record(action: "STOP", reason: L10n.s("event.app_stopping"))
    }

    func setManualOverride(_ override: ManualOverride?) {
        manualOverride = override
        log.resetDecisionTracking()
        switch override {
        case .untilOff:
            log.record(
                action: "MANUAL",
                reason: L10n.s("event.manual_until_off"),
                note: L10n.s("log.detail.manual"),
                duration: L10n.s("duration.until_off")
            )
        case .timed(let until):
            log.record(
                action: "MANUAL",
                reason: L10n.fmt("event.manual_until_format", Self.fmt(until)),
                note: L10n.s("log.detail.manual"),
                until: until,
                duration: timedDuration(until)
            )
        case .none:
            log.record(action: "AUTO", reason: L10n.s("event.resume_auto"))
        }
        nextAutomaticCheckAt = nil
        tick()
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let interval = nextTimerInterval()
        let t = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
        t.tolerance = min(10, max(1, interval * 0.2))
        RunLoop.main.add(t, forMode: .common)
        timer = t
        currentSampleInterval = interval
    }

    private func observeConfigChanges() {
        guard configObserver == nil else { return }
        configObserver = NotificationCenter.default.addObserver(
            forName: ConfigStore.didChangeNotification,
            object: config,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.configDidChange() }
        }
    }

    private func observeSystemEvents() {
        guard systemEventObservers.isEmpty else { return }
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let distributedCenter = DistributedNotificationCenter.default()
        let delayedHandler: @Sendable (Notification) -> Void = { [weak self] _ in
            Task { @MainActor [weak self] in self?.scheduleSystemEventRefresh() }
        }
        let immediateHandler: @Sendable (Notification) -> Void = { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshSystemEventNow() }
        }
        systemEventObservers.append((
            workspaceCenter,
            workspaceCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main,
                using: delayedHandler
            )
        ))
        systemEventObservers.append((
            distributedCenter,
            distributedCenter.addObserver(
                forName: Notification.Name("com.apple.screenIsUnlocked"),
                object: nil,
                queue: .main,
                using: delayedHandler
            )
        ))
        systemEventObservers.append((
            distributedCenter,
            distributedCenter.addObserver(
                forName: Notification.Name("com.apple.screenIsLocked"),
                object: nil,
                queue: .main,
                using: immediateHandler
            )
        ))
    }

    private func scheduleSystemEventRefresh() {
        pendingSystemEventTimer?.invalidate()
        let t = Timer(timeInterval: Self.systemEventRefreshDelay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.pendingSystemEventTimer = nil
                self.nextAutomaticCheckAt = nil
                self.tick()
            }
        }
        t.tolerance = 0.5
        RunLoop.main.add(t, forMode: .common)
        pendingSystemEventTimer = t
    }

    private func refreshSystemEventNow() {
        pendingSystemEventTimer?.invalidate()
        pendingSystemEventTimer = nil
        nextAutomaticCheckAt = nil
        tick()
    }

    private func configDidChange() {
        let cfg = config.config
        if power.isAwake, power.preventsDisplaySleep != cfg.keepDisplayAwake {
            let reason = power.reason ?? L10n.s("reason.no_keep_evidence")
            if !power.ensureAwake(reason: reason, preventDisplaySleep: cfg.keepDisplayAwake),
               lastAssertionFailureReason != reason {
                lastAssertionFailureReason = reason
                log.record(action: "ERROR", reason: L10n.fmt("event.assertion_failed_format", reason))
            }
            isAwake = power.isAwake
            assertionReason = power.reason
        }
        let interval = nextTimerInterval()
        if currentSampleInterval != interval {
            scheduleTimer()
        }
    }

    private func tick() {
        if case .timed(let until) = manualOverride, Date() >= until {
            manualOverride = nil
            log.record(action: "AUTO", reason: L10n.s("event.manual_expired"))
        }

        let cfg = config.config

        if let manualOverride {
            let action = Policy.decide(PolicyInput(
                context: lastContext,
                signal: lastSignal,
                manualOverride: manualOverride,
                now: Date()
            ))
            apply(
                action,
                cfg: cfg,
                context: lastContext,
                signal: lastSignal,
                override: manualOverride
            )
            lastAction = action
            isAwake = power.isAwake
            assertionReason = power.reason
            keepAwakeTiming = power.isAwake ? keepAwakeTiming : nil
            scheduleTimer()
            return
        }

        if let nextAutomaticCheckAt, Date() < nextAutomaticCheckAt {
            keepAwakeTiming = power.isAwake ? L10n.fmt("duration.automatic_format", Int(cfg.cooldownSeconds)) : nil
            scheduleTimer()
            return
        }
        nextAutomaticCheckAt = nil

        let ctx = collector.sample(taskProcessNames: cfg.taskProcessNames)
        let deriver = SignalDeriver(
            cpuThreshold: cfg.cpuThreshold,
            networkThresholdBytesPerSec: cfg.networkThresholdBytesPerSec,
            diskThresholdBytesPerSec: cfg.diskThresholdBytesPerSec,
            idleThresholdSeconds: cfg.idleThresholdSeconds,
            taskProcessNames: cfg.taskProcessNames,
            workBundleIDs: cfg.workBundleIDs,
            blacklistBundleIDs: cfg.blacklistBundleIDs
        )
        let signal = deriver.derive(from: ctx)
        let input = PolicyInput(
            context: ctx,
            signal: signal,
            manualOverride: manualOverride,
            now: Date()
        )
        let action = Policy.decide(input)

        apply(action, cfg: cfg, context: ctx, signal: signal, override: manualOverride)

        lastContext = ctx
        lastSignal = signal
        lastAction = action
        isAwake = power.isAwake
        assertionReason = power.reason
        if !power.isAwake {
            keepAwakeTiming = nil
        }
        scheduleTimer()
    }

    private func apply(
        _ action: Action,
        cfg: Config,
        context: Context,
        signal: TaskSignal,
        override: ManualOverride?
    ) {
        switch action {
        case .keepAwake(let reason):
            let metadata = keepAwakeMetadata(
                context: context,
                signal: signal,
                cfg: cfg,
                override: override
            )
            let preventDisplay = cfg.keepDisplayAwake
            if !power.isAwake
                || power.reason != reason
                || power.preventsDisplaySleep != preventDisplay
            {
                if power.ensureAwake(reason: reason, preventDisplaySleep: preventDisplay) {
                    lastAssertionFailureReason = nil
                } else if lastAssertionFailureReason != reason {
                    lastAssertionFailureReason = reason
                    log.record(action: "ERROR", reason: L10n.fmt("event.assertion_failed_format", reason))
                }
            }
            if power.isAwake {
                if override == nil {
                    log.recordDecisionIfChanged(
                        state: .awake,
                        action: "KEEP_AWAKE",
                        reason: reason,
                        note: metadata.note,
                        until: metadata.until,
                        duration: metadata.duration
                    )
                }
            }
            keepAwakeTiming = metadata.duration
            scheduleNextAutomaticCheck(after: cfg.cooldownSeconds, enabled: override == nil)

        case .allowSleep(let reason):
            let action: String
            if power.isAwake {
                action = "ALLOW_SLEEP_RELEASED"
                power.release()
            } else {
                action = "ALLOW_SLEEP_SYSTEM"
            }
            if override == nil {
                log.recordDecisionIfChanged(
                    state: .sleep,
                    action: action,
                    reason: reason,
                    note: nil,
                    until: nil,
                    duration: nil
                )
            }
            keepAwakeTiming = nil
            scheduleNextAutomaticCheck(after: cfg.cooldownSeconds, enabled: override == nil)

        case .noChange:
            nextAutomaticCheckAt = nil
        }
    }

    private func nextTimerInterval() -> TimeInterval {
        if case .timed(let until) = manualOverride {
            return max(1, ceil(until.timeIntervalSinceNow))
        }
        if case .untilOff = manualOverride {
            return Self.manualUntilOffCheckInterval
        }
        if let nextAutomaticCheckAt, manualOverride == nil {
            return max(1, ceil(nextAutomaticCheckAt.timeIntervalSinceNow))
        }
        return Self.normalizedSampleInterval(config.config.sampleIntervalSeconds)
    }

    private func scheduleNextAutomaticCheck(after seconds: TimeInterval, enabled: Bool) {
        guard enabled else {
            nextAutomaticCheckAt = nil
            return
        }
        nextAutomaticCheckAt = Date().addingTimeInterval(max(1, seconds))
    }

    private func keepAwakeMetadata(
        context: Context,
        signal: TaskSignal,
        cfg: Config,
        override: ManualOverride?
    ) -> KeepAwakeMetadata {
        if let override {
            switch override {
            case .untilOff:
                return KeepAwakeMetadata(
                    note: L10n.s("log.detail.manual"),
                    until: nil,
                    duration: L10n.s("duration.until_off")
                )
            case .timed(let until):
                return KeepAwakeMetadata(
                    note: L10n.s("log.detail.manual"),
                    until: until,
                    duration: timedDuration(until)
                )
            }
        }

        let note: String
        if signal.isResourceBusy {
            note = resourceDetail(context: context, cfg: cfg)
        } else if signal.audioActive {
            note = L10n.s("log.detail.audio")
        } else if signal.hasUncertainSignals {
            let failures = context.probeFailures.map(\.rawValue).sorted().joined(separator: ", ")
            note = L10n.fmt("log.detail.uncertain_format", failures)
        } else if signal.hasActiveProcess {
            let names = context.runningProcessNames.sorted().prefix(6).joined(separator: ", ")
            let detail = names.isEmpty ? L10n.s("log.detail.active_process_unknown") : L10n.fmt("log.detail.active_process_format", names)
            note = detailWithRecentInput(detail, context: context)
        } else if signal.hasForegroundWork {
            note = detailWithRecentInput(foregroundDetail(context), context: context)
        } else if signal.fullscreenActive {
            let detail = context.fullscreenOwnerBundleID.map {
                L10n.fmt("log.detail.fullscreen_format", $0)
            } ?? L10n.s("log.detail.fullscreen_unknown")
            note = detailWithRecentInput(detail, context: context)
        } else {
            note = L10n.s("log.detail.automatic")
        }

        return KeepAwakeMetadata(
            note: note,
            until: nil,
            duration: L10n.fmt("duration.automatic_format", Int(cfg.cooldownSeconds))
        )
    }

    private func resourceDetail(context: Context, cfg: Config) -> String {
        var parts: [String] = []
        if context.maxCoreCPU >= cfg.cpuThreshold {
            parts.append(L10n.fmt("log.detail.cpu_format", Int(context.maxCoreCPU * 100), Int(cfg.cpuThreshold * 100)))
        }
        if context.networkRateBytesPerSec >= cfg.networkThresholdBytesPerSec {
            parts.append(L10n.fmt(
                "log.detail.network_format",
                Self.bytesPerSecond(context.networkRateBytesPerSec),
                Self.bytesPerSecond(cfg.networkThresholdBytesPerSec)
            ))
        }
        if context.diskRateBytesPerSec >= cfg.diskThresholdBytesPerSec {
            parts.append(L10n.fmt(
                "log.detail.disk_format",
                Self.bytesPerSecond(context.diskRateBytesPerSec),
                Self.bytesPerSecond(cfg.diskThresholdBytesPerSec)
            ))
        }
        return parts.isEmpty ? L10n.s("log.detail.resource") : parts.joined(separator: "; ")
    }

    private func detailWithRecentInput(_ detail: String, context: Context) -> String {
        let input = L10n.fmt("log.detail.recent_input_format", Int(context.idleSeconds))
        return "\(detail); \(input)"
    }

    private func foregroundDetail(_ context: Context) -> String {
        if let name = context.frontmostName, let bundle = context.frontmostBundleID {
            return L10n.fmt("log.detail.foreground_name_format", name, bundle)
        }
        if let bundle = context.frontmostBundleID {
            return L10n.fmt("log.detail.foreground_format", bundle)
        }
        return L10n.s("log.detail.foreground_unknown")
    }

    private func timedDuration(_ until: Date) -> String {
        L10n.fmt("duration.until_format", Self.fmt(until), Self.remaining(until))
    }

    private static func normalizedSampleInterval(_ interval: TimeInterval) -> TimeInterval {
        max(1, interval)
    }

    private static func fmt(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: date)
    }

    private static func remaining(_ date: Date) -> String {
        let seconds = max(0, Int(ceil(date.timeIntervalSinceNow)))
        if seconds >= 3600 {
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            return L10n.fmt("duration.remaining_hours_format", hours, minutes)
        }
        return L10n.fmt("duration.remaining_minutes_format", max(1, Int(ceil(Double(seconds) / 60))))
    }

    private static func bytesPerSecond(_ value: Double) -> String {
        if value >= 1024 * 1024 {
            return String(format: "%.1f MB/s", value / 1024 / 1024)
        }
        return String(format: "%.0f KB/s", value / 1024)
    }
}
