#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation
@testable import HammerCLI
import HammerAgentCore
import Testing

private func fixture(_ name: String) throws -> String {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "xml",
                                             subdirectory: "Fixtures"))
    return try String(contentsOf: url, encoding: .utf8)
}

private func element(_ predicate: (AndroidElement) -> Bool, in windows: [AndroidElement]) throws
    -> AndroidElement
{
    let matches = windows.flatMap(\.flattened).filter(predicate)
    try #require(matches.count == 1)
    return matches[0]
}

/// The rect rounded to a hundredth of a dp, since frames are scaled from pixels.
private func rounded(_ rect: CGRect) -> CGRect {
    func round(_ value: CGFloat) -> CGFloat { (value * 100).rounded() / 100 }
    return CGRect(x: round(rect.minX), y: round(rect.minY), width: round(rect.width),
                  height: round(rect.height))
}

struct UIAutomatorDumpTests {
    @Test
    func windowsAreBackToFrontAndLabeledByTitleOrPackage() throws {
        let windows = try #require(UIAutomatorDump.parse(try fixture("uiautomator-api37-windows"), scale: 3))

        #expect(windows.map(\.type) == ["Window", "Window"])
        #expect(windows.map(\.label) == ["Network & internet", "com.android.systemui"])
        #expect(windows.map { rounded($0.frame) } == [
            CGRect(x: 0, y: 0, width: 448, height: 997.33), CGRect(x: 0, y: 0, width: 448, height: 53),
        ])
    }

    @Test
    func switchIsAToggleButtonWithItsStateAsValue() throws {
        let windows = try #require(UIAutomatorDump.parse(try fixture("uiautomator-api37-windows"), scale: 3))
        let airplane = try element({ $0.identifier == "switchWidget" }, in: windows)

        #expect(airplane.type == "Switch")
        #expect(airplane.label == nil)
        #expect(airplane.value == "0")
        #expect(airplane.traits == ["toggleButton"])
        #expect(rounded(airplane.frame) == CGRect(x: 364, y: 270.33, width: 52, height: 48))
    }

    @Test
    func imageIsOnlyAnImageWithAContentDescription() throws {
        let windows = try #require(UIAutomatorDump.parse(try fixture("uiautomator-api37-windows"), scale: 3))
        let wifi = try element({ $0.identifier == "wifi_signal" }, in: windows)
        let mobile = try element({ $0.identifier == "mobile_signal" }, in: windows)

        #expect(wifi.label == "Wifi signal full.")
        #expect(wifi.traits == ["image"])
        #expect(mobile.label == nil)
        #expect(mobile.traits == [])
    }

    @Test
    func clickableIsAButtonAndTextIsStaticText() throws {
        let windows = try #require(UIAutomatorDump.parse(try fixture("uiautomator-api37-windows"), scale: 3))
        let up = try element({ $0.label == "Navigate up" }, in: windows)
        let title = try element({ $0.label == "Airplane mode" }, in: windows)

        #expect(up.type == "ImageButton")
        #expect(up.traits == ["button"])
        #expect(title.identifier == "title")
        #expect(title.traits == ["staticText"])
    }

    @Test
    func landscapeFramesAreInTheRotatedScreen() throws {
        let dump = try fixture("uiautomator-api37-windows-landscape")
        let windows = try #require(UIAutomatorDump.parse(dump, scale: 3))
        let airplane = try element({ $0.identifier == "switchWidget" }, in: windows)

        #expect(rounded(windows[0].frame) == CGRect(x: 0, y: 0, width: 997.33, height: 448))
        #expect(rounded(airplane.frame) == CGRect(x: 913.33, y: 269.33, width: 52, height: 48))
    }

    @Test
    func dumpWithoutWindowsHasOneRoot() throws {
        let windows = try #require(UIAutomatorDump.parse(try fixture("uiautomator-api28"), scale: 2.625))
        let wifi = try element({ $0.identifier == "switchWidget" }, in: windows)
        let airplane = try element({ $0.identifier == "switch_widget" }, in: windows)

        #expect(windows.count == 1)
        #expect(windows[0].type == "FrameLayout")
        #expect(wifi.label == "Wi\u{2011}Fi")
        #expect(wifi.value == "1")
        #expect(wifi.traits == ["toggleButton", "selected"])
        #expect(airplane.label == "OFF")
        #expect(airplane.value == "0")
        #expect(airplane.traits == ["toggleButton"])
    }

    @Test
    func focusedEditTextIsTheFocusedTextField() throws {
        let dump = """
            <?xml version='1.0' encoding='UTF-8' standalone='yes' ?><hierarchy rotation="0">\
            <node class="android.widget.FrameLayout" bounds="[0,0][300,300]">\
            <node class="android.widget.EditText" text="Ann" hint="Name" resource-id="com.example:id/name" \
            focused="true" bounds="[0,0][300,60]" />\
            <node class="android.widget.EditText" text="Email" hint="Email" focused="false" \
            bounds="[0,60][300,120]" />\
            </node></hierarchy>
            """
        let windows = try #require(UIAutomatorDump.parse(dump, scale: 1))
        let fields = windows[0].children

        #expect(fields.map(\.label) == ["Name", "Email"])
        #expect(fields.map(\.value) == ["Ann", nil])
        #expect(fields.map(\.isFocusedTextField) == [true, false])
    }

    @Test(arguments: [
        "android.widget.EditText", "android.widget.AutoCompleteTextView",
        "android.widget.MultiAutoCompleteTextView", "androidx.appcompat.widget.SearchView$SearchAutoComplete",
    ])
    func textFieldSubclassesAreTextFields(className: String) throws {
        let dump = """
            <?xml version='1.0' encoding='UTF-8' standalone='yes' ?><hierarchy rotation="0">\
            <node class="\(className)" text="SFO" hint="Search" focused="true" bounds="[0,0][300,60]" />\
            </hierarchy>
            """
        let field = try #require(UIAutomatorDump.parse(dump, scale: 1)?.first)

        #expect(field.label == "Search")
        #expect(field.value == "SFO")
        #expect(field.isFocusedTextField)
    }

    @Test
    func outputWithoutXMLIsNoDump() {
        #expect(UIAutomatorDump.parse("ERROR: null root node returned by UiTestAutomationBridge.",
                                      scale: 1) == nil)
    }
}

