import CoreGraphics
import Foundation
import UIKit

private let kDefaultRadius: CGFloat = 5
private let kScreenEdgeDistance: CGFloat = 1

extension EventGenerator {
    nonisolated public static let fingerLiftDelay: TimeInterval = 0.05
    nonisolated public static let longPressHoldDelay: TimeInterval = 2.0
    nonisolated public static let multiTapInterval: TimeInterval = 0.15
    nonisolated public static let fingerMoveInterval: TimeInterval = 1 / 60
    nonisolated public static let pinchDuration: TimeInterval = 0.15
    nonisolated public static let swipeDuration: TimeInterval = 0.2

    nonisolated public static let twoFingerDistance: CGFloat = 20
    nonisolated public static let rotationDistance: CGFloat = 100
    nonisolated public static let pinchLargeDistance: CGFloat = 200
    nonisolated public static let pinchSmallDistance: CGFloat = 20
    nonisolated public static let swipeDistance: CGFloat = 200

    // MARK: - Base Actions

    /// Sends a finger down event.
    ///
    /// - parameter indices:   The finger indices to touch down, must match the number of locations.
    /// - parameter locations: The locations where to touch down.
    public func fingerDown(_ indices: [FingerIndex?] = .automatic,
                           at locations: [HammerLocatable]) async throws
    {
        let indices = try self.fillNextFingerIndices(indices, withExpected: locations.count)
        let locations = try locations.map { try $0.windowHitPoint(for: self) }
        try await self.sendEvent(hand: HandInfo(fingers: zip(locations, indices).map { location, index in
            FingerInfo(fingerIndex: index, location: location, phase: .began,
                       pressure: 0, twist: 0, majorRadius: kDefaultRadius, minorRadius: kDefaultRadius)
        }), validate: true)
    }

    /// Sends a finger down event.
    ///
    /// - parameter index:    The finger index to touch down.
    /// - parameter location: The location where to touch down. Nil to use the center.
    public func fingerDown(_ index: FingerIndex? = .automatic,
                           at location: HammerLocatable? = nil) async throws
    {
        try await self.fingerDown([index], at: [location ?? self.mainView])
    }

    /// Sends a finger up event.
    ///
    /// Unless specified, the finger indices will be the last fingers that touched down.
    ///
    /// - parameter indices: The finger indices to touch up.
    public func fingerUp(_ indices: [FingerIndex?] = .automatic) async throws {
        let indices = try self.fillExistingFingerIndices(indices, withMinimum: 1)
        let locations = self.activeTouches.fingers(forIndices: indices).map(\.location)
        try await self.sendEvent(hand: HandInfo(fingers: zip(locations, indices).map { location, index in
            return FingerInfo(fingerIndex: index, location: location, phase: .ended,
                              pressure: 0, twist: 0, majorRadius: kDefaultRadius, minorRadius: kDefaultRadius)
        }), validate: true)
    }

    /// Sends a finger up event.
    ///
    /// Unless specified, the finger index will be the last finger that touched down.
    ///
    /// - parameter index: The finger index to touch up.
    public func fingerUp(_ index: FingerIndex?) async throws {
        try await self.fingerUp([index])
    }

    // MARK: - Tap Actions

    /// Sends a finger tap event.
    ///
    /// - parameter index:    The finger index to use for the tap.
    /// - parameter location: The location where to tap. Nil to use the center.
    /// - parameter tapCount: The number of taps to perform.
    /// - parameter interval: The interval between taps, if more than one.
    public func fingerTap(_ index: FingerIndex? = .automatic, at location: HammerLocatable? = nil,
                          numberOfTimes tapCount: Int = 1,
                          interval: TimeInterval = EventGenerator.multiTapInterval) async throws
    {
        for i in 0..<tapCount {
            try await self.fingerDown(index, at: location)
            try await self.wait(EventGenerator.fingerLiftDelay)
            try await self.fingerUp(index)
            if i < tapCount - 1 {
                try await self.wait(interval)
            }
        }
    }

