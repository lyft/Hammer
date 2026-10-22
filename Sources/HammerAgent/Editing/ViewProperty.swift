import HammerAgentCore
import UIKit

/// A property of a view that clients can read with `inspect` and change with `set_property`.
@MainActor
struct ViewProperty {
    /// The name clients use, the same as the UIKit property when there is one.
    let name: String

    /// What the property does.
    let summary: String

    /// The name of the value type, such as `color`.
    let typeName: String

    /// The JSON the property expects.
    let expectation: String

    private let applies: @MainActor (UIView) -> Bool
    private let get: @MainActor (UIView) -> JSONValue
    private let set: (@MainActor (UIView, JSONValue) -> (@MainActor () -> Void)?)?

    /// Creates a property that reads and writes the value with closures.
    ///
    /// - parameter name:    The name clients use.
    /// - parameter codec:   Converts the value to and from JSON.
    /// - parameter summary: What the property does.
    /// - parameter get:     Reads the value.
    /// - parameter set:     Writes the value, or nil if the property is read only.
    init<View: UIView, Value>(_ name: String, _ codec: ValueCodec<Value>, _ summary: String,
                              get: @escaping @MainActor (View) -> Value,
                              set: (@MainActor (View, Value) -> Void)? = nil)
    {
        self.name = name
        self.summary = summary
        self.typeName = codec.typeName
        self.expectation = codec.expectation
        self.applies = { $0 is View }
        self.get = { view in (view as? View).map { codec.encode(get($0), $0) } ?? .null }
        guard let set else {
            self.set = nil
            return
        }

        self.set = { (view: UIView, json: JSONValue) -> (@MainActor () -> Void)? in
            guard let view = view as? View, let value = codec.decode(json) else {
                return nil
            }

            let original = get(view)
            set(view, value)
            return { [weak view] in
                if let view {
                    set(view, original)
                }
            }
        }
    }

    /// Creates a property for a key path the client can change.
    ///
    /// - parameter name:    The name clients use.
    /// - parameter keyPath: The key path of the value.
    /// - parameter codec:   Converts the value to and from JSON.
    /// - parameter summary: What the property does.
    init<View: UIView, Value>(_ name: String, _ keyPath: ReferenceWritableKeyPath<View, Value>,
                              _ codec: ValueCodec<Value>, _ summary: String)
    {
        self.init(name, codec, summary, get: { (view: View) in view[keyPath: keyPath] },
                  set: { (view: View, value: Value) in view[keyPath: keyPath] = value })
    }

    /// Creates a property for a key path the client can only read.
    ///
    /// - parameter name:    The name clients use.
    /// - parameter keyPath: The key path of the value.
    /// - parameter codec:   Converts the value to JSON.
    /// - parameter summary: What the property does.
    init<View: UIView, Value>(_ name: String, readOnly keyPath: KeyPath<View, Value>,
                              _ codec: ValueCodec<Value>, _ summary: String)
    {
        self.init(name, codec, summary, get: { (view: View) in view[keyPath: keyPath] })
    }

    /// If clients can change the property.
    var isSettable: Bool {
        return self.set != nil
    }

    /// If the property exists on the view, such as `text` on a label.
    ///
    /// - parameter view: The view.
    ///
    /// - returns: If it applies.
    func applies(to view: UIView) -> Bool {
        return self.applies(view)
    }

    /// Returns the property's value.
    ///
    /// - parameter view: The view to read.
    ///
    /// - returns: The value as JSON.
    func value(of view: UIView) -> JSONValue {
        return self.get(view)
    }

    /// Sets the property's value.
    ///
    /// - parameter value: The value as JSON.
    /// - parameter view:  The view to change.
    ///
    /// - throws: An error if the property is read only or the value does not have its type.
    ///
    /// - returns: A closure that restores the original value.
    func setValue(_ value: JSONValue, of view: UIView) throws -> @MainActor () -> Void {
        guard let set = self.set else {
            throw AgentError.invalidArguments("The property \(self.name) can't be changed",
                                              hint: "Change the properties that inspect lists as settable")
        }

        guard let undo = set(view, value) else {
            throw AgentError.invalidArguments(
                "Invalid value \(value.compactDescription) for \(self.name), expected \(self.expectation)",
                hint: #"Pass it like --value '#FF0000', --value 0.5 or --value '{"x": 0, "y": 0}'"#)
        }

        return undo
    }
}
