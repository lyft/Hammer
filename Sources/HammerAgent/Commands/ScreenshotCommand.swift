import Hammer
import HammerAgentCore
import UIKit

struct ScreenshotCommand: AgentCommand {
    struct Arguments: Decodable {
        var scale: CGFloat?
    }

    let descriptor = BuiltinCommands.screenshot

    func run(_ arguments: Arguments, in context: AgentContext) async throws -> AgentImage {
        let scale = arguments.scale ?? 1
        guard scale > 0 && scale <= 4 else {
            throw AgentError.invalidArguments("Invalid scale \(scale), expected a number above 0 and up to 4",
                                              hint: "Use 1 for points or the device's scale, such as 3")
        }

        let window = try await context.eventGenerator().window
        let windows = (window.windowScene?.windows ?? [window])
            .filter { !$0.isHidden }
            .sorted { $0.windowLevel < $1.windowLevel }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let data = UIGraphicsImageRenderer(bounds: window.bounds, format: format).pngData { _ in
            for window in windows {
                window.drawHierarchy(in: window.frame, afterScreenUpdates: false)
            }
        }

        return AgentImage(mimeType: "image/png", data: data)
    }
}
