@testable import HammerAgent
import JavaScriptCore
import UIKit
import WebKit
import XCTest

/// Tests the parts of reading web pages that commands don't show directly.
@MainActor
final class WebContentInternalsTests: XCTestCase {
    func testScriptsAreValidJavaScript() throws {
        for script in [kWebContentScript, kWebContentCallScript] {
            let context = try XCTUnwrap(JSContext())
            var exception: String?
            context.exceptionHandler = { _, value in exception = value?.toString() }
            // The scripts run as the body of an async function, as callAsyncJavaScript runs them
            context.evaluateScript("(async function (operation, page, id, version) {\n\(script)\n})")
            XCTAssertNil(exception, String(script.prefix(80)))
        }
    }

    func testWebRefsOfAReplacedPageAreDropped() throws {
        let references = ObjectReferences()
        let webView = WKWebView()
        let first = references.ref(for: self.element(in: webView, page: "a", id: 1))
        XCTAssertEqual(references.ref(for: self.element(in: webView, page: "a", id: 1)), first)
        XCTAssertNoThrow(try references.webElement(for: first))

        let second = references.ref(for: self.element(in: webView, page: "b", id: 1))
        XCTAssertNotEqual(second, first)
        XCTAssertThrowsError(try references.webElement(for: first))
        XCTAssertNoThrow(try references.webElement(for: second))
    }

    func testAPageKeepsAtMostItsLatestWebRefs() throws {
        let references = ObjectReferences(maxWebElementRefs: 3)
        let webView = WKWebView()
        let refs = (1...5).map { references.ref(for: self.element(in: webView, page: "a", id: $0)) }

        XCTAssertThrowsError(try references.webElement(for: refs[0]))
        XCTAssertThrowsError(try references.webElement(for: refs[1]))
        for ref in refs[2...] {
            XCTAssertNoThrow(try references.webElement(for: ref))
        }
    }

    func testWebRefsOfAReleasedWebViewAreDropped() async throws {
        let references = ObjectReferences()
        weak var released: WKWebView?
        let ref = autoreleasepool {
            let webView = WKWebView()
            released = webView
            return references.ref(for: self.element(in: webView, page: "a", id: 1))
        }

        // WebKit can hold the web view until the run loop turns
        let deadline = Date().addingTimeInterval(5)
        while released != nil && Date() < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }

        XCTAssertNil(released)
        references.removeReleased()
        XCTAssertThrowsError(try references.webElement(for: ref))
    }

    func testConvertsWithoutTheContentViewLikeWithIt() async throws {
        // Zoomed out and scrolled, so the two ways must agree on the zoom and the offset
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(webView)
        window.isHidden = false
        defer { window.isHidden = true }
        webView.loadHTMLString("<div style='width: 980px; height: 4000px'></div>", baseURL: nil)
        let deadline = Date().addingTimeInterval(10)
        while (webView.isLoading || webView.scrollView.contentSize.height < 1000) && Date() < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }

        let scrollView = webView.scrollView
        scrollView.contentOffset = CGPoint(x: 0, y: 300)
        XCTAssertLessThan(scrollView.zoomScale, 1)
        // The view that shows the page is the one as big as the scroll view's content
        let contentView = try XCTUnwrap(WebContent.contentView(of: webView) ?? scrollView.subviews.first {
            abs($0.frame.width - scrollView.contentSize.width) < 1 && $0.frame.height > 1000
        })

        let rect = CGRect(x: 100, y: 900, width: 200, height: 50)
        let through = WebContent.convert(rect, from: webView, to: window, through: contentView)
        let fallback = WebContent.convert(rect, from: webView, to: window, through: nil)
        XCTAssertEqual(through.minX, fallback.minX, accuracy: 0.5)
        XCTAssertEqual(through.minY, fallback.minY, accuracy: 0.5)
        XCTAssertEqual(through.width, fallback.width, accuracy: 0.5)
    }

    private func element(in webView: WKWebView, page: String, id: Int) -> WebContent.Element {
        return WebContent.Element(webView: webView, page: page, id: id, type: "button", identifier: nil,
                                  label: "OK", value: nil, traits: .button, isEditable: false,
                                  frame: .zero, hitPoint: .zero, isVisible: true, isHittable: true)
    }
}
