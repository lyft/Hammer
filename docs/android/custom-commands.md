# Custom commands on Android

Apps can add their own commands, such as signing in as a test user or jumping to a screen. They appear in `hammer commands --android`, run like the built-in ones and show up as MCP tools.

```kotlin
class SignInCommand : AgentCommand {
    override val descriptor = CommandDescriptor(
        name = "sign_in",
        summary = "Signs in as a test user.",
        parameters = listOf(
            CommandDescriptor.Parameter("user", CommandDescriptor.ParameterType.StringValue, "The user name.", isRequired = true),
        ),
        examples = listOf(CommandDescriptor.Example("Sign in as the default user", mapOf("user" to JsonValue.String("test")))),
    )

    override suspend fun run(arguments: JsonValue.Object, context: AgentContext): JsonValue {
        // The agent already checked that user is a string
        TestSession.signIn(arguments["user"]?.stringValue.orEmpty())
        return JsonValue.Object()
    }
}
```

```bash
hammer sign-in --android --user test
```

## Registering commands

The agent starts before your `Application.onCreate`, so it finds your commands through a registrar that the debug manifest names. Put both in `src/debug`, since release builds don't contain the agent:

```kotlin
// src/debug/kotlin/com/example/app/DebugCommands.kt
class DebugCommands : HammerCommandRegistrar {
    override fun commands(context: Context): List<AgentCommand> = listOf(SignInCommand())
}
```

```xml
<!-- src/debug/AndroidManifest.xml -->
<application>
    <meta-data
        android:name="com.lyft.hammer.agent.commands:com.example.app.DebugCommands"
        android:value="com.lyft.hammer.agent.HammerCommandRegistrar" />
</application>
```

The class goes in the key, so several registrars can join, such as one from a library. The agent creates each through its constructor without arguments, in key order, and registers its commands before it starts listening, so the first `hammer commands --android` lists them. The library keeps registrars' constructors when the build is minified.

A registrar that can't be created or that throws, or a command that uses a reserved parameter name, is logged with the class and the problem and skipped; the agent starts with the other commands.

### Commands that need dependency injection

A registrar only gets the application `Context`. For commands built from your app's dependency graph, [start the agent yourself](getting-started.md#starting-it-yourself) and call `register`. `register` works at any time, even while the agent serves requests, and fails fast with `IllegalArgumentException` on a reserved parameter name. The manifest's registrars still join when you start it; pass `HammerAgent(application, readsManifestRegistrars = false)` to leave them out.

## Writing a command

- **Names:** use snake case. The tool shows them in kebab case, so `sign_in` becomes `hammer sign-in`.
- **Parameters:** the agent checks arguments against them before running the command, so `run` only sees arguments the descriptor allows. `output`, `port`, `system`, `udid`, `android`, `serial` and `app_id` are reserved for the tool's own options (`CommandDescriptor.reservedParameterNames`).
- **Arguments and output:** `JsonValue`, the same shape as Hammer's `JSONValue`. Return `JsonValue.Object()` when there is nothing to report.
- **Threading:** commands run one at a time, on the main thread, so they can touch views directly. `run` is a `suspend` function, so switch dispatchers for slow work.
- **Context:** `context.foregroundActivity` is the activity in front, `context.ref(view)` the ref `describe` gives a view, and `context.view(ref)` the view a ref points to.
- **Errors:** throw `AgentError` with a message and a hint on how to fix the call. Give errors clients may handle a code of their own:

```kotlin
throw AgentError("No user $user", code = "unknown_user", hint = "Use one of: test, admin")
```

`AgentErrorCode.INVALID_ARGUMENTS` answers with HTTP status 400, any other code with 500. Any other exception fails with the code `failed` and its message.

## Commands with the same name

A command replaces one with the same name and keeps its place in the list. The app's own `register` always wins, then registrars, then the built-in commands:

- `register` replaces any command, whenever it's called.
- A registrar's command replaces a built-in one, or one from a registrar earlier in key order, and the agent logs it. It never replaces a command the app registered, even one registered before `start()`; the agent logs that it skipped it.
