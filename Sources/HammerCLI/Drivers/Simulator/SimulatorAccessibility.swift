import CoreGraphics
import Foundation

@objc private protocol AXPTranslatorClass {
    func sharedInstance() -> AXPTranslator
}

@objc private protocol AXPTranslator {
    var bridgeTokenDelegate: AnyObject? { get set }

    @objc(frontmostApplicationWithDisplayId:bridgeDelegateToken:)
    func frontmostApplication(displayID: UInt32, bridgeDelegateToken: String) -> AXPTranslationObject?

    @objc(macPlatformElementFromTranslation:)
    func macPlatformElement(from translation: AXPTranslationObject) -> AXPMacPlatformElement?
}

@objc private protocol AXPTranslationObject {
    var bridgeDelegateToken: String? { get set }
}

@objc private protocol AXPMacPlatformElement {
    var translation: AXPTranslationObject { get }
    var accessibilityRole: String? { get }
    var accessibilityIdentifier: String? { get }
    var accessibilityLabel: String? { get }
    var accessibilityValue: Any? { get }
    var accessibilityFrame: CGRect { get }
    var accessibilityChildren: [AnyObject]? { get }
}

/// An accessibility element on the simulator's screen, from outside the app.
struct SystemElement {
    let role: String
    let identifier: String?
    let label: String?
    let value: String?
    /// The frame in screen points.
    let frame: CGRect
    let children: [SystemElement]
}

/// Reads the frontmost accessibility tree of the simulator, which includes SpringBoard's alerts.
enum SimulatorAccessibility {
    /// Takes a snapshot of the frontmost application's elements.
    ///
    /// - parameter device: The booted device.
    ///
    /// - throws: A `ClientError` if the tree could not be read.
    ///
    /// - returns: The root element.
    static func snapshot(of device: SimDevice) async throws -> SystemElement {
        try CoreSimulator.load("/System/Library/PrivateFrameworks/AccessibilityPlatformTranslation.framework/"
                               + "AccessibilityPlatformTranslation")
        let bridge = AccessibilityBridge(device: device)

        // The translator calls the bridge synchronously and the bridge waits for the device, so it runs
        // off the cooperative thread pool
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue(label: "com.lyft.hammer.simulator-accessibility").async {
                continuation.resume(with: Result { try self.frontmostElement(through: bridge) })
            }
        }
    }

    private static func frontmostElement(through bridge: AccessibilityBridge) throws -> SystemElement {
        let translatorClass = try CoreSimulator.objcClass("AXPTranslator")
        let translator = unsafeBitCast(translatorClass, to: AXPTranslatorClass.self).sharedInstance()
        let token = UUID().uuidString
        translator.bridgeTokenDelegate = bridge
        let application = translator.frontmostApplication(displayID: 0, bridgeDelegateToken: token)
        application?.bridgeDelegateToken = token
        guard let application, let root = translator.macPlatformElement(from: application) else {
            throw ClientError.failed(.init(error: "Unable to read the simulator's accessibility elements",
                                           code: .failed, hint: "Check the simulator has finished booting"))
        }

        return self.element(root, token: token)
    }

    private static func element(_ element: AXPMacPlatformElement, token: String) -> SystemElement {
        element.translation.bridgeDelegateToken = token
        let children = (element.accessibilityChildren ?? []).map {
            self.element(unsafeBitCast($0, to: AXPMacPlatformElement.self), token: token)
        }

        return SystemElement(role: element.accessibilityRole ?? "",
                             identifier: element.accessibilityIdentifier, label: element.accessibilityLabel,
                             value: element.accessibilityValue.map { "\($0)" },
                             frame: element.accessibilityFrame, children: children)
    }
}

/// Answers the translator's requests by sending them to the device.
private final class AccessibilityBridge: NSObject, @unchecked Sendable {
    private let device: SimDevice
    private let queue = DispatchQueue(label: "com.lyft.hammer.simulator-accessibility-requests")

    init(device: SimDevice) {
        self.device = device
    }

    @objc(accessibilityTranslationDelegateBridgeCallbackWithToken:)
    func callback(token: String) -> Any {
        let callback: @convention(block) (AnyObject) -> AnyObject? = { [device, queue] request in
            let response = ResponseBox()
            let done = DispatchSemaphore(value: 0)
            device.sendAccessibilityRequest(request, completionQueue: queue) { result in
                response.value = result
                done.signal()
            }

            _ = done.wait(timeout: .now() + 5)
            return response.value ?? Self.emptyResponse
        }

        return callback
    }

    /// What the translator expects when the device does not answer.
    private static var emptyResponse: AnyObject? {
        let responseClass = NSClassFromString("AXPTranslatorResponse") as AnyObject
        return responseClass.perform(NSSelectorFromString("emptyResponse"))?.takeUnretainedValue()
    }

    @objc(accessibilityTranslationConvertPlatformFrameToSystem:withToken:)
    func convert(frame: CGRect, token: String) -> CGRect {
        return frame
    }

    @objc(accessibilityTranslationRootParentWithToken:)
    func rootParent(token: String) -> Any? {
        return nil
    }
}

private final class ResponseBox: @unchecked Sendable {
    var value: AnyObject?
}
