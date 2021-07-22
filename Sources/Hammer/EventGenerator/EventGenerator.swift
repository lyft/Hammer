import CoreGraphics
import Foundation
import UIKit
#if canImport(SwiftUI)
import SwiftUI
#endif

private enum Storage {
    static var latestEventId: UInt32 = 0
}

/// Class for generating fake User Interaction events.
public final class EventGenerator {
    typealias CompletionHandler = () -> Void

    /// The window for the events
    public let window: UIWindow

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
    /// - parameter window: The window to receive events.
    public init(window: UIWindow) throws {
        self.window = window
        self.window.layoutIfNeeded()
        self.debugWindow.frame = self.window.frame

        UIApplication.swizzle()
        UIApplication.registerForHIDEvents(ObjectIdentifier(self)) { [weak self] event in
            self?.markerEventReceived(event)
        }

        try self.waitUntilWindowIsReady()
    }

    /// Initialize an event generator for a specified UIViewController.
    ///
    ///  Event Generator will temporarily create a wrapper UIWindow to send touches.
    ///
    /// - parameter viewController: The viewController to receive events.
    public convenience init(viewController: UIViewController) throws {
        let window = UIWindow(wrapping: viewController)

        if #available(iOS 13.0, *) {
            window.backgroundColor = .systemBackground
        } else {
            window.backgroundColor = .white
        }

        window.isHidden = false
        window.layoutIfNeeded()

        try self.init(window: window)
    }

    /// Initialize an event generator for a specified UIView.
    ///
    ///  Event Generator will temporarily create a wrapper UIWindow to send touches.
    ///
    /// - parameter view: The view to receive events.
    public convenience init(view: UIView) throws {
        try self.init(viewController: UIViewController(wrapping: view))
    }

    /// Initialize an event generator for a specified UIView.
    ///
    ///  Event Generator will temporarily create a wrapper UIWindow to send touches.
    ///
    /// - parameter view: The view to receive events.
    @available(iOS 13.0, *)
    public convenience init<Content: View>(view: Content) throws {
        try self.init(viewController: UIHostingController(wrapping: view))
    }

    deinit {
        UIApplication.unregisterForHIDEvents(ObjectIdentifier(self))
        if self.window.isWrapper {
            self.window.isHidden = true
            self.window.rootViewController = nil
            self.debugWindow.isHidden = true
            self.debugWindow.rootViewController = nil
            if #available(iOS 13.0, *) {
                self.window.windowScene = nil
                self.debugWindow.windowScene = nil
            }
        }
    }

    /// Waits until the window is ready to receive user interaction events.
    ///
    /// - parameter timeout: The maximum time to wait for the window to be ready.
    public func waitUntilWindowIsReady(timeout: TimeInterval = 5) throws {
        do {
            var initialMarkerEventReceived = false
            try self.sendMarkerEvent { initialMarkerEventReceived = true }
            try self.waitUntil(self.isWindowReady && initialMarkerEventReceived, timeout: timeout)
        } catch {
            throw HammerError.windowIsNotReadyForInteraction
        }
    }

    /// Returns if the window is ready to receive user interaction events
    public var isWindowReady: Bool {
        guard UIApplication.shared.keyWindow == self.window
                && self.window.isKeyWindow
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
        } else {
            guard !UIApplication.shared.isIgnoringInteractionEvents else {
                return false
            }
        }

        return true
    }

    /// The root view of the event generator
    public func rootView() throws -> UIView {
        if self.window.isWrapper {
            guard let view = self.window.rootViewController?.view else {
                throw HammerError.unableToFindMainView
            }

            if view.isWrapper {
                guard let wrappedView = view.subviews.first else {
                    throw HammerError.unableToFindMainView
                }

                return wrappedView
            }

            return view
        }

        return self.window
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

        let contextID = window.contextId
        guard contextID != 0 else {
            throw HammerError.unableToAccessPrivateApi(type: "UIWindow", method: "ContextID")
        }

        BackBoardServices.shared.eventSetDigitizerInfo(event, contextID, false, false, nil, 0, 0)

        app.enqueue(event)

        if wait {
            try self.waitForEvents()
        }
    }

    // MARK: - Sleep

    /// Sleeps the current thread until the events have finished sending.
    private func waitForEvents() throws {
        let runLoop = CFRunLoopGetCurrent()
        try self.sendMarkerEvent { CFRunLoopStop(runLoop) }
        CFRunLoopRun()
    }

    /// Sleeps the current thread for the specified duration.
    ///
    /// - parameter duration: The duration to sleep.
    func sleep(_ duration: TimeInterval) {
        guard duration > 0 else {
            return
        }

        CFRunLoopRunInMode(.defaultMode, duration, false)
    }
}
