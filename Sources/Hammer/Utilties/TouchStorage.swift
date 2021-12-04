import Foundation
import UIKit

struct TouchStorage {
    private typealias FingerStoreType = [(finger: FingerInfo, identifier: UInt32)]
    private typealias StylusStoreType = (stylus: StylusInfo, identifier: UInt32)

    private var fingerStore = FingerStoreType()
    private var stylusStore: StylusStoreType?

    var fingers: [FingerInfo] {
        return self.fingerStore.map(\.finger)
    }

    var stylus: StylusInfo? {
        return self.stylusStore?.stylus
    }

    var stylusIdentifier: UInt32? {
        return self.stylusStore?.identifier
    }

    func identifier(forFingerIndex fingerIndex: FingerIndex) -> UInt32? {
        return self.fingerStore.first { $0.finger.fingerIndex == fingerIndex }?.identifier
    }

    func fingers(forIndices indices: [FingerIndex]) -> [FingerInfo] {
        return self.fingers.filter { indices.contains($0.fingerIndex) }
    }

    mutating func append(finger: FingerInfo, forIdentifier identifier: UInt32) throws {
        guard UIDevice.current.maxNumberOfFingers > 0 else {
            throw HammerError.deviceDoesNotSupportTouches
        }

        guard self.fingerStore.count < UIDevice.current.maxNumberOfFingers else {
            throw HammerError.fingerLimitReached(limit: self.fingerStore.count)
        }

        self.fingerStore.append((finger: finger, identifier: identifier))
    }

    mutating func set(stylus: StylusInfo, forIdentifier identifier: UInt32) throws {
        guard UIDevice.current.supportsStylus else {
            throw HammerError.deviceDoesNotSupportStylus
        }

        self.stylusStore = (stylus: stylus, identifier: identifier)
    }

    mutating func remove(forIdentifier identifier: UInt32) {
        self.fingerStore.removeAll { $0.identifier == identifier }
        if self.stylusStore?.identifier == identifier {
            self.stylusStore = nil
        }
    }

    mutating func update(finger: FingerInfo, forIdentifier identifier: UInt32) throws {
        self.fingerStore.removeAll { $0.identifier == identifier }
        self.fingerStore.append((finger, identifier))
    }
}
