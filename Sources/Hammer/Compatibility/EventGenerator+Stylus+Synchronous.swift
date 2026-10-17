import CoreGraphics
import Foundation

// Synchronous versions of the async API, for tests that are not async.
extension EventGenerator {
    public func stylusDown(at location: HammerLocatable? = nil,
                           azimuth: CGFloat = 0, altitude: CGFloat = 0, pressure: CGFloat = 0) throws
    {
        try self.runSynchronously {
            try await self.stylusDown(at: location, azimuth: azimuth, altitude: altitude, pressure: pressure)
        }
    }

    public func stylusUp() throws {
        try self.runSynchronously { try await self.stylusUp() }
    }

    public func stylusTap(at location: HammerLocatable? = nil, numberOfTimes tapCount: Int,
                          interval: TimeInterval = EventGenerator.multiTapInterval,
                          azimuth: CGFloat = 0, altitude: CGFloat = 0, pressure: CGFloat = 0) throws
    {
        try self.runSynchronously {
            try await self.stylusTap(at: location, numberOfTimes: tapCount, interval: interval,
                                     azimuth: azimuth, altitude: altitude, pressure: pressure)
        }
    }

    public func stylusTap(at location: HammerLocatable? = nil,
                          azimuth: CGFloat = 0, altitude: CGFloat = 0, pressure: CGFloat = 0) throws
    {
        try self.runSynchronously {
            try await self.stylusTap(at: location, azimuth: azimuth, altitude: altitude, pressure: pressure)
        }
    }

    public func stylusDoubleTap(at location: HammerLocatable? = nil,
                                azimuth: CGFloat = 0, altitude: CGFloat = 0, pressure: CGFloat = 0) throws
    {
        try self.runSynchronously {
            try await self.stylusDoubleTap(at: location, azimuth: azimuth, altitude: altitude,
                                           pressure: pressure)
        }
    }

    public func stylusLongPress(at location: HammerLocatable? = nil,
                                azimuth: CGFloat = 0, altitude: CGFloat = 0, pressure: CGFloat = 0,
                                duration: TimeInterval = EventGenerator.longPressHoldDelay) throws
    {
        try self.runSynchronously {
            try await self.stylusLongPress(at: location, azimuth: azimuth, altitude: altitude,
                                           pressure: pressure, duration: duration)
        }
    }

    public func stylusMove(to location: HammerLocatable,
                           azimuth: CGFloat = 0, altitude: CGFloat = 0, pressure: CGFloat = 0) throws
    {
        try self.runSynchronously {
            try await self.stylusMove(to: location, azimuth: azimuth, altitude: altitude, pressure: pressure)
        }
    }

    public func stylusMove(to location: HammerLocatable,
                           azimuth: CGFloat = 0, altitude: CGFloat = 0, pressure: CGFloat = 0,
                           duration: TimeInterval) throws
    {
        try self.runSynchronously {
            try await self.stylusMove(to: location, azimuth: azimuth, altitude: altitude, pressure: pressure,
                                      duration: duration)
        }
    }
}