struct FocusedTextFieldTests {
    private let windows = [
        AndroidElement(type: "Window", identifier: nil, label: nil, value: nil, traits: [],
                       frame: CGRect(x: 0, y: 0, width: 400, height: 800), children: [
            AndroidElement(type: "EditText", identifier: "name", label: "Name", value: nil, traits: [],
                           frame: CGRect(x: 0, y: 0, width: 400, height: 60), children: [],
                           isFocusedTextField: true),
            AndroidElement(type: "EditText", identifier: "email", label: "Email", value: nil, traits: [],
                           frame: CGRect(x: 0, y: 100, width: 400, height: 60), children: []),
        ]),
    ]

    @Test
    func focusOnTheTappedFieldCounts() {
        #expect(AndroidSystemDriver.hasFocusedTextField(at: CGPoint(x: 200, y: 30), in: self.windows))
    }

    @Test
    func focusOnAnotherFieldDoesntCount() {
        #expect(!AndroidSystemDriver.hasFocusedTextField(at: CGPoint(x: 200, y: 130), in: self.windows))
    }
}

struct AndroidScreenTests {
    @Test(arguments: [
        ("Physical density: 480\nPhysical size: 1344x2992\ncur=1344x2992\n",
         CGSize(width: 1344, height: 2992)),
        ("Physical density: 480\nPhysical size: 1344x2992\ncur=2992x1344\n",
         CGSize(width: 2992, height: 1344)),
        ("Physical density: 420\nPhysical size: 1080x2400\n", CGSize(width: 1080, height: 2400)),
        ("Physical density: 420\nOverride density: 480\nPhysical size: 1080x2400\nOverride size: 720x1600\n",
         CGSize(width: 720, height: 1600)),
    ])
    func metricsUseTheCurrentRotatedSize(output: String, size: CGSize) throws {
        let metrics = try AndroidScreen.metrics(from: output)

        #expect(metrics.size == size)
    }

    @Test
    func metricsUseTheDensityOverride() throws {
        let metrics = try AndroidScreen.metrics(from: "Physical density: 420\nOverride density: 480\n"
            + "Physical size: 1080x2400\n")

        #expect(metrics.scale == 3)
        #expect(metrics.bounds == CGRect(x: 0, y: 0, width: 360, height: 800))
        #expect(metrics.pixel(CGPoint(x: 10.2, y: 20.5)) == (31, 62))
    }

    @Test
    func unreadableMetricsFail() {
        #expect(throws: ClientError.self) { try AndroidScreen.metrics(from: "Error: no display") }
    }

    @Test(arguments: [
        ("hello", "input text 'hello'"),
        ("a b", "input text 'a%sb'"),
        ("it's", #"input text 'it'\''s'"#),
        ("50%s off", "input text '50%' && input text 's%soff'"),
        ("%s%s", "input text '%' && input text 's%' && input text 's'"),
    ])
    func typingSendsSpacesAsPercentSAndSplitsALiteralOne(text: String, command: String) {
        #expect(AndroidScreen.typingCommand(text) == command)
    }

    @Test
    func dumpWritesToAFileAndPrintsIt() throws {
        let command = AndroidScreen.dumpCommand(options: "--windows")
        let file = try #require(command.firstMatch(of: #/\/data\/local\/tmp\/hammer-[0-9A-F-]+\.xml/#))
            .output

        #expect(command == "uiautomator dump --windows \(file) 1>&2; cat \(file); status=$?; rm -f \(file); "
            + "exit $status")
        #expect(AndroidScreen.dumpCommand(options: "").hasPrefix("uiautomator dump /data/local/tmp/hammer-"))
    }

