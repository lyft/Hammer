import HammerAgentCore
import UIKit

/// Converts the values of a property type to and from JSON, and describes the JSON it expects.
@MainActor
struct ValueCodec<Value> {
    /// The name of the type, such as `color`, shown next to each property.
    let typeName: String

    /// The JSON the type expects, to explain an invalid value.
    let expectation: String

    /// Converts a value of the property of the view to JSON.
    let encode: @MainActor (Value, UIView) -> JSONValue

    /// Converts JSON to a value, or nil if it is not one.
    let decode: @MainActor (JSONValue) -> Value?
}

extension ValueCodec where Value == CGFloat {
    static let number = ValueCodec(typeName: "number", expectation: "a number, such as 0.5",
                                   encode: { value, _ in .number(Double(value).roundedForOutput) },
                                   decode: { $0.number.map { CGFloat($0) } })
}

extension ValueCodec where Value == Int {
    static let integer = ValueCodec(typeName: "integer", expectation: "an integer, such as 2",
                                    encode: { value, _ in .number(Double(value)) },
                                    decode: { $0.number.flatMap { $0.rounded() == $0 ? Int($0) : nil } })
}

extension ValueCodec where Value == Bool {
    static let boolean = ValueCodec(typeName: "boolean", expectation: "true or false",
                                    encode: { value, _ in .bool(value) },
                                    decode: { if case .bool(let bool) = $0 { bool } else { nil } })
}

extension ValueCodec where Value == String? {
    static let string = ValueCodec(typeName: "string", expectation: "a string, or null",
                                   encode: { value, _ in value.map(JSONValue.string) ?? .null },
                                   decode: { value in
                                       switch value {
                                       case .string(let string):
                                           return .some(string)
                                       case .null:
                                           return .some(nil)
                                       default:
                                           return nil
                                       }
                                   })
}

extension ValueCodec where Value == UIColor? {
    static let color = ValueCodec(
        typeName: "color",
        expectation: """
            a color: a hex string such as "#3366FF" or "#3366FF80" with alpha, a name such as \
            "systemBlue", "label", "red" or "clear", an object such as {"red": 0.2, "green": 0.4, \
            "blue": 1, "alpha": 1}, or null for no color
            """,
        encode: { value, view in
            value.map { .string($0.resolvedColor(with: view.traitCollection).hexString) } ?? .null
        },
        decode: { value in
            switch value {
            case .null:
                return .some(nil)
            case .string(let string):
                guard let color = UIColor(hexString: string) ?? UIColor.named[string] else {
                    return nil
                }

                return .some(color)
            case .object(let object):
                guard let red = object["red"]?.number, let green = object["green"]?.number,
                      let blue = object["blue"]?.number
                else {
                    return nil
                }

                return UIColor(red: red, green: green, blue: blue, alpha: object["alpha"]?.number ?? 1)
            default:
                return nil
            }
        })
}

extension ValueCodec where Value == CGPoint {
    static let point = ValueCodec.object(typeName: "point", keys: ["x", "y"],
                                         make: { CGPoint(x: $0[0], y: $0[1]) },
                                         values: { [$0.x, $0.y] })
}

extension ValueCodec where Value == CGSize {
    static let size = ValueCodec.object(typeName: "size", keys: ["width", "height"],
                                        make: { CGSize(width: $0[0], height: $0[1]) },
                                        values: { [$0.width, $0.height] })
}

extension ValueCodec where Value == CGRect {
    static let rect = ValueCodec.object(typeName: "rect", keys: ["x", "y", "width", "height"],
                                        make: { CGRect(x: $0[0], y: $0[1], width: $0[2], height: $0[3]) },
                                        values: { [$0.minX, $0.minY, $0.width, $0.height] })
}

extension ValueCodec where Value == UIEdgeInsets {
    static let insets = ValueCodec.object(typeName: "insets", keys: ["top", "left", "bottom", "right"],
                                          make: { UIEdgeInsets(top: $0[0], left: $0[1], bottom: $0[2],
                                                               right: $0[3]) },
                                          values: { [$0.top, $0.left, $0.bottom, $0.right] })
}

extension ValueCodec where Value: Equatable {
    /// A codec for an enumeration, with the names clients use for its cases.
    ///
    /// - parameter typeName: The name of the type.
    /// - parameter cases:    The name of each case.
    ///
    /// - returns: The codec.
    static func choice(_ typeName: String, _ cases: [(String, Value)]) -> ValueCodec {
        let names = cases.map(\.0)
        return ValueCodec(typeName: typeName,
                          expectation: "one of " + names.map { "\"\($0)\"" }.joined(separator: ", "),
                          encode: { value, _ in
                              cases.first { $0.1 == value }.map { .string($0.0) } ?? .null
                          },
                          decode: { value in
                              guard case .string(let name) = value else {
                                  return nil
                              }

                              return cases.first { $0.0 == name }?.1
                          })
    }
}

