import CoreGraphics
import Foundation

// Synchronous versions of the async API, for tests that are not async.
extension EventGenerator {
    public func fingerDown(_ indices: [FingerIndex?] = .automatic, at locations: [HammerLocatable]) throws {
        try self.runSynchronously { try await self.fingerDown(indices, at: locations) }
    }

    public func fingerDown(_ index: FingerIndex? = .automatic, at location: HammerLocatable? = nil) throws {
        try self.runSynchronously { try await self.fingerDown(index, at: location) }
    }

    public func fingerUp(_ indices: [FingerIndex?] = .automatic) throws {
        try self.runSynchronously { try await self.fingerUp(indices) }
    }

    public func fingerUp(_ index: FingerIndex?) throws {
        try self.runSynchronously { try await self.fingerUp(index) }
    }

    public func fingerTap(_ index: FingerIndex? = .automatic, at location: HammerLocatable? = nil,
                          numberOfTimes tapCount: Int = 1,
                          interval: TimeInterval = EventGenerator.multiTapInterval) throws
    {
        try self.runSynchronously {
            try await self.fingerTap(index, at: location, numberOfTimes: tapCount, interval: interval)
        }
    }

    public func fingerDoubleTap(_ index: FingerIndex? = .automatic, at location: HammerLocatable? = nil,
                                interval: TimeInterval = EventGenerator.multiTapInterval) throws
    {
        try self.runSynchronously { try await self.fingerDoubleTap(index, at: location, interval: interval) }
    }

    public func fingerLongPress(_ index: FingerIndex? = .automatic, at location: HammerLocatable? = nil,
                                duration: TimeInterval = EventGenerator.longPressHoldDelay) throws
    {
        try self.runSynchronously { try await self.fingerLongPress(index, at: location, duration: duration) }
    }

    public func fingerMove(_ indices: [FingerIndex?] = .automatic, to locations: [HammerLocatable]) throws {
        try self.runSynchronously { try await self.fingerMove(indices, to: locations) }
    }

    public func fingerMove(_ indices: [FingerIndex?] = .automatic, translationX x: CGFloat, y: CGFloat,
                           duration: TimeInterval) throws
    {
        try self.runSynchronously {
            try await self.fingerMove(indices, translationX: x, y: y, duration: duration)
        }
    }

    public func fingerMove(_ index: FingerIndex? = .automatic, to location: HammerLocatable) throws {
        try self.runSynchronously { try await self.fingerMove(index, to: location) }
    }

    public func fingerMove(_ indices: [FingerIndex?] = .automatic, to locations: [HammerLocatable],
                           duration: TimeInterval) throws
    {
        try self.runSynchronously { try await self.fingerMove(indices, to: locations, duration: duration) }
    }

    public func fingerMove(_ index: FingerIndex? = .automatic, to location: HammerLocatable,
                           duration: TimeInterval) throws
    {
        try self.runSynchronously { try await self.fingerMove(index, to: location, duration: duration) }
    }

    public func fingerDrag(_ index: FingerIndex? = .automatic, from startPoint: HammerLocatable,
                           to endPoint: HammerLocatable, duration: TimeInterval) throws
    {
        try self.runSynchronously {
            try await self.fingerDrag(index, from: startPoint, to: endPoint, duration: duration)
        }
    }

    public func fingerSwipe(_ index: FingerIndex? = .automatic, at location: HammerLocatable? = nil,
                            direction: SwipeDirection, distance: CGFloat = EventGenerator.swipeDistance,
                            duration: TimeInterval = EventGenerator.swipeDuration) throws
    {
        try self.runSynchronously {
            try await self.fingerSwipe(index, at: location, direction: direction, distance: distance,
                                       duration: duration)
        }
    }

    public func fingerEdgeSwipe(_ index: FingerIndex? = .automatic, direction: SwipeDirection,
                                distance: CGFloat = EventGenerator.swipeDistance,
                                duration: TimeInterval = EventGenerator.swipeDuration) throws
    {
        try self.runSynchronously {
            try await self.fingerEdgeSwipe(index, direction: direction, distance: distance,
                                           duration: duration)
        }
    }