    @Test(arguments: [
        ("adb -s emulator-5554 shell uiautomator dump failed: ERROR: could not get idle state.", true),
        ("adb -s emulator-5554 shell uiautomator dump failed: ERROR: null root node returned by "
            + "UiTestAutomationBridge.", true),
        ("adb -s emulator-5554 shell uiautomator dump failed: Usage: uiautomator dump [--compressed]", false),
    ])
    func onlyAChangingScreenIsRetried(error: String, isTransient: Bool) {
        #expect(AndroidScreen.isTransientDumpError(error) == isTransient)
    }
}

struct AndroidSystemCommandsTests {
    @Test
    func deviceButtonsAreNamedApartFromKeyboardKeys() {
        let codes = AndroidSystemCommands.keyCodes

        #expect(codes["deviceBack"] == "KEYCODE_BACK")
        #expect(codes["deviceHome"] == "KEYCODE_HOME")
        #expect(codes["appSwitch"] == "KEYCODE_APP_SWITCH")
        #expect(codes["home"] == "KEYCODE_MOVE_HOME")
        #expect(codes["back"] == nil)
        #expect(codes["letterA"] == "KEYCODE_A")
        #expect(codes["number0"] == "KEYCODE_0")
        #expect(codes["functionF12"] == "KEYCODE_F12")
    }

    @Test
    func catalogParameters() {
        let parameters = Dictionary(uniqueKeysWithValues: AndroidSystemCommands.all.map {
            ($0.name, $0.parameters.map(\.name))
        })

        #expect(AndroidSystemCommands.all.map(\.name) == [
            "describe", "tap", "swipe", "edge_swipe", "type_text", "press_key", "screenshot",
        ])
        #expect(parameters["tap"] == ["identifier", "label", "value", "traits", "x", "y"])
        #expect(parameters["screenshot"] == ["identifier", "label", "value", "traits", "scale"])
    }

    @Test
    func tapCountIsRejectedBeforeReachingTheDevice() async throws {
        let driver = AndroidSystemDriver(adb: Adb(environment: ["ANDROID_HOME": "/nonexistent"]), serial: nil)
        let error = await #expect(throws: ClientError.self) {
            _ = try await driver.run("tap", arguments: ["label": "OK", "count": 2])
        }

        guard case .failed(let body, let isInvalidCall) = error else {
            Issue.record("Expected an invalid call, got \(String(describing: error))")
            return
        }

        #expect(body.code == .invalidArguments)
        #expect(isInvalidCall)
    }
}

struct AndroidSystemDriverFallbackTests {
    @Test
    func onlyReadsRunAgainThroughUIAutomator() {
        let reads = AndroidSystemCommands.all.map(\.name).filter(AndroidSystemDriver.isRead)

        #expect(reads == ["describe", "screenshot"])
    }

    @Test
    func interruptedActionSaysItMayHaveRun() {
        let dropped = ClientError.disconnected

        let error = AndroidSystemDriver.interrupted("type_text", error: dropped, helperRunning: false)

        guard case .failed(let body, _) = error else {
            Issue.record("Expected a failure, got \(error)")
            return
        }

        #expect(body.error == "The system helper stopped during type_text (\(dropped.description))")
        #expect(body.code == .disconnected)
        #expect(body.hint?.hasPrefix("The command may have run, so hammer didn't run it again.") == true)
    }
}

struct SwipeArgumentsTests {
    private func swipe(_ json: String) throws -> SwipeArguments {
        return try JSONDecoder().decode(SwipeArguments.self, from: Data(json.utf8))
    }

    @Test
    func swipeIsCenteredOnThePoint() throws {
        let line = try self.swipe(#"{"direction": "up", "distance": 100}"#)
            .line(centeredAt: CGPoint(x: 200, y: 500))

        #expect(line.start == CGPoint(x: 200, y: 550))
        #expect(line.end == CGPoint(x: 200, y: 450))
    }

    @Test(arguments: [
        ("down", CGPoint(x: 224, y: 1), CGPoint(x: 224, y: 201)),
        ("up", CGPoint(x: 224, y: 996), CGPoint(x: 224, y: 796)),
        ("right", CGPoint(x: 1, y: 498.5), CGPoint(x: 201, y: 498.5)),
        ("left", CGPoint(x: 447, y: 498.5), CGPoint(x: 247, y: 498.5)),
    ])
    func edgeSwipeStartsJustInsideTheOppositeEdge(direction: String, start: CGPoint, end: CGPoint) throws {
        let line = try self.swipe(#"{"direction": "\#(direction)"}"#)
            .edgeLine(in: CGRect(x: 0, y: 0, width: 448, height: 997))

        #expect(line.start == start)
        #expect(line.end == end)
    }

    @Test
    func unknownDirectionIsRejected() {
        #expect(throws: DecodingError.self) { try self.swipe(#"{"direction": "diagonal"}"#) }
    }
}
