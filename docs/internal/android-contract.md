# The Android agent's contract files

The Android agent in `android/` is written in Kotlin, and the `hammer` tool and the iOS agent in Swift. Both
sides describe the same built-in commands, reserved parameter names and error codes, so Swift writes them to
`android/contract/` and the Kotlin tests check the agent against them:

| File | Swift source | Kotlin check |
| --- | --- | --- |
| `builtin-commands.json` | `BuiltinCommands.all(for: .android)` | `BuiltinCommands.all` |
| `reserved-parameter-names.json` | `CommandDescriptor.reservedParameterNames(for: .android)` | `CommandDescriptor.reservedParameterNames` |
| `error-codes.json` | `AgentErrorCode.agentCodes` | `AgentErrorCode`'s constants |

`AndroidContractTests` in `HammerCLITests` fails when a file no longer matches the Swift side, and `ContractTest`
in `android/hammer-agent` fails when the agent no longer matches a file. So a change on one side fails CI until
the other side catches up.

The Kotlin test reads the files as JSON, so key order doesn't matter, and a missing `parameters` or `examples`
counts as empty, as [the HTTP API](http-api.md) says.

## After changing the Swift side

Regenerate the files, then change the agent to match and commit both:

```sh
HAMMER_UPDATE_CONTRACT=1 swift test --filter AndroidContractTests
cd android && ./gradlew :hammer-agent:testDebugUnitTest --tests '*ContractTest'
```

## Adding an error code

`AgentErrorCode` can't list its own codes, so a new `static let` also goes in `AgentErrorCode.agentCodes`, if
agents report it, or in `AgentErrorCode.clientCodes`, if only clients do. A test fails until it's in one of them.
