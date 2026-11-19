import Hammer
import HammerAgentCore
import UIKit
import WebKit

/// Reads the pages of the key window's web views with `WebContentScript`, since the agent can't reach a
/// page's accessibility elements: WebKit serves them from its web content process.
@MainActor
enum WebContent {
    /// An element of a page, such as a link, a button, a text field or a run of text.
    struct Element {
        /// The web view that shows the page.
        let webView: WKWebView

        /// The page the element is on, which changes when the web view loads another page.
        let page: String

        /// The element's id on its page.
        let id: Int

        /// The HTML tag, or `text` for text.
        let type: String
        let identifier: String?
        let label: String?
        let value: String?
        let traits: UIAccessibilityTraits

        /// If it takes typed text, such as a text field.
        let isEditable: Bool

        /// The frame in the window's coordinates.
        let frame: CGRect

        /// The point touches go to in the window's coordinates, the center of its visible part.
        let hitPoint: CGPoint

        /// If any part of it is on screen.
        let isVisible: Bool

        /// If touches at `hitPoint` reach it.
        let isHittable: Bool

        func matches(_ query: AccessibilityQuery) -> Bool {
            if let identifier = query.identifier, self.identifier != identifier {
                return false
            }

            if let label = query.label, self.label != label {
                return false
            }

            if let value = query.value, self.value != value {
                return false
            }

            return self.traits.contains(query.traits)
        }

        /// Describes the element in errors.
        var summary: String {
            let parts = [
                self.identifier.map { "identifier \"\($0)\"" },
                self.label.map { "label \"\($0)\"" },
            ].compactMap { $0 }
            return "The web \(self.type)" + (parts.isEmpty ? "" : " with " + parts.joined(separator: ", "))
        }

        /// The point to touch.
        ///
        /// - throws: An error if it is off screen or something covers it.
        func checkedHitPoint() throws -> CGPoint {
            guard self.isVisible else {
                throw AgentError.failed(
                    "\(self.summary) is off screen or hidden",
                    hint: "Swipe over the web view to scroll it into view, or wait_for it to be visible",
                    code: .notVisible)
            }

            guard self.isHittable else {
                throw AgentError.failed("\(self.summary) is covered or ignores touches", hint: """
                    Take a screenshot or call describe to see what is on top, such as a banner of the page, \
                    an alert or the keyboard
                    """, code: .notHittable)
            }

            return self.hitPoint
        }
    }

    private struct Output: Decodable {
        struct RawElement: Decodable {
            let id: Int
            let type: String
            let identifier: String?
            let label: String?
            let value: String?
            let traits: [String]
            let editable: Bool
            let x: Double
            let y: Double
            let width: Double
            let height: Double
            let hitX: Double
            let hitY: Double
            let visible: Bool
            let hittable: Bool
        }

        let page: String
        let elements: [RawElement]
    }

    /// The content world the script runs in, apart from the page's scripts.
    private static let world = WKContentWorld.world(name: "HammerAgent")

    /// How long a web view has to answer, so a stuck web content process can't hold up a command.
    private static let timeout: TimeInterval = 5

    /// The visible web views in the window, back to front.
    ///
    /// - parameter window: The window.
    ///
    /// - returns: The web views.
    static func webViews(in window: UIWindow) -> [WKWebView] {
        func search(_ view: UIView) -> [WKWebView] {
            if let webView = view as? WKWebView {
                return [webView]
            }

            return view.subviews.filter { !$0.isHidden && $0.alpha >= 0.01 }.flatMap(search)
        }

        return search(window)
    }

    /// Reads the elements of the web view's page.
    ///
    /// - parameter webView: The web view.
    /// - parameter window:  The window to give frames in.
    ///
    /// - throws: An error if the page doesn't answer.
    ///
    /// - returns: The elements, in the page's order.
    static func elements(in webView: WKWebView, window: UIWindow) async throws -> [Element] {
        let output: Output = try await self.run(["operation": "read"], in: webView)
        return output.elements.map { self.element($0, page: output.page, in: webView, window: window) }
    }

    /// Reads the element again, such as to find where it moved.
    ///
    /// - parameter page:    The element's page.
    /// - parameter id:      The element's id.
    /// - parameter webView: The web view.
    /// - parameter window:  The window to give frames in.
    ///
    /// - throws: An error if the page doesn't answer.
    ///
    /// - returns: The element, or nil if it is gone or the web view shows another page.
    static func element(page: String, id: Int, in webView: WKWebView, window: UIWindow) async throws
        -> Element?
    {
        let output: Output = try await self.run(["operation": "locate", "page": page, "id": id], in: webView)
        return output.elements.first.map { self.element($0, page: output.page, in: webView, window: window) }
    }

    /// Returns the elements of every web view in the window that match the query, leaving out the pages that
    /// don't answer.
    ///
    /// - parameter query:  The query.
    /// - parameter window: The window.
    ///
    /// - returns: The matching elements.
    static func elements(matching query: AccessibilityQuery, in window: UIWindow) async -> [Element] {
        var matches = [Element]()
        for webView in self.webViews(in: window) {
            let elements = (try? await self.elements(in: webView, window: window)) ?? []
            matches += elements.filter { $0.matches(query) }
        }

        return matches
    }

