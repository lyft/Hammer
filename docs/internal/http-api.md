# Agent HTTP API

The wire contract between `HammerAgent` and its clients: the `hammer` tool and its MCP server. It is for developing Hammer itself. Outside tools should use the [command line tool](../cli/getting-started.md), which is the supported interface.

The routes, environment variables and shared bodies are defined in [AgentWire.swift](../../Sources/HammerAgentCore/AgentWire.swift), and descriptors in [CommandDescriptor.swift](../../Sources/HammerAgentCore/CommandDescriptor.swift). Both live in `HammerAgentCore`, which the agent and the tool share, so keep this page in sync when changing them. [Built-in commands](commands.md) covers what each command does.

## Transport

- HTTP/1.1 over TCP, one request per connection (`Connection: close`).
- Port 9876, or `HAMMER_AGENT_PORT` for both sides. `HammerAgent(port: 0)` picks a free one.
- Bound to the loopback interface, or to every interface with `allowsRemoteConnections`.
- Requests up to 16 MB.
- Commands run one at a time, in the order they arrive, so gestures never interleave.
- Every response is `Content-Type: application/json`.

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
- `output` and `port` are reserved parameter names, for the tool's own options. Registering a command that uses them is a precondition failure.

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

`unreachable` and `disconnected` never come from the agent. The tool reports them when it can't connect or the connection closes before a response.

## Refs and live changes

- Refs such as `e12` (views and elements) and `c4` (constraints) are assigned by the agent and stay the same while their object is alive. Objects are held weakly, so a ref stops resolving once its object is released.
- Changes from `set_property`, `set_constraint` and `add_constraint` are recorded with their original values until `revert`. They live in the agent's memory, so relaunching the app drops them.

## Compatibility

The API has no version number yet. Until it does:

- Add fields rather than renaming or removing them, and make new fields optional for clients.
- New parameter types are safe, since clients treat unknown ones as `json`.
- The tool falls back to the built-in descriptors it was built with when no agent is running, so `hammer help` works offline. Those can differ from an older or newer agent's.
