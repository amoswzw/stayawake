import Foundation

struct PolicyInput {
    var context: Context
    var signal: TaskSignal
    var manualOverride: ManualOverride?
    var now: Date
}

enum Policy {
    static func decide(_ input: PolicyInput) -> Action {
        if let override = input.manualOverride {
            switch override {
            case .untilOff:
                return .keepAwake(reason: L10n.s("reason.manual_until_off"))
            case .timed(let until):
                if input.now < until {
                    let remaining = Int(until.timeIntervalSince(input.now) / 60) + 1
                    return .keepAwake(reason: L10n.fmt("reason.manual_timed_format", remaining))
                }
            }
        }

        if input.context.onBattery && input.context.thermalState.isSleepPreferred {
            return .allowSleep(reason: L10n.s("reason.thermal_battery"))
        }

        if input.signal.isResourceBusy {
            return .keepAwake(reason: L10n.s("reason.resource_busy"))
        }
        if input.signal.audioActive {
            return .keepAwake(reason: L10n.s("reason.audio"))
        }

        if input.signal.hasUncertainSignals {
            return .keepAwake(reason: L10n.s("reason.uncertain_signals"))
        }

        if input.signal.hasRecentUserInput {
            if input.signal.hasActiveProcess {
                return .keepAwake(reason: L10n.s("reason.active_process_recent_input"))
            }
            if input.signal.hasForegroundWork {
                return .keepAwake(reason: L10n.s("reason.foreground_work_recent_input"))
            }
            if input.signal.fullscreenActive {
                return .keepAwake(reason: L10n.s("reason.fullscreen_recent_input"))
            }
        }

        if input.signal.isUserIdle {
            return .allowSleep(reason: L10n.s("reason.user_idle"))
        }

        return .allowSleep(reason: L10n.s("reason.no_keep_evidence"))
    }
}

struct SignalDeriver {
    var cpuThreshold: Double
    var networkThresholdBytesPerSec: Double
    var diskThresholdBytesPerSec: Double
    var idleThresholdSeconds: TimeInterval
    var taskProcessNames: Set<String>
    var workBundleIDs: Set<String>
    var blacklistBundleIDs: Set<String>

    func derive(from ctx: Context) -> TaskSignal {
        let processActive = !taskProcessNames.isDisjoint(with: ctx.runningProcessNames)

        let resourceBusy =
            ctx.maxCoreCPU >= cpuThreshold ||
            ctx.networkRateBytesPerSec >= networkThresholdBytesPerSec ||
            ctx.diskRateBytesPerSec >= diskThresholdBytesPerSec

        let frontBundle = ctx.frontmostBundleID ?? ""
        let isBlack = blacklistBundleIDs.contains(frontBundle)
        let isWhite = workBundleIDs.contains(frontBundle)
        let foregroundWork = !isBlack && isWhite
        let fullscreenFromBlockedApp = ctx.fullscreenOwnerBundleID.map(blacklistBundleIDs.contains) ?? false

        return TaskSignal(
            hasActiveProcess: processActive,
            isResourceBusy: resourceBusy,
            hasForegroundWork: foregroundWork,
            fullscreenActive: ctx.fullscreenActive && !fullscreenFromBlockedApp,
            audioActive: ctx.audioActive,
            isUserIdle: ctx.idleSeconds >= idleThresholdSeconds,
            hasRecentUserInput: ctx.idleSeconds < recentInputThresholdSeconds,
            hasUncertainSignals: !ctx.probeFailures.isEmpty
        )
    }

    private var recentInputThresholdSeconds: TimeInterval {
        min(120, max(30, idleThresholdSeconds / 5))
    }
}

private extension ProcessInfo.ThermalState {
    var isSleepPreferred: Bool {
        switch self {
        case .serious, .critical:
            return true
        default:
            return false
        }
    }
}
