import Foundation
@testable import HammerCLI
import HammerAgentCore
import Testing
#if canImport(Glibc)
import Glibc
#endif

// swiftlint:disable line_length
/// `dumpsys activity processes` on Android 17 for an app frozen in the background, cut to the lines that
/// matter.
private let frozenProcesses = """
    ACTIVITY MANAGER RUNNING PROCESSES (dumpsys activity processes)
      All known processes:
      *APP* UID 10268 ProcessRecord{9029806 6392:com.example.app/u0a268}
        user #0 uid=10268 gids={3002, 3003, 3001, 50268, 20268, 9997}
        hasPendingCompaction=false    isPendingFreeze=false isFrozen=true
        earliestFreezableTimeMs=-58s175ms
      *APP* UID 99021 ProcessRecord{2b1007b 6479:com.google.android.webview:sandboxed_process0:org.chromium.content.app.SandboxedProcessService0:0/u0a268i21}
        user #0 uid=10268 ISOLATED uid=99021 gids={}
        hasPendingCompaction=false    isPendingFreeze=false isFrozen=true
        earliestFreezableTimeMs=-58s175ms
      mHomeProcess: ProcessRecord{c27a6af 19603:com.google.android.apps.nexuslauncher/u0a192}
      PID mappings:
        PID #6392: ProcessRecord{9029806 6392:com.example.app/u0a268}
    """
// swiftlint:enable line_length

private let device = AndroidDevice(adb: Adb(environment: [:]), serial: "emulator-5554",
                                   appID: "com.example.app")

private actor Counter {
    private(set) var count = 0

    func increment() {
        self.count += 1
    }
}

struct AndroidAgentClientTests {
    @Test
    func frozenMainProcessIsFrozen() {
        #expect(AndroidDevice.isFrozen(in: frozenProcesses, appID: "com.example.app"))
    }

    @Test
    func runningMainProcessIsNotFrozen() {
        let mainProcess = "isFrozen=true\n    earliestFreezableTimeMs=-58s175ms\n  *APP* UID 99021"
        let running = frozenProcesses.replacingOccurrences(
            of: mainProcess, with: mainProcess.replacingOccurrences(of: "=true", with: "=false"))

        #expect(running != frozenProcesses)
        #expect(!AndroidDevice.isFrozen(in: running, appID: "com.example.app"))
    }

    @Test
    func otherProcessesOfTheAppDontCount() {
        let remote = frozenProcesses.replacingOccurrences(of: "6392:com.example.app/",
                                                          with: "6392:com.example.app:remote/")

        #expect(!AndroidDevice.isFrozen(in: remote, appID: "com.example.app"))
        #expect(!AndroidDevice.isFrozen(in: frozenProcesses, appID: "com.example"))
    }

    @Test
    func versionsWithoutAFreezerAreNotFrozen() {
        let api28 = """
            ACTIVITY MANAGER RUNNING PROCESSES (dumpsys activity processes)
              All known processes:
              *APP* UID 10088 ProcessRecord{deefb9f 7053:com.example.app/u0a88}
                user #0 uid=10088 gids={50088, 20088, 9997}
            """

        #expect(!AndroidDevice.isFrozen(in: api28, appID: "com.example.app"))
    }

    @Test
    func frozenErrorNamesTheAppAndDevice() {
        let error = device.frozenError

        #expect(error.code == .appFrozen)
        #expect(error.description == "Android froze com.example.app on emulator-5554 in the background, "
            + "so its Hammer agent can't respond")
    }

    @Test
    func fastCallDoesntCheck() async throws {
        let checks = Counter()
        let result = try await AndroidAgentClient.failingWhenFrozen(
            delay: .seconds(10), isFrozen: { await checks.increment(); return true },
            call: { "done" })

        #expect(result == "done")
        #expect(await checks.count == 0)
    }

    @Test
    func slowCallToAFrozenAppFailsEarly() async throws {
        let checks = Counter()
        let calls = Counter()
        let start = ContinuousClock.now
        await #expect(throws: AndroidAgentClient.AppFrozen.self) {
            try await AndroidAgentClient.failingWhenFrozen(
                delay: .milliseconds(50), isFrozen: { await checks.increment(); return true },
                call: {
                    try await Task.sleep(for: .seconds(30))
                    await calls.increment()
                    return "done"
                })
        }

        #expect(ContinuousClock.now - start < .seconds(5))
        #expect(await checks.count == 1)
        #expect(await calls.count == 0)
    }

    /// A frozen app's forwarded port takes the connection and never answers, so the client has to stop
    /// waiting when the call is cancelled rather than at its timeout.
    @Test
    func callToAFrozenAppThatNeverAnswersFailsEarly() async throws {
        let (descriptor, port) = try Self.silentListener()
        defer { close(descriptor) }

        let start = ContinuousClock.now
        await #expect(throws: AndroidAgentClient.AppFrozen.self) {
            try await AndroidAgentClient.failingWhenFrozen(
                delay: .milliseconds(200), isFrozen: { true },
                call: { try await AgentClient(port: port, token: nil).run("describe", arguments: [:]) })
        }

        #expect(ContinuousClock.now - start < .seconds(10))
    }

    @Test
    func slowCallToARunningAppKeepsCheckingUntilItReturns() async throws {
        let checks = Counter()
        let result = try await AndroidAgentClient.failingWhenFrozen(
            delay: .milliseconds(50), isFrozen: { await checks.increment(); return false },
            call: {
                while await checks.count < 3 {
                    try await Task.sleep(for: .milliseconds(1))
                }
                return "done"
            })

        #expect(result == "done")
        #expect(await checks.count == 3)
    }

    @Test
    func appFrozenDuringALongCallFailsAtTheNextCheck() async throws {
        let checks = Counter()
        await #expect(throws: AndroidAgentClient.AppFrozen.self) {
            try await AndroidAgentClient.failingWhenFrozen(
                delay: .milliseconds(20),
                isFrozen: {
                    await checks.increment()
                    return await checks.count == 4
                },
                call: {
                    try await Task.sleep(for: .seconds(30))
                    return "done"
                })
        }

        #expect(await checks.count == 4)
    }
}

extension AndroidAgentClientTests {
    /// A socket on 127.0.0.1 that accepts connections into its backlog and never reads or answers them.
    fileprivate static func silentListener() throws -> (descriptor: Int32, port: UInt16) {
        #if canImport(Glibc)
        let descriptor = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
        #else
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        #endif
        var address = sockaddr_in()
        #if canImport(Darwin)
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        #endif
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        var size = socklen_t(MemoryLayout<sockaddr_in>.size)
        let bound = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
                bind(descriptor, address, size) == 0 && listen(descriptor, 8) == 0
                    && getsockname(descriptor, address, &size) == 0
            }
        }
        guard bound else {
            close(descriptor)
            throw POSIXError(.EADDRINUSE)
        }

        return (descriptor, UInt16(bigEndian: address.sin_port))
    }
}
