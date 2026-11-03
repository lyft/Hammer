import CoreGraphics
import Foundation
import HammerAgentCore

// CoreSimulator and SimulatorKit are private frameworks, loaded at runtime from the selected Xcode.

@objc protocol SimServiceContextClass {
    @objc(sharedServiceContextForDeveloperDir:error:)
    func sharedServiceContext(forDeveloperDir developerDir: String) throws -> SimServiceContext
}

@objc protocol SimServiceContext {
    @objc(defaultDeviceSetWithError:)
    func defaultDeviceSet() throws -> SimDeviceSet
}

@objc protocol SimDeviceSet {
    var devices: [AnyObject] { get }
}

@objc protocol SimDevice {
    @objc(UDID) var udid: NSUUID { get }
    var name: String { get }
    var state: UInt { get }
    var deviceType: SimDeviceType { get }

    @objc(sendAccessibilityRequestAsync:completionQueue:completionHandler:)
    func sendAccessibilityRequest(_ request: AnyObject, completionQueue: DispatchQueue,
                                  completionHandler: @escaping (AnyObject?) -> Void)
}

@objc protocol SimDeviceType {
    /// The screen's size in pixels.
    var mainScreenSize: CGSize { get }
    var mainScreenScale: Float { get }
}

extension SimDevice {
    var isBooted: Bool {
        // SimDeviceStateBooted
        return self.state == 3
    }

    /// The screen's size in points, the coordinates of accessibility frames.
    var screenSize: CGSize {
        let scale = CGFloat(self.deviceType.mainScreenScale)
        let pixels = self.deviceType.mainScreenSize
        return CGSize(width: pixels.width / scale, height: pixels.height / scale)
    }
}

/// Loads the frameworks and finds simulators.
enum CoreSimulator {
    /// The environment variable that picks the simulator, by UDID.
    static let udidEnvironmentKey = "HAMMER_SIMULATOR_UDID"

    /// The developer directory of the selected Xcode, such as `/Applications/Xcode.app/Contents/Developer`.
    static func developerDirectory() throws -> URL {
        if let path = ProcessInfo.processInfo.environment["DEVELOPER_DIR"], !path.isEmpty {
            return URL(filePath: path)
        }

        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/xcode-select")
        process.arguments = ["--print-path"]
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(bytes: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        let path = output?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard process.terminationStatus == 0, !path.isEmpty else {
            throw ClientError.noSimulator("No Xcode is selected",
                                          hint: "Select one with `xcode-select --switch`")
        }

        return URL(filePath: path)
    }

    /// Finds the simulator to drive: the one with the UDID, or the only booted one.
    ///
    /// - parameter udid: The UDID, or nil to use `HAMMER_SIMULATOR_UDID` or the only booted simulator.
    ///
    /// - throws: A `ClientError` if no simulator matches, or several are booted and none was picked.
    ///
    /// - returns: The device.
    static func device(udid: String?) throws -> SimDevice {
        let developerDirectory = try self.developerDirectory()
        try self.load("/Library/Developer/PrivateFrameworks/CoreSimulator.framework/CoreSimulator")
        try self.load(developerDirectory
            .appending(path: "../SharedFrameworks/SimulatorKit.framework/SimulatorKit").standardized.path)

        let contextClass = unsafeBitCast(try self.objcClass("SimServiceContext"),
                                         to: SimServiceContextClass.self)
        let devices = try contextClass.sharedServiceContext(forDeveloperDir: developerDirectory.path)
            .defaultDeviceSet().devices.map { unsafeBitCast($0, to: SimDevice.self) }
        let booted = devices.filter(\.isBooted)

        let udid = udid ?? ProcessInfo.processInfo.environment[self.udidEnvironmentKey].flatMap {
            $0.isEmpty ? nil : $0
        }
        if let udid {
            let isRequested = { (device: SimDevice) in
                device.udid.uuidString.caseInsensitiveCompare(udid) == .orderedSame
            }
            guard let device = booted.first(where: isRequested) else {
                throw ClientError.noSimulator("No booted simulator has the UDID \(udid)",
                                                 hint: self.bootedHint(booted))
            }

            return device
        }

        guard booted.count == 1, let device = booted.first else {
            let description = booted.isEmpty
                ? "No simulator is booted" : "\(booted.count) simulators are booted"
            throw ClientError.noSimulator(description, hint: self.bootedHint(booted))
        }

        return device
    }

    /// Loads a framework.
    ///
    /// - parameter path: The path of the framework's binary.
    ///
    /// - throws: A `ClientError` if it could not be loaded.
    static func load(_ path: String) throws {
        guard dlopen(path, RTLD_NOW) != nil else {
            let reason = dlerror().map { String(cString: $0) } ?? path
            throw ClientError.noSimulator("Unable to load \(path): \(reason)",
                                             hint: "Install Xcode and its iOS simulator runtime")
        }
    }

    /// A class from a loaded framework, to cast to the protocol that declares its class methods.
    ///
    /// - parameter name: The class name.
    ///
    /// - throws: A `ClientError` if the class is missing.
    ///
    /// - returns: The class object.
    static func objcClass(_ name: String) throws -> AnyObject {
        guard let objcClass = NSClassFromString(name) else {
            throw ClientError.noSimulator("This Xcode has no \(name)",
                                          hint: "Use an Xcode version that Hammer supports")
        }

        return objcClass as AnyObject
    }

    private static func bootedHint(_ booted: [SimDevice]) -> String {
        let list = booted.map { "\($0.name) (\($0.udid.uuidString))" }.joined(separator: ", ")
        let pick = "Pass --udid or set \(self.udidEnvironmentKey) to the simulator to drive"
        return booted.isEmpty ? "Boot a simulator first" : "\(pick). The booted ones are \(list)"
    }
}

extension ClientError {
    /// The simulator, or the frameworks to drive it, are unavailable.
    static func noSimulator(_ description: String, hint: String) -> ClientError {
        return .failed(AgentErrorBody(error: description, code: .noSimulator, hint: hint))
    }
}
