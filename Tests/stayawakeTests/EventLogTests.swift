import XCTest
@testable import stayawake

final class EventLogTests: XCTestCase {
    func testDecisionLogsAreDeduplicatedByStateAndReason() {
        let log = EventLog(capacity: 10)

        XCTAssertTrue(log.recordDecisionIfChanged(
            state: .awake,
            action: "KEEP_AWAKE",
            reason: "resource busy"
        ))
        XCTAssertFalse(log.recordDecisionIfChanged(
            state: .awake,
            action: "KEEP_AWAKE",
            reason: "resource busy",
            note: "CPU changed, but reason did not"
        ))
        XCTAssertTrue(log.recordDecisionIfChanged(
            state: .awake,
            action: "KEEP_AWAKE",
            reason: "audio"
        ))
        XCTAssertTrue(log.recordDecisionIfChanged(
            state: .sleep,
            action: "ALLOW_SLEEP_SYSTEM",
            reason: "audio"
        ))

        let events = log.recent(limit: 10)
        XCTAssertEqual(events.map(\.reason), ["audio", "audio", "resource busy"])
    }

    func testDecisionTrackingCanBeResetAroundManualActions() {
        let log = EventLog(capacity: 10)

        XCTAssertTrue(log.recordDecisionIfChanged(
            state: .sleep,
            action: "ALLOW_SLEEP_SYSTEM",
            reason: "idle"
        ))
        XCTAssertFalse(log.recordDecisionIfChanged(
            state: .sleep,
            action: "ALLOW_SLEEP_SYSTEM",
            reason: "idle"
        ))

        log.resetDecisionTracking()

        XCTAssertTrue(log.recordDecisionIfChanged(
            state: .sleep,
            action: "ALLOW_SLEEP_SYSTEM",
            reason: "idle"
        ))
        XCTAssertEqual(log.recent(limit: 10).count, 2)
    }
}
