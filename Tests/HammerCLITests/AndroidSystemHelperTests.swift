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

    // RFC 4231 test cases 2 and 6, the second with a key longer than a block
    @Test(arguments: [
        (Data("Jefe".utf8), Data("what do ya want for nothing?".utf8),
         "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"),
        (Data(repeating: 0xaa, count: 131),
         Data("Test Using Larger Than Block-Size Key - Hash Key First".utf8),
         "60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54"),
    ])
    func hmacMatchesTheStandardVectors(key: Data, message: Data, mac: String) {
        #expect(SHA256.hmacHex(key: key, message: message) == mac)
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
/// digest `installed`, writes the secret `am instrument` gets where the helper keeps it, and lists the
/// helper's socket once that ran. Its helper is a `FakeHelperServer` proving that secret, or nothing when
/// `squatter`.
private final class FakeHelperDevice: @unchecked Sendable {
    let fake: FakeAdb
    let log: URL
    let directory: URL
    let server: FakeHelperServer

    init(installed: String?, version: String = "", startFails: Bool = false, startHangs: Bool = false,
         running: Bool = false, squatter: Bool = false) throws
    {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "hammer-helper-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let log = directory.appending(path: "adb.log")
        let started = directory.appending(path: "started")
        let secret = directory.appending(path: "secret")
        if running || squatter {
            try Data().write(to: started)
            try Data("1234".utf8).write(to: secret)
        }

        self.server = try FakeHelperServer(version: version, proofKey: {
            squatter ? nil : try? Data(contentsOf: secret)
        }, onRequest: { path in
            if path.hasSuffix("/stop") {
                try? FileManager.default.removeItem(at: started)
            }
        })
        let path = installed == nil ? "exit 0" : "echo package:/data/app/helper/base.apk; exit 0"
        let start = startFails || startHangs ? "" : """
            touch '\(started.path)'
            echo "$*" | sed -n 's/.*-e secret \\([0-9a-f]*\\).*/\\1/p' | tr -d '\\n' > '\(secret.path)'
            """
        let forceStop = squatter ? ":" : "rm -f '\(started.path)'"
        let script = """
            echo "$*" >> '\(log.path)'
            case "$*" in
              *"forward --list"*) exit 0 ;;
              *"forward tcp:0"*) echo \(self.server.port); exit 0 ;;
              *"pm path"*) \(path) ;;
              *sha256sum*) echo "\(installed ?? "")  /data/app/helper/base.apk"; exit 0 ;;
              *"am instrument"*)
                printf 'WARNING: linker: unused DT entry: type 0x1d\\n11-12 22:22:18.000\\n'
                \(start)
                echo pid:4242; exit 0 ;;
              *"cat \(AndroidSystemHelper.secretPath)"*) cat '\(secret.path)' 2>/dev/null; exit 0 ;;
              *"force-stop"*) \(forceStop); exit 0 ;;
              *"/proc/net/unix"*)
                if [ -f '\(started.path)' ]; then
                  echo "0000000000000000: 00000002 00000000 00010000 0001 01 1 @hammer_system"
                fi
                case "$*" in *"kill -0 4242"*) \(startFails ? "echo exited" : ":") ;; esac
                exit 0 ;;
              *logcat*)
                echo "11-12 22:22:18.764 26848 26860 E HammerSystem: UiAutomation is held by another tool"
                exit 0 ;;
            esac
            """
        self.fake = try FakeAdb(devices: "List of devices attached\nemulator-5554\tdevice\n", script: script)
        self.log = log
        self.directory = directory
    }

    func commands() throws -> [String] {
        let log = (try? String(contentsOf: self.log, encoding: .utf8)) ?? ""
        return log.split(separator: "\n").map { String($0.dropFirst("-s emulator-5554 ".count)) }
    }

    func starts() throws -> [String] {
        return try self.commands().filter { $0.contains("am instrument") }
    }

    func helper(apk: Data?, startWait: Duration = .seconds(10)) throws -> AndroidSystemHelper {
        var environment: [String: String] = [:]
        if let apk {
            let file = self.directory.appending(path: "helper.apk")
            try apk.write(to: file)
            environment[AndroidSystemHelper.apkEnvironmentKey] = file.path
        }

        let adb = self.fake.adb(environment: environment)
        var helper = AndroidSystemHelper(adb: adb, serial: "emulator-5554")
        helper.stateDirectory = self.directory
        helper.startWait = startWait
        return helper
    }
}

struct AndroidSystemHelperTests {
    private let apk = Data("helper".utf8)

    private var digest: String {
        return SHA256.hex(self.apk)
    }

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
    func sameHelperIsStartedWithANewSecretWithoutInstalling() async throws {
        let device = try FakeHelperDevice(installed: self.digest, version: self.digest)

        _ = try await device.helper(apk: self.apk).client()

        let commands = try device.commands()
        #expect(commands.filter { $0.hasPrefix("install") || $0.hasPrefix("uninstall") } == [])
        let starts = try device.starts()
        #expect(starts.count == 1)
        let secret = try String(contentsOf: device.directory.appending(path: "secret"), encoding: .utf8)
        #expect(secret.count == 64)
        #expect(starts.first == "shell umask 077; printf %s \(secret) > \(AndroidSystemHelper.secretPath); "
            + "date '+%m-%d %H:%M:%S.000'; setsid nohup am instrument -w -e secret \(secret) "
            + "com.lyft.hammer.system/.SystemServer >/dev/null 2>&1 </dev/null & echo pid:$!")
    }

    @Test
    func otherHelperIsReplaced() async throws {
        let device = try FakeHelperDevice(installed: SHA256.hex(Data("older".utf8)), version: self.digest)

        _ = try await device.helper(apk: self.apk).client()

        let commands = try device.commands()
        let changes = commands.filter { $0.hasPrefix("install") || $0.hasPrefix("uninstall") }
        #expect(changes.count == 2)
        #expect(changes.first == "uninstall com.lyft.hammer.system")
        #expect(changes.last?.hasPrefix("install -r -t ") == true)
    }

    @Test
    func missingHelperIsInstalled() async throws {
        let device = try FakeHelperDevice(installed: nil, version: self.digest)

        _ = try await device.helper(apk: self.apk).client()

        let changes = try device.commands().filter { $0.hasPrefix("install") || $0.hasPrefix("uninstall") }
        #expect(changes.count == 1)
        #expect(changes.first?.hasPrefix("install -r -t ") == true)
    }

    @Test
    func runningHelperThatProvesItsSecretIsUsedWithoutStarting() async throws {
        let device = try FakeHelperDevice(installed: self.digest, version: self.digest, running: true)

        _ = try await device.helper(apk: self.apk).client()

        #expect(try device.starts() == [])
        #expect(device.server.paths == ["/commands/version"])
    }

    @Test
    func processOnTheSocketThatProvesNothingIsRefusedWithoutBeingSentCommands() async throws {
        let device = try FakeHelperDevice(installed: self.digest, version: self.digest, squatter: true)

        let error = await #expect(throws: AndroidSystemHelper.Unavailable.self) {
            try await device.helper(apk: self.apk).client()
        }

        #expect(error?.description.hasPrefix("another process listens on @hammer_system") == true)
        #expect(try device.starts() == [])
        #expect(Set(device.server.paths) == ["/commands/version"])
    }

    @Test
    func runningClientIsNilWhenTheHelperIsntRunning() async throws {
        let device = try FakeHelperDevice(installed: self.digest, version: self.digest)

        let client = try await device.helper(apk: self.apk).runningClient()

        #expect(client == nil)
        #expect(try device.starts() == [])
    }

    @Test
    func runningClientRefusesAProcessThatProvesNothing() async throws {
        let device = try FakeHelperDevice(installed: self.digest, version: self.digest, squatter: true)

        await #expect(throws: AndroidSystemHelper.Unavailable.self) {
            try await device.helper(apk: self.apk).runningClient()
        }
        #expect(Set(device.server.paths) == ["/commands/version"])
    }

    @Test
    func helperThatExitsFailsTheStartAtOnceWithItsReason() async throws {
        let device = try FakeHelperDevice(installed: self.digest, startFails: true)
        let start = ContinuousClock.now

        let error = await #expect(throws: AndroidSystemHelper.Unavailable.self) {
            try await device.helper(apk: self.apk).client()
        }

        #expect(error?.description == "UiAutomation is held by another tool")
        #expect(try device.commands().last == "logcat -d -T 11-12 22:22:18.000 -s HammerSystem:E")
        #expect(ContinuousClock.now - start < .seconds(5))
    }

    @Test
    func failedStartIsntTriedAgainForAWhileUnlessAsked() async throws {
        let device = try FakeHelperDevice(installed: self.digest, startFails: true)
        let helper = try device.helper(apk: self.apk)
        _ = try? await helper.client()

        let error = await #expect(throws: AndroidSystemHelper.Unavailable.self) {
            try await helper.client()
        }
        #expect(error?.description.hasPrefix("UiAutomation is held by another tool (from a start ") == true)
        #expect(try device.starts().count == 1)

        _ = try? await helper.client(retryingRecentFailure: true)
        #expect(try device.starts().count == 2)
    }

    @Test
    func startThatTimesOutIsKilled() async throws {
        let device = try FakeHelperDevice(installed: self.digest, startHangs: true)

        await #expect(throws: AndroidSystemHelper.Unavailable.self) {
            try await device.helper(apk: self.apk, startWait: .milliseconds(300)).client()
        }

        #expect(try device.commands().contains("shell kill 4242; am force-stop com.lyft.hammer.system"))
    }

    @Test
    func parallelClientsStartTheHelperOnce() async throws {
        let device = try FakeHelperDevice(installed: self.digest, version: self.digest)
        let first = try device.helper(apk: self.apk)
        let second = try device.helper(apk: self.apk)

        async let one = first.client()
        async let two = second.client()
        _ = try await (one, two)

        #expect(try device.starts().count == 1)
    }

    @Test
    func startOutputIgnoresOtherLines() {
        let output = "WARNING: linker: unused DT entry\n11-12 22:22:18.000\nsome other line\npid:4242\n"

        let parsed = AndroidSystemHelper.startOutput(output)

        #expect(parsed?.time == "11-12 22:22:18.000")
        #expect(parsed?.pid == 4242)
        #expect(AndroidSystemHelper.startOutput("11-12 22:22:18.000\n") == nil)
    }

    @Test
    func onlyAutoLetsAppCommandsStartTheHelper() {
        let key = AndroidSystemHelper.enabledEnvironmentKey
        #expect(AndroidSystemHelper.isEnabled(environment: [:]))
        #expect(!AndroidSystemHelper.isEnabled(environment: [key: "0"]))
        #expect(!AndroidSystemHelper.startsForAppCommands(environment: [:]))
        #expect(AndroidSystemHelper.startsForAppCommands(environment: [key: "auto"]))
    }
}
