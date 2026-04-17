import XCTest
@testable import stayawake

final class PolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func baseCtx() -> Context { .empty }

    private func baseSignal() -> TaskSignal {
        TaskSignal(
            hasActiveProcess: false,
            isResourceBusy: false,
            hasForegroundWork: false,
            fullscreenActive: false,
            audioActive: false,
            isUserIdle: false,
            hasRecentUserInput: false,
            hasUncertainSignals: false
        )
    }

    func testManualOverrideUntilOffAlwaysKeepsAwake() {
        var s = baseSignal()
        s.isUserIdle = true
        let action = Policy.decide(PolicyInput(
            context: baseCtx(),
            signal: s,
            manualOverride: .untilOff,
            now: now
        ))
        guard case .keepAwake = action else {
            XCTFail("expected keepAwake, got \(action)"); return
        }
    }

    func testManualOverrideTimedActiveKeepsAwake() {
        let action = Policy.decide(PolicyInput(
            context: baseCtx(),
            signal: baseSignal(),
            manualOverride: .timed(until: now.addingTimeInterval(300)),
            now: now
        ))
        guard case .keepAwake = action else {
            XCTFail("expected keepAwake"); return
        }
    }

    func testManualOverrideTimedExpiredFallsThrough() {
        var s = baseSignal()
        s.isUserIdle = true
        let action = Policy.decide(PolicyInput(
            context: baseCtx(),
            signal: s,
            manualOverride: .timed(until: now.addingTimeInterval(-1)),
            now: now
        ))
        guard case .allowSleep = action else {
            XCTFail("expected allowSleep, got \(action)"); return
        }
    }

    func testActiveProcessAloneAllowsSleep() {
        var s = baseSignal()
        s.hasActiveProcess = true
        let action = Policy.decide(PolicyInput(
            context: baseCtx(), signal: s, manualOverride: nil, now: now
        ))
        guard case .allowSleep = action else { XCTFail(); return }
    }

    func testActiveProcessWithRecentInputKeepsAwake() {
        var s = baseSignal()
        s.hasActiveProcess = true
        s.hasRecentUserInput = true
        let action = Policy.decide(PolicyInput(
            context: baseCtx(), signal: s, manualOverride: nil, now: now
        ))
        guard case .keepAwake = action else { XCTFail(); return }
    }

    func testResourceBusyKeepsAwake() {
        var s = baseSignal()
        s.isResourceBusy = true
        s.isUserIdle = true
        let action = Policy.decide(PolicyInput(
            context: baseCtx(), signal: s, manualOverride: nil, now: now
        ))
        guard case .keepAwake = action else { XCTFail(); return }
    }

    func testFullscreenAloneAllowsSleep() {
        var s = baseSignal()
        s.fullscreenActive = true
        let action = Policy.decide(PolicyInput(
            context: baseCtx(), signal: s, manualOverride: nil, now: now
        ))
        guard case .allowSleep = action else { XCTFail(); return }
    }

    func testFullscreenWithRecentInputKeepsAwake() {
        var s = baseSignal()
        s.fullscreenActive = true
        s.hasRecentUserInput = true
        let action = Policy.decide(PolicyInput(
            context: baseCtx(), signal: s, manualOverride: nil, now: now
        ))
        guard case .keepAwake = action else { XCTFail(); return }
    }

    func testAudioKeepsAwake() {
        var s = baseSignal()
        s.audioActive = true
        s.isUserIdle = true
        let action = Policy.decide(PolicyInput(
            context: baseCtx(), signal: s, manualOverride: nil, now: now
        ))
        guard case .keepAwake = action else { XCTFail(); return }
    }

    func testForegroundWorkAloneAllowsSleep() {
        var s = baseSignal()
        s.hasForegroundWork = true
        let action = Policy.decide(PolicyInput(
            context: baseCtx(), signal: s, manualOverride: nil, now: now
        ))
        guard case .allowSleep = action else { XCTFail(); return }
    }

    func testForegroundWorkWithRecentInputKeepsAwake() {
        var s = baseSignal()
        s.hasForegroundWork = true
        s.hasRecentUserInput = true
        let action = Policy.decide(PolicyInput(
            context: baseCtx(), signal: s, manualOverride: nil, now: now
        ))
        guard case .keepAwake = action else { XCTFail(); return }
    }

    func testIdleWithNoSignalsAllowsSleep() {
        var s = baseSignal()
        s.isUserIdle = true
        let action = Policy.decide(PolicyInput(
            context: baseCtx(), signal: s, manualOverride: nil, now: now
        ))
        guard case .allowSleep = action else { XCTFail(); return }
    }

    func testRecentInputNoSignalsAllowsSleep() {
        var s = baseSignal()
        s.hasRecentUserInput = true
        let action = Policy.decide(PolicyInput(
            context: baseCtx(), signal: s, manualOverride: nil, now: now
        ))
        guard case .allowSleep = action else { XCTFail(); return }
    }

    func testCriticalThermalOnBatteryAllowsSleep() {
        var ctx = baseCtx()
        ctx.onBattery = true
        ctx.thermalState = .critical
        var s = baseSignal()
        s.hasActiveProcess = true  // even with activity
        let action = Policy.decide(PolicyInput(
            context: ctx, signal: s, manualOverride: nil, now: now
        ))
        guard case .allowSleep = action else { XCTFail(); return }
    }

    func testSeriousThermalOnBatteryAllowsSleep() {
        var ctx = baseCtx()
        ctx.onBattery = true
        ctx.thermalState = .serious
        var s = baseSignal()
        s.hasActiveProcess = true
        let action = Policy.decide(PolicyInput(
            context: ctx, signal: s, manualOverride: nil, now: now
        ))
        guard case .allowSleep = action else { XCTFail(); return }
    }

    func testCriticalThermalOnACKeepsAwake() {
        var ctx = baseCtx()
        ctx.onBattery = false
        ctx.thermalState = .critical
        var s = baseSignal()
        s.hasActiveProcess = true
        s.hasRecentUserInput = true
        let action = Policy.decide(PolicyInput(
            context: ctx, signal: s, manualOverride: nil, now: now
        ))
        guard case .keepAwake = action else { XCTFail(); return }
    }

    func testUncertainSignalsKeepAwake() {
        var ctx = baseCtx()
        ctx.probeFailures = [.idle]
        let deriver = SignalDeriver(
            cpuThreshold: 0.3,
            networkThresholdBytesPerSec: 50_000,
            diskThresholdBytesPerSec: 1_000_000,
            idleThresholdSeconds: 600,
            taskProcessNames: [],
            workBundleIDs: [],
            blacklistBundleIDs: []
        )
        let s = deriver.derive(from: ctx)
        let action = Policy.decide(PolicyInput(
            context: ctx, signal: s, manualOverride: nil, now: now
        ))
        guard case .keepAwake = action else { XCTFail(); return }
    }

    func testSignalDeriverMatchesProcess() {
        var ctx = baseCtx()
        ctx.runningProcessNames = ["zsh", "ffmpeg", "Xcode"]
        let deriver = SignalDeriver(
            cpuThreshold: 0.3,
            networkThresholdBytesPerSec: 50_000,
            diskThresholdBytesPerSec: 1_000_000,
            idleThresholdSeconds: 600,
            taskProcessNames: ["ffmpeg", "rsync"],
            workBundleIDs: [],
            blacklistBundleIDs: []
        )
        let s = deriver.derive(from: ctx)
        XCTAssertTrue(s.hasActiveProcess)
    }

    func testDefaultConfigIncludesAIAgentProcesses() {
        let names = Config().taskProcessNames
        XCTAssertTrue(names.contains("claude"))
        XCTAssertTrue(names.contains("codex"))
        XCTAssertTrue(names.contains("gemini"))
        XCTAssertTrue(names.contains("opencode"))
    }

    func testSignalDeriverRecentInputWindow() {
        var ctx = baseCtx()
        ctx.idleSeconds = 60
        let deriver = SignalDeriver(
            cpuThreshold: 0.3,
            networkThresholdBytesPerSec: 50_000,
            diskThresholdBytesPerSec: 1_000_000,
            idleThresholdSeconds: 600,
            taskProcessNames: [],
            workBundleIDs: [],
            blacklistBundleIDs: []
        )
        XCTAssertTrue(deriver.derive(from: ctx).hasRecentUserInput)

        ctx.idleSeconds = 180
        XCTAssertFalse(deriver.derive(from: ctx).hasRecentUserInput)
    }

    func testSignalDeriverBlacklistSuppressesMatchingFullscreenButNotAudio() {
        var ctx = baseCtx()
        ctx.frontmostBundleID = "com.example.idle"
        ctx.fullscreenActive = true
        ctx.fullscreenOwnerBundleID = "com.example.idle"
        ctx.audioActive = true
        let deriver = SignalDeriver(
            cpuThreshold: 0.3,
            networkThresholdBytesPerSec: 50_000,
            diskThresholdBytesPerSec: 1_000_000,
            idleThresholdSeconds: 600,
            taskProcessNames: [],
            workBundleIDs: [],
            blacklistBundleIDs: ["com.example.idle"]
        )
        let s = deriver.derive(from: ctx)
        XCTAssertFalse(s.fullscreenActive)
        XCTAssertTrue(s.audioActive)
        XCTAssertFalse(s.hasForegroundWork)
    }

    func testSignalDeriverBlacklistDoesNotSuppressOtherFullscreenOwner() {
        var ctx = baseCtx()
        ctx.frontmostBundleID = "com.example.idle"
        ctx.fullscreenActive = true
        ctx.fullscreenOwnerBundleID = "com.example.video"
        let deriver = SignalDeriver(
            cpuThreshold: 0.3,
            networkThresholdBytesPerSec: 50_000,
            diskThresholdBytesPerSec: 1_000_000,
            idleThresholdSeconds: 600,
            taskProcessNames: [],
            workBundleIDs: [],
            blacklistBundleIDs: ["com.example.idle"]
        )
        let s = deriver.derive(from: ctx)
        XCTAssertTrue(s.fullscreenActive)
    }

    func testSlidingWindowP75() {
        var w = SlidingWindow(duration: 100)
        let t = Date(timeIntervalSince1970: 0)
        for (i, v) in [1.0, 2.0, 3.0, 4.0, 5.0].enumerated() {
            w.add(v, at: t.addingTimeInterval(TimeInterval(i)))
        }
        XCTAssertEqual(w.percentile(0.75), 4.0, accuracy: 0.001)
    }

    func testSlidingWindowEvicts() {
        var w = SlidingWindow(duration: 10)
        let t = Date(timeIntervalSince1970: 0)
        w.add(100, at: t)
        w.add(1, at: t.addingTimeInterval(20))
        XCTAssertEqual(w.percentile(0.75), 1, accuracy: 0.001)
    }
}
