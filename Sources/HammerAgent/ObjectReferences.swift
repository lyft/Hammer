import Hammer
import UIKit

/// Gives views, accessibility elements and constraints short refs, such as `e12` or `c4`, that clients pass
/// back to act on them.
///
/// The same object keeps its ref while it is alive. Objects are held weakly so the agent never keeps a view
/// around, and a ref stops resolving once its object is released.
@MainActor
final class ObjectReferences {
    private enum Kind: String {
        case element = "e"
        case constraint = "c"
    }

    private struct Entry {
        weak var object: NSObject?
        /// The view an element belongs to, unused for constraints.
        weak var containerView: UIView?
    }

    private var entries = [String: Entry]()
    private var refs = [ObjectIdentifier: String]()
    private var nextIndex = 1

    /// Returns the element's ref, assigning a new one the first time.
    ///
    /// - parameter element: The element.
    ///
    /// - returns: The ref.
    func ref(for element: AccessibilityElement) -> String {
        return self.ref(for: element.object, containerView: element.containerView, kind: .element)
    }

    /// Returns the constraint's ref, assigning a new one the first time.
    ///
    /// - parameter constraint: The constraint.
    ///
    /// - returns: The ref.
    func ref(for constraint: NSLayoutConstraint) -> String {
        return self.ref(for: constraint, containerView: nil, kind: .constraint)
    }

    /// Returns the element for the ref.
    ///
    /// - parameter ref: The ref.
    ///
    /// - throws: An error if the ref is unknown or its element was released.
    ///
    /// - returns: The element.
    func element(for ref: String) throws -> AccessibilityElement {
        guard ref.hasPrefix(Kind.element.rawValue), let entry = self.entries[ref], let object = entry.object,
              let containerView = entry.containerView
        else {
            throw AgentError.invalidArguments(
                "Unknown element ref \"\(ref)\", its element is gone or the ref is not from describe",
                hint: "Call describe or hierarchy to get the current refs")
        }

        return AccessibilityElement(object: object, containerView: containerView)
    }

    /// Returns the constraint for the ref.
    ///
    /// - parameter ref: The ref.
    ///
    /// - throws: An error if the ref is unknown or its constraint was released.
    ///
    /// - returns: The constraint.
    func constraint(for ref: String) throws -> NSLayoutConstraint {
        guard ref.hasPrefix(Kind.constraint.rawValue),
              let constraint = self.entries[ref]?.object as? NSLayoutConstraint
        else {
            throw AgentError.invalidArguments(
                "Unknown constraint ref \"\(ref)\", the constraint is gone or the ref is not from inspect",
                hint: "Call inspect on the view to get the current constraint refs")
        }

        return constraint
    }

    /// Forgets the refs of released objects.
    func removeReleased() {
        self.entries = self.entries.filter { ref, entry in
            entry.object != nil && (!ref.hasPrefix(Kind.element.rawValue) || entry.containerView != nil)
        }
        self.refs = self.refs.filter { self.entries[$0.value] != nil }
    }

    private func ref(for object: NSObject, containerView: UIView?, kind: Kind) -> String {
        let key = ObjectIdentifier(object)
        // Identifiers are reused after an object is released, so the entry must still point to it
        if let ref = self.refs[key], self.entries[ref]?.object === object {
            return ref
        }

        let ref = "\(kind.rawValue)\(self.nextIndex)"
        self.nextIndex += 1
        self.refs[key] = ref
        self.entries[ref] = Entry(object: object, containerView: containerView)
        return ref
    }
}