    /// Sends a finger double tap event.
    ///
    /// - parameter index:    The finger index to use for the taps.
    /// - parameter location: The location where to tap. Nil to use the center.
    /// - parameter interval: The interval between taps.
    public func fingerDoubleTap(_ index: FingerIndex? = .automatic, at location: HammerLocatable? = nil,
                                interval: TimeInterval = EventGenerator.multiTapInterval) async throws
    {
        try await self.fingerTap(index, at: location, numberOfTimes: 2, interval: interval)
    }

    /// Sends a finger long press event.
    ///
    /// - parameter index:    The finger index to use for the long press.
    /// - parameter location: The location where to press. Nil to use the center.
    /// - parameter duration: The duration the touch should be on screen.
    public func fingerLongPress(_ index: FingerIndex? = .automatic, at location: HammerLocatable? = nil,
                                duration: TimeInterval = EventGenerator.longPressHoldDelay) async throws
    {
        try await self.fingerDown(index, at: location)
        try await self.wait(duration)
        try await self.fingerUp(index)
    }

    // MARK: - Move Actions

    /// Sends a finger move event.
    ///
    /// Unless specified, the finger indices will be the last fingers that touched down.
    ///
    /// - parameter indices:   The finger indices to move, must match the number of locations.
    /// - parameter locations: The new locations of the fingers.
    public func fingerMove(_ indices: [FingerIndex?] = .automatic,
                           to locations: [HammerLocatable]) async throws
    {
        let indices = try self.fillExistingFingerIndices(indices, withMinimum: locations.count)
        let locations = try locations.map { try $0.windowHitPoint(for: self) }
        let fingers = zip(locations, indices).map { location, index in
            FingerInfo(fingerIndex: index, location: location, phase: .moved,
                       pressure: 0, twist: 0, majorRadius: kDefaultRadius, minorRadius: kDefaultRadius)
        }

        try await self.sendEvent(hand: HandInfo(fingers: fingers), validate: true)
    }

    /// Sends a finger move event.
    ///
    /// Unless specified, the finger indices will be the last fingers that touched down.
    ///
    /// - parameter indices: The finger indices to move.
    /// - parameter x:       The delta value along x-axis from the current location of the finger.
    /// - parameter y:       The delta value along y-axis from the current location of the finger.
    public func fingerMove(_ indices: [FingerIndex?] = .automatic, translationX x: CGFloat, y: CGFloat,
                           duration: TimeInterval) async throws {
        let indices = try self.fillExistingFingerIndices(indices, withMinimum: 1)
        let fingers = self.activeTouches.fingers(forIndices: indices)
        let targetLocations = fingers.map(\.location).map { $0.offset(x: x, y: y) }
        try await self.fingerMove(indices, to: targetLocations, duration: duration)
    }

    /// Sends a finger move event.
    ///
    /// Unless specified, the finger indices will be the last fingers that touched down.
    ///
    /// - parameter index:    The finger index to move.
    /// - parameter location: The new location of the finger.
    public func fingerMove(_ index: FingerIndex? = .automatic, to location: HammerLocatable) async throws {
        try await self.fingerMove([index], to: [location])
    }

    /// Sends a finger move event, interpolating between the changes for the specified duration.
    ///
    /// Unless specified, the finger indices will be the last fingers that touched down.
    ///
    /// - parameter indices:   The finger indices to move, must match the number of locations.
    /// - parameter locations: The new locations of the fingers.
    /// - parameter duration:  The time to interpolate between the changes.
    public func fingerMove(_ indices: [FingerIndex?] = .automatic, to locations: [HammerLocatable],
                           duration: TimeInterval) async throws
    {
        guard duration > 0 else {
            try await self.fingerMove(indices, to: locations)
            return
        }

        let indices = try self.fillExistingFingerIndices(indices, withMinimum: locations.count)
        let locations = try locations.map { try $0.windowHitPoint(for: self) }
        let startLocations = self.activeTouches.fingers(forIndices: indices).map(\.location)

        try await self.performSteps(duration: duration) { progress in
            let nextLocations = zip(startLocations, locations).map { startLocation, endLocation in
                return curveInterpolation(from: startLocation, to: endLocation, time: progress)
            }

            try await self.fingerMove(indices, to: nextLocations)
        }
    }