    /// Finds the element to interact with for the query, choosing like the agent does for views: visible
    /// ones first, then the ones that act, such as buttons.
    ///
    /// - parameter query:  The query.
    /// - parameter window: The window.
    ///
    /// - throws: An error if several elements match.
    ///
    /// - returns: The element, or nil if none matches.
    static func element(matching query: AccessibilityQuery, in window: UIWindow) async throws -> Element? {
        var targets = await self.elements(matching: query, in: window)
        let visible = targets.filter(\.isVisible)
        targets = visible.isEmpty ? targets : visible
        let actionable = targets.filter { !$0.traits.isDisjoint(with: [.button, .link, .adjustable]) }
        targets = actionable.isEmpty ? targets : actionable
        if targets.count > 1 {
            throw AgentError.failed("\(targets.count) web elements match \(query)", hint: """
                Add more of identifier, label, value and traits to tell them apart, or pass a ref from \
                describe
                """, code: .ambiguousTarget)
        }

        return targets.first
    }

    /// Returns if the element has the keyboard focus, in the page and in the app.
    ///
    /// - parameter element: The element.
    ///
    /// - returns: If typed text goes to it.
    static func hasFocus(_ element: Element) async -> Bool {
        let arguments: [String: Any] = ["operation": "focused", "page": element.page, "id": element.id]
        guard (try? await self.run(arguments, in: element.webView) as Bool) == true else {
            return false
        }

        // The page takes the focus first, then the web view becomes the first responder
        return self.contentView(of: element.webView)?.isFirstResponder ?? true
    }

    // MARK: - Helpers

    private static func element(_ raw: Output.RawElement, page: String, in webView: WKWebView,
                                window: UIWindow) -> Element
    {
        let frame = self.convert(CGRect(x: raw.x, y: raw.y, width: raw.width, height: raw.height),
                                 from: webView, to: window)
        let hitPoint = self.convert(CGRect(x: raw.hitX, y: raw.hitY, width: 0, height: 0),
                                    from: webView, to: window).origin
        let visibleArea = webView.convert(webView.bounds, to: window).intersection(window.bounds)
        let isVisible = raw.visible && frame.intersects(visibleArea)
        let hitView = window.hitTest(hitPoint, with: nil)
        let isHittable = isVisible && raw.hittable && visibleArea.contains(hitPoint)
            && hitView?.isDescendant(of: webView) == true
        let traits = raw.traits.reduce(into: UIAccessibilityTraits()) { traits, name in
            UIAccessibilityTraits(name: name).map { traits.formUnion($0) }
        }

        return Element(webView: webView, page: page, id: raw.id, type: raw.type, identifier: raw.identifier,
                       label: raw.label, value: raw.value, traits: traits, isEditable: raw.editable,
                       frame: frame, hitPoint: hitPoint, isVisible: isVisible, isHittable: isHittable)
    }

    /// Converts a rectangle in the document's CSS pixels to the window, through the view the web view zooms,
    /// which is scaled and scrolled with the page.
    private static func convert(_ rect: CGRect, from webView: WKWebView, to window: UIWindow) -> CGRect {
        let scrollView = webView.scrollView
        if let contentView = self.contentView(of: webView) {
            return contentView.convert(rect, to: window)
        }

        let scale = scrollView.zoomScale
        let scaled = CGRect(x: rect.minX * scale, y: rect.minY * scale,
                            width: rect.width * scale, height: rect.height * scale)
        return scrollView.convert(scaled, to: window)
    }

    /// The view that shows the page, which the web view's scroll view zooms.
    private static func contentView(of webView: WKWebView) -> UIView? {
        let scrollView = webView.scrollView
        return scrollView.delegate?.viewForZooming?(in: scrollView)
    }

    private static func run<T: Decodable>(_ arguments: [String: Any], in webView: WKWebView) async throws
        -> T
    {
        let json = try await self.evaluate(arguments, in: webView)
        do {
            return try JSONDecoder().decode(T.self, from: Data(json.utf8))
        } catch {
            throw AgentError.failed("The web view returned an unexpected result: \(error)")
        }
    }

    private static func evaluate(_ arguments: [String: Any], in webView: WKWebView) async throws -> String {
        let once = ResumeOnce()
        return try await withCheckedThrowingContinuation { continuation in
            once.continuation = continuation
            webView.callAsyncJavaScript(kWebContentScript, arguments: arguments, in: nil,
                                        in: self.world)
            { result in
                switch result {
                case .success(let value as String):
                    once.resume(with: .success(value))
                case .success:
                    once.resume(with: .failure(AgentError.failed("The web view returned no result")))
                case .failure(let error):
                    once.resume(with: .failure(AgentError.failed(
                        "The web view couldn't read its page: \(error.localizedDescription)",
                        hint: "Wait for the page to load, then try again")))
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + self.timeout) {
                once.resume(with: .failure(AgentError.failed(
                    "The web view didn't answer within \(Int(self.timeout)) seconds",
                    hint: "The page may be busy or its web content process may have stopped",
                    code: .timedOut)))
            }
        }
    }
}

/// Resumes a continuation once, with the result or the timeout, whichever comes first.
@MainActor
private final class ResumeOnce {
    var continuation: CheckedContinuation<String, Error>?

    func resume(with result: Result<String, Error>) {
        self.continuation?.resume(with: result)
        self.continuation = nil
    }
}
