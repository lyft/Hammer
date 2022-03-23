import CoreGraphics
import UIKit

extension CGRect {
    /// Convenience getter for the center of a rect.
    var center: CGPoint {
        return CGPoint(x: self.midX, y: self.midY)
    }
}

extension CGPoint {
    /// Calculates the offset point by translating using the specified x and y values.
    ///
    /// - parameter x: The offset in the horizontal direction, positive means to the right
    /// - parameter y: The offset in the vertical direction, positive means down
    ///
    /// - returns: The offset point
    func offset(x: CGFloat, y: CGFloat) -> CGPoint {
        return CGPoint(x: self.x + x, y: self.y + y)
    }
}

extension UITextField {
    /// Disables the predictive bar which causes autolayout issues
    func disablePredictiveBar() {
        self.inputAssistantItem.leadingBarButtonGroups = []
        self.inputAssistantItem.trailingBarButtonGroups = []
    }
}

extension UITextView {
    /// Disables the predictive bar which causes autolayout issues
    func disablePredictiveBar() {
        self.inputAssistantItem.leadingBarButtonGroups = []
        self.inputAssistantItem.trailingBarButtonGroups = []
    }
}

extension UIView {
    func setOrigin(x: CGFloat? = nil, y: CGFloat? = nil) {
        guard let superview = self.superview else {
            fatalError("Add the view to a superview first")
        }

        self.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            x.map { self.leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: $0) },
            y.map { self.topAnchor.constraint(equalTo: superview.topAnchor, constant: $0) },
        ].compactMap { $0 })
    }

    func setSize(width: CGFloat? = nil, height: CGFloat? = nil) {
        self.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            width.map { self.widthAnchor.constraint(equalToConstant: $0) },
            height.map { self.heightAnchor.constraint(equalToConstant: $0) },
        ].compactMap { $0 })
    }
}