    /// Sends a finger move event, interpolating between the changes for the specified duration.
    ///
    /// Unless specified, the finger indices will be the last fingers that touched down.
    ///
    /// - parameter index:    The finger index to move.
    /// - parameter location: The new location of the finger.
    /// - parameter duration: The time to interpolate between the changes.
    public func fingerMove(_ index: FingerIndex? = .automatic, to location: HammerLocatable,
                           duration: TimeInterval) async throws
    {
        try await self.fingerMove([index], to: [location], duration: duration)
    }

    /// Sends a finger drag event, interpolating between the changes for the specified duration.
    ///
    /// - parameter index:      The finger index to use for dragging.
    /// - parameter startPoint: The start location of the finger for touch down.
    /// - parameter endPoint:   The end location of the finger for touch up.
    /// - parameter duration:   The time to interpolate between the changes.
    public func fingerDrag(_ index: FingerIndex? = .automatic, from startPoint: HammerLocatable,
                           to endPoint: HammerLocatable, duration: TimeInterval) async throws
    {
        let index = try index ?? self.nextFingerIndex()
        try await self.fingerDown(index, at: startPoint)
        try await self.fingerMove(index, to: endPoint, duration: duration)
        try await self.fingerUp(index)
    }

    // MARK: - Swipe Actions

    /// Sends a finger swipe event, interpolating between the changes for the specified duration.
    ///
    /// - parameter index:     The finger index to use for the swipe.
    /// - parameter location:  The center location of the swipe. Nil to use the center.
    /// - parameter direction: The direction the finger moves, swiping up scrolls the content down.
    /// - parameter distance:  The distance the finger moves.
    /// - parameter duration:  The time to interpolate between the changes.
    public func fingerSwipe(_ index: FingerIndex? = .automatic, at location: HammerLocatable? = nil,
                            direction: SwipeDirection, distance: CGFloat = EventGenerator.swipeDistance,
                            duration: TimeInterval = EventGenerator.swipeDuration) async throws
    {
        let location = try (location ?? self.mainView).windowHitPoint(for: self)
        let vector = direction.vector
        let startPoint = location.offset(x: -vector.dx * distance / 2, y: -vector.dy * distance / 2)
        let endPoint = location.offset(x: vector.dx * distance / 2, y: vector.dy * distance / 2)
        try await self.fingerDrag(index, from: startPoint, to: endPoint, duration: duration)
    }

    /// Sends a finger swipe event from the edge of the screen, like the swipe to go back in a navigation
    /// controller, interpolating between the changes for the specified duration.
    ///
    /// - parameter index:     The finger index to use for the swipe.
    /// - parameter direction: The direction the finger moves, starting from the opposite edge of the screen.
    ///                        Swiping right starts from the left edge.
    /// - parameter distance:  The distance the finger moves.
    /// - parameter duration:  The time to interpolate between the changes.
    public func fingerEdgeSwipe(_ index: FingerIndex? = .automatic, direction: SwipeDirection,
                                distance: CGFloat = EventGenerator.swipeDistance,
                                duration: TimeInterval = EventGenerator.swipeDuration) async throws
    {
        // Start inside the screen so the touch is hittable and still counts as an edge touch
        let screenBounds = self.window.convert(self.window.screen.bounds,
                                               from: self.window.screen.coordinateSpace)
            .insetBy(dx: kScreenEdgeDistance, dy: kScreenEdgeDistance)
        let vector = direction.vector
        let startPoint = CGPoint(x: screenBounds.midX - vector.dx * screenBounds.width / 2,
                                 y: screenBounds.midY - vector.dy * screenBounds.height / 2)
        let endPoint = startPoint.offset(x: vector.dx * distance, y: vector.dy * distance)
        try await self.fingerDrag(index, from: startPoint, to: endPoint, duration: duration)
    }

    // MARK: - Two Finger Actions

