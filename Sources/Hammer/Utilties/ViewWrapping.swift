import UIKit
#if canImport(SwiftUI)
import SwiftUI
#endif

private let kHammerWrapperIdentifier = "hammer_wrapper"

extension UIWindow {
    convenience init(wrapping viewController: UIViewController) {
        self.init(frame: UIScreen.main.bounds)
        self.accessibilityIdentifier = kHammerWrapperIdentifier
        self.rootViewController = viewController
    }
}

extension UIViewController {
    convenience init(wrapping view: UIView) {
        self.init(nibName: nil, bundle: nil)
        self.view.accessibilityIdentifier = kHammerWrapperIdentifier
        view.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: self.view.topAnchor).priority(.defaultHigh),
            view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).priority(.defaultHigh),
            view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).priority(.defaultHigh),
            view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).priority(.defaultHigh),
            view.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
            view.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
        ])
    }
}

@available(iOS 13.0, *)
extension UIHostingController {
    convenience init(wrapping view: Content) {
        self.init(rootView: view)
        self.view.accessibilityIdentifier = kHammerWrapperIdentifier
    }
}

extension UIView {
    /// If the view is a wrapper created by Hammer
    var isWrapper: Bool {
        return self.accessibilityIdentifier == kHammerWrapperIdentifier
    }
}

extension NSLayoutConstraint {
    fileprivate func priority(_ priority: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}
