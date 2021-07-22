import Hammer
import XCTest
#if canImport(SwiftUI)
import SwiftUI
#endif

final class HandTests_SwiftUI: XCTestCase {
    func testButtonTap() throws {
        guard #available(iOS 13.0, *) else {
            throw XCTSkip("SwiftUI tests require iOS 13 or later")
        }

        let expectation = XCTestExpectation(description: "Button Tapped")

        let view = Button("Button", action: expectation.fulfill)
            .background(Color.green)

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)
        try eventGenerator.fingerTap()

        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 1), .completed)
    }

    func testButtonTapOnHidden() throws {
        guard #available(iOS 13.0, *) else {
            throw XCTSkip("SwiftUI tests require iOS 13 or later")
        }

        let view = Button("Button", action: {})
            .background(Color.green)
            .hidden()

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.wait(0.5)

        do {
            try eventGenerator.fingerTap()
            XCTFail("Button should not be tappable")
        } catch HammerError.unableToFindMainView {
            // Success
        } catch {
            throw error
        }
    }

    func testButtonTapOnMinimumAlpha() throws {
        guard #available(iOS 13.0, *) else {
            throw XCTSkip("SwiftUI tests require iOS 13 or later")
        }

        let view = Button("Button", action: {})
            .background(Color.green)
            .opacity(0.001)

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.wait(0.5)

        do {
            try eventGenerator.fingerTap()
            XCTFail("Button should not be tappable")
        } catch HammerError.viewIsNotVisible {
            // Success
        } catch {
            throw error
        }
    }

    func testViewTapGesture() throws {
        guard #available(iOS 13.0, *) else {
            throw XCTSkip("SwiftUI tests require iOS 13 or later")
        }

        let expectation = XCTestExpectation(description: "Gesture Tapped")

        let view = Text("Hello World")
            .background(Color.green)
            .onTapGesture(perform: expectation.fulfill)

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)
        try eventGenerator.fingerTap()

        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 1), .completed)
    }

    func testViewLongPressGesture() throws {
        guard #available(iOS 13.0, *) else {
            throw XCTSkip("SwiftUI tests require iOS 13 or later")
        }

        let expectation = XCTestExpectation(description: "Gesture Long Pressed Tapped")

        let view = Text("Hello World")
            .background(Color.green)
            .onLongPressGesture(perform: expectation.fulfill)

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)
        try eventGenerator.fingerLongPress()

        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 3), .completed)
    }

    func testSwitchToggle() throws {
        guard #available(iOS 13.0, *) else {
            throw XCTSkip("SwiftUI tests require iOS 13 or later")
        }

        var isOn = false
        let isOnBinding = Binding<Bool>(get: { isOn }, set: { isOn = $0 })
        let view = Toggle(isOn: isOnBinding) { EmptyView() }

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        XCTAssertFalse(isOn)
        try eventGenerator.fingerTap()
        try eventGenerator.wait(1)
        XCTAssertTrue(isOn)
    }

    func testSwitchToggleOnOff() throws {
        guard #available(iOS 13.0, *) else {
            throw XCTSkip("SwiftUI tests require iOS 13 or later")
        }

        var isOn = false
        let isOnBinding = Binding<Bool>(get: { isOn }, set: { isOn = $0 })
        let view = Toggle(isOn: isOnBinding) { EmptyView() }

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)
        let rootView = try eventGenerator.rootView()

        XCTAssertFalse(isOn)
        try eventGenerator.fingerDown(at: rootView.frame.center.offset(x: -20, y: 0))
        try eventGenerator.fingerMove(to: rootView.frame.center.offset(x: 40, y: 0), duration: 0.5)
        try eventGenerator.fingerUp()
        XCTAssertTrue(isOn)
        try eventGenerator.fingerDown(at: rootView.frame.center.offset(x: 20, y: 0))
        try eventGenerator.fingerMove(to: rootView.frame.center.offset(x: -40, y: 0), duration: 0.5)
        try eventGenerator.fingerUp()
        XCTAssertFalse(isOn)
    }
}
