/// The distances between a pinch's two fingers, so every agent pinches the same way for the same arguments.
public enum PinchDistances {
    /// The distances at the start and the end. The fingers are `distance` apart where they're farthest, so a
    /// pinch stays the same size whichever way it goes.
    ///
    /// - parameter scale:    The end distance divided by the start one. It must be above 0 and other than 1.
    /// - parameter distance: The distance where the fingers are farthest apart. It must be above 0.
    public static func of(scale: Double, distance: Double) -> (start: Double, end: Double) {
        return scale > 1 ? (distance / scale, distance) : (distance, distance * scale)
    }

    /// Why the arguments can't pinch, as an error message and a hint, or nil when they can.
    public static func problem(scale: Double, distance: Double) -> (message: String, hint: String)? {
        if !(scale > 0) || scale == 1 {
            return ("Invalid scale \(scale), expected above 0 and other than 1",
                    "Use a scale above 1, such as 2, to zoom in and below 1, such as 0.5, to zoom out")
        }

        if !(distance > 0) {
            return ("Invalid distance \(distance), expected above 0",
                    "Leave distance out for 200, or pass how far apart the fingers get")
        }

        return nil
    }
}
