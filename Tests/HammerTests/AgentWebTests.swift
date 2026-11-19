import Hammer
import HammerAgent
import HammerAgentCore
import UIKit
import WebKit
import XCTest

@MainActor
final class AgentWebTests: XCTestCase {
    private var agent: HammerAgent!
    private var hostEventGenerator: EventGenerator?

    override func setUp() async throws {
        try await super.setUp()
        self.agent = HammerAgent(port: 0)
        try await self.agent.start()
    }

    override func tearDown() async throws {
        self.agent.stop()
        try await self.hostEventGenerator?.finish()
        self.hostEventGenerator = nil
        try await super.tearDown()
    }

    func testDescribeListsThePageElements() async throws {
        try await self.presentPage("""
            <h1>Welcome</h1>
            <p>Read the <b>terms</b> first</p>
            <a href="#more">More</a>
            <button id="sign_in">Sign In</button>
            <label for="email">Email</label><input id="email" value="a@b.c">
            <input type="checkbox" id="remember" checked aria-label="Remember me">
            <img src="data:," alt="Logo" width="20" height="20">
            <button disabled>Later</button>
            <div aria-hidden="true">Hidden</div>
            """)

        let nodes = try await self.describe()
        let webView = try XCTUnwrap(nodes.first { $0.type == "WKWebView" })
        let elements = try XCTUnwrap(webView.children).filter { $0.ref.hasPrefix("w") }
        let summary = elements.map { "\($0.type) \($0.label ?? "-") \($0.traits ?? [])" }
        XCTAssertEqual(summary, [
            "h1 Welcome [\"header\"]",
            "text Read the terms first [\"staticText\"]",
            "a More [\"link\"]",
            "button Sign In [\"button\"]",
            "text Email [\"staticText\"]",
            "input Email []",
            "input Remember me [\"button\", \"selected\", \"toggleButton\"]",
            "img Logo [\"image\"]",
            "button Later [\"button\", \"notEnabled\"]",
        ])

        let email = try XCTUnwrap(elements.first { $0.identifier == "email" })
        XCTAssertEqual(email.value, "a@b.c")
        XCTAssertEqual(elements.first { $0.identifier == "remember" }?.value, "1")
        XCTAssertTrue(email.hittable)
        let webFrame = webView.frame
        XCTAssertTrue(email.frame.minX >= webFrame.minX && email.frame.maxX <= webFrame.maxX,
                      "\(email.frame)")
    }

    func testTapsAWebButtonByLabel() async throws {
        let webView = try await self.presentPage("""
            <button onclick="this.textContent = 'Tapped'">Sign In</button>
            """)

        let (_, status) = try await self.agent.run("tap", ["label": "Sign In", "traits": ["button"]])
        XCTAssertEqual(status, 200)
        try await self.waitForPage(webView, "document.querySelector('button').textContent", toBe: "Tapped")
    }

    func testTapsALinkThatWrapsOnItsFirstLine() async throws {
        let webView = try await self.presentPage("""
            <p style="width: 200px; font-size: 18px">Read the terms first, then
            <a href="#" id="wrapped" onclick="this.textContent = 'Tapped'; return false">see section seventeen
            below</a> for more.</p>
            """)

        let elementsBefore = try await self.webElements()
        let link = try XCTUnwrap(elementsBefore.first { $0.identifier == "wrapped" })
        XCTAssertGreaterThan(link.frame.height, 30, "The link wraps onto two lines")
        XCTAssertTrue(link.hittable)

        let (_, status) = try await self.agent.run("tap", ["ref": .string(link.ref)])
        XCTAssertEqual(status, 200)
        try await self.waitForPage(webView, "document.getElementById('wrapped').textContent", toBe: "Tapped")
    }

