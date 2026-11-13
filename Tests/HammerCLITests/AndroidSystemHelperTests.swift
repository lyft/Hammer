#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation
@testable import HammerCLI
import HammerAgentCore
import Testing

struct SHA256Tests {
    @Test(arguments: [
        ("", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
        ("abc", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),
        ("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
         "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"),
        (String(repeating: "a", count: 1000),
         "41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3"),
    ])
    func hexMatchesTheStandardVectors(input: String, digest: String) {
        #expect(SHA256.hex(Data(input.utf8)) == digest)
    }
}

struct HelperDumpTests {
    private let output = """
        {"windows":[
          {"title":"Example","package":"com.example.app","bounds":[0,0,1344,2992],"root":
            {"class":"android.widget.FrameLayout","bounds":[0,0,1344,2992],"flags":[],"children":[
              {"class":"android.widget.EditText","resource-id":"com.example.app:id/password",
               "hint":"Password","text":"secret","bounds":[0,100,1344,268],
               "flags":["editable","password","focused"]},
              {"class":"android.widget.ScrollView","bounds":[0,300,1344,2000],
               "flags":["scrollable","scroll-forward"]},
              {"class":"android.widget.Button","text":"Send","bounds":[42,2100,462,2268],
               "flags":["clickable","disabled"]},
              {"class":"android.view.View","content-desc":"Web field","bounds":[0,2300,1344,2468],
               "flags":["editable"]}
            ]}},
          {"package":"com.android.systemui","bounds":[0,0,1344,147],"root":
            {"class":"android.widget.FrameLayout","bounds":[0,0,1344,147],"flags":[]}}
        ]}
        """

    private func windows() throws -> [AndroidElement] {
        return try HelperDump.windows(from: Data(self.output.utf8), scale: 2.1)
    }

    @Test
    func windowsAreLabeledByTitleOrPackageInDp() throws {
        let windows = try self.windows()

        #expect(windows.map(\.label) == ["Example", "com.android.systemui"])
        #expect(windows.map(\.frame.height) == [2992 / 2.1, 147 / 2.1])
    }

    @Test
    func flagsBecomeTheSameElementsAsUIAutomatorAttributes() throws {
        let nodes = try #require(try self.windows().first?.children.first?.children)

        #expect(nodes.count == 4)
        #expect(nodes[0].identifier == "password")
        #expect(nodes[0].label == "Password")
        #expect(nodes[0].value == "secret")
        #expect(nodes[0].isFocusedTextField)
        #expect(nodes[0].isSecure)
        #expect(nodes[1].scrollDirections == ["forward"])
        #expect(nodes[2].traits == ["button", "notEnabled"])
        #expect(nodes[2].frame == CGRect(x: 20, y: 1000, width: 200, height: 80))
        #expect(nodes[3].label == "Web field")
        #expect(nodes[3].value == nil)
    }

    @Test
    func describeShowsSecureFieldsAndScrollOnlyNodes() throws {
        let encoded = String(bytes: try DescribedElement.encode(try self.windows()), encoding: .utf8) ?? ""

        #expect(encoded.contains(#""secure":true"#))
        #expect(encoded.contains(#""scroll":["forward"]"#))
    }

    @Test
    func otherOutputIsUnreadable() {
        #expect(throws: ClientError.self) {
            try HelperDump.windows(from: Data(#"{"error":"nope"}"#.utf8), scale: 1)
        }
    }
}

/// A fake device for the helper's lifecycle: it logs adb's arguments, has the helper installed with the
/// digest `installed`, and lists the helper's socket once `am instrument` ran.
private struct FakeHelperDevice {
    let fake: FakeAdb
    let log: URL

    init(installed: String?, startFails: Bool = false) throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "hammer-helper-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let log = directory.appending(path: "adb.log")
        let started = directory.appending(path: "started").path
        // Port 1 refuses connections, like a forward to a socket nothing listens on
        let path = installed == nil ? "exit 0" : "echo package:/data/app/helper/base.apk; exit 0"
        let start = startFails ? "" : "touch '\(started)';"
        let script = """
            echo "$*" >> '\(log.path)'
            case "$*" in
              *"forward --list"*) exit 0 ;;
              *"forward tcp:0"*) echo 1; exit 0 ;;
              *"pm path"*) \(path) ;;
              *sha256sum*) echo "\(installed ?? "")  /data/app/helper/base.apk"; exit 0 ;;
              *"/proc/net/unix"*)
                if [ -f '\(started)' ]; then
                  echo "0000000000000000: 00000002 00000000 00010000 0001 01 1 @hammer_system"
                fi
                case "$*" in *"kill -0 4242"*) [ -f '\(started)' ] || echo exited ;; esac
                exit 0 ;;
              *logcat*)
                echo "11-12 22:22:18.764 26848 26860 E HammerSystem: UiAutomation is held by another tool"
                exit 0 ;;
              *"am instrument"*) echo "11-12 22:22:18.000"; \(start) echo 4242; exit 0 ;;
            esac
            """
        self.fake = try FakeAdb(devices: "List of devices attached\nemulator-5554\tdevice\n", script: script)
        self.log = log
    }

