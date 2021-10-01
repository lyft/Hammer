import CoreGraphics
import Foundation
import UIKit

private let kStylusFingerId: UInt32 = 0

extension EventGenerator {
    // MARK: - Base Actions

    /// Sends a stylus down event.
    ///
    /// - parameter location: The location where to touch down. Nil to use the center.
    /// - parameter azimuth:  The azimuth of the stylus in radians where 0 is true north.
    /// - parameter altitude: The altitude of the stylus in radians where 0 is straight down.
    /// - parameter pressure: The pressure of the touch, from 0 to 1.
    public func stylusDown(at location: HammerLocatable? = nil,
                           azimuth: CGFloat = 0, altitude: CGFloat = 0, pressure: CGFloat = 0) throws
    {
        let location = try (location ?? self.mainView).windowHitPoint(for: self)
        try self.sendEvent(stylus: StylusInfo(location: location, phase: .began,
                                              pressure: pressure, twist: 0,
                                              altitude: altitude, azimuth: azimuth))
    }

    /// Sends a stylus up event.
    public func stylusUp() throws {
        guard let location = self.activeTouches.stylus?.location else {
            throw HammerError.touchForStylusDoesNotExist
        }

        try self.sendEvent(stylus: StylusInfo(location: location, phase: .ended, pressure: 0, twist: 0,
                                              altitude: 0, azimuth: 0))
    }

    // MARK: - Tap Actions

    /// Sends a stylus tap event.
    ///
    /// - parameter location: The location where to tap. Nil to use the center.
    /// - parameter tapCount: The number of taps to perform.
    /// - parameter interval: The interval between taps, if more than one.
    /// - parameter azimuth:  The azimuth of the stylus in radians where 0 is true north.
    /// - parameter altitude: The altitude of the stylus in radians where 0 is straight down.
    /// - parameter pressure: The pressure of the touch, from 0 to 1.
    public func stylusTap(at location: HammerLocatable? = nil, numberOfTimes tapCount: Int,
                          interval: TimeInterval = EventGenerator.multiTapInterval,
                          azimuth: CGFloat = 0, altitude: CGFloat = 0, pressure: CGFloat = 0) throws
    {
        for i in 0..<tapCount {
            try self.stylusDown(at: location, azimuth: azimuth, altitude: altitude, pressure: pressure)
            try self.wait(EventGenerator.fingerLiftDelay)
            try self.stylusUp()
            if i < tapCount - 1 {
                try self.wait(interval)
            }
        }
    }

    /// Sends a stylus tap event.
    ///
    /// - parameter location: The location where to tap. Nil to use the center.
    /// - parameter azimuth:  The azimuth of the stylus in radians where 0 is true north.
    /// - parameter altitude: The altitude of the stylus in radians where 0 is straight down.
    /// - parameter pressure: The pressure of the touch, from 0 to 1.
    public func stylusTap(at location: HammerLocatable? = nil,
                          azimuth: CGFloat = 0, altitude: CGFloat = 0, pressure: CGFloat = 0) throws
    {
        try self.stylusTap(at: location, numberOfTimes: 1,
                           azimuth: azimuth, altitude: altitude, pressure: pressure)
    }

    /// Sends a stylus double tap event.
    ///
    /// - parameter location: The location where to tap. Nil to use the center.
    /// - parameter azimuth:  The azimuth of the stylus in radians where 0 is true north.
    /// - parameter altitude: The altitude of the stylus in radians where 0 is straight down.
    /// - parameter pressure: The pressure of the touch, from 0 to 1.
    public func stylusDoubleTap(at location: HammerLocatable? = nil,
                                azimuth: CGFloat = 0, altitude: CGFloat = 0, pressure: CGFloat = 0) throws
    {
        try self.stylusTap(at: location, numberOfTimes: 2,
                           azimuth: azimuth, altitude: altitude, pressure: pressure)
    }

    /// Sends a stylus long press event.
    ///
    /// - parameter location: The location where to long press. Nil to use the center.
    /// - parameter azimuth:  The azimuth of the stylus in radians where 0 is true north.
    /// - parameter altitude: The altitude of the stylus in radians where 0 is straight down.
    /// - parameter pressure: The pressure of the touch, from 0 to 1.
    /// - parameter duration: The duration the touch should be on screen.
    public func stylusLongPress(at location: HammerLocatable? = nil,
                                azimuth: CGFloat = 0, altitude: CGFloat = 0, pressure: CGFloat = 0,
                                duration: TimeInterval = EventGenerator.longPressHoldDelay) throws
    {
        try self.stylusDown(at: location, azimuth: azimuth, altitude: altitude, pressure: pressure)
        try self.wait(duration)
        try self.stylusUp()
    }

    // MARK: - Move Actions

