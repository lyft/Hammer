# Custom commands

Apps can add their own commands, such as signing in as a test user or jumping to a screen. They appear in `hammer commands`, run like the built-in ones and show up as MCP tools.

```swift
struct SignInCommand: AgentCommand {
    struct Arguments: Decodable {
        let user: String
    }

    let descriptor = CommandDescriptor(
        name: "sign_in",
        summary: "Signs in as a test user.",
        parameters: [.init("user", .string, "The user name.", isRequired: true)],
        examples: [.init("Sign in as the default user", ["user": "test"])]
    )

    func run(_ arguments: Arguments, in context: AgentContext) async throws -> NoOutput {
        try await TestSession.signIn(as: arguments.user)
        return NoOutput()
    }
}

agent.register(SignInCommand())
```

```bash
hammer sign-in --user test
```

- **Names:** use snake case. The tool shows them in kebab case, so `sign_in` becomes `hammer sign-in`.
- **Parameters:** must match the keys `Arguments` decodes. The agent checks arguments against them before running the command. `output` and `port` are reserved for the tool's own options.
- **Output:** any `Encodable` value, returned as JSON. Return `NoOutput()` when there is nothing to report.
- **Events:** `context.eventGenerator()` returns an event generator for the key window, to send touches and keys like the built-in commands.
- **Errors:** throw `AgentError` with a message and a hint on how to fix the call. Give errors clients may handle a code of their own:

```swift
throw AgentError.failed("No user \(user)", hint: "Use one of: test, admin", code: "unknown_user")
```

Registering a command with the name of an existing one replaces it.
