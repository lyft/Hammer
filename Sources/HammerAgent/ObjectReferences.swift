import Hammer
import UIKit
import WebKit

/// Gives views, accessibility elements, constraints and elements of web pages short refs, such as `e12`, `c4`
/// or `w7`, that clients pass back to act on them.
///
/// The same object keeps its ref while it is alive. Objects are held weakly so the agent never keeps a view
/// around, and a ref stops resolving once its object is released. An element of a web page keeps its ref
/// while its page is loaded, and is found again on the page when the ref is used.
@MainActor
final class ObjectReferences {
    private enum Kind: String {
        case element = "e"
        case constraint = "c"
        case web = "w"
    }

    /// An element of a web page, which the agent finds again by its id on the page.
    struct WebElementReference {
        let webView: WKWebView
        let page: String
        let id: Int
    }

    private struct WebKey: Hashable {
        let webView: ObjectIdentifier
        let page: String
        let id: Int
    }

    private struct WebEntry {
        weak var webView: WKWebView?
        let page: String
        let id: Int
    }

    private struct Entry {
        weak var object: NSObject?
        /// The view an element belongs to, unused for constraints.
        weak var containerView: UIView?
    }

    private var entries = [String: Entry]()
    private var refs = [ObjectIdentifier: String]()
    private var webEntries = [String: WebEntry]()
    private var webRefs = [WebKey: String]()
    /// The refs of each web view's page, oldest first, and the page they're on.
    private var webPages = [ObjectIdentifier: (page: String, refs: [String])]()
    private var nextIndex = 1

    /// The most refs a web view keeps for its page. A page that keeps changing without loading another,
    /// such as a single page app, drops its oldest refs past it.
    private let maxWebElementRefs: Int

    /// Creates the refs.
    ///
    /// - parameter maxWebElementRefs: The most refs a web view keeps for its page.
    init(maxWebElementRefs: Int = 2000) {
        self.maxWebElementRefs = maxWebElementRefs
    }

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

    /// Returns the ref of an element of a web page, assigning a new one the first time.
    ///
    /// - parameter element: The element.
    ///
    /// - returns: The ref.
    func ref(for element: WebContent.Element) -> String {
        let key = WebKey(webView: ObjectIdentifier(element.webView), page: element.page, id: element.id)
        if let ref = self.webRefs[key], self.webEntries[ref]?.webView === element.webView {
            return ref
        }

        let ref = "\(Kind.web.rawValue)\(self.nextIndex)"
        self.nextIndex += 1
        self.webRefs[key] = ref
        self.webEntries[ref] = WebEntry(webView: element.webView, page: element.page, id: element.id)

        // A new page's refs replace the old page's, which can't resolve anymore
        var page = self.webPages[key.webView] ?? (page: element.page, refs: [])
        if page.page != element.page {
            self.forgetWebRefs(page.refs)
            page = (page: element.page, refs: [])
        }

        page.refs.append(ref)
        if page.refs.count > self.maxWebElementRefs {
            let dropped = page.refs.count - self.maxWebElementRefs
            self.forgetWebRefs(Array(page.refs.prefix(dropped)))
            page.refs.removeFirst(dropped)
        }

        self.webPages[key.webView] = page
        return ref
    }

    private func forgetWebRefs(_ refs: [String]) {
        for ref in refs {
            if let entry = self.webEntries.removeValue(forKey: ref), let webView = entry.webView {
                self.webRefs[WebKey(webView: ObjectIdentifier(webView), page: entry.page, id: entry.id)] = nil
            }
        }
    }

    /// If the ref is one of an element of a web page.
    ///
    /// - parameter ref: The ref.
    ///
    /// - returns: If it is.
    static func isWebElementRef(_ ref: String) -> Bool {
        return ref.hasPrefix(Kind.web.rawValue)
    }

    /// Returns the element of a web page for the ref.
    ///
    /// - parameter ref: The ref.
    ///
    /// - throws: An error if the ref is unknown or its web view was released.
    ///
    /// - returns: The web view, page and id of the element.
    func webElement(for ref: String) throws -> WebElementReference {
        guard let entry = self.webEntries[ref], let webView = entry.webView else {
            throw AgentError.invalidArguments(
                "Unknown web element ref \"\(ref)\", its web view is gone or the ref is not from describe",
                hint: "Call describe to get the current refs")
        }

        return WebElementReference(webView: webView, page: entry.page, id: entry.id)
    }

    /// Returns the element for the ref.
    ///
    /// - parameter ref: The ref.
    ///
    /// - throws: An error if the ref is unknown or its element was released.
    ///
    /// - returns: The element.
    func element(for ref: String) throws -> AccessibilityElement {
        if Self.isWebElementRef(ref) {
            throw AgentError.invalidArguments(
                "\"\(ref)\" is an element of a web page, not a view or an accessibility element",
                hint: "Target the WKWebView that shows the page instead, by its ref from describe")
        }

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
        self.webEntries = self.webEntries.filter { $0.value.webView != nil }
        self.webRefs = self.webRefs.filter { self.webEntries[$0.value] != nil }
        self.webPages = self.webPages.filter { _, page in page.refs.contains { self.webEntries[$0] != nil } }
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
