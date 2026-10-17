import Foundation
import UIKit

/// The reason a window is not ready to receive user interaction events.
public enum WindowNotReadyReason: Equatable, Sendable {
    /// The application is ignoring interaction events, usually during a transition.
    case applicationIsIgnoringInteractionEvents

    /// The window is hidden.
    case windowIsHidden

    /// The window has user interaction disabled.
    case windowUserInteractionIsDisabled

    /// The window is not attached to a scene.
    case windowHasNoScene

    /// The window's scene is not foreground active, for example because the host app is in the background
    /// or a system alert is covering it.
    case sceneIsNotForegroundActive(activationState: String)

    /// The window's root view controller has not loaded its view.
    case rootViewControllerIsNotLoaded

    /// The window's root view controller is being presented, dismissed or moved.
    case rootViewControllerIsTransitioning

    /// The view controller that contains the view has not appeared yet.
    case viewControllerHasNotAppeared

    /// No frame was rendered, usually because the app is not on screen.
    case frameWasNotRendered

    /// Animations on the window were still running.
    case animationsAreRunning

    /// The main run loop did not get to the work scheduled on it.
    case runLoopIsBusy
}

extension WindowNotReadyReason: CustomStringConvertible {
    public var description: String {
        switch self {
        case .applicationIsIgnoringInteractionEvents:
            return "the application is ignoring interaction events"
        case .windowIsHidden:
            return "the window is hidden"
        case .windowUserInteractionIsDisabled:
            return "the window has user interaction disabled"
        case .windowHasNoScene:
            return "the window is not attached to a scene"
        case .sceneIsNotForegroundActive(let activationState):
            return "the window's scene is not foreground active (\(activationState)), the host app may be "
                + "in the background or covered by a system alert"
        case .rootViewControllerIsNotLoaded:
            return "the window's root view controller has not loaded its view"
        case .rootViewControllerIsTransitioning:
            return "the window's root view controller is being presented, dismissed or moved"
        case .viewControllerHasNotAppeared:
            return "the view controller containing the view has not appeared"
        case .frameWasNotRendered:
            return "no frame was rendered, the app may not be on screen"
        case .animationsAreRunning:
            return "animations are still running"
        case .runLoopIsBusy:
            return "the main run loop did not get to scheduled work"
        }
    }
}

extension EventGenerator {
    /// Returns if the window is ready to receive user interaction events.
    public var isWindowReady: Bool {
        return self.windowNotReadyReason == nil
    }

    /// The reason the window is not ready to receive user interaction events, nil if it is ready.
    public var windowNotReadyReason: WindowNotReadyReason? {
        if (UIApplication.shared as UIApplicationDeprecated).isIgnoringInteractionEvents {
            return .applicationIsIgnoringInteractionEvents
        }

        if self.window.isHidden {
            return .windowIsHidden
        }

        if !self.window.isUserInteractionEnabled {
            return .windowUserInteractionIsDisabled
        }

        guard let rootViewController = self.window.rootViewController,
              rootViewController.viewIfLoaded != nil else
        {
            return .rootViewControllerIsNotLoaded
        }

        if rootViewController.isBeingPresented || rootViewController.isBeingDismissed
            || rootViewController.isMovingToParent || rootViewController.isMovingFromParent
        {
            return .rootViewControllerIsTransitioning
        }

        guard let scene = self.window.windowScene else {
            return .windowHasNoScene
        }

        if scene.activationState != .foregroundActive {
            return .sceneIsNotForegroundActive(activationState: scene.activationState.name)
        }

        if let hammerWindow = self.window as? HammerWindow, !hammerWindow.viewControllerHasAppeared {
            return .viewControllerHasNotAppeared
        }

        return nil
    }

    /// Throws if the window is not ready to receive user interaction events.
    func checkWindowIsReady() throws {
        guard !self.isFinished else {
            throw HammerError.eventGeneratorIsFinished
        }

        try self.checkIsLatestActiveGenerator()

        if let reason = self.windowNotReadyReason {
            throw HammerError.windowIsNotReadyForInteraction(reason: reason)
        }
    }

    /// Waits until the window is ready to receive user interaction events.
    ///
    /// - parameter timeout: The maximum time to wait for all readiness checks combined, or nil to use
    ///                      `settings.windowReadyTimeout`.
    ///
    /// - throws: `HammerError.windowIsNotReadyForInteraction` with the check that did not pass.
    public func waitUntilWindowIsReady(timeout: TimeInterval? = nil) async throws {
        var deadline = ContinuousClock.now + .seconds(timeout ?? self.settings.windowReadyTimeout)
        let remaining = { max((deadline - .now).timeInterval, 0) }

        while let reason = self.windowNotReadyReason {
            if remaining() == 0 {
                throw HammerError.windowIsNotReadyForInteraction(reason: reason)
            }

            // Checking every frame lets the generator start as soon as the window appears
            try await self.waitForNextFrame(before: deadline)
        }

        // The accessibility warm up is a fixed delay, so it does not count against the timeout
        let accessibilityStart = ContinuousClock.now
        try await self.waitUntilAccessibilityActivate()
        deadline += .now - accessibilityStart

        if self.settings.waitForFrameRender {
            try await self.waitUntilReady(.frameWasNotRendered) {
                try await self.waitUntilFrameIsRendered(timeout: remaining())
            }
        }

        if self.settings.waitForAnimations {
            try await self.waitUntilReady(.animationsAreRunning) {
                try await self.waitUntilAnimationsAreFinished(timeout: remaining())
            }
        }

        try await self.waitUntilReady(.runLoopIsBusy) {
            try await self.waitUntilRunloopIsFlushed(timeout: remaining())
        }
    }

    /// Waits until animations are finished.
    ///
    /// - parameter timeout: The maximum time to wait, or nil to use `settings.waitTimeout`.
    public func waitUntilAnimationsAreFinished(timeout: TimeInterval? = nil) async throws {
        try await self.waitUntil(!self.hasRunningAnimations, timeout: timeout)
    }

    /// Returns if the view or any of its subviews has running animations.
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

    // MARK: - Private

    private func waitUntilReady(_ reason: WindowNotReadyReason, wait: () async throws -> Void) async throws {
        do {
            try await wait()
        } catch HammerError.waitConditionTimeout {
            throw HammerError.windowIsNotReadyForInteraction(reason: reason)
        }
    }

    private func waitUntilAccessibilityActivate() async throws {
        guard self.settings.forceActivateAccessibilityEngine else {
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

        try await self.wait(
            simAccessibilityActivated
            ? self.settings.accessibilityActivateDelay // Default: 0.02s
            : self.settings.accessibilityActivateFirstTimeDelay // Default: 5.0s
        )

        self.isAccessibilityActivated = true
        if !simAccessibilityActivated {
            UserDefaults.standard.set(true, forKey: simAccessibilityActivatedKey)
        }
    }
}

extension UIScene.ActivationState {
    fileprivate var name: String {
        switch self {
        case .unattached:
            return "unattached"
        case .foregroundActive:
            return "foregroundActive"
        case .foregroundInactive:
            return "foregroundInactive"
        case .background:
            return "background"
        @unknown default:
            return "unknown (\(self.rawValue))"
        }
    }
}

// Bypasses deprecation warning for `isIgnoringInteractionEvents`
@MainActor
private protocol UIApplicationDeprecated {
    var isIgnoringInteractionEvents: Bool { get }
}

extension UIApplication: UIApplicationDeprecated {}