    func testTapsAWebElementByRefAfterThePageScrolls() async throws {
        let webView = try await self.presentPage("""
            <div style="height: 2000px"></div>
            <button id="far" onclick="this.textContent = 'Tapped'">Far</button>
            <div style="height: 2000px"></div>
            """)

        let offScreenElement = try await self.webElements().first { $0.identifier == "far" }
        XCTAssertNil(offScreenElement, "Elements off screen are left out of describe")

        let (offScreen, offScreenStatus) = try await self.agent.run("tap", ["identifier": "far"])
        XCTAssertEqual(offScreenStatus, 500)
        XCTAssertEqual(try JSONDecoder().decode(AgentErrorBody.self, from: offScreen).code, .notVisible)

        _ = try await self.evaluate(webView,
                                    "document.getElementById('far').scrollIntoView({block: 'start'})")
        let refElements = try await self.webElements()
        let ref = try XCTUnwrap(refElements.first { $0.identifier == "far" }?.ref)

        _ = try await self.evaluate(webView, "window.scrollBy(0, -100)")
        let (_, status) = try await self.agent.run("tap", ["ref": .string(ref)])
        XCTAssertEqual(status, 200)
        try await self.waitForPage(webView, "document.getElementById('far').textContent", toBe: "Tapped")
        let afterTap = try await self.webElements()
        XCTAssertEqual(afterTap.first { $0.identifier == "far" }?.ref, ref)
    }

    func testTapsAtTheRightPointOnAZoomedOutPage() async throws {
        // Without a viewport, the page is laid out 980 pixels wide and zoomed out to fit
        let webView = try await self.presentPage("""
            <button id="right" style="position: absolute; left: 700px; top: 300px; width: 200px; height: 80px"
                    onclick="this.textContent = 'Tapped'">Right</button>
            """, viewport: false)
        XCTAssertLessThan(webView.scrollView.zoomScale, 0.5)

        let buttonElements = try await self.webElements()

        let button = try XCTUnwrap(buttonElements.first { $0.identifier == "right" })
        let scale = Double(webView.scrollView.zoomScale)
        XCTAssertEqual(button.frame.width, 200 * scale, accuracy: 1)

        let (_, status) = try await self.agent.run("tap", ["ref": .string(button.ref)])
        XCTAssertEqual(status, 200)
        try await self.waitForPage(webView, "document.getElementById('right').textContent", toBe: "Tapped")
    }

    func testTypesIntoAWebField() async throws {
        let webView = try await self.presentPage("""
            <input id="name" autocomplete="off" autocorrect="off" autocapitalize="off" spellcheck="false">
            """)

        let (data, status) = try await self.agent.run("type_text", ["identifier": "name", "text": "Hammer"])
        XCTAssertEqual(status, 200, String(bytes: data, encoding: .utf8) ?? "")
        try await self.waitForPage(webView, "document.getElementById('name').value", toBe: "Hammer")
    }

    func testWaitsForAWebElement() async throws {
        try await self.presentPage("""
            <script>
            setTimeout(() => {
                const button = document.createElement('button');
                button.textContent = 'Continue';
                document.body.append(button);
            }, 500);
            </script>
            """)

        let (_, status) = try await self.agent.run("wait_for", ["label": "Continue", "timeout": 5])
        XCTAssertEqual(status, 200)

        let (_, goneStatus) = try await self.agent.run("wait_for", [
            "label": "Continue", "condition": "gone", "timeout": 0.2,
        ])
        XCTAssertEqual(goneStatus, 500)
    }

    func testReadsSameOriginFramesAndShadowRoots() async throws {
        let webView = try await self.presentPage("""
            <iframe style="width: 280px; height: 120px; border: 4px solid black"
                    srcdoc="<button onclick=&quot;parent.framed = true&quot;>Framed</button>"></iframe>
            <div id="host"></div>
            <script>
            const root = document.getElementById('host').attachShadow({mode: 'open'});
            root.innerHTML = '<button onclick="window.shadowed = true">Shadowed</button>';
            </script>
            """)
        try await self.waitForPage(webView, "String(!!document.querySelector('iframe').contentDocument?.body"
            + "?.querySelector('button'))", toBe: "true")

        let (_, framedStatus) = try await self.agent.run("tap", ["label": "Framed"])
        XCTAssertEqual(framedStatus, 200)
        try await self.waitForPage(webView, "String(window.framed)", toBe: "true")

        let (_, shadowedStatus) = try await self.agent.run("tap", ["label": "Shadowed"])
        XCTAssertEqual(shadowedStatus, 200)
        try await self.waitForPage(webView, "String(window.shadowed)", toBe: "true")
    }

