// swiftlint:disable type_name

import CoreGraphics
import Foundation

private let kIOKitPath
    = "/System/Library/Frameworks/IOKit.framework/IOKit"

let kIOHIDEventOptionNone: CFOptionFlags = 0
let kIOHIDTransducerTouch: CFOptionFlags = 0x00020000

@objc protocol IOHIDEvent: NSObjectProtocol {}
@objc protocol IOHIDEventSystemClient: NSObjectProtocol {}

struct IOHID {
    typealias IOHIDEventSystemClientEventCallback = (_ target: Any?, _ refcon: Any?,
                                                     _ queue: AnyObject, _ event: IOHIDEvent) -> Void

    typealias IOHIDEventCreateDigitizerEvent = @convention(c) (
        _ allocator: CFAllocator?, _ timestamp: UInt64,
        _ transducer_type: DigitizerTransducerType.RawValue, _ index: UInt32, _ identifier: UInt32,
        _ eventMask: DigitizerEventMask.RawValue, _ buttonEvent: UInt32,
        _ x: CGFloat, _ y: CGFloat, _ z: CGFloat, _ pressure: CGFloat, _ twist: CGFloat,
        _ isRange: Bool, _ isTouch: Bool, _ options: CFOptionFlags) -> IOHIDEvent

    typealias IOHIDEventCreateDigitizerFingerEvent = @convention(c) (
        _ allocator: CFAllocator?, _ timestamp: UInt64, _ identifier: UInt32, _ fingerIndex: UInt32,
        _ eventMask: DigitizerEventMask.RawValue,
        _ x: CGFloat, _ y: CGFloat, _ z: CGFloat, _ pressure: CGFloat, _ twist: CGFloat,
        _ isRange: Bool, _ isTouch: Bool, _ options: CFOptionFlags) -> IOHIDEvent

    typealias IOHIDEventCreateDigitizerStylusEvent = @convention(c) (
        _ allocator: CFAllocator?, _ timestamp: UInt64, _ identifier: UInt32, _ index: UInt32,
        _ eventMask: DigitizerEventMask.RawValue, _ buttonMask: UInt32,
        _ x: CGFloat, _ y: CGFloat, _ z: CGFloat, _ tipPressure: CGFloat, _ barrelPressure: CGFloat,
        _ twist: CGFloat, _ altitude: CGFloat, _ azimuth: CGFloat,
        _ isRange: Bool, _ isTouch: Bool, _ options: CFOptionFlags) -> IOHIDEvent

    typealias IOHIDEventCreateKeyboardEvent = @convention(c) (
        _ allocator: CFAllocator?, _ timestamp: UInt64, _ identifier: UInt32, _ usage: UInt32,
        _ isKeyDown: Bool, _ options: CFOptionFlags) -> IOHIDEvent

    typealias IOHIDEventCreateVendorDefinedEvent = @convention(c) (
        _ allocator: CFAllocator?, _ timestamp: UInt64, _ usagePage: UInt32, _ usage: UInt32,
        _ version: UInt32, _ data: NSArray, _ length: Int, _ options: CFOptionFlags) -> IOHIDEvent

    typealias IOHIDEventSystemClientCreate = @convention(c) (
        _ allocator: CFAllocator?) -> IOHIDEventSystemClient
    typealias IOHIDEventSystemClientScheduleWithRunLoop = @convention(c) (
        _ client: IOHIDEventSystemClient, _ runloop: CFRunLoop, _ mode: CFRunLoopMode.RawValue) -> Void
    typealias IOHIDEventSystemClientRegisterEventCallback = @convention(c) (
        _ client: IOHIDEventSystemClient, _ callback: @escaping IOHIDEventSystemClientEventCallback,
        _ target: Any?, _ refcon: Any?) -> Void

