import Hammer
import HammerAgentCore
import UIKit
import WebKit

/// Reads the pages of the key window's web views with `kWebContentScript`, since the agent can't reach a
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

        /// The point touches go to in the window's coordinates, on its first visible line.
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

        /// If it does something when touched or typed into, which queries prefer over text and images.
        var isActionable: Bool {
            return self.isEditable || !self.traits.isDisjoint(with: [.button, .link, .adjustable])
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

    /// What reading a web view's page gave.
    struct Page {
        /// The web view.
        let webView: WKWebView

        /// The page's elements, or why the page couldn't be read.
        let elements: Result<[Element], AgentError>
    }

    fileprivate struct Output: Decodable, Sendable {
        struct RawElement: Decodable, Sendable {
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
    fileprivate static let world = WKContentWorld.world(name: "HammerAgent")

    /// Names this agent's script, so a page that has another agent's script installs this one.
    fileprivate static let version = UUID().uuidString

    /// How long a web view has to answer by default, so a stuck web content process can't hold up a command.
    static let defaultTimeout: TimeInterval = 5

    /// How long a read waits for the web view to stop scrolling, so frames don't lag behind the screen and a
    /// touch isn't taken as one that stops the scrolling.
    fileprivate static let scrollSettleTimeout: TimeInterval = 3

    /// The web views with a call that hasn't answered, such as one that timed out. The web content process
    /// still runs it, so the next call waits for it to finish instead of queueing behind it.
    fileprivate static var busyWebViews = Set<ObjectIdentifier>()

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

    /// Reads the pages of the web views at the same time, so one that doesn't answer doesn't hold up the
    /// others.
    ///
    /// - parameter webViews: The web views.
    /// - parameter window:   The window to give frames in.
    /// - parameter timeout:  How long each web view has to answer.
    ///
    /// - returns: The pages, in the order of the web views.
    static func pages(of webViews: [WKWebView], window: UIWindow,
                      timeout: TimeInterval = WebContent.defaultTimeout) async -> [Page]
    {
        let reads = webViews.map { webView in
            Task { @MainActor in
                try await self.run(["operation": "read"], in: webView, timeout: timeout) as Output
            }
        }

        var pages = [Page]()
        for (webView, read) in zip(webViews, reads) {
            let elements = await read.result
                .map { output in
                    output.elements.map { self.element($0, page: output.page, in: webView, window: window) }
                }
                .mapError { $0 as? AgentError ?? AgentError.failed(String(describing: $0)) }
            pages.append(Page(webView: webView, elements: elements))
        }

        return pages
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
    /// can't be read.
    ///
    /// - parameter query:   The query.
    /// - parameter window:  The window.
    /// - parameter timeout: How long each web view has to answer.
    ///
    /// - returns: The matching elements.
    static func elements(matching query: AccessibilityQuery, in window: UIWindow,
                         timeout: TimeInterval = WebContent.defaultTimeout) async -> [Element]
    {
        let webViews = self.webViews(in: window)
        guard !webViews.isEmpty else {
            return []
        }

        let pages = await self.pages(of: webViews, window: window, timeout: timeout)
        return pages.flatMap { (try? $0.elements.get()) ?? [] }.filter { $0.matches(query) }
    }

    /// Finds the element to interact with for the query, choosing like the agent does for views: visible
    /// ones first, then the ones that act, such as buttons and fields, over text.
    ///
    /// - parameter query:  The query.
    /// - parameter window: The window.
    ///
    /// - throws: An error if several elements match.
    ///
    /// - returns: The element, or nil if none matches.
    static func element(matching query: AccessibilityQuery, in window: UIWindow) async throws -> Element? {
        return try self.choose(from: await self.elements(matching: query, in: window), for: query)
    }

    /// Chooses the element to interact with from the ones that match the query.
    ///
    /// - throws: An error if several elements are left.
    static func choose(from matches: [Element], for query: AccessibilityQuery) throws -> Element? {
        var targets = matches
        let visible = targets.filter(\.isVisible)
        targets = visible.isEmpty ? targets : visible
        let actionable = targets.filter(\.isActionable)
        targets = actionable.isEmpty ? targets : actionable
        let notText = targets.filter { !$0.traits.contains(.staticText) }
        targets = notText.isEmpty ? targets : notText
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
        if let contentView = self.contentView(of: element.webView) {
            return contentView.isFirstResponder
        }

        return self.containsFirstResponder(element.webView)
    }

    // MARK: - Coordinates

    fileprivate static func element(_ raw: Output.RawElement, page: String, in webView: WKWebView,
                                    window: UIWindow) -> Element
    {
        let contentView = self.contentView(of: webView)
        let frame = self.convert(CGRect(x: raw.x, y: raw.y, width: raw.width, height: raw.height),
                                 from: webView, to: window, through: contentView)
        let hitPoint = self.convert(CGRect(x: raw.hitX, y: raw.hitY, width: 0, height: 0),
                                    from: webView, to: window, through: contentView).origin
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

    /// Converts a rectangle in the document's CSS pixels to the window.
    ///
    /// Through the content view, which is scaled and scrolled with the page, the conversion includes every
    /// transform UIKit applies. Without it, the document is the scroll view's content scaled by its zoom.
    ///
    /// - parameter rect:        The rectangle in CSS pixels from the top left of the document.
    /// - parameter webView:     The web view.
    /// - parameter window:      The window.
    /// - parameter contentView: The view the web view zooms, from `contentView(of:)`, or nil.
    ///
    /// - returns: The rectangle in the window.
    static func convert(_ rect: CGRect, from webView: WKWebView, to window: UIWindow,
                        through contentView: UIView?) -> CGRect
    {
        if let contentView {
            return contentView.convert(rect, to: window)
        }

        let scrollView = webView.scrollView
        let scale = scrollView.zoomScale
        let scaled = CGRect(x: rect.minX * scale, y: rect.minY * scale,
                            width: rect.width * scale, height: rect.height * scale)
        return scrollView.convert(scaled, to: window)
    }

    /// The view that shows the page, which the web view's scroll view zooms.
    ///
    /// This relies on the scroll view's delegate giving it, which WebKit doesn't promise and some iOS
    /// versions don't do; without it, `convert(_:from:to:through:)` falls back to the scroll view's zoom.
    ///
    /// - parameter webView: The web view.
    ///
    /// - returns: The content view, or nil if the scroll view's delegate doesn't give one.
    static func contentView(of webView: WKWebView) -> UIView? {
        let scrollView = webView.scrollView
        return scrollView.delegate?.viewForZooming?(in: scrollView)
    }

    fileprivate static func containsFirstResponder(_ view: UIView) -> Bool {
        return view.isFirstResponder || view.subviews.contains(where: self.containsFirstResponder)
    }

}

// MARK: - Running the script

extension WebContent {
    fileprivate static func run<T: Decodable>(_ arguments: [String: Any], in webView: WKWebView,
                                              timeout: TimeInterval = WebContent.defaultTimeout) async throws
        -> T
    {
        let deadline = Date().addingTimeInterval(timeout)
        try await self.waitUntilScrollingStops(webView, until: deadline)

        let id = ObjectIdentifier(webView)
        guard !self.busyWebViews.contains(id) else {
            throw AgentError.failed("The web view is still running an earlier read of its page", hint: """
                The page may be busy or its web content process may have stopped. Wait and try again
                """, code: .timedOut)
        }

        var arguments = arguments
        arguments["version"] = self.version
        arguments["page"] = arguments["page"] ?? ""
        arguments["id"] = arguments["id"] ?? 0
        var json = try await self.evaluate(kWebContentCallScript, arguments, in: webView, until: deadline)
        if json == kWebContentScriptNotInstalled {
            json = try await self.evaluate(kWebContentScript, arguments, in: webView, until: deadline)
        }

        do {
            return try JSONDecoder().decode(T.self, from: Data(json.utf8))
        } catch {
            throw AgentError.failed("The web view returned an unexpected result: \(error)")
        }
    }

    /// Waits for the web view to stop scrolling, since the page reports where it was scrolled to with a delay
    /// while the scroll view moves, such as after a swipe.
    private static func waitUntilScrollingStops(_ webView: WKWebView, until deadline: Date) async throws {
        let scrollView = webView.scrollView
        let settleDeadline = min(deadline, Date().addingTimeInterval(self.scrollSettleTimeout))
        while scrollView.isDragging || scrollView.isDecelerating || scrollView.isZooming {
            guard Date() < settleDeadline else {
                return
            }

            try await Task.sleep(for: .milliseconds(16))
        }
    }

    private static func evaluate(_ script: String, _ arguments: [String: Any], in webView: WKWebView,
                                 until deadline: Date) async throws -> String
    {
        let id = ObjectIdentifier(webView)
        let timeout = max(deadline.timeIntervalSinceNow, 0.05)
        let once = ResumeOnce()
        self.busyWebViews.insert(id)
        return try await withCheckedThrowingContinuation { continuation in
            once.continuation = continuation
            webView.callAsyncJavaScript(script, arguments: arguments, in: nil, in: self.world) { result in
                self.busyWebViews.remove(id)
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

            once.timeout = Task { @MainActor in
                try? await Task.sleep(for: .seconds(timeout))
                guard !Task.isCancelled else {
                    return
                }

                once.resume(with: .failure(AgentError.failed(
                    "The web view didn't answer within \(String(format: "%.1f", timeout)) seconds",
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
    var timeout: Task<Void, Never>?

    func resume(with result: Result<String, Error>) {
        self.timeout?.cancel()
        self.timeout = nil
        self.continuation?.resume(with: result)
        self.continuation = nil
    }
}
