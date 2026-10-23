import Foundation
import Darwin

enum ProcessProbe {
    static func running(matching candidates: Set<String>) -> [pid_t: String] {
        guard !candidates.isEmpty else { return [:] }

        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size: size_t = 0

        var rc = mib.withUnsafeMutableBufferPointer { buf in
            sysctl(buf.baseAddress, u_int(buf.count), nil, &size, nil, 0)
        }
        guard rc == 0, size > 0 else { return [:] }

        let count = size / MemoryLayout<kinfo_proc>.stride
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: count)
        rc = procs.withUnsafeMutableBufferPointer { procBuf in
            mib.withUnsafeMutableBufferPointer { mibBuf in
                sysctl(mibBuf.baseAddress, u_int(mibBuf.count), procBuf.baseAddress, &size, nil, 0)
            }
        }
        guard rc == 0 else { return [:] }

        let actual = size / MemoryLayout<kinfo_proc>.stride
        let uid = getuid()
        var argsBuffer = [CChar](repeating: 0, count: argsBufferSize)
        var matches: [pid_t: String] = [:]
        for i in 0..<actual {
            let pid = procs[i].kp_proc.p_pid
            let name = withUnsafePointer(to: &procs[i].kp_proc.p_comm) { tuplePtr -> String in
                tuplePtr.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN) + 1) {
                    String(cString: $0)
                }
            }
            if candidates.contains(name) {
                matches[pid] = name
            } else if procs[i].kp_eproc.e_ucred.cr_uid == uid,
                      let launched = launchName(pid: pid, buffer: &argsBuffer),
                      candidates.contains(launched) {
                matches[pid] = launched
            }
        }
        return matches
    }

    private static let argsBufferSize = 4096

    // p_comm is the executable's file name truncated to 16 chars, which misses version-named
    // binaries (Claude Code's native install is `versions/2.1.x`) and long names. argv[0] is
    // what `ps` shows; only that string is parsed, the rest of the args/env is ignored.
    private static func launchName(pid: pid_t, buffer: inout [CChar]) -> String? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = buffer.count
        let rc = buffer.withUnsafeMutableBytes { buf in
            mib.withUnsafeMutableBufferPointer { mibBuf in
                sysctl(mibBuf.baseAddress, u_int(mibBuf.count), buf.baseAddress, &size, nil, 0)
            }
        }
        let headerSize = MemoryLayout<Int32>.size
        guard rc == 0, size > headerSize else { return nil }

        // Layout: argc, exec path, NUL padding, argv[0], ...
        var idx = headerSize
        while idx < size, buffer[idx] != 0 { idx += 1 }
        while idx < size, buffer[idx] == 0 { idx += 1 }
        let start = idx
        while idx < size, buffer[idx] != 0 { idx += 1 }
        guard idx < size, idx > start else { return nil }

        let argv0 = buffer[start..<idx].withUnsafeBufferPointer {
            String(decoding: UnsafeRawBufferPointer($0), as: UTF8.self)
        }
        return (argv0 as NSString).lastPathComponent
    }
}

final class TaskCPUProbe {
    private var prevTimes: [pid_t: UInt64] = [:]
    private var prevAt: Date?
    private static let nanosPerTick: Double = {
        var tb = mach_timebase_info_data_t()
        mach_timebase_info(&tb)
        return Double(tb.numer) / Double(tb.denom)
    }()

    /// Combined CPU of `pids` since the previous call, as a fraction of one core.
    func sampleUsage(pids: some Collection<pid_t>) -> Double {
        let now = Date()
        var times: [pid_t: UInt64] = [:]
        for pid in pids {
            var info = rusage_info_v0()
            let rc = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_V0, $0)
                }
            }
            if rc == 0 { times[pid] = info.ri_user_time &+ info.ri_system_time }
        }
        defer {
            prevTimes = times
            prevAt = now
        }
        guard let prevAt else { return 0 }
        let dt = now.timeIntervalSince(prevAt)
        guard dt > 0 else { return 0 }
        // A pid not seen last time counts its whole lifetime CPU, which biases toward keep awake.
        var ticks: UInt64 = 0
        for (pid, t) in times {
            ticks &+= t &- min(t, prevTimes[pid] ?? 0)
        }
        return Double(ticks) * Self.nanosPerTick / 1e9 / dt
    }
}