    /// Sends a stylus move event.
    ///
    /// - parameter location: The new location of the finger.
    /// - parameter azimuth:  The azimuth of the stylus in radians where 0 is true north.
    /// - parameter altitude: The altitude of the stylus in radians where 0 is straight down.
    /// - parameter pressure: The pressure of the touch, from 0 to 1.
    public func stylusMove(to location: HammerLocatable,
                           azimuth: CGFloat = 0, altitude: CGFloat = 0, pressure: CGFloat = 0) throws
    {
        let location = try location.windowHitPoint(for: self)
        try self.sendEvent(stylus: StylusInfo(location: location, phase: .moved, pressure: pressure, twist: 0,
                                              altitude: altitude, azimuth: azimuth))
    }

    /// Sends a stylus move event, interpolating between the changes for the specified duration.
    ///
    /// - parameter location: The new location of the finger.
    /// - parameter azimuth:  The azimuth of the stylus in radians where 0 is true north.
    /// - parameter altitude: The altitude of the stylus in radians where 0 is straight down.
    /// - parameter pressure: The pressure of the touch, from 0 to 1.
    /// - parameter duration: The time to interpolate between the changes.
    public func stylusMove(to location: HammerLocatable,
                           azimuth: CGFloat = 0, altitude: CGFloat = 0, pressure: CGFloat = 0,
                           duration: TimeInterval) throws
    {
        guard let existingStylus = self.activeTouches.stylus else {
            throw HammerError.touchForStylusDoesNotExist
        }

        let location = try location.windowHitPoint(for: self)

        let startLocation = existingStylus.location
        let startAzimuth = existingStylus.azimuth
        let startAltitude = existingStylus.altitude
        let startPressure = existingStylus.pressure

        let startTime = Date()
        var elapsed: TimeInterval = 0

        while elapsed < (duration - EventGenerator.fingerMoveInterval) {
            elapsed = Date().timeIntervalSince(startTime)
            let interval = elapsed / duration

            let nextLocation = curveInterpolation(from: startLocation, to: location, time: interval)
            let nextAzimuth = curveInterpolation(from: startAzimuth, to: azimuth, time: interval)
            let nextAltitude = curveInterpolation(from: startAltitude, to: altitude, time: interval)
            let nextPressure = curveInterpolation(from: startPressure, to: pressure, time: interval)

            try self.stylusMove(to: nextLocation, azimuth: nextAzimuth,
                                altitude: nextAltitude, pressure: nextPressure)
            try self.wait(EventGenerator.fingerMoveInterval)
        }

        try self.stylusMove(to: location, azimuth: azimuth, altitude: altitude, pressure: pressure)
    }

    // MARK: - Event

    /// Sends a stylus event.
    ///
    /// - parameter stylus: The event to send.
    private func sendEvent(stylus: StylusInfo) throws {
        try self.checkPointsAreHittable([stylus.location])

        let machTime = mach_absolute_time()
        let isTouching = stylus.phase.isTouching

        let event = IOHID.shared.createDigitizerEvent(
            kCFAllocatorDefault, machTime,
            IOHID.DigitizerTransducerType.stylus.rawValue, 0, 0,
            stylus.eventMask.rawValue,
            0, 0, 0, 0, 0, 0,
            false, isTouching,
            kIOHIDEventOptionNone)

        IOHID.shared.eventSetIntegerValue(event, IOHID.EventField.Digitizer.isDisplayIntegrated.rawValue, 1)
        IOHID.shared.eventSetSenderID(event, self.senderId)

        let identifier = try self.identifier(for: stylus)
        let subEvent = IOHID.shared.createDigitizerStylusEvent(
            kCFAllocatorDefault, machTime,
            identifier, kStylusFingerId,
            stylus.eventMask.rawValue, 0,
            stylus.location.x, stylus.location.y, 0,
            stylus.pressure * 500,
            stylus.twist, 0,
            .pi - stylus.altitude,
            .pi * 2 - stylus.azimuth,
            isTouching, false,
            isTouching ? kIOHIDTransducerTouch : kIOHIDEventOptionNone)

        IOHID.shared.eventAppendEvent(event, subEvent, 0)

        self.debugWindow.update(stylusLocation: stylus.phase.isTouching ? stylus.location : nil)

        try self.sendEvent(event, wait: true)
    }

    private func identifier(for stylus: StylusInfo) throws -> UInt32 {
        let existingIdentifier = self.activeTouches.stylusIdentifier
        switch stylus.phase {
        case .began:
            guard existingIdentifier == nil else {
                throw HammerError.touchForStylusAlreadyExists
            }

            let identifier = self.nextEventId()
            try self.activeTouches.set(stylus: stylus, forIdentifier: identifier)
            return identifier
        case .moved, .stationary:
            guard let existingIdentifier = existingIdentifier else {
                throw HammerError.touchForStylusDoesNotExist
            }

            return existingIdentifier
        case .ended, .cancelled:
            guard let existingIdentifier = existingIdentifier else {
                throw HammerError.touchForStylusDoesNotExist
            }

            self.activeTouches.remove(forIdentifier: existingIdentifier)
            return existingIdentifier
        case .regionEntered, .regionMoved, .regionExited:
            throw HammerError.unsupportedTouchPhase(stylus.phase)
        @unknown default:
            throw HammerError.unsupportedTouchPhase(stylus.phase)
        }
    }
}
