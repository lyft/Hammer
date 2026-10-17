import SwiftUI
import UIKit

extension EventGenerator {
    /// Initialize an event generator for a SwiftUI view, hosting it in a temporary window.
    ///
    /// Find the view's elements by passing their `accessibilityIdentifier` to the event and waiting methods.
    ///
    /// - parameter view:      The view to receive events.
    /// - parameter alignment: The wrapping alignment to use.
    public convenience init(view: some View, alignment: WrappingAlignment = .center) async throws {
        let hostingController = EventGenerator.hostingController(for: view)
        self.init(window: EventGenerator.window(for: hostingController, alignment: alignment),
                  mainView: hostingController.view)
        try await self.waitUntilWindowIsReady()
    }

    /// Creates a hosting controller that sizes itself to the view, so it can be centered.
    ///
    /// - parameter view: The view to host.
    ///
    /// - returns: The hosting controller.
    static func hostingController(for view: some View) -> UIViewController {
        let hostingController = UIHostingController(rootView: view)
        hostingController.sizingOptions = .intrinsicContentSize
        return hostingController
    }

    /// Presents the view controller in a new temporary window, aligned within it.
    ///
    /// - parameter viewController: The view controller to receive events.
    /// - parameter alignment:      The wrapping alignment to use.
    ///
    /// - returns: The window to send events to.
    static func window(for viewController: UIViewController, alignment: WrappingAlignment) -> UIWindow {
        let window = HammerWindow()
        window.presentContained(UIViewController(wrapping: viewController, alignment: alignment))
        return window
    }
}
