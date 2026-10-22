import Hammer
import HammerAgentCore
import UIKit

struct ScreenshotCommand: AgentCommand {
    struct Arguments: Decodable {
        private enum CodingKeys: String, CodingKey {
            case scale
        }

        let target: Target
        let scale: CGFloat

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.target = try Target(from: decoder)
            self.scale = try container.decodeIfPresent(CGFloat.self, forKey: .scale) ?? 1
        }
    }

    let descriptor = BuiltinCommands.screenshot

    func run(_ arguments: Arguments, in context: AgentContext) async throws -> AgentImage {
        let scale = arguments.scale
        guard scale > 0 && scale <= 4 else {
            throw AgentError.invalidArguments("Invalid scale \(scale), expected a number above 0 and up to 4",
                                              hint: "Use 1 for points or the device's scale, such as 3")
        }

        let window = try await context.eventGenerator().window
        let bounds = arguments.target.isEmpty
            ? window.bounds
            : try await arguments.target.view(in: context).frameInWindow.intersection(window.bounds)
        guard !bounds.isEmpty else {
            throw AgentError.invalidArguments("The view is empty or outside the window",
                                              hint: "Call inspect to see its frame, or capture the screen")
        }

        let windows = (window.windowScene?.windows ?? [window])
            .filter { !$0.isHidden }
            .sorted { $0.windowLevel < $1.windowLevel }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let data = UIGraphicsImageRenderer(bounds: bounds, format: format).pngData { _ in
            for window in windows {
                window.drawHierarchy(in: window.frame, afterScreenUpdates: false)
            }
        }

        return AgentImage(mimeType: "image/png", data: data)
    }
}
