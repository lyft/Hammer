import Foundation

/// Tells whether a system alert, such as a permission prompt, is over the app.
///
/// From iOS 27, a permission alert that appears while the app is active leaves the app's scene foreground
/// active, so the activation state doesn't show it. FrontBoard still stops the scene from showing alerts of
/// its own while one is up, and that private setting is the only change the app can see.
enum SystemAlerts {
    /// Returns whether a system alert is over the scene.
    ///
    /// - parameter scene: The scene, or an object with the same private accessors.
    ///
    /// - returns: True if FrontBoard says the scene can't show alerts, false if it can or doesn't say.
    static func isShowing(over scene: NSObject) -> Bool {
        guard let frontBoardScene = scene.privateObject(named: "_FBSScene"),
              let settings = frontBoardScene.privateObject(named: "settings"),
              settings.responds(to: NSSelectorFromString("canShowAlerts"))
        else {
            return false
        }

        return (settings.value(forKey: "canShowAlerts") as? Bool) == false
    }
}

extension NSObject {
    fileprivate func privateObject(named name: String) -> NSObject? {
        let selector = NSSelectorFromString(name)
        guard self.responds(to: selector) else {
            return nil
        }

        return self.perform(selector)?.takeUnretainedValue() as? NSObject
    }
}
