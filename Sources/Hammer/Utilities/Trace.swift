import Darwin
import Foundation
import QuartzCore

// Temporary instrumentation for the slow first test on iOS 17. Not for merging.
enum Trace {
    static let start = CACurrentMediaTime()

    static let watchdog: Void = {
        let mainThread = pthread_mach_thread_np(pthread_self())
        Thread.detachNewThread {
            while true {
                let sent = CACurrentMediaTime()
                let mainCPU = Trace.cpuTime(of: mainThread)
                let processCPU = Trace.processCPUTime()
                let semaphore = DispatchSemaphore(value: 0)
                DispatchQueue.main.async { semaphore.signal() }
                if semaphore.wait(timeout: .now() + 0.2) == .timedOut {
                    semaphore.wait()
                    var load = [Double](repeating: 0, count: 3)
                    getloadavg(&load, 3)
                    Trace.log(String(
                        format: "main thread blocked for %.3fs, main cpu %.3fs, process cpu %.3fs, load %.1f",
                        CACurrentMediaTime() - sent, Trace.cpuTime(of: mainThread) - mainCPU,
                        Trace.processCPUTime() - processCPU, load[0]))
                }

                Thread.sleep(forTimeInterval: 0.05)
            }
        }
    }()

    static func log(_ message: String) {
        NSLog("HAMMERTRACE %@", String(format: "t=%.3f ", CACurrentMediaTime() - self.start) + message)
    }

    private static func cpuTime(of thread: thread_act_t) -> Double {
        var info = thread_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<thread_basic_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                thread_info(thread, thread_flavor_t(THREAD_BASIC_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return 0
        }

        return Double(info.user_time.seconds + info.system_time.seconds)
            + Double(info.user_time.microseconds + info.system_time.microseconds) / 1_000_000
    }

    private static func processCPUTime() -> Double {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
            + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
    }
}
