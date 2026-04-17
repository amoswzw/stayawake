import Foundation
import Darwin

final class NetworkProbe {
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
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0, let head = addrs else { return nil }
        defer { freeifaddrs(head) }

        var sum: UInt64 = 0
        var cur: UnsafeMutablePointer<ifaddrs>? = head
        while let p = cur {
            defer { cur = p.pointee.ifa_next }
            guard let rawAddr = p.pointee.ifa_addr else { continue }
            if rawAddr.pointee.sa_family != UInt8(AF_LINK) { continue }
            guard let dataPtr = p.pointee.ifa_data else { continue }
            let name = String(cString: p.pointee.ifa_name)
            if name.hasPrefix("lo") { continue }
            let data = dataPtr.assumingMemoryBound(to: if_data.self)
            sum &+= UInt64(data.pointee.ifi_ibytes)
            sum &+= UInt64(data.pointee.ifi_obytes)
        }
        return sum
    }
}