extension ValueCodec {
    /// A codec for a value made of numbers, encoded as an object with a key for each one.
    fileprivate static func object(typeName: String, keys: [String], make: @escaping ([CGFloat]) -> Value,
                                   values: @escaping (Value) -> [CGFloat]) -> ValueCodec
    {
        let example = keys.enumerated().map { "\"\($0.element)\": \($0.offset * 10)" }.joined(separator: ", ")
        return ValueCodec(typeName: typeName, expectation: "an object such as {\(example)}",
                          encode: { value, _ in
                              let pairs = zip(keys, values(value)).map {
                                  ($0, JSONValue.number(Double($1).roundedForOutput))
                              }
                              return .object(Dictionary(uniqueKeysWithValues: pairs))
                          },
                          decode: { value in
                              guard case .object(let object) = value, object.count == keys.count else {
                                  return nil
                              }

                              let numbers = keys.compactMap { object[$0]?.number.map { CGFloat($0) } }
                              return numbers.count == keys.count ? make(numbers) : nil
                          })
    }
}

extension JSONValue {
    fileprivate var number: Double? {
        guard case .number(let number) = self else {
            return nil
        }

        return number
    }
}

extension Double {
    /// The value rounded to a hundredth, so outputs don't show floating point noise.
    var roundedForOutput: Double {
        return (self * 100).rounded() / 100
    }
}

extension UIColor {
    /// The colors clients can pass by name.
    static let named: [String: UIColor] = [
        "black": .black, "white": .white, "clear": .clear, "gray": .gray, "red": .red, "green": .green,
        "blue": .blue, "yellow": .yellow, "orange": .orange, "purple": .purple, "brown": .brown,
        "cyan": .cyan, "magenta": .magenta,
        "systemRed": .systemRed, "systemOrange": .systemOrange, "systemYellow": .systemYellow,
        "systemGreen": .systemGreen, "systemMint": .systemMint, "systemTeal": .systemTeal,
        "systemCyan": .systemCyan, "systemBlue": .systemBlue, "systemIndigo": .systemIndigo,
        "systemPurple": .systemPurple, "systemPink": .systemPink, "systemBrown": .systemBrown,
        "systemGray": .systemGray, "systemGray2": .systemGray2, "systemGray3": .systemGray3,
        "systemGray4": .systemGray4, "systemGray5": .systemGray5, "systemGray6": .systemGray6,
        "label": .label, "secondaryLabel": .secondaryLabel, "tertiaryLabel": .tertiaryLabel,
        "quaternaryLabel": .quaternaryLabel, "link": .link, "placeholderText": .placeholderText,
        "separator": .separator, "opaqueSeparator": .opaqueSeparator,
        "systemBackground": .systemBackground, "secondarySystemBackground": .secondarySystemBackground,
        "tertiarySystemBackground": .tertiarySystemBackground,
        "systemGroupedBackground": .systemGroupedBackground,
        "secondarySystemGroupedBackground": .secondarySystemGroupedBackground,
        "tertiarySystemGroupedBackground": .tertiarySystemGroupedBackground,
        "systemFill": .systemFill, "secondarySystemFill": .secondarySystemFill,
        "tertiarySystemFill": .tertiarySystemFill, "quaternarySystemFill": .quaternarySystemFill,
    ]

    /// Creates a color from `#RRGGBB` or `#RRGGBBAA`.
    ///
    /// - parameter hexString: The hex string.
    convenience init?(hexString: String) {
        let digits = hexString.hasPrefix("#") ? String(hexString.dropFirst()) : ""
        guard digits.count == 6 || digits.count == 8, let value = UInt64(digits, radix: 16) else {
            return nil
        }

        let rgba = digits.count == 6 ? value << 8 | 0xFF : value
        self.init(red: CGFloat(rgba >> 24 & 0xFF) / 255, green: CGFloat(rgba >> 16 & 0xFF) / 255,
                  blue: CGFloat(rgba >> 8 & 0xFF) / 255, alpha: CGFloat(rgba & 0xFF) / 255)
    }

    /// The color as `#RRGGBB`, or `#RRGGBBAA` when it is not opaque.
    var hexString: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let components = alpha < 1 ? [red, green, blue, alpha] : [red, green, blue]
        let bytes = components.map { Int((min(max($0, 0), 1) * 255).rounded()) }
        return "#" + bytes.map { String(format: "%02X", $0) }.joined()
    }
}
