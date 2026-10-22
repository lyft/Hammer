import Hammer
import UIKit

/// Gives views and accessibility elements short refs, such as `e12`, that clients pass back to act on them.
///
/// The same element keeps its ref while it is alive. Elements are held weakly so the agent never keeps a
/// view around, and a ref stops resolving once its element is released.
@MainActor
final class ElementReferences {
    private struct Entry {
        weak var object: NSObject?
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
        let key = ObjectIdentifier(element.object)
        // Identifiers are reused after an object is released, so the entry must still point to it
        if let ref = self.refs[key], self.entries[ref]?.object === element.object {
            return ref
        }

        let ref = "e\(self.nextIndex)"
        self.nextIndex += 1
        self.refs[key] = ref
        self.entries[ref] = Entry(object: element.object, containerView: element.containerView)
        return ref
    }

    /// Returns the element for the ref.
    ///
    /// - parameter ref: The ref.
    ///
    /// - throws: An error if the ref is unknown or its element was released.
    ///
    /// - returns: The element.
    func element(for ref: String) throws -> AccessibilityElement {
        guard let entry = self.entries[ref], let object = entry.object,
              let containerView = entry.containerView
        else {
            throw AgentError.invalidArguments("Unknown ref \"\(ref)\", call describe to get the current refs")
        }

        return AccessibilityElement(object: object, containerView: containerView)
    }

    /// Forgets the refs of released elements.
    func removeReleased() {
        self.entries = self.entries.filter { $0.value.object != nil && $0.value.containerView != nil }
        self.refs = self.refs.filter { self.entries[$0.value] != nil }
    }
}
