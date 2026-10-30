import CoreGraphics
import Foundation

@objc private protocol SimDeviceLegacyHIDClient {
    @objc(sendWithMessage:freeWhenDone:completionQueue:completion:)
    func send(message: UnsafeMutableRawPointer, freeWhenDone: Bool, completionQueue: DispatchQueue,
              completion: @escaping (NSError?) -> Void)
}

/// Sends touches to the simulator's screen the way Simulator.app sends mouse clicks, so they go through
/// the system like a finger's and reach whatever is on screen, such as SpringBoard's alerts.
struct SimulatorHID {
    private typealias MessageForMouseEvent = @convention(c) (
        _ point: UnsafeMutablePointer<CGPoint>, _ secondPoint: UnsafeMutablePointer<CGPoint>?,
        _ target: UInt32, _ eventType: UInt, _ edge: UInt32, _ size: CGSize) -> UnsafeMutableRawPointer?
    private typealias Alloc = @convention(c) (AnyClass, Selector) -> UnsafeMutableRawPointer
    private typealias InitWithDevice = @convention(c) (
        UnsafeMutableRawPointer, Selector, AnyObject, AutoreleasingUnsafeMutablePointer<NSError?>)
        -> Unmanaged<AnyObject>?

    private static let mainScreenTarget: UInt32 = 0x32
    private static let mouseDown: UInt = 1
    private static let mouseUp: UInt = 2

    private let client: SimDeviceLegacyHIDClient
    private let messageForMouseEvent: MessageForMouseEvent
    private let screenSize: CGSize

    /// Connects to the device's HID system. `CoreSimulator.device(udid:)` loads the frameworks first.
    ///
    /// - parameter device: The booted device.
    ///
    /// - throws: A `ClientError` if SimulatorKit lacks what the driver needs or the connection fails.
    init(device: SimDevice) throws {
        guard let clientClass = NSClassFromString("SimulatorKit.SimDeviceLegacyHIDClient"),
              let messageForMouseEvent = dlsym(UnsafeMutableRawPointer(bitPattern: -2),
                                               "IndigoHIDMessageForMouseNSEvent"),
              let msgSend = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "objc_msgSend")
        else {
            throw ClientError.noSimulator("This Xcode's SimulatorKit can't send touches",
                                          hint: "Use an Xcode version that Hammer supports")
        }

        // The client is a Swift class without a Swift initializer, so it's created as Objective-C does
        let allocated = unsafeBitCast(msgSend, to: Alloc.self)(clientClass, NSSelectorFromString("alloc"))
        var error: NSError?
        let client = unsafeBitCast(msgSend, to: InitWithDevice.self)(
            allocated, NSSelectorFromString("initWithDevice:error:"), device, &error)
        guard let client else {
            throw ClientError.noSimulator("Unable to connect to the simulator's touch screen: "
                                          + (error?.localizedDescription ?? "unknown error"),
                                          hint: "Check the simulator is still booted")
        }

        self.client = unsafeBitCast(client.takeRetainedValue(), to: SimDeviceLegacyHIDClient.self)
        self.messageForMouseEvent = unsafeBitCast(messageForMouseEvent, to: MessageForMouseEvent.self)
        self.screenSize = device.screenSize
    }

    /// Taps a point.
    ///
    /// - parameter point: The point in screen points.
    /// - parameter count: The number of taps.
    ///
    /// - throws: A `ClientError` if the simulator rejects a touch.
    func tap(at point: CGPoint, count: Int) async throws {
        for index in 0..<count {
            if index > 0 {
                try await Task.sleep(for: .milliseconds(80))
            }

            try await self.send(Self.mouseDown, at: point)
            try await Task.sleep(for: .milliseconds(50))
            try await self.send(Self.mouseUp, at: point)
        }
    }

    private func send(_ eventType: UInt, at point: CGPoint) async throws {
        // Indigo takes the point as a fraction of the screen
        var ratio = CGPoint(x: point.x / self.screenSize.width, y: point.y / self.screenSize.height)
        guard let message = self.messageForMouseEvent(&ratio, nil, Self.mainScreenTarget, eventType, 0,
                                                       CGSize(width: 1, height: 1))
        else {
            throw ClientError.failed(.init(error: "Unable to create a touch event", code: .failed))
        }

        let queue = DispatchQueue(label: "com.lyft.hammer.simulator-hid")
        let error: NSError? = await withCheckedContinuation { continuation in
            self.client.send(message: message, freeWhenDone: true, completionQueue: queue) { error in
                continuation.resume(returning: error)
            }
        }

        if let error {
            let description = "The simulator rejected a touch: \(error.localizedDescription)"
            throw ClientError.failed(.init(error: description, code: .failed,
                                           hint: "Check the simulator is still booted"))
        }
    }
}