    func testARefFromAnotherPageIsNotFound() async throws {
        let webView = try await self.presentPage("<button>Sign In</button>")
        let refElements = try await self.webElements()
        let ref = try XCTUnwrap(refElements.first { $0.label == "Sign In" }?.ref)

        try await self.load(webView, "<button>Sign In</button>")
        let (data, status) = try await self.agent.run("tap", ["ref": .string(ref)])
        XCTAssertEqual(status, 500)
        XCTAssertEqual(try JSONDecoder().decode(AgentErrorBody.self, from: data).code, .notFound)
    }

    func testRejectsAWebRefForViewCommands() async throws {
        try await self.presentPage("<button>Sign In</button>")
        let refElements = try await self.webElements()
        let ref = try XCTUnwrap(refElements.first { $0.label == "Sign In" }?.ref)

        let (data, status) = try await self.agent.run("inspect", ["ref": .string(ref)])
        XCTAssertEqual(status, 400)
        let body = try JSONDecoder().decode(AgentErrorBody.self, from: data)
        XCTAssertTrue(body.error.contains("web page"), body.error)
    }

    func testPageScriptsCantSeeTheAgent() async throws {
        let webView = try await self.presentPage("<button>Sign In</button>")
        _ = try await self.describe()

        let type = try await self.evaluate(webView, "typeof globalThis.__hammer")
        XCTAssertEqual(type, "undefined")
    }

    // MARK: - Helpers

    private struct DescribedNode: Decodable {
        struct Frame: Decodable {
            let x: Double
            let y: Double
            let width: Double
            let height: Double

            var minX: Double { self.x }
            var maxX: Double { self.x + self.width }
        }

        let ref: String
        let type: String
        let identifier: String?
        let label: String?
        let value: String?
        let traits: [String]?
        let frame: Frame
        let hittable: Bool
        let children: [DescribedNode]?

        var flattened: [DescribedNode] {
            return [self] + (self.children ?? []).flatMap(\.flattened)
        }
    }

    private func describe() async throws -> [DescribedNode] {
        let (data, status) = try await self.agent.run("describe")
        XCTAssertEqual(status, 200)
        return try JSONDecoder().decode([DescribedNode].self, from: data)
    }

    private func webElements() async throws -> [DescribedNode] {
        return try await self.describe().flatMap(\.flattened).filter { $0.ref.hasPrefix("w") }
    }

    @discardableResult
    private func presentPage(_ body: String, viewport: Bool = true) async throws -> WKWebView {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        webView.setSize(width: 320, height: 480)
        self.hostEventGenerator = try await EventGenerator(view: webView)
        try await self.load(webView, body, viewport: viewport)
        return webView
    }

    /// Loads a page with the body, and waits until it is the one shown.
    private func load(_ webView: WKWebView, _ body: String, viewport: Bool = true) async throws {
        let marker = UUID().uuidString
        let head = viewport ? #"<meta name="viewport" content="width=device-width, initial-scale=1">"# : ""
        let html = """
            <!doctype html><html data-load="\(marker)"><head>\(head)</head><body>\(body)</body></html>
            """
        webView.loadHTMLString(html, baseURL: URL(string: "https://hammer.test/"))
        try await self.waitForPage(webView, """
            document.readyState === 'complete' && document.documentElement.dataset.load === '\(marker)'
                ? 'loaded' : 'loading'
            """, toBe: "loaded", timeout: 15)
        // Lets the web view apply the page's zoom before reading frames
        try await self.hostEventGenerator?.waitUntilFrameIsRendered()
        try await Task.sleep(for: .milliseconds(200))
    }

    private func waitForPage(_ webView: WKWebView, _ script: String, toBe expected: String,
                             timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line)
        async throws
    {
        let deadline = Date().addingTimeInterval(timeout)
        var value = try? await self.evaluate(webView, script)
        while value != expected && Date() < deadline {
            try await Task.sleep(for: .milliseconds(50))
            value = try? await self.evaluate(webView, script)
        }

        XCTAssertEqual(value, expected, script, file: file, line: line)
    }

    /// Evaluates the expression in the page's own world, as the page's scripts see it.
    private func evaluate(_ webView: WKWebView, _ expression: String) async throws -> String? {
        return try await withCheckedThrowingContinuation { continuation in
            webView.callAsyncJavaScript("return String(\(expression))", arguments: [:], in: nil,
                                        in: .page)
            { result in
                continuation.resume(with: result.map { $0 as? String })
            }
        }
    }
}
