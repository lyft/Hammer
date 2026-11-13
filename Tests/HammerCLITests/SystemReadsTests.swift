#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation
@testable import HammerCLI
import HammerAgentCore
import Testing

struct SystemReadsTests {
    private let describe = """
        [{"ref":"e4","type":"android.widget.FrameLayout","frame":{"x":0,"y":53,"width":448,"height":920.3},
          "hittable":true,
          "children":[{"ref":"e5","type":"android.webkit.WebView","identifier":"web_page",
                       "accessibilityClass":"android.webkit.WebView",
                       "frame":{"x":0,"y":53,"width":448,"height":920.3},"hittable":true,
                       "needsSystemRead":true}]},
         {"ref":"e6","type":"android.view.View","identifier":"navigationBarBackground",
          "frame":{"x":0,"y":973.3,"width":448,"height":24},"hittable":true}]
        """

    // The helper's read of the same screen at 3 pixels per dp: the web view and the page inside it
    private let helper = """
        {"windows":[{"package":"com.example.app","bounds":[0,0,1344,2992],"root":
          {"class":"android.widget.FrameLayout","bounds":[0,159,1344,2920],"flags":[],"children":[
            {"class":"android.webkit.WebView","resource-id":"com.example.app:id/web_page",
             "bounds":[0,159,1344,2920],"flags":[],"children":[
              {"class":"android.webkit.WebView","bounds":[0,159,1344,2920],
               "flags":["scrollable","scroll-forward"],
               "children":[
                {"class":"android.widget.EditText","resource-id":"email","bounds":[177,411,987,537],
                 "flags":["clickable","editable"]},
                {"class":"android.widget.Button","text":"Send","bounds":[996,411,1182,537],
                 "flags":["clickable"]},
                {"class":"android.widget.Button","text":"Press","bounds":[75,831,225,897],
                 "flags":["clickable"]}
              ]}
            ]}
          ]}}]}
        """

    private func nodes() throws -> [JSONValue] {
        return try JSONDecoder().decode([JSONValue].self, from: Data(self.describe.utf8))
    }

    private func windows() throws -> [AndroidElement] {
        return try HelperDump.windows(from: Data(self.helper.utf8), scale: 3)
    }

    private func labels(_ nodes: [JSONValue]) -> [String] {
        return nodes.flatMap { node -> [String] in
            guard case .object(let fields) = node else {
                return []
            }

            let label = fields["label"].flatMap { value -> String? in
                if case .string(let label) = value { return label } else { return nil }
            }
            let children: [JSONValue]
            if case .array(let array)? = fields["children"] { children = array } else { children = [] }
            return (label.map { [$0] } ?? []) + self.labels(children)
        }
    }

    private func content(_ windows: [AndroidElement]? = nil) throws -> [JSONValue] {
        let regions = SystemReads.regions(in: try self.nodes())
        return try #require(SystemReads.contents(of: regions, in: try windows ?? self.windows()).first ?? nil)
    }

    private func send(in content: [JSONValue]) throws -> String {
        let query = ElementQuery(identifier: nil, label: "Send", value: nil, traits: [])
        let send = try #require(SystemReads.matches(query, in: content).first)
        guard case .string(let ref)? = send["ref"] else {
            throw ClientError.failed(.init(error: "Send has no ref", code: .failed))
        }

        return ref
    }

    @Test
    func regionsAreTheMarkedNodesWithTheirClassAndIdentifier() throws {
        let regions = SystemReads.regions(in: try self.nodes())

        let webView = SystemReads.Region(frame: CGRect(x: 0, y: 53, width: 448, height: 920.3),
                                         className: "android.webkit.WebView", identifier: "web_page")
        #expect(regions == [webView])
        #expect(regions.first?.isWebView == true)
    }

    @Test
    func contentIsWhatIsInsideTheOutermostViewOfTheRegionsClassAndIdentifier() throws {
        let content = try self.content()

        #expect(self.labels(content) == ["Send", "Press"])
        #expect(content.count == 1)
    }

    @Test
    func childThatFillsTheViewIsntTakenForIt() throws {
        // A page whose overlay fills the web view, which the agent's own frame for it also matches
        let overlay = self.helper.replacingOccurrences(of: """
            {"class":"android.widget.EditText"
            """, with: """
            {"class":"android.webkit.WebView","bounds":[0,159,1344,2920],"flags":[]},
            {"class":"android.widget.EditText"
            """)

        let content = try self.content(HelperDump.windows(from: Data(overlay.utf8), scale: 3))

        #expect(self.labels(content) == ["Send", "Press"])
    }

    @Test
    func regionWithoutAClassTakesTheInnermostView() throws {
        let nodes = try self.nodes()
        let region = try #require(SystemReads.regions(in: nodes).first)
        let unclassed = SystemReads.Region(frame: region.frame, className: nil, identifier: nil)

        let content = try #require(SystemReads.contents(of: [unclassed], in: try self.windows()).first ?? nil)

        #expect(self.labels(content) == ["Send", "Press"])
        #expect(content.count == 3)
    }

