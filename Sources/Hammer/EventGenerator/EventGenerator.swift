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
    var isAccessibilityActivated = false

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
    ///
    /// - throws: `HammerError.eventProcessingTimeout` if UIKit did not process the events in time.
    private func waitForEvents() throws {
        let timeout = EventGenerator.settings.eventProcessingTimeout
        do {
            try self.waitUntil({ waiter in
                try self.sendMarkerEvent { try? waiter.complete() }
            }, timeout: timeout)
        } catch HammerError.waitConditionTimeout {
            throw HammerError.eventProcessingTimeout(timeout)
        }
    }
}
