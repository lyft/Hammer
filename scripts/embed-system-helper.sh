#!/bin/bash
# Embeds the Android system helper APK in the hammer tool's source, so the built tool installs it on devices.
# Usage: scripts/embed-system-helper.sh <hammer-system.apk>
set -euo pipefail

apk="${1:?Usage: $0 <hammer-system.apk>}"
source_file="$(dirname "$0")/../Sources/HammerCLI/Drivers/Android/SystemHelperAPK.swift"

{
    echo "// The system helper's APK, base64 encoded, embedded by scripts/embed-system-helper.sh."
    echo "enum SystemHelperAPK {"
    echo "    // swiftlint:disable:next line_length"
    printf '    static let base64 = "%s"\n' "$(base64 < "$apk" | tr -d '\n')"
    echo "}"
} > "$source_file"
