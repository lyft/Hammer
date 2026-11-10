#!/bin/bash
# Drives the Compose sample with the hammer tool on a running emulator or device: describe, tap, the
# sample's custom command, and a release build that must not run the agent. Needs macOS for hammer.
# Usage: android/e2e.sh, with ANDROID_SERIAL set when several devices are attached.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
app=com.example.hammer.compose
socket=hammer_$app

step() { printf '\n== %s\n' "$*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

step "Building hammer"
(cd "$root" && swift build --product hammer >/dev/null)
bin=$(cd "$root" && swift build --product hammer --show-bin-path)
hammer() { "$bin/hammer" "$@" --android --app-id "$app"; }

launch() {
    adb shell am force-stop "$app"
    adb shell monkey -p "$app" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
}

step "Installing the debug build"
(cd "$root/android" && ./gradlew -q :sample-compose:installDebug)
launch
for _ in $(seq 1 60); do
    hammer describe >/dev/null 2>&1 && break
    sleep 0.5
done

step "hammer describe --android"
hammer describe | grep -q '"greet_button"' || fail "describe doesn't list greet_button"
echo "lists greet_button"

step "hammer tap --android --label"
hammer tap --label "Open the Compose screen" >/dev/null
hammer wait-for --identifier count_button --timeout 10 >/dev/null || fail "the Compose screen didn't open"
hammer tap --identifier count_button >/dev/null
hammer wait-for --label "Count: 1" --timeout 5 >/dev/null || fail "the tap didn't count"
hammer press-key --key deviceBack >/dev/null
hammer wait-for --identifier greet_button --condition hittable --timeout 10 >/dev/null || fail "deviceBack didn't go back"
echo "opened the Compose screen, counted a tap and went back"

step "hammer commands --android"
hammer commands | grep -q '^  show-greeting$' || fail "commands doesn't list show-greeting"
echo "lists show-greeting"

step "hammer show-greeting --android"
hammer show-greeting --name Ada | grep -q '"ref"' || fail "show_greeting returned no ref"
hammer wait-for --label "Hello, Ada" --timeout 5 >/dev/null || fail "show_greeting didn't greet"
echo "greeted Ada"

step "Installing the release build"
(cd "$root/android" && ./gradlew -q :sample-compose:uninstallDebug :sample-compose:installRelease)
launch
sleep 3
if adb shell cat /proc/net/unix | grep -q "@$socket\$"; then fail "the release build listens on @$socket"; fi
echo "no @$socket in /proc/net/unix"
(cd "$root/android" && ./gradlew -q :sample-compose:uninstallRelease)

step "Passed"
