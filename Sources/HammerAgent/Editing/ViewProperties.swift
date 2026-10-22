import UIKit

/// The properties `inspect` shows and `set_property` changes. Add a line here to support another one.
@MainActor
enum ViewProperties {
    /// Returns the properties that exist on the view, in the order clients see them.
    ///
    /// - parameter view: The view.
    ///
    /// - returns: The properties.
    static func properties(of view: UIView) -> [ViewProperty] {
        return self.all.filter { $0.applies(to: view) }
    }

    private static let all: [ViewProperty] = view + layer + control + label + button + textField + imageView
        + stackView + scrollView + toggle

    private static let view: [ViewProperty] = [
        .init("isHidden", \UIView.isHidden, .boolean, "If the view is hidden"),
        .init("alpha", \UIView.alpha, .number, "The opacity, from 0 to 1"),
        .init("backgroundColor", \UIView.backgroundColor, .color, "The background color"),
        .init("tintColor", \UIView.tintColor, .color, "The tint color of the view and its subviews"),
        .init("frame", \UIView.frame, .rect,
              "The frame in the superview. Auto Layout replaces it on the next layout, change constraints"),
        .init("bounds", \UIView.bounds, .rect, "The bounds in the view's own coordinates"),
        .init("clipsToBounds", \UIView.clipsToBounds, .boolean, "If subviews are clipped to the bounds"),
        .init("isUserInteractionEnabled", \UIView.isUserInteractionEnabled, .boolean,
              "If the view receives touches"),
        .init("contentMode", \UIView.contentMode, .contentMode, "How the content fills the bounds"),
        .init("layoutMargins", \UIView.layoutMargins, .insets, "The layout margins"),
        .init("translatesAutoresizingMaskIntoConstraints", \UIView.translatesAutoresizingMaskIntoConstraints,
              .boolean, "If Auto Layout creates constraints from the frame"),
        .init("intrinsicContentSize", readOnly: \UIView.intrinsicContentSize, .size,
              "The natural size of the content, -1 when there is none"),
        .init("accessibilityIdentifier", \UIView.accessibilityIdentifier, .string,
              "The accessibility identifier"),
    ]

    private static let layer: [ViewProperty] = [
        .init("cornerRadius", \UIView.layer.cornerRadius, .number, "The radius of the corners"),
        .init("borderWidth", \UIView.layer.borderWidth, .number, "The width of the border"),
        .init("borderColor", .color, "The color of the border", get: { (view: UIView) in
            view.layer.borderColor.map { UIColor(cgColor: $0) }
        }, set: { view, color in
            view.layer.borderColor = color?.resolvedColor(with: view.traitCollection).cgColor
        }),
    ]

    private static let control: [ViewProperty] = [
        .init("isEnabled", \UIControl.isEnabled, .boolean, "If the control is enabled"),
        .init("isSelected", \UIControl.isSelected, .boolean, "If the control is selected"),
    ]

    private static let label: [ViewProperty] = [
        .init("text", \UILabel.text, .string, "The text"),
        .init("textColor", \UILabel.textColor, .color, "The color of the text"),
        .init("fontSize", .number, "The point size of the font", get: { (label: UILabel) in
            label.font.pointSize
        }, set: { label, size in
            label.font = label.font.withSize(size)
        }),
        .init("numberOfLines", \UILabel.numberOfLines, .integer,
              "The maximum number of lines, 0 for no limit"),
        .init("textAlignment", \UILabel.textAlignment, .textAlignment, "The alignment of the text"),
        .init("adjustsFontSizeToFitWidth", \UILabel.adjustsFontSizeToFitWidth, .boolean,
              "If the font shrinks to fit the width"),
    ]

    private static let button: [ViewProperty] = [
        .init("title", .string, "The title for the normal state", get: { (button: UIButton) in
            button.title(for: .normal)
        }, set: { button, title in
            button.setTitle(title, for: .normal)
        }),
        .init("titleColor", .color, "The title color for the normal state", get: { (button: UIButton) in
            button.titleColor(for: .normal)
        }, set: { button, color in
            button.setTitleColor(color, for: .normal)
        }),
    ]

