import Foundation
import IOKit

final class DiskProbe {
    private var prevTotal: UInt64 = 0
    private var prevTime: Date?

    func sampleRateBytesPerSec() -> Double? {
        let now = Date()
        guard let total = Self.totalBytes() else { return nil }
        defer {
            prevTotal = total
            prevTime = now
        }
        guard let last = prevTime else { return 0 }
        let dt = now.timeIntervalSince(last)
        guard dt > 0 else { return 0 }
        guard total >= prevTotal else { return 0 }
        let delta = total - prevTotal
        return Double(delta) / dt
    }

    private static func totalBytes() -> UInt64? {
        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOBlockStorageDriver"),
            &iterator
        )
        guard kr == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var sum: UInt64 = 0
        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 { break }
            defer { IOObjectRelease(service) }

            guard let stats = IORegistryEntryCreateCFProperty(
                service,
                "Statistics" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? [String: Any] else { continue }

            sum &+= uint64(stats["Bytes (Read)"])
            sum &+= uint64(stats["Bytes (Write)"])
        }
        return sum
    }

    private static func uint64(_ value: Any?) -> UInt64 {
        if let v = value as? UInt64 { return v }
        if let n = value as? NSNumber { return n.uint64Value }
        return 0
    }
}
