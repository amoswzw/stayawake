import Foundation
import Darwin

enum ProcessProbe {
    static func runningNames(matching candidates: Set<String>) -> Set<String> {
        guard !candidates.isEmpty else { return [] }

        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size: size_t = 0

        var rc = mib.withUnsafeMutableBufferPointer { buf in
            sysctl(buf.baseAddress, u_int(buf.count), nil, &size, nil, 0)
        }
        guard rc == 0, size > 0 else { return [] }

        let count = size / MemoryLayout<kinfo_proc>.stride
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: count)
        rc = procs.withUnsafeMutableBufferPointer { procBuf in
            mib.withUnsafeMutableBufferPointer { mibBuf in
                sysctl(mibBuf.baseAddress, u_int(mibBuf.count), procBuf.baseAddress, &size, nil, 0)
            }
        }
        guard rc == 0 else { return [] }

        let actual = size / MemoryLayout<kinfo_proc>.stride
        var names = Set<String>()
        names.reserveCapacity(min(actual, candidates.count))
        for i in 0..<actual {
            let name = withUnsafePointer(to: &procs[i].kp_proc.p_comm) { tuplePtr -> String in
                tuplePtr.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN) + 1) {
                    String(cString: $0)
                }
            }
            if candidates.contains(name) {
                names.insert(name)
                if names.count == candidates.count { break }
            }
        }
        return names
    }
}
