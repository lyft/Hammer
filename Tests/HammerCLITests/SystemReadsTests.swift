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

    @Test
    func regionsAreTheFramesOfMarkedNodes() throws {
        #expect(SystemReads.regions(in: try self.nodes()) == [CGRect(x: 0, y: 53, width: 448, height: 920.3)])
    }

    @Test
    func contentIsWhatIsInsideTheInnermostViewWithTheRegionsFrame() throws {
        let region = try #require(SystemReads.regions(in: try self.nodes()).first)

        let content = try #require(SystemReads.content(of: region, in: try self.windows()))

        #expect(self.labels(content) == ["Send", "Press"])
        #expect(content.count == 3)
    }

    @Test
    func viewTheHelperDidntReadHasNoContent() throws {
        let elsewhere = CGRect(x: 10, y: 10, width: 50, height: 50)

        #expect(SystemReads.content(of: elsewhere, in: try self.windows()) == nil)
    }

    @Test
    func mergeAddsTheContentAndDropsTheMark() throws {
        let nodes = try self.nodes()
        let content = SystemReads.content(of: SystemReads.regions(in: nodes)[0], in: try self.windows())

        let merged = SystemReads.merge(nodes, contents: [content])

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
        let region = SystemReads.regions(in: try self.nodes())[0]
        let content = try #require(SystemReads.content(of: region, in: try self.windows()))
        let send = try #require(SystemReads.matches(ElementQuery(identifier: nil, label: "Send", value: nil,
                                                                 traits: []), in: content).first)
        guard case .string(let ref)? = send["ref"] else {
            Issue.record("Send has no ref")
            return
        }

        #expect(ref.hasPrefix(SystemReads.refPrefix))
        #expect(SystemReads.point(of: ref, in: try self.windows()) == CGPoint(x: 363, y: 158))
    }

    @Test
    func movedElementLosesItsRef() throws {
        let content = try #require(SystemReads.content(of: SystemReads.regions(in: try self.nodes())[0],
                                                       in: try self.windows()))
        let send = try #require(SystemReads.matches(ElementQuery(identifier: nil, label: "Send", value: nil,
                                                                 traits: []), in: content).first)
        let moved = self.helper.replacingOccurrences(of: "[996,411,1182,537]", with: "[996,111,1182,237]")
        let scrolled = try HelperDump.windows(from: Data(moved.utf8), scale: 3)
        guard case .string(let ref)? = send["ref"] else {
            Issue.record("Send has no ref")
            return
        }

        #expect(SystemReads.point(of: ref, in: scrolled) == nil)
    }

    @Test
    func queriesMatchLikeTheAgents() throws {
        let content = try #require(SystemReads.content(of: SystemReads.regions(in: try self.nodes())[0],
                                                       in: try self.windows()))

        let query = ElementQuery(identifier: nil, label: nil, value: nil, traits: ["button"])
        let buttons = SystemReads.matches(query, in: content)
        let email = SystemReads.matches(ElementQuery(identifier: "email", label: nil, value: nil, traits: []),
                                        in: content)

        #expect(buttons.count == 3)
        #expect(email.count == 1)
    }
}
