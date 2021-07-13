import UIKit

extension UITouch.Phase {
    // Returns 1 for all events where the fingers are on the glass.
    var isTouching: Bool {
        return self == .began || self == .moved || self == .stationary
    }

    var eventMask: IOHID.DigitizerEventMask {
        var mask: IOHID.DigitizerEventMask = []

        if self == .began || self == .ended || self == .cancelled {
            mask.insert(.touch)
            mask.insert(.range)
        }

        if self == .moved {
            mask.insert(.position)
        }

        if self == .cancelled {
            mask.insert(.cancel)
        }

        return mask
    }
}

extension UIDevice {
    public var maxNumberOfFingers: Int {
        switch self.userInterfaceIdiom {
        case .phone, .carPlay:
            return 5
        case .pad:
            return 10
        default:
            return 0
        }
    }

    public var supportsStylus: Bool {
        return self.userInterfaceIdiom == .pad
    }
}

extension UIWindow {
    convenience init(wrapping viewController: UIViewController) {
        self.init(frame: UIScreen.main.bounds)
        self.rootViewController = viewController
    }
}

extension UIViewController {
    convenience init(wrapping view: UIView) {
        self.init(nibName: nil, bundle: nil)
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

extension NSLayoutConstraint {
    fileprivate func priority(_ priority: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}