    @Test
    func stackedViewsWithOneFrameEachGetTheirOwnContent() throws {
        let region = try #require(SystemReads.regions(in: try self.nodes()).first)
        let unnamed = SystemReads.Region(frame: region.frame, className: region.className, identifier: nil)
        let stacked = self.helper.replacingOccurrences(of: """
            "flags":[],"children":[
                {"class":"android.webkit.WebView","resource-id"
            """, with: """
            "flags":[],"children":[
                {"class":"android.webkit.WebView","bounds":[0,159,1344,2920],"flags":[],"children":[
                  {"class":"android.widget.Button","text":"Behind","bounds":[75,831,225,897],"flags":[]}]},
                {"class":"android.webkit.WebView","resource-id"
            """)
        #expect(stacked != self.helper)

        let contents = SystemReads.contents(of: [unnamed, unnamed],
                                            in: try HelperDump.windows(from: Data(stacked.utf8), scale: 3))

        #expect(contents.map { self.labels($0 ?? []) } == [["Behind"], ["Send", "Press"]])
    }

    @Test
    func viewWithoutAnIdForTheHelperIsFoundByItsFrameAndClass() throws {
        let unnamed = self.helper.replacingOccurrences(of: #""resource-id":"com.example.app:id/web_page","#,
                                                       with: "")
        #expect(unnamed != self.helper)

        let content = try self.content(HelperDump.windows(from: Data(unnamed.utf8), scale: 3))

        #expect(self.labels(content) == ["Send", "Press"])
    }

    @Test
    func viewWithAnotherIdIsntTheRegionsView() throws {
        let region = try #require(SystemReads.regions(in: try self.nodes()).first)
        let other = SystemReads.Region(frame: region.frame, className: region.className, identifier: "other")
        let page = #"{"class":"android.webkit.WebView","bounds""#
        let named = self.helper.replacingOccurrences(
            of: page, with: #"{"class":"android.webkit.WebView","resource-id":"page","bounds""#)
        #expect(named != self.helper)
        let windows = try HelperDump.windows(from: Data(named.utf8), scale: 3)

        #expect(SystemReads.contents(of: [other], in: windows) == [nil])
    }

    @Test
    func viewTheHelperDidntReadHasNoContent() throws {
        let elsewhere = SystemReads.Region(frame: CGRect(x: 10, y: 10, width: 50, height: 50),
                                           className: "android.webkit.WebView", identifier: nil)

        #expect(SystemReads.contents(of: [elsewhere], in: try self.windows()) == [nil])
    }

    @Test
    func mergeAddsTheContentAndDropsTheMark() throws {
        let nodes = try self.nodes()

        let merged = SystemReads.merge(nodes, contents: [try self.content()])

        #expect(SystemReads.regions(in: merged) == [])
        #expect(self.labels(merged) == ["Send", "Press"])
    }

    @Test
    func unreadContentKeepsTheMark() throws {
        let nodes = try self.nodes()

        let merged = SystemReads.merge(nodes, contents: [nil])

        #expect(merged == nodes)
    }

    @Test
    func refsNameTheSameElementInEveryReadAndFindItsCenter() throws {
        let ref = try self.send(in: self.content())

        #expect(ref.hasPrefix(SystemReads.refPrefix))
        #expect(SystemReads.point(of: ref, in: try self.windows()) == CGPoint(x: 363, y: 158))
    }

    @Test
    func fieldKeepsItsRefAsItsValueChanges() throws {
        let email = ElementQuery(identifier: "email", label: nil, value: nil, traits: [])
        let typed = self.helper.replacingOccurrences(of: #""resource-id":"email","#,
                                                     with: #""resource-id":"email","text":"a@b.c","#)
        #expect(typed != self.helper)
        let before = try #require(SystemReads.matches(email, in: try self.content()).first?["ref"])

        let after = try #require(SystemReads.matches(
            email, in: try self.content(HelperDump.windows(from: Data(typed.utf8), scale: 3))).first)

        #expect(after["value"] == .string("a@b.c"))
        #expect(after["ref"] == before)
    }

    @Test
    func movedElementLosesItsRef() throws {
        let ref = try self.send(in: self.content())
        let moved = self.helper.replacingOccurrences(of: "[996,411,1182,537]", with: "[996,111,1182,237]")

        let scrolled = try HelperDump.windows(from: Data(moved.utf8), scale: 3)

        #expect(SystemReads.point(of: ref, in: scrolled) == nil)
    }

    @Test
    func queriesMatchLikeTheAgents() throws {
        let content = try self.content()

        let query = ElementQuery(identifier: nil, label: nil, value: nil, traits: ["button"])
        let buttons = SystemReads.matches(query, in: content)
        let email = SystemReads.matches(ElementQuery(identifier: "email", label: nil, value: nil, traits: []),
                                        in: content)

        #expect(buttons.count == 3)
        #expect(email.count == 1)
    }
}
