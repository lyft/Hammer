import CoreFoundation
import Darwin

private let kBackBoardServicesPath
    = "/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices"

struct BackBoardServices {
    typealias CHIDEventSetDigitizerInfo = @convention(c) (
        _ digitizerEvent: IOHIDEvent, _ contextID: UInt32, _ systemGestureIsPossible: Bool,
        _ isSystemGestureStateChangeEvent: Bool, _ displayUUID: CFString?,
        _ initialTouchTimestamp: CFTimeInterval, _ maxForce: Float) -> Void

    let eventSetDigitizerInfo: CHIDEventSetDigitizerInfo

    static let shared = BackBoardServices()

    private init() {
        let handle = dlopen(kBackBoardServicesPath, RTLD_NOW)
        self.eventSetDigitizerInfo = unsafeBitCast(dlsym(handle, "BKSHIDEventSetDigitizerInfo"),
                                                   to: CHIDEventSetDigitizerInfo.self)
    }
}
