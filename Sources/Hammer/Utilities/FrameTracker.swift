import QuartzCore

// Singleton class that helps detect frame renders
@MainActor
final class FrameTracker {
    static let shared = FrameTracker()

    private var displayLink: CADisplayLink?
    private var listeners: [@MainActor () -> Void] = []

    private init() {
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

    @objc
    private func displayLinkCallback() {
        // Listeners added by a listener wait for the following frame
        let listeners = self.listeners
        self.listeners.removeAll(keepingCapacity: true)
        listeners.forEach { $0() }
    }
}
