import UIKit

/// Describes the views and accessibility elements to find, such as SwiftUI's.
///
/// Every property that is set must match, and the element must have all the specified traits.
public struct AccessibilityQuery: Sendable {
    /// The accessibility identifier to match.
    public var identifier: String?

    /// The accessibility label to match.
    public var label: String?

    /// The accessibility value to match.
    public var value: String?

    /// The accessibility traits the element must have.
    public var traits: UIAccessibilityTraits

    /// Creates a query for views and accessibility elements.
    ///
    /// - parameter identifier: The accessibility identifier to match.
    /// - parameter label:      The accessibility label to match.
    /// - parameter value:      The accessibility value to match.
    /// - parameter traits:     The accessibility traits the element must have.
    public init(identifier: String? = nil, label: String? = nil, value: String? = nil,
                traits: UIAccessibilityTraits = [])
    {
        self.identifier = identifier
        self.label = label
        self.value = value
        self.traits = traits
    }

    /// Returns if the view or element matches the query.
    ///
    /// - parameter object: The view or element to check.
    ///
    /// - returns: If it matches.
    @MainActor
    func matches(_ object: NSObject) -> Bool {
        if let identifier = self.identifier, object.accessibilityIdentifierValue != identifier {
            return false
        }

        if let label = self.label, object.accessibilityLabel != label {
            return false
        }

        if let value = self.value, object.accessibilityValue != value {
            return false
        }

        return object.accessibilityTraits.contains(self.traits)
    }
}

extension HammerLocatable where Self == AccessibilityQuery {
    /// Creates a query for the view or element with the accessibility identifier.
    ///
    /// - parameter identifier: The accessibility identifier to match.
    /// - parameter traits:     The accessibility traits the element must have.
    public static func identifier(_ identifier: String, traits: UIAccessibilityTraits = []) -> Self {
        return AccessibilityQuery(identifier: identifier, traits: traits)
    }

    /// Creates a query for the view or element with the accessibility label.
    ///
    /// - parameter label:  The accessibility label to match.
    /// - parameter traits: The accessibility traits the element must have.
    public static func label(_ label: String, traits: UIAccessibilityTraits = []) -> Self {
        return AccessibilityQuery(label: label, traits: traits)
    }

    /// Creates a query for the view or element with the accessibility value.
    ///
    /// - parameter value:  The accessibility value to match.
    /// - parameter traits: The accessibility traits the element must have.
    public static func value(_ value: String, traits: UIAccessibilityTraits = []) -> Self {
        return AccessibilityQuery(value: value, traits: traits)
    }
}

extension AccessibilityQuery: HammerLocatable {
    public func windowHitPoint(for eventGenerator: EventGenerator) throws -> CGPoint {
        return try eventGenerator.windowHitPoint(for: self)
    }
}

extension AccessibilityQuery: CustomStringConvertible {
    public var description: String {
        let parts = [
            self.identifier.map { "identifier \"\($0)\"" },
            self.label.map { "label \"\($0)\"" },
            self.value.map { "value \"\($0)\"" },
            self.traits.isEmpty ? nil : "traits \(self.traits.rawValue)",
        ]

        return parts.compactMap { $0 }.joined(separator: ", ")
    }
}
