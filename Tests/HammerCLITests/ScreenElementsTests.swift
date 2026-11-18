#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation
@testable import HammerCLI
import HammerAgentCore
import Testing

private struct FakeElement: ScreenElement {
    var type = "View"
    var identifier: String?
    var label: String?
    var value: String?
    var traits: [String] = []
    var frame = CGRect(x: 0, y: 0, width: 10, height: 10)
    var children: [FakeElement] = []
}

private func target(_ json: String) throws -> ScreenTarget {
    return try JSONDecoder().decode(ScreenTarget.self, from: Data(json.utf8))
}

private func failure(_ body: () throws -> Void) -> AgentErrorBody? {
    do {
        try body()
        return nil
    } catch ClientError.failed(let error, _) {
        return error
    } catch {
        return nil
    }
}

struct ScreenElementsTests {
    private let root = FakeElement(children: [
        FakeElement(label: "OK", traits: ["button"], frame: CGRect(x: 10, y: 20, width: 30, height: 40)),
        FakeElement(identifier: "name", value: "Ann", traits: ["textField"]),
        FakeElement(label: "Cancel", traits: ["button"]),
    ])

    @Test
    func queryMatchesEveryPropertyGiven() throws {
        let query = try #require(try target(#"{"label": "OK", "traits": ["button"]}"#)
            .query(traitNames: ["button", "textField"]))

        #expect(try query.element(in: self.root).frame == CGRect(x: 10, y: 20, width: 30, height: 40))
    }

    @Test
    func pointTargetHasNoQuery() throws {
        let point = try target(#"{"x": 1.5, "y": 2}"#)

        #expect(try point.query(traitNames: []) == nil)
        #expect(try point.point() == CGPoint(x: 1.5, y: 2))
    }

    @Test
    func onlyOneCoordinateIsInvalid() throws {
        let error = failure { _ = try target(#"{"x": 1}"#).point() }

        #expect(error?.code == .invalidArguments)
        #expect(error?.hint == "Pass both, in the coordinates of describe's frames")
    }

    @Test
    func elementAndPointTogetherAreInvalid() throws {
        let error = failure { _ = try target(#"{"label": "OK", "x": 1, "y": 2}"#).query(traitNames: []) }

        #expect(error?.code == .invalidArguments)
        #expect(error?.error == "The target has both an element and a point")
    }

    @Test
    func unknownTraitSuggestsTheClosest() throws {
        let buton = try target(#"{"traits": ["buton"]}"#)
        let error = failure { _ = try buton.query(traitNames: ["button", "image"]) }

        #expect(error?.error == "Unknown trait \"buton\", did you mean button?")
        #expect(error?.hint == "The traits are button, image")
    }

    @Test
    func severalMatchesAreAmbiguous() throws {
        let query = ElementQuery(identifier: nil, label: nil, value: nil, traits: ["button"])
        let error = failure { _ = try query.element(in: self.root) }

        #expect(error?.code == .ambiguousTarget)
        #expect(error?.error == "2 elements match traits button")
    }

    @Test
    func notFoundNamesTheButtons() throws {
        let query = ElementQuery(identifier: nil, label: "Done", value: nil, traits: [])
        let error = failure { _ = try query.element(in: self.root) }

        #expect(error?.code == .notFound)
        #expect(error?.error == "Unable to find element: label \"Done\"")
        #expect(error?.hint == "Call describe to see the elements on screen. The buttons on screen are "
            + "\"OK\", \"Cancel\"")
    }

    @Test
    func notFoundNamesAtMostTenButtons() throws {
        let buttons = (1...25).map { FakeElement(label: "B\($0)", traits: ["button"]) }
        let query = ElementQuery(identifier: nil, label: "Done", value: nil, traits: [])
        let error = failure { _ = try query.element(in: FakeElement(children: buttons)) }

        #expect(error?.hint == "Call describe to see the elements on screen. The buttons on screen are "
            + (1...10).map { "\"B\($0)\"" }.joined(separator: ", ") + " and 15 more")
    }

    @Test
    func describeReplacesEmptyElementsByTheirChildren() throws {
        let root = FakeElement(label: " ", children: [
            FakeElement(type: "Button", label: "OK", traits: ["button"],
                        frame: CGRect(x: 1.04, y: 2.06, width: 3, height: 4)),
        ])
        let json = try #require(String(data: try DescribedElement.encode([root]), encoding: .utf8))

        #expect(json == #"[{"frame":{"height":4,"width":3,"x":1,"y":2.1},"label":"OK","traits":["button"],"#
            + #""type":"Button"}]"#)
    }
}
