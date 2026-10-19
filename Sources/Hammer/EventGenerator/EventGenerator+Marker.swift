import CoreFoundation
import Darwin
import Foundation

extension EventGenerator {
    // Static so the events sent while an event generator deinitializes still complete
    private static var markerCallbacks = [UInt32: CompletionHandler]()

    func sendMarkerEvent(withCompletionBlock completion: @escaping CompletionHandler) throws {
        let eventId = self.nextEventId()
        Trace.log("marker sent id=\(eventId)")
        EventGenerator.markerCallbacks[eventId] = completion

        let eventIdBytes = withUnsafeBytes(of: Int(eventId), Array.init)
        let markerEvent = IOHID.shared.createVendorDefinedEvent(
            kCFAllocatorDefault, mach_absolute_time(),
            IOHID.Page.vendorDefinedStart.rawValue + 100,
            0, 1,
            eventIdBytes as NSArray, MemoryLayout.size(ofValue: eventIdBytes),
            kIOHIDEventOptionNone)

        // NOTE: This should not be needed. It is a workaround because the previous method doesn't seem to be
        // setting the data correctly
        IOHID.shared.eventSetIntegerValue(markerEvent, IOHID.EventField.VendorDefined.data.rawValue,
                                          Int(eventId))

        try self.enqueueEvent(markerEvent)
    }

    static func markerEventReceived(_ event: IOHIDEvent) {
        guard IOHID.shared.eventGetType(event) == IOHID.EventType.vendorDefined.rawValue else {
            return
        }

        let callbackIDRaw = IOHID.shared.eventGetIntegerValue(event,
                                                              IOHID.EventField.VendorDefined.data.rawValue)
        let callbackID = UInt32(callbackIDRaw)
        let completionBlock = self.markerCallbacks.removeValue(forKey: callbackID)
        completionBlock?()
    }
}