    func commands() throws -> [String] {
        let log = (try? String(contentsOf: self.log, encoding: .utf8)) ?? ""
        return log.split(separator: "\n").map { String($0.dropFirst("-s emulator-5554 ".count)) }
    }

    func helper(apk: Data?) throws -> AndroidSystemHelper {
        var environment: [String: String] = [:]
        if let apk {
            let file = FileManager.default.temporaryDirectory
                .appending(path: "helper-\(UUID().uuidString).apk")
            try apk.write(to: file)
            environment[AndroidSystemHelper.apkEnvironmentKey] = file.path
        }

        return AndroidSystemHelper(adb: self.fake.adb(environment: environment), serial: "emulator-5554")
    }
}

struct AndroidSystemHelperTests {
    private let apk = Data("helper".utf8)

    @Test
    func toolWithoutTheHelperIsUnavailable() async throws {
        let device = try FakeHelperDevice(installed: nil)

        let error = await #expect(throws: AndroidSystemHelper.Unavailable.self) {
            try await device.helper(apk: nil).client()
        }

        #expect(error?.description.hasPrefix("this hammer was built without the system helper") == true)
        #expect(try device.commands().contains { $0.hasPrefix("install") } == false)
    }

    @Test
    func sameHelperIsStartedWithoutInstalling() async throws {
        let device = try FakeHelperDevice(installed: SHA256.hex(self.apk))

        _ = try await device.helper(apk: self.apk).client()

        let commands = try device.commands()
        #expect(commands.filter { $0.hasPrefix("install") || $0.hasPrefix("uninstall") } == [])
        #expect(commands.filter { $0.contains("am instrument") } == [
            "shell date '+%m-%d %H:%M:%S.000'; setsid nohup am instrument -w "
                + "com.lyft.hammer.system/.SystemServer >/dev/null 2>&1 </dev/null & echo $!",
        ])
    }

    @Test
    func otherHelperIsReplaced() async throws {
        let device = try FakeHelperDevice(installed: SHA256.hex(Data("older".utf8)))

        _ = try await device.helper(apk: self.apk).client()

        let commands = try device.commands()
        let changes = commands.filter { $0.hasPrefix("install") || $0.hasPrefix("uninstall") }
        #expect(changes.count == 2)
        #expect(changes.first == "uninstall com.lyft.hammer.system")
        #expect(changes.last?.hasPrefix("install -r -t ") == true)
    }

    @Test
    func missingHelperIsInstalled() async throws {
        let device = try FakeHelperDevice(installed: nil)

        _ = try await device.helper(apk: self.apk).client()

        let changes = try device.commands().filter { $0.hasPrefix("install") || $0.hasPrefix("uninstall") }
        #expect(changes.count == 1)
        #expect(changes.first?.hasPrefix("install -r -t ") == true)
    }

    @Test
    func helperThatExitsFailsTheStartAtOnceWithItsReason() async throws {
        let device = try FakeHelperDevice(installed: SHA256.hex(self.apk), startFails: true)
        let start = ContinuousClock.now

        let error = await #expect(throws: AndroidSystemHelper.Unavailable.self) {
            try await device.helper(apk: self.apk).client()
        }

        #expect(error?.description == "UiAutomation is held by another tool")
        #expect(try device.commands().last == "logcat -d -T 11-12 22:22:18.000 -s HammerSystem:E")
        #expect(ContinuousClock.now - start < .seconds(5))
    }

    @Test
    func disabledHelperIsSkipped() {
        #expect(AndroidSystemHelper.isEnabled(environment: [:]))
        #expect(!AndroidSystemHelper.isEnabled(environment: [AndroidSystemHelper.enabledEnvironmentKey: "0"]))
    }
}
