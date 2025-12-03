import CoreGraphics
import Foundation
import UIKit

private enum Storage {
    static var latestEventId: UInt32 = 0
}

/// Class for generating fake User Interaction events.
public final class EventGenerator {
    typealias CompletionHandler = () -> Void

    public enum WrappingAlignment {
        /// Expand to fill the full available space
        case fill

        /// Center inside the available space
        case center
    }

    /// The window for the events
    public let window: UIWindow

    /// The view that was used to create the event generator
    public let mainView: UIView

    var activeTouches = TouchStorage()
    var debugWindow = DebugVisualizerWindow()
    var eventCallbacks = [UInt32: CompletionHandler]()

    /// The default sender id for all events.
    ///
    /// Can be any value except 0.
    public var senderId: UInt64 = 0x0000000123456789

    /// If the generated touches should be displayed over the view.
    public var showTouches: Bool {
        get { self.debugWindow.isHidden == false }
        set { self.debugWindow.isHidden = !newValue }
    }

    /// Initialize an event generator for a specified UIWindow.
    ///
    /// - parameter window:   The window to receive events.
    /// - parameter mainView: The view that was used to create the event generator
    private init(window: UIWindow, mainView: UIView) throws {
        self.window = window
        self.mainView = mainView
        self.window.layoutIfNeeded()
        self.debugWindow.frame = self.window.frame

        UIApplication.swizzle()
        UIApplication.registerForHIDEvents(ObjectIdentifier(self)) { [weak self] event in
            self?.markerEventReceived(event)
        }
    }

    /// Initialize an event generator for a specified UIWindow.
    ///
    /// - parameter window: The window to receive events.
    public convenience init(window: UIWindow) throws {
        try self.init(window: window, mainView: window)
        try self.waitUntilWindowIsReady()
    }

    /// Initialize an event generator for a specified UIViewController.
    ///
    /// If the view controller's view does not have a window, this will temporarily create a wrapper
    /// UIWindow to send touches.
    ///
    /// - parameter viewController: The viewController to receive events.
    public convenience init(viewController: UIViewController) throws {
        if let window = viewController.view.window  {
            try self.init(window: window, mainView: viewController.view)
        } else {
            let window = HammerWindow()
            window.presentContained(viewController)
            try self.init(window: window, mainView: viewController.view)
        }

        try self.waitUntilWindowIsReady()
    }

    /// Initialize an event generator for a specified UIView.
    ///
    /// If the view does not have a window, this will temporarily create a wrapper UIWindow to send touches.
    ///
    /// - parameter view:      The view to receive events.
    /// - parameter alignment: The wrapping alignment to use.
    public convenience init(view: UIView, alignment: WrappingAlignment = .center) throws {
        if let window = view.window {
            try self.init(window: window, mainView: view)
        } else {
            let viewController = UIViewController(wrapping: view.topLevelView, alignment: alignment)
            let window = HammerWindow()
            window.presentContained(viewController)
            try self.init(window: window, mainView: view)
        }

        try self.waitUntilWindowIsReady()
    }

    deinit {
        UIApplication.unregisterForHIDEvents(ObjectIdentifier(self))
        self.debugWindow.removeFromScene()
        if let window = self.window as? HammerWindow {
            window.dismissContained()
        }
    }

    /// Waits until the window is ready to receive user interaction events.
    ///
    /// - parameter timeout: The maximum time to wait for the window to be ready.
    public func waitUntilWindowIsReady(timeout: TimeInterval = 3) throws {
        do {
            try self.waitUntil(self.isWindowReady, timeout: timeout)
            try self.waitUntilAccessibilityActivate()

            if EventGenerator.settings.waitForFrameRender {
                try self.waitUntilFrameIsRendered(timeout: timeout)
            }

            if EventGenerator.settings.waitForAnimations {
                try self.waitUntilAnimationsAreFinished(timeout: timeout)
            }

            try self.waitUntilRunloopIsFlushed(timeout: timeout)
        } catch {
            throw HammerError.windowIsNotReadyForInteraction
        }
    }

    /// Waits until animations are finished.
    ///
    /// - parameter timeout: The maximum time to wait for the window to be ready.
    public func waitUntilAnimationsAreFinished(timeout: TimeInterval) throws {
        try self.waitUntil(!self.hasRunningAnimations, timeout: timeout)
    }

