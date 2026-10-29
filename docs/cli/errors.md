# Errors

A failed command prints one JSON object to standard error:

```json
{
  "error": "Unable to find element: identifier \"sign_in\"",
  "code": "not_found",
  "hint": "Call describe to see the elements on screen, or wait_for the element if it is still appearing"
}
```

- `error` says what went wrong.
- `code` is a stable name for the kind of error, for scripts to match.
- `hint` says how to fix the call. Follow it instead of retrying the same command.

## Codes

| Code | Meaning |
| --- | --- |
| `invalid_arguments` | The arguments are missing, of the wrong type, or don't make sense together. |
| `unknown_command` | The app has no command with that name. |
| `invalid_request` | The agent refused the request, such as one without its token. |
| `not_found` | No element or view matches the target. |
| `ambiguous_target` | Several elements match the target. |
| `not_visible` | The element is hidden, off screen or no longer on screen. |
| `not_hittable` | Something covers the element, or it ignores touches. |
| `not_ready` | The app is busy, still presenting, or another window has the keyboard focus. |
| `timed_out` | A wait ran out of time, or the app did not respond in time. |
| `unreachable` | No agent listens on the port. The app is not running or hasn't started the agent. |
| `disconnected` | The app closed the connection before responding. |
| `no_simulator` | `--system` found no booted simulator, or several and none was picked, or Xcode can't drive it. |
| `failed` | Anything else. |

Custom commands can report codes of their own.

## Exit codes

- `0`: the command succeeded.
- `1`: the command failed.
- `2`: the call itself is invalid, such as an unknown command or argument. Run `hammer help <command>`.

A command that fails with `timed_out` or `disconnected` may still have run, so check the app's state before running it again.
