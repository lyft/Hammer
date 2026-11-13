# Adding the agent to an Android app

The Hammer agent runs inside your app and lets the [`hammer` command line tool](../cli/android.md), its MCP server and scripts drive it with `--android`. Because it runs in the app, it finds Views and Jetpack Compose elements by resource id, test tag, content description, text or state, and waits for the app's main thread to be idle. It can't reach system UI such as permission dialogs or the home screen; `hammer --system --android` does that through adb.

⚠️ IMPORTANT: Anything that can run adb commands on the device can control an app that runs the agent. Only add it to debug builds.

## Setup

Add the agent to your app's debug builds:

```kotlin
dependencies {
    debugImplementation("com.lyft.hammer:hammer-agent-android:<version>")
}
```

`<version>` is the Hammer release, the same as the `hammer` tool's. Each [release](https://github.com/lyft/Hammer/releases) attaches `hammer-agent-android-<version>.aar` and its `.pom`; publish both to a Maven repository your build reads from, so Gradle also resolves the agent's dependencies. That's all: the library's manifest adds a `ContentProvider` that starts the agent when a debuggable build launches, before `Application.onCreate`. The app needs no permission, no code and no `Application` subclass. Logcat shows where it listens:

```
I Hammer  : Hammer agent listening on @hammer_com.example.app, adb and this app can control it
```

Then drive the app from your Mac:

```bash
hammer describe --android
hammer tap --android --label "Sign in"
```

The agent requires Android 9 (API 28) or later, and the app to compile with `compileSdk` 34 or later. It works with Views, Jetpack Compose or both.

Its dependencies are the oldest versions it works with, so it doesn't change the versions the debug build resolves, and debug and release run the same libraries:

| Library | Version | |
| --- | --- | --- |
| kotlinx-coroutines | 1.6.4 or later | |
| Compose UI | 1.4 or later | Optional: used when the app has it, never added |
| AndroidX `activity` | 1.5 or later | Optional: used when the app has it, for back in dialogs |

## Starting it yourself

To start the agent from your own code, such as to register commands that need your app's dependency injection, turn auto-start off in the debug manifest, `src/debug/AndroidManifest.xml`:

```xml
<application>
    <meta-data
        android:name="com.lyft.hammer.agent.autostart"
        android:value="false" />
</application>
```

Then create the agent in `Application.onCreate`, from debug code, register your commands and start it:

```kotlin
val agent = HammerAgent(application)
agent.register(SignInCommand(session))
agent.start()
```

Create it there, before the first activity starts: the agent learns about activities from their lifecycle callbacks, so one created later doesn't see the activity already on screen until it resumes again. Keep a reference to `agent` for as long as the app runs. `start()` throws `AgentStartError` when the app isn't debuggable or something else holds the agent's socket: another process, or the auto-started agent when auto-start is still on. Auto-start only logs these, and never throws.

## The socket

The agent has no port. It listens on the abstract socket `hammer_<applicationId>`, so several apps can run an agent at once, and `hammer` reaches it through `adb forward`. Pass `--app-id` to pick one app when several run an agent. Only the app's main process runs the agent; in another process, `start()` logs why and does nothing.

## Release builds

With `debugImplementation`, release builds don't contain the agent, so nothing starts and nothing listens. Keep code that uses it, such as [custom commands](custom-commands.md), in `src/debug` too, or the release build won't compile.

## How it works

- Apps can't hold the permission to inject events into the input system, so the agent dispatches touches and keys to the window's root view on the main thread, the way Compose UI tests send them. A touch goes to the window the input system would pick: windows that aren't touchable, such as a toast, are skipped, and a modal window, such as a dialog, also takes the touches outside it, so a tap there cancels the dialog rather than reaching the screen behind it. `describe` calls the elements behind a modal window not hittable.
- A gesture that fails or is cancelled after a finger went down sends `ACTION_CANCEL`, so the view doesn't stay pressed.
- `pinch` sends two fingers as one multi-touch gesture to the window the first one lands in, with pointer ids 0 and 1.
- `deviceBack` calls the activity's `onBackPressed`, which runs the app's own back handling, a dialog's `OnBackPressedDispatcher`, such as a `ComponentDialog`'s or a Compose dialog's, or a plain `Dialog`'s `onBackPressed`. Callbacks the app registers with the platform's `OnBackInvokedDispatcher` directly only run for the system's back: `hammer press-key --key deviceBack --system`.
- `type_text` commits the text through the focused field's input connection, as a keyboard app does, so it types any characters, and presses enter for each line break. It fails with `not_found` when no text field has focus.
- `wait_for_idle` also waits while Compose has pending work, and while an Espresso idling resource the app registers is busy. Windows that open during the wait count too. Work that ends later, such as a network response, needs `wait_for`.
- Views that Compose hosts, such as a map in an `AndroidView`, are placed in the Compose tree where they are drawn.
- A Compose `clickable` without `onLongClick` handles a long press as a tap.
- A `SurfaceView`'s own surface, such as a map's, shows as blank in screenshots. `screenshot --system` captures it.
- On Android 9 (API 28), the agent reads the app's windows from `WindowManagerGlobal` by reflection, as Espresso does, since Android 9 has no public API for them, and falls back to the resumed activity's window. From Android 10 it uses `WindowInspector`.

## Next steps

- [Security](security.md): who can connect, release builds and physical devices.
- [Custom commands](custom-commands.md): add commands for your app, such as signing in.
- [Android](../cli/android.md): driving the app with `hammer --android`.
