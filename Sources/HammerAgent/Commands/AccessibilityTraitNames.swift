import UIKit

extension UIAccessibilityTraits {
    private static let named: [(name: String, trait: UIAccessibilityTraits)] = [
        ("button", .button),
        ("link", .link),
        ("header", .header),
        ("searchField", .searchField),
        ("image", .image),
        ("selected", .selected),
        ("playsSound", .playsSound),
        ("keyboardKey", .keyboardKey),
        ("staticText", .staticText),
        ("summaryElement", .summaryElement),
        ("notEnabled", .notEnabled),
        ("updatesFrequently", .updatesFrequently),
        ("startsMediaSession", .startsMediaSession),
        ("adjustable", .adjustable),
        ("allowsDirectInteraction", .allowsDirectInteraction),
        ("causesPageTurn", .causesPageTurn),
        ("tabBar", .tabBar),
        ("toggleButton", .toggleButton),
        ("supportsZoom", .supportsZoom),
    ]

    /// Creates the trait with the name of its static property, such as `button`.
    ///
    /// - parameter name: The name of the trait.
    init?(name: String) {
        guard let trait = Self.named.first(where: { $0.name == name })?.trait else {
            return nil
        }

        self = trait
    }

    /// The names of the traits it contains.
    var names: [String] {
        return Self.named.filter { self.contains($0.trait) }.map(\.name)
    }
}
