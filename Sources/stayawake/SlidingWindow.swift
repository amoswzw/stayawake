import Foundation

struct SlidingWindow {
    let duration: TimeInterval
    private var samples: [(time: Date, value: Double)] = []

    init(duration: TimeInterval) {
        self.duration = duration
    }

    mutating func add(_ value: Double, at time: Date = Date()) {
        samples.append((time, value))
        let cutoff = time.addingTimeInterval(-duration)
        while let first = samples.first, first.time < cutoff {
            samples.removeFirst()
        }
    }

    func percentile(_ p: Double) -> Double {
        guard !samples.isEmpty else { return 0 }
        let sorted = samples.map { $0.value }.sorted()
        let clamped = min(max(p, 0), 1)
        let idxFloat = clamped * Double(sorted.count - 1)
        let lo = Int(idxFloat.rounded(.down))
        let hi = Int(idxFloat.rounded(.up))
        if lo == hi { return sorted[lo] }
        let frac = idxFloat - Double(lo)
        return sorted[lo] * (1 - frac) + sorted[hi] * frac
    }
}
