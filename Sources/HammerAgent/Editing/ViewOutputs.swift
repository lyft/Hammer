import Hammer
import UIKit

/// A view in an output, by its ref and type.
struct ViewReference: Encodable {
    let ref: String
    let type: String

    @MainActor
    init(_ view: UIView, in context: AgentContext) {
        self.ref = context.ref(for: AccessibilityElement(object: view, containerView: view))
        self.type = String(describing: Swift.type(of: view))
    }
}

/// A rect in an output, in window points.
struct Frame: Encodable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(_ rect: CGRect) {
        self.x = Double(rect.minX).roundedForOutput
        self.y = Double(rect.minY).roundedForOutput
        self.width = Double(rect.width).roundedForOutput
        self.height = Double(rect.height).roundedForOutput
    }
}

extension UIView {
    /// The frame in the window's coordinates.
    var frameInWindow: CGRect {
        return self.convert(self.bounds, to: nil)
    }

    /// The type of the view controller whose root view this is.
    var viewControllerType: String? {
        return (self.next as? UIViewController).map { String(describing: type(of: $0)) }
    }

    /// Lays out the window after a change, so the next command sees its effect.
    func layoutWindow() {
        (self.window ?? self).layoutIfNeeded()
    }
}