    public func twoFingerDown(_ indices: [FingerIndex?] = .automatic, at location: HammerLocatable? = nil,
                              withDistance distance: CGFloat = EventGenerator.twoFingerDistance,
                              angle radians: CGFloat = 0) throws
    {
        try self.runSynchronously {
            try await self.twoFingerDown(indices, at: location, withDistance: distance, angle: radians)
        }
    }

    public func twoFingerUp(_ indices: [FingerIndex?] = .automatic) throws {
        try self.runSynchronously { try await self.twoFingerUp(indices) }
    }

    public func twoFingerMove(_ indices: [FingerIndex?] = .automatic, to location: HammerLocatable,
                              withDistance distance: CGFloat = EventGenerator.twoFingerDistance,
                              angle radians: CGFloat = 0) throws
    {
        try self.runSynchronously {
            try await self.twoFingerMove(indices, to: location, withDistance: distance, angle: radians)
        }
    }

    public func twoFingerMove(_ indices: [FingerIndex?] = .automatic, to location: HammerLocatable,
                              withDistance distance: CGFloat = EventGenerator.twoFingerDistance,
                              angle radians: CGFloat = 0, duration: TimeInterval) throws
    {
        try self.runSynchronously {
            try await self.twoFingerMove(indices, to: location, withDistance: distance, angle: radians,
                                         duration: duration)
        }
    }

    public func twoFingerTap(_ indices: [FingerIndex?] = .automatic, at location: HammerLocatable? = nil,
                             withDistance distance: CGFloat = EventGenerator.twoFingerDistance,
                             angle radians: CGFloat = 0) throws
    {
        try self.runSynchronously {
            try await self.twoFingerTap(indices, at: location, withDistance: distance, angle: radians)
        }
    }

    public func fingerPinch(_ indices: [FingerIndex?] = .automatic, at location: HammerLocatable? = nil,
                            fromDistance startDistance: CGFloat, toDistance endDistance: CGFloat,
                            angle radians: CGFloat = 0, duration: TimeInterval) throws
    {
        try self.runSynchronously {
            try await self.fingerPinch(indices, at: location, fromDistance: startDistance,
                                       toDistance: endDistance, angle: radians, duration: duration)
        }
    }

    public func fingerPinchClose(_ indices: [FingerIndex?] = .automatic, at location: HammerLocatable? = nil,
                                 duration: TimeInterval = EventGenerator.pinchDuration) throws
    {
        try self.runSynchronously {
            try await self.fingerPinchClose(indices, at: location, duration: duration)
        }
    }

    public func fingerPinchOpen(_ indices: [FingerIndex?] = .automatic, at location: HammerLocatable? = nil,
                                duration: TimeInterval = EventGenerator.pinchDuration) throws
    {
        try self.runSynchronously {
            try await self.fingerPinchOpen(indices, at: location, duration: duration)
        }
    }

    public func fingerPivot(_ indices: [FingerIndex?] = .automatic, aroundAnchor anchor: HammerLocatable,
                            angle radians: CGFloat) throws
    {
        try self.runSynchronously {
            try await self.fingerPivot(indices, aroundAnchor: anchor, angle: radians)
        }
    }

    public func fingerPivot(_ indices: [FingerIndex?] = .automatic, aroundAnchor anchor: HammerLocatable,
                            byAngle radians: CGFloat, duration: TimeInterval) throws
    {
        try self.runSynchronously {
            try await self.fingerPivot(indices, aroundAnchor: anchor, byAngle: radians, duration: duration)
        }
    }

    public func fingerRotate(_ indices: [FingerIndex?] = .automatic, at location: HammerLocatable? = nil,
                             withDistance distance: CGFloat = EventGenerator.rotationDistance,
                             fromAngle startRadians: CGFloat, toAngle endRadians: CGFloat,
                             duration: TimeInterval) throws
    {
        try self.runSynchronously {
            try await self.fingerRotate(indices, at: location, withDistance: distance,
                                        fromAngle: startRadians, toAngle: endRadians, duration: duration)
        }
    }

    public func fingerRotate(_ indices: [FingerIndex?] = .automatic, at location: HammerLocatable? = nil,
                             withDistance distance: CGFloat = EventGenerator.rotationDistance,
                             angle radians: CGFloat, duration: TimeInterval) throws
    {
        try self.runSynchronously {
            try await self.fingerRotate(indices, at: location, withDistance: distance, angle: radians,
                                        duration: duration)
        }
    }
}
