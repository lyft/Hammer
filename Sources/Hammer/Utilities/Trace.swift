import Foundation
import QuartzCore

// Temporary instrumentation for the slow first test on iOS 17. Not for merging.
enum Trace {
    static let start = CACurrentMediaTime()

    static let watchdog: Void = {
        Thread.detachNewThread {
            while true {
                let sent = CACurrentMediaTime()
                let semaphore = DispatchSemaphore(value: 0)
                DispatchQueue.main.async { semaphore.signal() }
                if semaphore.wait(timeout: .now() + 0.2) == .timedOut {
                    semaphore.wait()
                    Trace.log(String(format: "main thread blocked for %.3fs", CACurrentMediaTime() - sent))
                }

                Thread.sleep(forTimeInterval: 0.05)
            }
        }
    }()

    static func log(_ message: String) {
        NSLog("HAMMERTRACE %@", String(format: "t=%.3f ", CACurrentMediaTime() - self.start) + message)
    }
}
