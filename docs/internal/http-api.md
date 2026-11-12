# Agent HTTP API

The wire contract between an agent and its clients: the `hammer` tool and its MCP server. `HammerAgent` implements it on iOS, and the Android agent in `android/` (`com.lyft.hammer:hammer-agent-android`) implements it over the [Android transport](#android-transport). It is for developing Hammer and agents. Outside tools should use the [command line tool](../cli/getting-started.md), which is the supported interface.

The routes, environment variables and shared bodies are defined in [AgentWire.swift](../../Sources/HammerAgentCore/AgentWire.swift), and descriptors in [CommandDescriptor.swift](../../Sources/HammerAgentCore/CommandDescriptor.swift). Both live in `HammerAgentCore`, which the agent and the tool share, so keep this page in sync when changing them. [Built-in commands](commands.md) covers what each command does.

## Transport

- HTTP/1.1 over TCP, one request per connection (`Connection: close`).
- Port 9876, or `HAMMER_AGENT_PORT` for both sides. `HammerAgent(port: 0)` picks a free one.
- Bound to the loopback interface, or to every interface with `allowsRemoteConnections`.
- Requests up to 16 MB.
- Commands run one at a time, in the order they arrive, so gestures never interleave.
- Every response is `Content-Type: application/json`.

## Android transport

An Android agent serves the same routes, rules and errors over a local socket instead of TCP, and `hammer --android` reaches it through `adb forward`. An agent must:

- **Listen on the abstract socket `hammer_<applicationId>`**, the app's application id, such as `@hammer_com.example.app` in `/proc/net/unix`. `hammer` finds apps by these sockets.
- **Listen in one process only**, the app's main process. Other processes, such as `:remote`, must not start an agent, since they would compete for the name.
- **Accept only adb's `shell` user (uid 2000), root (uid 0) and the app's own uid**, from the connecting socket's peer credentials, and close any other connection before reading it. Any app on the device can connect to an abstract socket, so this check is what keeps other apps out; clients can't enforce it.
- **Apply the [request rules](#request-rules)**, since a browser on the Mac can reach the forwarded port.
- **Not run a request whose connection the client already closed.** Android freezes cached apps in the background, and a request sent while the app is frozen waits in the socket until it thaws. `hammer` gives up on such a call with `app_frozen` and closes the connection, so the agent must check that the connection is still open after reading a request, and again when a request that waited for another command is about to run, and drop it otherwise, rather than run a command the caller has moved on from. A readable socket with no bytes left to read, from `poll`, shows the client closed its side.
- Measure frames and points in screen dp, and describe its built-in commands with `BuiltinCommands.all(for: .android)`, so clients can describe them before the app runs.
- Reserve the parameter names in `CommandDescriptor.reservedParameterNames(for: .android)`, which adds `android`, `serial` and `app_id` to the iOS ones, since `hammer --android` takes them as its own options.

The abstract namespace is shared by every user of the device, so only one instance of an app can run an agent, such as the personal and not the work profile one.

`hammer` sends `HAMMER_AGENT_TOKEN` as on iOS. An agent may require a token as well as the peer check, and must answer a missing or wrong one with `401`. The agent in `android/` doesn't require one, since Android apps have no environment to read it from.

The agent in `android/` implements this transport. Its built-in descriptors, the reserved parameter names and the error codes are checked against Swift's in CI, see [The Android agent's contract files](android-contract.md).

## Routes

### `GET /commands`

Returns the commands the agent runs, as a JSON array of descriptors in registration order: the built-in commands, then the app's.

```json
[
  {
    "name": "tap",
    "summary": "Taps an element or a point. Elements match every identifier, label, value and traits given.",
    "parameters": [
      {"name": "ref", "type": {"type": "string"}, "summary": "The ref of the element from describe.", "isRequired": false},
      {"name": "count", "type": {"type": "integer"}, "summary": "The number of taps, 2 for a double tap. Defaults to 1.", "isRequired": false}
    ],
    "examples": [
      {"summary": "Tap an element from describe", "arguments": {"ref": "e12"}}
    ]
  }
]
```

- `name` is snake case. The tool shows it in kebab case (`type_text` is `hammer type-text`), and the MCP server uses it as the tool name.
- `parameters` and `examples` may be missing, meaning empty.
- `type.type` is one of `string`, `integer`, `number`, `boolean`, `stringList`, `choice` (with `values`, the allowed strings) or `json` (any value). Clients decode a type they don't know as `json`, so agents can add types before clients know them.
- `output`, `port`, `system`, `udid`, `android`, `serial` and `app_id` are reserved parameter names, for the tool's own options. Registering a command that uses them is a precondition failure.

### `POST /commands/<name>`

Runs a command. The body is a JSON object of arguments, or empty for none. The request must send `Content-Type: application/json`.

```http
POST /commands/tap HTTP/1.1
Host: 127.0.0.1:9876
Content-Type: application/json

{"identifier": "sign_in"}
```

Before running the command, the agent validates the arguments against its descriptor: unknown names, missing required ones and wrong types fail with `invalid_arguments`. Then the command decodes them into its `Arguments` type.

On success the response is `200` with the command's output, encoded with sorted keys. Commands without output return `{}`. Images are encoded as:

```json
{"type": "image", "mimeType": "image/png", "data": "<base64>"}
```

Clients recognize images by `"type": "image"`. The tool writes them to a file, and the MCP server returns them as image content.

## Request rules

The server checks these before routing, in order:

| Check | Status |
| --- | --- |
| The request parses and fits in 16 MB. | `400` |
| No `Origin` or `Sec-Fetch-Site` header, which browsers always send. | `403` |
| `Host` is an IP address or `localhost`, so a site can't rebind its own domain to the device. | `403` |
| `Authorization: Bearer <token>` matches, when the agent has a token. | `401` |
| A `POST` has `Content-Type: application/json`, which browsers only send after a preflight the server never allows. | `415` |

All of these fail with the code `invalid_request`. Tokens are compared in constant time.

## Errors

Every failure returns an error body:

```json
{"error": "Unable to find element: identifier \"sign_in\"", "code": "not_found", "hint": "Call describe to see the elements on screen, or wait_for the element if it is still appearing"}
```

- `error` is a message for people and agents.
- `code` is a stable snake case name. Agents before 2.2 omit it.
- `hint` is optional, and says how to fix the call.

| Status | When | Codes |
| --- | --- | --- |
| `400` | The arguments are invalid, or the request is malformed. | `invalid_arguments`, `invalid_request` |
| `401`, `403`, `415` | The request broke a [request rule](#request-rules). | `invalid_request` |
| `404` | Unknown command or route. | `unknown_command`, `invalid_request` |
| `500` | The command ran and failed. | `failed`, `not_found`, `ambiguous_target`, `not_visible`, `not_hittable`, `not_ready`, `timed_out` or a custom code |

[ErrorReport.swift](../../Sources/HammerAgent/ErrorReport.swift) maps Swift errors to these: `AgentError` keeps its code, and `HammerError` cases map to the codes above. Any other error becomes `500` with `failed`.

`unreachable` and `disconnected` never come from the agent. The tool reports them when it can't connect or the connection closes before a response. On Android it also reports `app_frozen` when a call is slow because Android froze the app in the background, as it does to cached apps soon after they leave the screen.

## Refs and live changes

- Refs such as `e12` (views and elements) and `c4` (constraints) are assigned by the agent and stay the same while their object is alive. Objects are held weakly, so a ref stops resolving once its object is released.
- Changes from `set_property`, `set_constraint` and `add_constraint` are recorded with their original values until `revert`. They live in the agent's memory, so relaunching the app drops them.

## Compatibility

The API has no version number yet. Until it does:

- Add fields rather than renaming or removing them, and make new fields optional for clients.
- New parameter types are safe, since clients treat unknown ones as `json`.
- The tool falls back to the built-in descriptors it was built with when no agent is running, so `hammer help` works offline. Those can differ from an older or newer agent's.
