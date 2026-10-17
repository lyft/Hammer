import CoreGraphics
import Foundation
import UIKit

@MainActor
private enum Storage {
    static var latestEventId: UInt32 = 0

    /// The event generators that are not finished, oldest first.
    static var activeGenerators = [ObjectIdentifier]()
}

/// Class for generating fake User Interaction events.
@preconcurrency
@MainActor
public final class EventGenerator {
    typealias CompletionHandler = @MainActor () -> Void

    public enum WrappingAlignment: Sendable {
        /// Expand to fill the full available space
        case fill

        /// Center inside the available space
        case center
    }

    /// The window for the events
    public let window: UIWindow

    /// The view that was used to create the event generator
    public let mainView: UIView

    /// The settings for this event generator, starting from `EventGenerator.settings`.
    public var settings = EventGenerator.settings

    var activeTouches = TouchStorage()
    var pressedKeys = Set<KeyboardKey>()
    var debugWindow = DebugVisualizerWindow()
    var isAccessibilityActivated = false
    private(set) var isFinished = false

    /// The touches UIKit began delivering to the window since the last event was sent.
    var deliveredBeganTouches = [UITouch]()

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
    init(window: UIWindow, mainView: UIView) {
        self.window = window
        self.mainView = mainView
        self.window.layoutIfNeeded()
        self.debugWindow.frame = self.window.frame

        Storage.activeGenerators.append(ObjectIdentifier(self))
        UIApplication.swizzle()
        UIApplication.register(ObjectIdentifier(self), hidEventCallback: { event in
            EventGenerator.markerEventReceived(event)
        }, uiEventCallback: { [weak self] event in
            self?.eventDispatched(event)
        })
    }

    /// Initialize an event generator for a specified UIWindow.
    ///
    /// - parameter window: The window to receive events.
    public convenience init(window: UIWindow) async throws {
        self.init(window: window, mainView: window)
        try await self.waitUntilWindowIsReady()
    }

    /// Initialize an event generator for a specified UIViewController.
    ///
    /// If the view controller's view does not have a window, this will temporarily create a wrapper
    /// UIWindow to send touches.
    ///
    /// - parameter viewController: The viewController to receive events.
    public convenience init(viewController: UIViewController) async throws {
        self.init(window: EventGenerator.window(for: viewController), mainView: viewController.view)
        try await self.waitUntilWindowIsReady()
    }

    /// Initialize an event generator for a specified UIView.
    ///
    /// If the view does not have a window, this will temporarily create a wrapper UIWindow to send touches.
    ///
    /// - parameter view:      The view to receive events.
    /// - parameter alignment: The wrapping alignment to use.
    public convenience init(view: UIView, alignment: WrappingAlignment = .center) async throws {
        self.init(window: EventGenerator.window(for: view, alignment: alignment), mainView: view)
        try await self.waitUntilWindowIsReady()
    }

    /// Returns the view controller's window, or presents it in a new temporary window.
    ///
    /// - parameter viewController: The view controller to receive events.
    ///
    /// - returns: The window to send events to.
    static func window(for viewController: UIViewController) -> UIWindow {
        if let window = viewController.view.window {
            return window
        }

        let window = HammerWindow()
        window.presentContained(viewController)
        return window
    }

    /// Returns the view's window, or presents it in a new temporary window.
    ///
    /// - parameter view:      The view to receive events.
    /// - parameter alignment: The wrapping alignment to use.
    ///
    /// - returns: The window to send events to.
    static func window(for view: UIView, alignment: WrappingAlignment) -> UIWindow {
        if let window = view.window {
            return window
        }

        let window = HammerWindow()
        window.presentContained(UIViewController(wrapping: view.topLevelView, alignment: alignment))
        return window
    }

    deinit {
        // UIKit objects are only released on the main thread, and this often runs while an error thrown by
        // the test is propagating, even after `finish` because the views are released here
        MainActor.assumeIsolated {
            SwiftErrorHooks.suspend {
                guard !self.isFinished else {
                    return
                }

                // Deinit cannot suspend, but the window must stay until UIKit has cancelled the touches in it
                if self.enqueueReleaseEvents() {
                    var isProcessed = false
                    if (try? self.sendMarkerEvent { isProcessed = true }) != nil {
                        MainRunLoop.run(until: { isProcessed }, timeout: self.settings.eventProcessingTimeout)
                    }
                }

                self.removeFromApplication()
            }
        }
    }