    private static let textField: [ViewProperty] = [
        .init("text", \UITextField.text, .string, "The text"),
        .init("placeholder", \UITextField.placeholder, .string, "The placeholder"),
        .init("textColor", \UITextField.textColor, .color, "The color of the text"),
    ]

    private static let imageView: [ViewProperty] = [
        .init("imageSize", readOnly: \UIImageView.image?.size, .optionalSize, "The size of the image"),
    ]

    private static let stackView: [ViewProperty] = [
        .init("axis", \UIStackView.axis, .axis, "The direction of the arrangement"),
        .init("spacing", \UIStackView.spacing, .number, "The space between arranged views"),
        .init("alignment", \UIStackView.alignment, .stackAlignment, "The alignment across the axis"),
        .init("distribution", \UIStackView.distribution, .stackDistribution,
              "How arranged views fill the axis"),
        .init("isLayoutMarginsRelativeArrangement", \UIStackView.isLayoutMarginsRelativeArrangement, .boolean,
              "If arranged views are inside the layout margins"),
    ]

    private static let scrollView: [ViewProperty] = [
        .init("contentOffset", \UIScrollView.contentOffset, .point, "The scroll position"),
        .init("contentSize", \UIScrollView.contentSize, .size, "The size of the scrollable content"),
        .init("contentInset", \UIScrollView.contentInset, .insets, "The space around the content"),
        .init("isScrollEnabled", \UIScrollView.isScrollEnabled, .boolean, "If the view scrolls"),
    ]

    private static let toggle: [ViewProperty] = [
        .init("isOn", \UISwitch.isOn, .boolean, "If the switch is on"),
        .init("onTintColor", \UISwitch.onTintColor, .color, "The color when on"),
    ]
}

extension ValueCodec where Value == CGSize? {
    static let optionalSize = ValueCodec(
        typeName: "size", expectation: ValueCodec<CGSize>.size.expectation,
        encode: { size, view in size.map { ValueCodec<CGSize>.size.encode($0, view) } ?? .null },
        decode: { $0 == .null ? .some(nil) : ValueCodec<CGSize>.size.decode($0) })
}

extension ValueCodec where Value == UIView.ContentMode {
    static let contentMode = ValueCodec.choice("contentMode", [
        ("scaleToFill", .scaleToFill), ("scaleAspectFit", .scaleAspectFit),
        ("scaleAspectFill", .scaleAspectFill), ("redraw", .redraw), ("center", .center), ("top", .top),
        ("bottom", .bottom), ("left", .left), ("right", .right), ("topLeft", .topLeft),
        ("topRight", .topRight), ("bottomLeft", .bottomLeft), ("bottomRight", .bottomRight),
    ])
}

extension ValueCodec where Value == NSTextAlignment {
    static let textAlignment = ValueCodec.choice("textAlignment", [
        ("left", .left), ("center", .center), ("right", .right), ("justified", .justified),
        ("natural", .natural),
    ])
}

extension ValueCodec where Value == NSLayoutConstraint.Axis {
    static let axis = ValueCodec.choice("axis", [("horizontal", .horizontal), ("vertical", .vertical)])
}

extension ValueCodec where Value == UIStackView.Alignment {
    static let stackAlignment = ValueCodec.choice("alignment", [
        ("fill", .fill), ("leading", .leading), ("top", .top), ("firstBaseline", .firstBaseline),
        ("center", .center), ("trailing", .trailing), ("bottom", .bottom), ("lastBaseline", .lastBaseline),
    ])
}

extension ValueCodec where Value == UIStackView.Distribution {
    static let stackDistribution = ValueCodec.choice("distribution", [
        ("fill", .fill), ("fillEqually", .fillEqually), ("fillProportionally", .fillProportionally),
        ("equalSpacing", .equalSpacing), ("equalCentering", .equalCentering),
    ])
}