    /// Returns if the window is ready to receive user interaction events
    public var isWindowReady: Bool {
        guard !(UIApplication.shared as UIApplicationDeprecated).isIgnoringInteractionEvents
                && self.window.isHidden == false
                && self.window.isUserInteractionEnabled
                && self.window.rootViewController?.viewIfLoaded != nil
                && self.window.rootViewController?.isBeingPresented == false
                && self.window.rootViewController?.isBeingDismissed == false
                && self.window.rootViewController?.isMovingToParent == false
                && self.window.rootViewController?.isMovingFromParent == false else
        {
            return false
        }

        if #available(iOS 13.0, *) {
            guard self.window.windowScene?.activationState == .foregroundActive else {
                return false
            }
        }

        if let hammerWindow = self.window as? HammerWindow, !hammerWindow.viewControllerHasAppeared {
            return false
        }

        return true
    }

    // Returns if the view or any of its subviews has running animations.
    public var hasRunningAnimations: Bool {
        // Recursive
        func hasRunningAnimations(currentView: UIView) -> Bool {
            // If the view is not visible, we do not need to consider it as running animation
            guard self.viewIsVisible(currentView) else {
                return false
            }

            // If there are animations running on the layer, return true
            if currentView.layer.animationKeys()?.isEmpty == false {
                return true
            }

            // Special case for parallax dimming view which happens during some animations
            if String(describing: type(of: currentView)) == "_UIParallaxDimmingView" {
                return true
            }

            // Traverse subviews
            return currentView.subviews.contains { hasRunningAnimations(currentView: $0) }
        }

        return hasRunningAnimations(currentView: self.window)
    }

    /// Gets the next event ID to use. Event IDs are global and sequential.
    ///
    /// - returns: The next event ID.
    func nextEventId() -> UInt32 {
        Storage.latestEventId += 1
        return Storage.latestEventId
    }

    /// Sends a user interaction event.
    ///
    /// - parameter event: The event to send.
    /// - parameter wait:  If we should wait until the event has finished being sent.
    func sendEvent(_ event: IOHIDEvent, wait: Bool) throws {
        guard let window = self.window as? UIWindow & UIWindowPrivate else {
            throw HammerError.unableToAccessPrivateApi(type: "UIWindow", method: "Protocol")
        }

        guard let app = UIApplication.shared as? UIApplication & UIApplicationPrivate else {
            throw HammerError.unableToAccessPrivateApi(type: "UIApplication", method: "Protocol")
        }

        BackBoardServices.shared.eventSetDigitizerInfo(event, window.contextId, false, false, nil, 0, 0)

        app.enqueue(event)

        if wait {
            try self.waitForEvents()
        }
    }

    // MARK: - Sleep

    /// Sleeps the current thread until the events have finished sending.
    private func waitForEvents() throws {
        let waiter = Waiter(timeout: 1)
        try self.sendMarkerEvent { try? waiter.complete() }
        try waiter.start()
    }

    // MARK: - Accessibility initialization

    private var isAccessibilityActivated = false

    private func waitUntilAccessibilityActivate() throws {
        guard EventGenerator.settings.forceActivateAccessibilityEngine else {
            return
        }

        UIApplication.shared.accessibilityActivate()
        if self.isAccessibilityActivated {
            return
        }

        // The first time the accessibility engine is activated in a simulator it needs more time to warm up
        // and start producing consistent results, after that only a short delay per test case is enough
        let simAccessibilityActivatedKey = "accessibility_activated"
        let simAccessibilityActivated = UserDefaults.standard.bool(forKey: simAccessibilityActivatedKey)
        if !simAccessibilityActivated {
            print("Activating accessibility engine for the first time in this simulator and waiting 5s")
        } else {
            print("Activating accessibility engine and waiting 0.1s")
        }

        try self.wait(
            simAccessibilityActivated
            ? EventGenerator.settings.accessibilityActivateDelay // Default: 0.02s
            : EventGenerator.settings.accessibilityActivateFirstTimeDelay // Default: 5.0s
        )

        self.isAccessibilityActivated = true
        if !simAccessibilityActivated {
            UserDefaults.standard.set(true, forKey: simAccessibilityActivatedKey)
        }
    }
}

// Bypasses deprecation warning for `isIgnoringInteractionEvents`
private protocol UIApplicationDeprecated {
    var isIgnoringInteractionEvents: Bool { get }
}

extension UIApplication: UIApplicationDeprecated {}