    /// Sends a two finger down event.
    ///
    /// - parameter indices:  The finger indices to touch down, must be two indices.
    /// - parameter location: The center location between the two fingers. Nil to use the center.
    /// - parameter distance: The distance between the two fingers.
    /// - parameter radians:  The angle in radians of the two fingers. An angle of zero is assumed to be
    ///                       horizontal and positive angle moves clockwise.
    public func twoFingerDown(_ indices: [FingerIndex?] = .automatic, at location: HammerLocatable? = nil,
                              withDistance distance: CGFloat = EventGenerator.twoFingerDistance,
                              angle radians: CGFloat = 0) async throws
    {
        let indices = try self.fillNextFingerIndices(indices, withExpected: 2)
        let location = try (location ?? self.mainView).windowHitPoint(for: self)
        try await self.fingerDown(indices, at: location.twoWayOffset(distance, angle: radians))
    }

    /// Sends a two finger up event.
    ///
    /// Unless specified, the finger indices will be the last fingers that touched down.
    ///
    /// - parameter indices: The finger indices to touch up, must be two indices.
    public func twoFingerUp(_ indices: [FingerIndex?] = .automatic) async throws {
        let indices = try self.fillExistingFingerIndices(indices, withMinimum: 2)
        try await self.fingerUp(indices)
    }

    /// Sends a two finger move event.
    ///
    /// Unless specified, the finger indices will be the last fingers that touched down.
    ///
    /// - parameter indices:  The finger indices to move, must be two indices.
    /// - parameter location: The new center location between the two fingers.
    /// - parameter distance: The new distance between the two fingers.
    /// - parameter radians:  The new angle in radians of the two fingers. An angle of zero is assumed to be
    ///                       horizontal and positive angle moves clockwise.
    public func twoFingerMove(_ indices: [FingerIndex?] = .automatic, to location: HammerLocatable,
                              withDistance distance: CGFloat = EventGenerator.twoFingerDistance,
                              angle radians: CGFloat = 0) async throws
    {
        let indices = try self.fillExistingFingerIndices(indices, withMinimum: 2)
        let location = try location.windowHitPoint(for: self)
        try await self.fingerMove(indices, to: location.twoWayOffset(distance, angle: radians))
    }

    /// Sends a two finger move event, interpolating between the changes for the specified duration.
    ///
    /// Unless specified, the finger indices will be the last fingers that touched down.
    ///
    /// - parameter indices:  The finger indices to move, must be two indices.
    /// - parameter location: The new center location between the two fingers.
    /// - parameter distance: The new distance between the two fingers.
    /// - parameter radians:  The new angle in radians of the two fingers. An angle of zero is assumed to be
    ///                       horizontal and positive angle moves clockwise.
    /// - parameter duration: The time to interpolate between the changes.
    public func twoFingerMove(_ indices: [FingerIndex?] = .automatic, to location: HammerLocatable,
                              withDistance distance: CGFloat = EventGenerator.twoFingerDistance,
                              angle radians: CGFloat = 0, duration: TimeInterval) async throws
    {
        let location = try location.windowHitPoint(for: self)
        try await self.fingerMove(indices, to: location.twoWayOffset(distance, angle: radians),
                                  duration: duration)
    }

    /// Sends a two finger tap event.
    ///
    /// - parameter indices:  The finger indices to use for the tap, must be two indices.
    /// - parameter location: The center location between the two fingers. Nil to use the center.
    /// - parameter distance: The distance between the two fingers.
    /// - parameter radians:  The angle in radians of the two fingers. An angle of zero is assumed to be
    ///                       horizontal and positive angle moves clockwise.
    public func twoFingerTap(_ indices: [FingerIndex?] = .automatic, at location: HammerLocatable? = nil,
                             withDistance distance: CGFloat = EventGenerator.twoFingerDistance,
                             angle radians: CGFloat = 0) async throws
    {
        let indices = try self.fillNextFingerIndices(indices, withExpected: 2)
        try await self.twoFingerDown(indices, at: location, withDistance: distance, angle: radians)
        try await self.wait(EventGenerator.fingerLiftDelay)
        try await self.twoFingerUp(indices)
    }

    // MARK: - Pinch Actions

