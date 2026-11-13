import Foundation
@testable import HammerCLI
import HammerAgentCore
import Testing

struct AndroidDeviceTests {
    // swiftlint:disable line_length
    @Test
    func attachedDevicesWithTheirStates() {
        let output = """
            * daemon not running; starting now at tcp:5037
            * daemon started successfully
            List of devices attached
            emulator-5554\tdevice
            R58N12ABCDE\tunauthorized
            emulator-5556\toffline
            0123456789\tno permissions (missing udev rules); see [http://developer.android.com/tools/device.html]

            """
        let devices = AndroidDevice.attachedDevices(in: output)

        #expect(devices.map(\.serial) == ["emulator-5554", "R58N12ABCDE", "emulator-5556", "0123456789"])
        #expect(devices.map(\.state) == [
            "device", "unauthorized", "offline",
            "no permissions (missing udev rules); see [http://developer.android.com/tools/device.html]",
        ])
    }

    @Test
    func listeningAppIDsReadsOnlyListeningHammerSockets() throws {
        // Lines from an API 37 emulator: a listening agent, a connected one, and another app's socket
        let listing = """
            Num       RefCount Protocol Flags    Type St Inode Path
            0000000000000000: 00000002 00000000 00010000 0001 01 1250159 @hammer_com.example.app
            0000000000000000: 00000003 00000000 00000000 0001 03 1250171 @hammer_com.example.app
            0000000000000000: 00000002 00000000 00010000 0001 01 1250160 @hammer_com.example.connected
            0000000000000000: 00000002 00000000 00000000 0001 03 1250161 @hammer_com.example.client
            0000000000000000: 00000002 00000000 00010000 0001 01 18839 @other_tool_com.example.app
            0000000000000000: 00000002 00000000 00010000 0001 01 1234 /dev/socket/zygote
            """

        #expect(AndroidDevice.listeningAppIDs(in: listing) == ["com.example.app", "com.example.connected"])
    }

    @Test(arguments: [
        // API 37
        ("""
          mCurrentFocus=Window{585dc4b u0 com.example.app/com.example.app.MainActivity}
          mFocusedApp=ActivityRecord{138529899 u0 com.example.app/com.example.app.MainActivity t121}
        """, ["com.example.app"]),
        // API 28 nests the activity record in the window token
        ("""
            mFocusedApp=Token{7c1a5b5 ActivityRecord{4c82dec u0 com.android.launcher3/.Launcher t2}}
          mCurrentFocus=Window{fad6ee7 u0 com.android.launcher3/com.android.launcher3.Launcher}
          mFocusedApp=AppWindowToken{ceee44a token=Token{7c1a5b5 ActivityRecord{4c82dec u0 com.android.launcher3/.Launcher t2}}}
        """, ["com.android.launcher3"]),
        ("  mFocusedApp=AppWindowToken{ceee44a token=Token{7c1a5b5 ActivityRecord{4c82dec u0 com.android.launcher3/.Launcher t2}}}\n",
         ["com.android.launcher3"]),
        // The notification shade has focus, so the focused activity decides
        ("""
          mCurrentFocus=Window{c0ffee u0 NotificationShade}
          mFocusedApp=ActivityRecord{1234 u0 com.example.app/com.example.app.MainActivity t121}
        """, ["com.example.app"]),
        // API 37: a permission dialog is another app's activity, in the task of the app that asked
        ("""
          mCurrentFocus=Window{b98b146 u0 com.google.android.permissioncontroller/com.android.permissioncontroller.permission.ui.GrantPermissionsActivity}
          mFocusedApp=ActivityRecord{25666788 u0 com.google.android.permissioncontroller/com.android.permissioncontroller.permission.ui.GrantPermissionsActivity t142}
          * Task{c26d958 #142 type=standard A=10268:com.example.app U=0 visible=true visibleRequested=true mode=fullscreen translucent=false sz=2}
          * Task{3b54fbf #1 type=home U=0 visible=false visibleRequested=false mode=fullscreen translucent=true sz=1}
          * Task{f3d03c7 #126 type=standard A=1000:com.android.settings U=0 visible=false visibleRequested=false mode=fullscreen translucent=true sz=1}
        """, ["com.google.android.permissioncontroller", "com.example.app"]),
        // API 28 lists tasks as TaskRecord, with no uid in the affinity
        ("""
          mCurrentFocus=Window{aa11 u0 com.example.dialog/com.example.dialog.Prompt}
          mFocusedApp=AppWindowToken{bb22 token=Token{cc33 ActivityRecord{dd44 u0 com.example.dialog/.Prompt t17}}}
            * TaskRecord{807bf19 #17 A=com.example.app U=0 StackId=10 sz=2}
        """, ["com.example.dialog", "com.example.app"]),
        ("  mCurrentFocus=null\n  mFocusedApp=null\n", []),
    ])
    func focusedAppIDs(output: String, appIDs: [String]) {
        #expect(AndroidDevice.focusedAppIDs(in: output) == appIDs)
    }

    // swiftlint:enable line_length

    @Test
    func forwardedPortMatchesTheDeviceAndSocket() {
        let list = """
            emulator-5556 tcp:61000 localabstract:hammer_com.example.app
            emulator-5554 tcp:61001 localabstract:other_tool_com.example.app
            emulator-5554 tcp:61002 localabstract:hammer_com.example.app
            """

        #expect(AndroidDevice.forwardedPort(in: list, serial: "emulator-5554",
                                            socket: "localabstract:hammer_com.example.app") == 61002)
        #expect(AndroidDevice.forwardedPort(in: list, serial: "emulator-5554",
                                            socket: "localabstract:hammer_com.example") == nil)
    }

    @Test
    func resolveSerialReportsAnUnauthorizedDevice() async throws {
        let adb = try FakeAdb(devices: "List of devices attached\nR58N12ABCDE\tunauthorized\n").adb()

        let error = await #expect(throws: ClientError.self) {
            try await AndroidDevice.resolveSerial(adb: adb, serial: nil)
        }

        #expect(error?.code == .noDevice)
        #expect(error?.description == "No Android device is ready: R58N12ABCDE is unauthorized")
        #expect(error?.hint == "Accept the USB debugging prompt on the device, then try again")
    }

    @Test
    func resolveSerialReadsTheInjectedEnvironment() async throws {
        let devices = "List of devices attached\nemulator-5554\tdevice\nemulator-5556\tdevice\n"
        let adb = try FakeAdb(devices: devices).adb(environment: [Adb.serialEnvironmentKey: "emulator-5556"])

        #expect(try await AndroidDevice.resolveSerial(adb: adb, serial: nil) == "emulator-5556")
    }

    @Test
    func resolveSerialRejectsSeveralDevices() async throws {
        let devices = "List of devices attached\nemulator-5554\tdevice\nemulator-5556\tdevice\n"
        let adb = try FakeAdb(devices: devices).adb()

        let error = await #expect(throws: ClientError.self) {
            try await AndroidDevice.resolveSerial(adb: adb, serial: nil)
        }

        #expect(error?.description == "2 Android devices are attached")
        #expect(error?.hint == """
            Pass --serial or set ANDROID_SERIAL to the device to drive. Attached: emulator-5554 (device), \
            emulator-5556 (device)
            """)
    }

    @Test
    func adbFailureIsFailedWithItsError() async throws {
        let adb = try FakeAdb(devices: "", failure: "error: closed").adb()

        let error = await #expect(throws: ClientError.self) { try await adb.run(["shell", "true"]) }

        #expect(error?.code == .failed)
        #expect(error?.description == "adb shell true failed: error: closed")
    }

    @Test
    func adbThatHangsTimesOut() async throws {
        let adb = try FakeAdb(devices: "", hang: true).adb()

        let error = await #expect(throws: ClientError.self) {
            try await adb.run(["shell", "true"], timeout: .milliseconds(300))
        }

        #expect(error?.code == .timedOut)
    }

    @Test
    func adbThatTimesOutWithAChildHoldingItsOutputStillEndsTheCall() async throws {
        let adb = try FakeAdb(devices: "", script: "sleep 30 & wait").adb()
        let started = ContinuousClock.now

        let error = await #expect(throws: ClientError.self) {
            try await adb.run(["shell", "true"], timeout: .milliseconds(300))
        }

        #expect(error?.code == .timedOut)
        #expect(ContinuousClock.now - started < .seconds(5))
    }

    @Test
    func adbThatExitsWithAChildHoldingItsOutputReturnsWhatItWrote() async throws {
        // Such as adb starting the adb server, which keeps the pipes it inherited
        let adb = try FakeAdb(devices: "", script: "sleep 30 & echo started; exit 0").adb()
        let started = ContinuousClock.now

        let output = try await adb.run(["shell", "true"], timeout: .seconds(10))

        #expect(output == "started\n")
        #expect(ContinuousClock.now - started < .seconds(5))
    }

    @Test
    func adbIsFoundOnThePathWithoutAnSDK() async throws {
        let fake = try FakeAdb(devices: "", script: "echo from-path; exit 0")
        let adb = Adb(environment: ["PATH": "/nonexistent:\(fake.home.appending(path: "platform-tools").path)"],
                      home: "/nonexistent")

        #expect(try await adb.run(["version"]) == "from-path\n")
    }

    @Test
    func adbIsFoundInTheLinuxSDK() async throws {
        let home = FileManager.default.temporaryDirectory.appending(path: "hammer-home-\(UUID().uuidString)")
        let fake = try FakeAdb(devices: "", script: "echo linux-sdk; exit 0", home: home.appending(path: "Android/Sdk"))
        let adb = Adb(environment: ["PATH": "/nonexistent"], home: home.path)

        #expect(fake.home.path.hasSuffix("Android/Sdk"))
        #expect(try await adb.run(["version"]) == "linux-sdk\n")
    }

    @Test
    func missingAdbSaysHowToInstallIt() async throws {
        let adb = Adb(environment: ["PATH": "/nonexistent"], home: "/nonexistent")

        let error = await #expect(throws: ClientError.self) { try await adb.run(["devices"]) }

        #expect(error?.code == .noDevice)
        #expect(error?.description == "adb was not found")
        #expect(error?.hint == """
            Install the Android SDK platform tools, and set ANDROID_HOME or put adb on the PATH
            """)
    }

    @Test
    func adbReadsLargeErrorOutputWithoutBlocking() async throws {
        let adb = try FakeAdb(devices: "", noisy: true).adb()

        let output = try await adb.run(["shell", "true"], timeout: .seconds(10))

        #expect(output == "done\n")
    }
}

/// A fake `adb` in a temporary SDK, which `Adb` finds through `ANDROID_HOME`.
struct FakeAdb {
    let home: URL

    init(devices: String, failure: String? = nil, hang: Bool = false, noisy: Bool = false, script: String? = nil,
         home: URL? = nil) throws
    {
        self.home = home ?? FileManager.default.temporaryDirectory.appending(path: "hammer-adb-\(UUID().uuidString)")
        let tools = self.home.appending(path: "platform-tools")
        try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
        let script = """
            #!/bin/sh
            if [ "$1" = "devices" ]; then printf '%s' '\(devices)'; exit 0; fi
            \(hang ? "sleep 30" : "")
            \(noisy ? "head -c 200000 /dev/zero | tr '\\\\0' x >&2; echo done; exit 0" : "")
            \(script ?? "")
            \(failure.map { "echo '\($0)' >&2; exit 1" } ?? "exit 0")
            """
        let adb = tools.appending(path: "adb")
        try script.write(to: adb, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: adb.path)
    }

    func adb(environment: [String: String] = [:]) -> Adb {
        let sdk = ["ANDROID_HOME": self.home.path]
        return Adb(environment: environment.merging(sdk) { current, _ in current })
    }
}
