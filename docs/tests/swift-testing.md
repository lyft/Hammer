# Swift Testing

Hammer works with [Swift Testing](https://developer.apple.com/xcode/swift-testing/) too. Tests that use it must run on the main actor, and should finish their event generators since Swift Testing has no tear down. Only the most recently created event generator that is not finished can send events, since their windows overlap, so tests that use Hammer must not run in parallel. `.serialized` covers one suite and the suites nested in it; tests in other suites still run in parallel unless parallel testing is turned off.

```swift
@MainActor
@Suite(.serialized)
struct MyViewTests {
    @Test
    func buttonTap() async throws {
        let eventGenerator = try await EventGenerator(view: myView)
        try await eventGenerator.fingerTap(at: "my_button")
        try await eventGenerator.finish()
    }
}
```
