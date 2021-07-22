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

extension UIView {
    func size(width: CGFloat, height: CGFloat) -> Self {
        self.widthAnchor.constraint(equalToConstant: width).isActive = true
        self.heightAnchor.constraint(equalToConstant: height).isActive = true
        return self
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