    /// Sends a two finger pinch event, interpolating between the changes for the specified duration.
    ///
    /// - parameter indices:       The finger indices to pinch, must be two indices.
    /// - parameter location:      The center location between the two fingers.
    /// - parameter startDistance: The initial distance between the two fingers.
    /// - parameter endDistance:   The final distance between the two fingers.
    /// - parameter radians:       The angle in radians of the two fingers. An angle of zero is assumed to be
    ///                            horizontal and positive angle moves clockwise.
    /// - parameter duration:      The time to interpolate between the changes.
    public func fingerPinch(_ indices: [FingerIndex?] = .automatic, at location: HammerLocatable? = nil,
                            fromDistance startDistance: CGFloat, toDistance endDistance: CGFloat,
                            angle radians: CGFloat = 0, duration: TimeInterval) async throws
    {
        let indices = try self.fillNextFingerIndices(indices, withExpected: 2)
        let location = try (location ?? self.mainView).windowHitPoint(for: self)
        let startLocations = location.twoWayOffset(startDistance, angle: radians)
        let endLocations = location.twoWayOffset(endDistance, angle: radians)
        try await self.fingerDown(indices, at: startLocations)
        try await self.fingerMove(indices, to: endLocations, duration: duration)
        try await self.fingerUp(indices)
    }

    /// Sends a two finger pinch event shrinking the distance between fingers and interpolating between the
    /// changes for the specified duration.
    ///
    /// - parameter indices:  The finger indices to pinch, must be two indices.
    /// - parameter location: The center location between the two fingers.
    /// - parameter duration: The time to interpolate between the changes.
    public func fingerPinchClose(_ indices: [FingerIndex?] = .automatic, at location: HammerLocatable? = nil,
                                 duration: TimeInterval = EventGenerator.pinchDuration) async throws
    {
        try await self.fingerPinch(indices, at: location,
                             fromDistance: EventGenerator.pinchLargeDistance,
                             toDistance: EventGenerator.pinchSmallDistance,
                             duration: duration)
    }

    /// Sends a two finger pinch event increasing the distance between fingers and interpolating between the
    /// changes for the specified duration.
    ///
    /// - parameter indices:  The finger indices to pinch, must be two indices.
    /// - parameter location: The center location between the two fingers.
    /// - parameter duration: The time to interpolate between the changes.
    public func fingerPinchOpen(_ indices: [FingerIndex?] = .automatic, at location: HammerLocatable? = nil,
                                duration: TimeInterval = EventGenerator.pinchDuration) async throws
    {
        try await self.fingerPinch(indices, at: location,
                             fromDistance: EventGenerator.pinchSmallDistance,
                             toDistance: EventGenerator.pinchLargeDistance,
                             duration: duration)
    }

    // MARK: - Rotate Actions

    /// Sends a finger move event pivoting around an anchor.
    ///
    /// Unless specified, the finger indices will be the last fingers that touched down.
    ///
    /// - parameter indices: The finger indices to pivot.
    /// - parameter anchor:  The location to use as the anchor for pivoting.
    /// - parameter radians: The angle in radians to pivot. An angle of zero is assumed to be horizontal and
    ///                      positive angle moves clockwise.
    public func fingerPivot(_ indices: [FingerIndex?] = .automatic, aroundAnchor anchor: HammerLocatable,
                            angle radians: CGFloat) async throws
    {
        let indices = try self.fillExistingFingerIndices(indices, withMinimum: 1)
        let anchor = try anchor.windowHitPoint(for: self)
        let locations = self.activeTouches.fingers(forIndices: indices).map(\.location)
        try await self.fingerMove(indices, to: locations.map { $0.pivot(anchor: anchor, angle: radians) })
    }

