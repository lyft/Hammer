import Darwin
import QuartzCore

// Singleton class that helps detect frame renders
@MainActor
final class FrameTracker {
    static let shared = FrameTracker()

    /// How long frames can stop before the time the main thread did not run counts as a stall.
    private static let stallThreshold: CFTimeInterval = 0.1

    private var displayLink: CADisplayLink?
    private var listeners: [@MainActor () -> Void] = []
    private let mainThread = pthread_mach_thread_np(pthread_self())
    private var lastFrameTime = CACurrentMediaTime()
    private var lastFrameCPUTime: CFTimeInterval = 0
    private var completedStallsTime: CFTimeInterval = 0

    /// The number of frames rendered so far.
    private(set) var frameCount = 0

    /// When the next frame is due, in `CACurrentMediaTime` seconds.
    private(set) var nextFrameTime: CFTimeInterval = 0

    /// The time the app had to run, in seconds. It leaves out the stalls where the main thread was blocked or
    /// not scheduled, such as on an overloaded machine, so timeouts measure the app and not the machine.
    var appTime: CFTimeInterval {
        CACurrentMediaTime() - self.completedStallsTime - self.currentStallTime
    }

    private init() {
        self.lastFrameCPUTime = self.mainThreadCPUTime()
        self.displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallback))
        self.displayLink?.add(to: .main, forMode: .common)
    }

    /// Adds a listener that will be called on the next frame render. Will only be called once
    ///
    /// - parameter listener: The listener to call on the next frame render
    func addNextFrameListener(_ listener: @escaping @MainActor () -> Void) {
        self.listeners.append(listener)
    }

    // MARK: - Private Methods

    /// The part of the time since the last frame that the main thread spent stalled, past the threshold so
    /// that app time stays continuous.
    private var currentStallTime: CFTimeInterval {
        let gap = CACurrentMediaTime() - self.lastFrameTime - FrameTracker.stallThreshold
        guard gap > 0 else {
            return 0
        }

        return max(gap - (self.mainThreadCPUTime() - self.lastFrameCPUTime), 0)
    }

    private func mainThreadCPUTime() -> CFTimeInterval {
        var info = thread_basic_info()
        let size = MemoryLayout<thread_basic_info>.size / MemoryLayout<integer_t>.size
        var count = mach_msg_type_number_t(size)
        let result = withUnsafeMutablePointer(to: &info) { info in
            info.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { info in
                thread_info(self.mainThread, thread_flavor_t(THREAD_BASIC_INFO), info, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return 0
        }

        let time = info.user_time.seconds + info.system_time.seconds
        let microseconds = info.user_time.microseconds + info.system_time.microseconds
        return CFTimeInterval(time) + CFTimeInterval(microseconds) / 1_000_000
    }

    @objc
    private func displayLinkCallback() {
        self.completedStallsTime += self.currentStallTime
        self.lastFrameTime = CACurrentMediaTime()
        self.lastFrameCPUTime = self.mainThreadCPUTime()
        self.frameCount += 1
        self.nextFrameTime = self.displayLink?.targetTimestamp ?? 0

        // Listeners added by a listener wait for the following frame
        let listeners = self.listeners
        self.listeners.removeAll(keepingCapacity: true)
        listeners.forEach { $0() }
    }
}
