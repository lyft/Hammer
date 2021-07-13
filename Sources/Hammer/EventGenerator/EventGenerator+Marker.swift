import CoreFoundation
import Darwin

extension EventGenerator {
    func sendMarkerEvent(withCompletionBlock completion: @escaping CompletionHandler) throws {
        let eventId = self.nextEventId()
        self.eventCallbacks[eventId] = completion

        let eventIdBytes = withUnsafeBytes(of: Int(eventId), Array.init)
        let markerEvent = IOHID.shared.createVendorDefinedEvent(
            kCFAllocatorDefault, mach_absolute_time(),
            IOHID.Page.vendorDefinedStart.rawValue + 100,
            0, 1,
            eventIdBytes, MemoryLayout.size(ofValue: eventIdBytes),
            kIOHIDEventOptionNone)

        // NOTE: This should not be needed. It is a workaround because the previous method doesn't seem to be
        // setting the data correctly
        IOHID.shared.eventSetIntegerValue(markerEvent, IOHID.EventField.VendorDefined.data.rawValue,
                                          Int(eventId))

        try self.sendEvent(markerEvent, wait: false)
    }

    func markerEventReceived(_ event: IOHIDEvent) {
        guard IOHID.shared.eventGetType(event) == IOHID.EventType.vendorDefined.rawValue else {
            return
        }

        let callbackIDRaw = IOHID.shared.eventGetIntegerValue(event,
                                                              IOHID.EventField.VendorDefined.data.rawValue)
        let callbackID = UInt32(callbackIDRaw)
        let completionBlock = self.eventCallbacks.removeValue(forKey: callbackID)
        completionBlock?()
    }
}
