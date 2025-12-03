import QuartzCore

final class FrameTracker {
    static let shared = FrameTracker()

    private var displayLink: CADisplayLink?
    private var listeners: [() -> Void] = []

    private init() {
        self.displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallback))
        self.displayLink?.add(to: .main, forMode: .common)
    }

    func addNextFrameListener(_ listener: @escaping () -> Void) {
        self.listeners.append(listener)
    }

    deinit {
        self.displayLink?.invalidate()
    }

    // MARK: - Private Methods

    @objc
    private func displayLinkCallback() {
        self.listeners.forEach { $0() }
        self.listeners.removeAll(keepingCapacity: true)
    }
}
