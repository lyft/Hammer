// The system helper's APK, base64 encoded. Release.yml fills it in with scripts/embed-system-helper.sh
// before it builds the tool. A tool built without it runs the whole screen through uiautomator, unless
// HAMMER_SYSTEM_HELPER_APK names an APK.
enum SystemHelperAPK {
    static let base64 = ""
}