    /// Sends a finger move event pivoting around an anchor and interpolating between the changes for the
    /// specified duration.
    ///
    /// Unless specified, the finger indices will be the last fingers that touched down.
    ///
    /// - parameter indices:  The finger indices to pivot.
    /// - parameter anchor:   The location to use as the anchor for pivoting.
    /// - parameter radians:  The angle in radians to pivot. An angle of zero is assumed to be horizontal and
    ///                       positive angle moves clockwise.
    /// - parameter duration: The time to interpolate between the changes.
    public func fingerPivot(_ indices: [FingerIndex?] = .automatic, aroundAnchor anchor: HammerLocatable,
                            byAngle radians: CGFloat, duration: TimeInterval) async throws
    {
        guard duration > 0 else {
            try await self.fingerPivot(indices, aroundAnchor: anchor, angle: radians)
            return
        }

        let indices = try self.fillExistingFingerIndices(indices, withMinimum: 1)
        let anchor = try anchor.windowHitPoint(for: self)
        let startLocations = self.activeTouches.fingers(forIndices: indices).map(\.location)

        try await self.performSteps(duration: duration) { progress in
            let radians = curveInterpolation(from: 0, to: radians, time: progress)
            let nextLocations = startLocations.map { $0.pivot(anchor: anchor, angle: radians) }

            try await self.fingerMove(indices, to: nextLocations)
        }
    }

    /// Sends a finger move event rotating a between to angles and interpolating between the changes for the
    /// specified duration.
    ///
    /// - parameter indices:      The finger indices to rotate, must be two indices.
    /// - parameter location:     The center location between the two fingers.
    /// - parameter distance:     The distance between the two fingers.
    /// - parameter startRadians: The initial angle in radians for touch down. An angle of zero is assumed to
    ///                           be horizontal and positive angle moves clockwise.
    /// - parameter endRadians:   The final angle in radians for touch up. An angle of zero is assumed to
    ///                           be horizontal and positive angle moves clockwise.
    /// - parameter duration:     The time to interpolate between the changes.
    public func fingerRotate(_ indices: [FingerIndex?] = .automatic, at location: HammerLocatable? = nil,
                             withDistance distance: CGFloat = EventGenerator.rotationDistance,
                             fromAngle startRadians: CGFloat, toAngle endRadians: CGFloat,
                             duration: TimeInterval) async throws
    {
        let indices = try self.fillNextFingerIndices(indices, withExpected: 2)
        let location = try (location ?? self.mainView).windowHitPoint(for: self)
        try await self.fingerDown(indices, at: location.twoWayOffset(distance, angle: startRadians))
        try await self.fingerPivot(indices, aroundAnchor: location, byAngle: endRadians - startRadians,
                             duration: duration)
        try await self.fingerUp(indices)
    }

    /// Sends a finger move event rotating a specified angle and interpolating between the changes for the
    /// specified duration.
    ///
    /// - parameter indices:  The finger indices to rotate, must be two indices.
    /// - parameter location: The center location between the two fingers.
    /// - parameter distance: The distance between the two fingers.
    /// - parameter radians:  The angle in radians for the rotation, staring from zero. An angle of zero is
    ///                       assumed to be horizontal and positive angle moves clockwise.
    /// - parameter duration: The time to interpolate between the changes.
    public func fingerRotate(_ indices: [FingerIndex?] = .automatic, at location: HammerLocatable? = nil,
                             withDistance distance: CGFloat = EventGenerator.rotationDistance,
                             angle radians: CGFloat, duration: TimeInterval) async throws
    {
        try await self.fingerRotate(indices, at: location, withDistance: distance,
                                    fromAngle: 0, toAngle: radians, duration: duration)
    }

    // MARK: - Event

    /// Sends a hand event.
    ///
    /// - parameter hand:     The event to send.
    /// - parameter validate: If the window must be ready and the locations hittable.
    private func sendEvent(hand: HandInfo, validate: Bool) async throws {
        if validate {
            try self.checkPointsAreHittable(hand.fingers.map(\.location))
        }

        let event = try self.handEvent(hand)
        self.deliveredBeganTouches.removeAll()
        try await self.sendEvent(event)
        try self.checkTouchesWereDelivered(for: hand.fingers.filter { $0.phase == .began })
    }