    typealias IOHIDEventGetIntegerValue = @convention(c) (
        _ event: IOHIDEvent, _ field: UInt32) -> Int
    typealias IOHIDEventSetIntegerValue = @convention(c) (
        _ event: IOHIDEvent, _ field: UInt32, _ value: Int) -> Void
    typealias IOHIDEventGetFloatValue = @convention(c) (
        _ event: IOHIDEvent, _ field: UInt32) -> CGFloat
    typealias IOHIDEventSetFloatValue = @convention(c) (
        _ event: IOHIDEvent, _ field: UInt32, _ value: CGFloat) -> Void
    typealias IOHIDEventGetDataValue = @convention(c) (
        _ event: IOHIDEvent, _ field: UInt32) -> Data
    typealias IOHIDEventAppendEvent = @convention(c) (
        _ event: IOHIDEvent, _ subevent: IOHIDEvent, _ options: CFOptionFlags) -> Void
    typealias IOHIDEventSetSenderID = @convention(c) (
        _ event: IOHIDEvent, _ senderId: UInt64) -> Void
    typealias IOHIDEventGetType = @convention(c) (
        _ event: IOHIDEvent) -> EventType.RawValue

    let createDigitizerEvent: IOHIDEventCreateDigitizerEvent
    let createDigitizerFingerEvent: IOHIDEventCreateDigitizerFingerEvent
    let createDigitizerStylusEvent: IOHIDEventCreateDigitizerStylusEvent
    let createKeyboardEvent: IOHIDEventCreateKeyboardEvent
    let createVendorDefinedEvent: IOHIDEventCreateVendorDefinedEvent

    let eventSystemClientCreate: IOHIDEventSystemClientCreate
    let eventSystemClientScheduleWithRunLoop: IOHIDEventSystemClientScheduleWithRunLoop
    let eventSystemClientRegisterEventCallback: IOHIDEventSystemClientRegisterEventCallback

    let eventGetIntegerValue: IOHIDEventGetIntegerValue
    let eventSetIntegerValue: IOHIDEventSetIntegerValue
    let eventGetFloatValue: IOHIDEventGetFloatValue
    let eventSetFloatValue: IOHIDEventSetFloatValue
    let eventGetDataValue: IOHIDEventGetDataValue
    let eventAppendEvent: IOHIDEventAppendEvent
    let eventSetSenderID: IOHIDEventSetSenderID
    let eventGetType: IOHIDEventGetType

    static let shared = IOHID()

