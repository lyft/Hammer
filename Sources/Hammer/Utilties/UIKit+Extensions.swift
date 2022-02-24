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
    convenience init(wrapping view: UIView, alignment: EventGenerator.WrappingAlignment) {
        self.init(nibName: nil, bundle: nil)
        view.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(view)

        switch alignment {
        case .fill:
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: self.view.topAnchor),
                view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
                view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            ])
        case .center:
            NSLayoutConstraint.activate([
                view.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
                view.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                view.topAnchor.constraint(greaterThanOrEqualTo: self.view.topAnchor),
                view.bottomAnchor.constraint(lessThanOrEqualTo: self.view.bottomAnchor),
                view.leadingAnchor.constraint(greaterThanOrEqualTo: self.view.leadingAnchor),
                view.trailingAnchor.constraint(lessThanOrEqualTo: self.view.trailingAnchor),
            ])
        }
    }
}

extension UIView {
    /// Returns the view at the top level of the view hierarchy. Could be a UIWindow.
    var topLevelView: UIView {
        return self.superview?.topLevelView ?? self
    }
}
