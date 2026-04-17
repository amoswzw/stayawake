import Foundation
import CoreGraphics

enum IdleProbe {
    static func secondsSinceInput() -> TimeInterval? {
        guard let anyInput = CGEventType(rawValue: ~UInt32(0)) else { return nil }
        let seconds = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: anyInput
        )
        guard seconds.isFinite, seconds >= 0 else { return nil }
        return seconds
    }
}