    /// Creates a hand event and records the fingers' new state.
    ///
    /// - parameter hand: The fingers for the event.
    ///
    /// - throws: An error if a finger's phase does not match its current state.
    ///
    /// - returns: The event to send.
    private func handEvent(_ hand: HandInfo) throws -> IOHIDEvent {
        let machTime = mach_absolute_time()
        let isTouching = hand.isTouching

        let event = IOHID.shared.createDigitizerEvent(
            kCFAllocatorDefault, machTime,
            IOHID.DigitizerTransducerType.hand.rawValue, 0, 0,
            hand.eventMask.rawValue,
            0, 0, 0, 0, 0, 0,
            false, isTouching,
            kIOHIDEventOptionNone)

        IOHID.shared.eventSetIntegerValue(event, IOHID.EventField.Digitizer.isDisplayIntegrated.rawValue, 1)
        IOHID.shared.eventSetSenderID(event, self.senderId)

        for finger in hand.fingers {
            let identifier = try self.identifier(for: finger)
            var eventMask = finger.eventMask
            if finger.phase == .began && self.isAtScreenEdge(finger.location) {
                eventMask.insert(.fromEdgeTip)
            }

            let subEvent = IOHID.shared.createDigitizerFingerEvent(
                kCFAllocatorDefault, machTime,
                identifier, finger.fingerIndex.rawValue,
                eventMask.rawValue,
                finger.location.x, finger.location.y, 0,
                finger.pressure, finger.twist,
                isTouching, isTouching,
                kIOHIDEventOptionNone)

            IOHID.shared.eventSetFloatValue(subEvent, IOHID.EventField.Digitizer.majorRadius.rawValue,
                                            finger.majorRadius)
            IOHID.shared.eventSetFloatValue(subEvent, IOHID.EventField.Digitizer.minorRadius.rawValue,
                                            finger.minorRadius)
            IOHID.shared.eventAppendEvent(event, subEvent, 0)

            self.debugWindow.update(fingerIndex: finger.fingerIndex,
                                    location: finger.phase.isTouching ? finger.location : nil)
        }

        return event
    }

    /// Returns if a location is at the edge of the screen, where touches start edge swipes.
    ///
    /// - parameter location: The location in window coordinates.
    private func isAtScreenEdge(_ location: CGPoint) -> Bool {
        let screenBounds = self.window.screen.bounds
        let screenLocation = self.window.convert(location, to: self.window.screen.coordinateSpace)
        return screenLocation.x - screenBounds.minX <= kScreenEdgeDistance
            || screenBounds.maxX - screenLocation.x <= kScreenEdgeDistance
            || screenLocation.y - screenBounds.minY <= kScreenEdgeDistance
            || screenBounds.maxY - screenLocation.y <= kScreenEdgeDistance
    }

    /// Creates an event that cancels the touches of all the fingers that are down.
    ///
    /// - throws: An error if the event could not be created.
    ///
    /// - returns: The event to send.
    func cancelFingersEvent() throws -> IOHIDEvent {
        let fingers = self.activeTouches.fingers.map { finger in
            FingerInfo(fingerIndex: finger.fingerIndex, location: finger.location, phase: .cancelled,
                       pressure: 0, twist: 0, majorRadius: kDefaultRadius, minorRadius: kDefaultRadius)
        }

        return try self.handEvent(HandInfo(fingers: fingers))
    }

    /// Records the touches UIKit begins delivering to any window, since a touch can land in a window
    /// presented above the event generator's window.
    ///
    /// - parameter event: The event UIKit is about to dispatch.
    func eventDispatched(_ event: UIEvent) {
        guard event.type == .touches else {
            return
        }

        let beganTouches = (event.allTouches ?? []).filter { touch in
            touch.phase == .began && touch.type == .direct
        }

        self.deliveredBeganTouches.append(contentsOf: beganTouches)
    }

    /// Checks that UIKit began a touch for each finger that touched down.
    ///
    /// - parameter fingers: The fingers that touched down.
    ///
    /// - throws: `HammerError.touchWasNotDelivered` if UIKit did not deliver a touch for a finger.
    private func checkTouchesWereDelivered(for fingers: [FingerInfo]) throws {
        var deliveredLocations = self.deliveredBeganTouches.compactMap { touch in
            touch.window?.convert(touch.location(in: nil), to: self.window)
        }
        let undeliveredFingers = fingers.filter { finger in
            let distances = deliveredLocations.map { $0.distance(to: finger.location) }
            guard let closestIndex = distances.indices.min(by: { distances[$0] < distances[$1] }) else {
                return true
            }

            deliveredLocations.remove(at: closestIndex)
            return false
        }

        guard let firstUndeliveredFinger = undeliveredFingers.first else {
            return
        }

        // UIKit has no touch for these fingers, so they are not down
        for finger in undeliveredFingers {
            if let identifier = self.activeTouches.identifier(forFingerIndex: finger.fingerIndex) {
                self.activeTouches.remove(forIdentifier: identifier)
            }

            self.debugWindow.update(fingerIndex: finger.fingerIndex, location: nil)
        }

        throw HammerError.touchWasNotDelivered(index: firstUndeliveredFinger.fingerIndex)
    }

