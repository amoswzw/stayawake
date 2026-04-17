import Foundation

struct Event: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let action: String
    let reason: String
    let note: String?
    let until: Date?
    let duration: String?
}

enum DecisionLogState: String, Equatable {
    case awake
    case sleep
}

final class EventLog {
    static let shared = EventLog()

    private let capacity: Int
    private var buffer: [Event] = []
    private var lastDecision: (state: DecisionLogState, reason: String)?
    private let lock = NSLock()

    init(capacity: Int = 1024) {
        self.capacity = capacity
    }

    func record(
        action: String,
        reason: String,
        note: String? = nil,
        until: Date? = nil,
        duration: String? = nil
    ) {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(Event(
            timestamp: Date(),
            action: action,
            reason: reason,
            note: note,
            until: until,
            duration: duration
        ))
        if buffer.count > capacity {
            buffer.removeFirst(buffer.count - capacity)
        }
    }

    @discardableResult
    func recordDecisionIfChanged(
        state: DecisionLogState,
        action: String,
        reason: String,
        note: String? = nil,
        until: Date? = nil,
        duration: String? = nil
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if let lastDecision,
           lastDecision.state == state,
           lastDecision.reason == reason {
            return false
        }

        lastDecision = (state, reason)
        appendLocked(Event(
            timestamp: Date(),
            action: action,
            reason: reason,
            note: note,
            until: until,
            duration: duration
        ))
        return true
    }

    func resetDecisionTracking() {
        lock.lock()
        defer { lock.unlock() }
        lastDecision = nil
    }

    func recent(limit: Int = 200) -> [Event] {
        lock.lock()
        defer { lock.unlock() }
        return Array(buffer.suffix(limit).reversed())
    }

    private func appendLocked(_ event: Event) {
        buffer.append(event)
        if buffer.count > capacity {
            buffer.removeFirst(buffer.count - capacity)
        }
    }
}
