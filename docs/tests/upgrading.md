# Upgrading from 1.x

- Make tests async and add `await`, or keep them synchronous as they are.
- Hammer now needs Swift 6, iOS 17 and the main actor.
- Waits check every frame, so `checkInterval` is gone.
- Timeouts are optional and default to `settings.waitTimeout`.

## Synchronous tests

Every async method also has a synchronous version with the same name and parameters, so tests that are not async keep working. Swift picks the synchronous version when the calling code is not async.

```swift
func testButtonTap() throws {
    let eventGenerator = try EventGenerator(view: myView)
    try eventGenerator.fingerTap(at: "my_button")
}
```

The synchronous versions keep the main run loop running while they wait, like `XCTestCase.wait(for:timeout:)`. Prefer async tests for new code.