    private func identifier(for finger: FingerInfo) throws -> UInt32 {
        let existingIdentifier = self.activeTouches.identifier(forFingerIndex: finger.fingerIndex)
        switch finger.phase {
        case .began:
            guard existingIdentifier == nil else {
                throw HammerError.touchForFingerAlreadyExists(index: finger.fingerIndex)
            }

            let identifier = self.nextEventId()
            try self.activeTouches.append(finger: finger, forIdentifier: identifier)
            return identifier
        case .moved, .stationary:
            guard let existingIdentifier = existingIdentifier else {
                throw HammerError.touchForFingerDoesNotExist(index: finger.fingerIndex)
            }

            try self.activeTouches.update(finger: finger, forIdentifier: existingIdentifier)
            return existingIdentifier
        case .ended, .cancelled:
            guard let existingIdentifier = existingIdentifier else {
                throw HammerError.touchForFingerDoesNotExist(index: finger.fingerIndex)
            }

            self.activeTouches.remove(forIdentifier: existingIdentifier)
            return existingIdentifier
        case .regionEntered, .regionMoved, .regionExited:
            throw HammerError.unsupportedTouchPhase(finger.phase)
        @unknown default:
            throw HammerError.unsupportedTouchPhase(finger.phase)
        }
    }

    private func nextFingerIndex() throws -> FingerIndex {
        if let nextIndex = try self.fillNextFingerIndices(.automatic, withExpected: 1).first {
            return nextIndex
        } else {
            throw HammerError.fingerLimitReached(limit: FingerIndex.defaultOrder.count)
        }
    }

    private func fillNextFingerIndices(_ indices: [FingerIndex?],
                                       withExpected expected: Int) throws -> [FingerIndex]
    {
        if indices.count > 0 && indices.count != expected {
            throw HammerError.invalidFingerCount(count: indices.count, expected: expected)
        }

        var indices = indices
        while indices.count < expected {
            indices.append(.automatic)
        }

        let activeFingerIndices = self.activeTouches.fingers.map(\.fingerIndex)
        let unusedFingersIndices = FingerIndex.defaultOrder
            .filter { !activeFingerIndices.contains($0) }
            .filter { !indices.contains($0) }

        let nilCount = indices.filter({ $0 == .automatic }).count
        guard nilCount <= unusedFingersIndices.count else {
            throw HammerError.fingerLimitReached(limit: FingerIndex.defaultOrder.count)
        }

        var nextIndices = unusedFingersIndices.prefix(nilCount)
        return indices.compactMap { $0 ?? nextIndices.popFirst() }
    }

    private func fillExistingFingerIndices(_ indices: [FingerIndex?],
                                           withMinimum minimum: Int) throws -> [FingerIndex]
    {
        if indices.count > 0 && indices.count < minimum {
            throw HammerError.invalidFingerCount(count: indices.count, expected: minimum)
        }

        var indices = indices
        while indices.count < minimum {
            indices.append(.automatic)
        }

        let activeFingerIndices = self.activeTouches.fingers.map(\.fingerIndex)

        guard indices.count <= activeFingerIndices.count else {
            throw HammerError.fingerLimitReached(limit: FingerIndex.defaultOrder.count)
        }

        let nilCount = indices.filter({ $0 == .automatic }).count
        var nextIndices = activeFingerIndices.filter { !indices.contains($0) }.suffix(nilCount)
        return indices.compactMap { $0 ?? nextIndices.popFirst() }
    }
}
