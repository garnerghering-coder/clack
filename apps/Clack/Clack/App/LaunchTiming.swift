// TEMPORARY measurement (not committed): prints ms since process start at named moments.
import Darwin
import Foundation

enum LaunchTiming {
    static let start: Double = {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        sysctl(&mib, 4, &info, &size, nil, 0)
        let t = info.kp_proc.p_un.__p_starttime
        return Double(t.tv_sec) + Double(t.tv_usec) / 1_000_000
    }()

    static func mark(_ name: String) {
        let ms = (Date().timeIntervalSince1970 - start) * 1000
        print("LAUNCHTIMING \(name) \(Int(ms))")
        fflush(stdout)
    }
}