    private init() {
        let handle = dlopen(kIOKitPath, RTLD_NOW)
        self.createDigitizerEvent = unsafeBitCast(dlsym(handle, "IOHIDEventCreateDigitizerEvent"),
                                                  to: IOHIDEventCreateDigitizerEvent.self)
        self.createDigitizerFingerEvent = unsafeBitCast(dlsym(handle, "IOHIDEventCreateDigitizerFingerEvent"),
                                                        to: IOHIDEventCreateDigitizerFingerEvent.self)
        self.createDigitizerStylusEvent = unsafeBitCast(dlsym(handle, "IOHIDEventCreateDigitizerStylusEvent"),
                                                        to: IOHIDEventCreateDigitizerStylusEvent.self)
        self.createKeyboardEvent = unsafeBitCast(dlsym(handle, "IOHIDEventCreateKeyboardEvent"),
                                                 to: IOHIDEventCreateKeyboardEvent.self)
        self.createVendorDefinedEvent = unsafeBitCast(dlsym(handle, "IOHIDEventCreateVendorDefinedEvent"),
                                                      to: IOHIDEventCreateVendorDefinedEvent.self)

        self.eventSystemClientCreate
            = unsafeBitCast(dlsym(handle, "IOHIDEventSystemClientCreate"),
                            to: IOHIDEventSystemClientCreate.self)
        self.eventSystemClientScheduleWithRunLoop
            = unsafeBitCast(dlsym(handle, "IOHIDEventSystemClientScheduleWithRunLoop"),
                            to: IOHIDEventSystemClientScheduleWithRunLoop.self)
        self.eventSystemClientRegisterEventCallback
            = unsafeBitCast(dlsym(handle, "IOHIDEventSystemClientRegisterEventCallback"),
                            to: IOHIDEventSystemClientRegisterEventCallback.self)

        self.eventGetIntegerValue = unsafeBitCast(dlsym(handle, "IOHIDEventGetIntegerValue"),
                                                  to: IOHIDEventGetIntegerValue.self)
        self.eventSetIntegerValue = unsafeBitCast(dlsym(handle, "IOHIDEventSetIntegerValue"),
                                                  to: IOHIDEventSetIntegerValue.self)
        self.eventGetFloatValue = unsafeBitCast(dlsym(handle, "IOHIDEventGetFloatValue"),
                                                to: IOHIDEventGetFloatValue.self)
        self.eventSetFloatValue = unsafeBitCast(dlsym(handle, "IOHIDEventSetFloatValue"),
                                                to: IOHIDEventSetFloatValue.self)
        self.eventGetDataValue = unsafeBitCast(dlsym(handle, "IOHIDEventGetDataValue"),
                                               to: IOHIDEventGetDataValue.self)
        self.eventAppendEvent = unsafeBitCast(dlsym(handle, "IOHIDEventAppendEvent"),
                                              to: IOHIDEventAppendEvent.self)
        self.eventSetSenderID = unsafeBitCast(dlsym(handle, "IOHIDEventSetSenderID"),
                                              to: IOHIDEventSetSenderID.self)
        self.eventGetType = unsafeBitCast(dlsym(handle, "IOHIDEventGetType"),
                                          to: IOHIDEventGetType.self)
    }
}

extension IOHID {
    enum DigitizerTransducerType: UInt32 {
        case stylus = 0
        // case puck = 1
        // case finger = 2
        case hand = 3
    }
}

extension IOHID {
    enum Page: UInt32 {
        case keyboardOrKeypad = 0x07
        case vendorDefinedStart = 0xFF00
    }
}

extension IOHID {
    enum EventType: UInt32 {
        case null = 0
        case vendorDefined = 1
        case button = 2
        case keyboard = 3
        case translation = 4
        case rotation = 5
        case scroll = 6
        case scale = 7
        case zoom = 8
        case velocity = 9
        case orientation = 10
        case digitizer = 11
        case swipe = 16
        case force = 32
    }

    enum EventField {
        enum VendorDefined: UInt32 { // (1 << 16)
            case usagePage = 0x10000
            case usage = 0x10001
            case version = 0x10002
            case dataLength = 0x10003
            case data = 0x10004
        }

        enum Digitizer: UInt32 { // (11 << 16)
            case x = 0xB0000
            case y = 0xB0001
            case majorRadius = 0xB0014
            case minorRadius = 0xB0015
            case isDisplayIntegrated = 0xB0019
        }
    }
}

extension IOHID {
    struct DigitizerEventMask: OptionSet {
        let rawValue: UInt32

        static let range = DigitizerEventMask(rawValue: 1 << 0)
        static let touch = DigitizerEventMask(rawValue: 1 << 1)
        static let position = DigitizerEventMask(rawValue: 1 << 2)
        static let identity = DigitizerEventMask(rawValue: 1 << 5)
        static let attribute = DigitizerEventMask(rawValue: 1 << 6)
        static let cancel = DigitizerEventMask(rawValue: 1 << 7)
        static let start = DigitizerEventMask(rawValue: 1 << 8)

        static let estimatedAltitude = DigitizerEventMask(rawValue: 1 << 28)
        static let estimatedAzimuth = DigitizerEventMask(rawValue: 1 << 29)
        static let estimatedPressure = DigitizerEventMask(rawValue: 1 << 30)
    }
}

let kGSEventPathInfoInRange: UInt8 = (1 << 0)
let kGSEventPathInfoInTouch: UInt8 = (1 << 1)

// swiftlint:enable type_name
