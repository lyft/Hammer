#if os(macOS)
import CoreGraphics
import Foundation
import HammerAgentCore

/// Runs commands on the simulator's whole screen from the Mac, like a person using Simulator.app, so they
/// reach system UI the app's agent can't, such as permission alerts.
struct SimulatorDriver: Driver {
    /// The simulator to drive, or nil for `HAMMER_SIMULATOR_UDID` or the only booted one.
    let udid: String?

    func catalog() async -> DriverCatalog {
        return DriverCatalog(commands: SimulatorCommands.all, note: nil)
    }

    func callableCommands() async throws -> [CommandDescriptor] {
        return SimulatorCommands.all
    }

    func run(_ name: String, arguments: [String: JSONValue]) async throws -> Data {
        guard let descriptor = SimulatorCommands.all.first(where: { $0.name == name }) else {
            let names = SimulatorCommands.all.map(\.name).joined(separator: ", ")
            throw ClientError.failed(.init(error: "\(name) does not run on the simulator's screen",
                                           code: .unknownCommand,
                                           hint: "Only \(names) do. Run \(name) in the app instead"),
                                     isInvalidCall: true)
        }

        do {
            try descriptor.validate(arguments)
        } catch let error as ArgumentsError {
            throw ClientError.invalidArguments(error.description, hint: error.hint)
        }

        let device = try CoreSimulator.device(udid: self.udid)
        switch descriptor.name {
        case SimulatorCommands.tap.name:
            let arguments = try JSONValue.object(arguments).decode(as: TapArguments.self)
            try await self.tap(arguments, on: device)
            return Data("{}".utf8)
        default:
            let root = try await SimulatorAccessibility.snapshot(of: device)
            return try DescribedElement.encode([root])
        }
    }

    private func tap(_ arguments: TapArguments, on device: SimDevice) async throws {
        guard arguments.count ?? 1 > 0 else {
            throw ClientError.invalidArguments("Invalid count \(arguments.count ?? 0), expected 1 or more",
                                               hint: "Use 1 for a tap and 2 for a double tap")
        }

        let point: CGPoint
        if let query = try arguments.target.query(traitNames: SimulatorCommands.traitNames) {
            let root = try await SimulatorAccessibility.snapshot(of: device)
            let element = try query.element(in: root)
            point = CGPoint(x: element.frame.midX, y: element.frame.midY)
        } else {
            point = try arguments.target.point() ?? CGPoint(x: device.screenSize.width / 2,
                                                     y: device.screenSize.height / 2)
        }

        try await SimulatorHID(device: device).tap(at: point, count: arguments.count ?? 1)
    }
}

private struct TapArguments: Decodable {
    private enum CodingKeys: String, CodingKey {
        case count
    }

    let target: ScreenTarget
    let count: Int?

    init(from decoder: Decoder) throws {
        self.target = try ScreenTarget(from: decoder)
        self.count = try decoder.container(keyedBy: CodingKeys.self).decodeIfPresent(Int.self, forKey: .count)
    }
}

extension SystemElement: ScreenElement {
    private static let traitsByRole = [
        "AXButton": "button", "AXLink": "link", "AXHeading": "header", "AXImage": "image",
        "AXStaticText": "staticText", "AXSearchField": "searchField",
    ]

    /// The role without the `AX` prefix of macOS accessibility roles, such as `Button`.
    var type: String {
        return self.role.hasPrefix("AX") ? String(self.role.dropFirst(2)) : self.role
    }

    /// The agent's trait names for the element's role, so queries read the same in both drivers.
    var traits: [String] {
        return Self.traitsByRole[self.role].map { [$0] } ?? []
    }
}
#else
import Foundation
import HammerAgentCore

/// The simulator needs macOS, so elsewhere its commands are described but fail when called.
struct SimulatorDriver: Driver {
    let udid: String?

    func catalog() async -> DriverCatalog {
        return DriverCatalog(commands: SimulatorCommands.all, note: nil)
    }

    func callableCommands() async throws -> [CommandDescriptor] {
        return SimulatorCommands.all
    }

    func run(_ name: String, arguments: [String: JSONValue]) async throws -> Data {
        throw ClientError.failed(.init(error: "The simulator's screen can only be driven on macOS",
                                       code: .failed,
                                       hint: "Add --android to drive an Android device"),
                                 isInvalidCall: true)
    }
}
#endif