    /// Lifts the fingers, stylus and keys still down and removes the windows Hammer added. No more events
    /// can be sent afterwards. Event generators that are not finished do this when they are released.
    ///
    /// - throws: `HammerError.eventProcessingTimeout` if UIKit did not process the released inputs in time.
    public func finish() async throws {
        guard !self.isFinished else {
            return
        }

        if self.enqueueReleaseEvents() {
            try await self.waitForEvents()
        }

        self.isFinished = true
        SwiftErrorHooks.suspend {
            self.removeFromApplication()
        }
    }

    /// Gets the next event ID to use. Event IDs are global and sequential.
    ///
    /// - returns: The next event ID.
    func nextEventId() -> UInt32 {
        Storage.latestEventId += 1
        return Storage.latestEventId
    }

    /// Sends a user interaction event and waits until UIKit has processed it.
    ///
    /// - parameter event: The event to send.
    ///
    /// - throws: `HammerError.eventProcessingTimeout` if UIKit did not process the event in time.
    func sendEvent(_ event: IOHIDEvent) async throws {
        try self.enqueueEvent(event)
        try await self.waitForEvents()
    }

    /// Hands a user interaction event to UIKit without waiting for it to be processed.
    ///
    /// - parameter event: The event to send.
    func enqueueEvent(_ event: IOHIDEvent) throws {
        guard let window = self.window as? UIWindow & UIWindowPrivate else {
            throw HammerError.unableToAccessPrivateApi(type: "UIWindow", method: "Protocol")
        }

        guard let app = UIApplication.shared as? UIApplication & UIApplicationPrivate else {
            throw HammerError.unableToAccessPrivateApi(type: "UIApplication", method: "Protocol")
        }

        BackBoardServices.shared.eventSetDigitizerInfo(event, window.contextId, false, false, nil, 0, 0)

        app.enqueue(event)
    }

    /// Throws if an event generator created after this one is still active, since their windows overlap and
    /// touches would reach the wrong one.
    func checkIsLatestActiveGenerator() throws {
        if Storage.activeGenerators.last != ObjectIdentifier(self) {
            throw HammerError.anotherEventGeneratorIsActive
        }
    }

    /// Waits until UIKit has processed all the events sent so far.
    ///
    /// - throws: `HammerError.eventProcessingTimeout` if UIKit did not process the events in time.
    func waitForEvents() async throws {
        let timeout = self.settings.eventProcessingTimeout
        do {
            // UIKit reacts to some events, such as by toggling a switch, at the end of the run loop pass
            try await self.waitForCompletion(timeout: timeout) { complete in
                try self.sendMarkerEvent { self.afterRunLoopPass(complete) }
            }
        } catch HammerError.waitConditionTimeout {
            throw HammerError.eventProcessingTimeout(timeout)
        }
    }

    // MARK: - Teardown

    /// Lifts the fingers, stylus and keys still down so UIKit does not keep them for the next test.
    ///
    /// - returns: If any events were enqueued.
    private func enqueueReleaseEvents() -> Bool {
        var events = self.pressedKeys.map { self.keyboardEvent(key: $0, isKeyDown: false) }
        if !self.activeTouches.fingers.isEmpty, let event = try? self.cancelFingersEvent() {
            events.append(event)
        }

        if self.activeTouches.stylus != nil, let event = try? self.cancelStylusEvent() {
            events.append(event)
        }

        events.forEach { try? self.enqueueEvent($0) }
        return !events.isEmpty
    }

    private func removeFromApplication() {
        Storage.activeGenerators.removeAll { $0 == ObjectIdentifier(self) }
        UIApplication.unregister(ObjectIdentifier(self))
        self.debugWindow.removeFromScene()
        if let window = self.window as? HammerWindow {
            window.dismissContained()
        }
    }
}
