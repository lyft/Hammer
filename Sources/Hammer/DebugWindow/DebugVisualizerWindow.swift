import Foundation
import UIKit

private let kWindowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 100)

private let kStylusColor = UIColor(hue: 0.800, saturation: 1, brightness: 0.8, alpha: 1)
private let kFingerColors: [FingerIndex: UIColor] = [
    .rightThumb: UIColor(hue: 0.00, saturation: 1, brightness: 0.8, alpha: 1),
    .rightIndex: UIColor(hue: 0.50, saturation: 1, brightness: 0.8, alpha: 1),
    .rightMiddle: UIColor(hue: 0.25, saturation: 1, brightness: 0.8, alpha: 1),
    .rightRing: UIColor(hue: 0.75, saturation: 1, brightness: 0.8, alpha: 1),
    .rightLittle: UIColor(hue: 0.125, saturation: 1, brightness: 0.8, alpha: 1),
    .leftThumb: UIColor(hue: 0.375, saturation: 1, brightness: 0.8, alpha: 1),
    .leftIndex: UIColor(hue: 0.625, saturation: 1, brightness: 0.8, alpha: 1),
    .leftMiddle: UIColor(hue: 0.875, saturation: 1, brightness: 0.8, alpha: 1),
    .leftRing: UIColor(hue: 0.437, saturation: 1, brightness: 0.8, alpha: 1),
    .leftLittle: UIColor(hue: 0.937, saturation: 1, brightness: 0.8, alpha: 1),
]

final class DebugVisualizerWindow: UIWindow {
    private let stylusView = TouchView.initializeForStylus()
    private let fingerViews = Dictionary(uniqueKeysWithValues: FingerIndex.defaultOrder.map { index in
        (index, TouchView.initializeForFinger(index: index))
    })

    override var canBecomeFirstResponder: Bool {
        return false
    }

    init() {
        super.init(frame: .zero)

        self.windowLevel = kWindowLevel
        self.backgroundColor = .clear
        self.isUserInteractionEnabled = false
        self.isAccessibilityElement = false
        self.isHidden = false

        self.fingerViews.values.forEach(self.addSubview(_:))
        if UIDevice.current.supportsStylus {
            self.addSubview(self.stylusView)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(fingerIndex: FingerIndex, location: CGPoint?) {
        self.fingerViews[fingerIndex]?.configure(location: location)
        self.layoutIfNeeded()
    }

    func update(stylusLocation location: CGPoint?) {
        self.stylusView.configure(location: location)
        self.layoutIfNeeded()
    }
}

private final class TouchView: UIView {
    private static let viewSize: CGFloat = 20

    private let label = UILabel()

    private init(text: String, color: UIColor) {
        super.init(frame: CGRect(x: 0, y: 0, width: TouchView.viewSize, height: TouchView.viewSize))
        self.isUserInteractionEnabled = false
        self.isAccessibilityElement = false
        self.layer.cornerRadius = TouchView.viewSize / 2

        self.label.textColor = .white
        self.label.textAlignment = .center
        self.label.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.label)
        self.label.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        self.label.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true

        self.label.text = text
        self.backgroundColor = color

        self.isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func initializeForFinger(index: FingerIndex) -> TouchView {
        return TouchView(text: "\(index.rawValue)", color: kFingerColors[index] ?? .black)
    }

    static func initializeForStylus() -> TouchView {
        return TouchView(text: "✐", color: kStylusColor)
    }

    func configure(location: CGPoint?) {
        if let location = location {
            self.center = location
            self.isHidden = false
        } else {
            self.isHidden = true
        }
    }
}
