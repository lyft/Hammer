/// Representation of a key in a keyboard
public enum KeyboardKey: UInt32 {
    case letterA = 0x04
    case letterB = 0x05
    case letterC = 0x06
    case letterD = 0x07
    case letterE = 0x08
    case letterF = 0x09
    case letterG = 0x0A
    case letterH = 0x0B
    case letterI = 0x0C
    case letterJ = 0x0D
    case letterK = 0x0E
    case letterL = 0x0F
    case letterM = 0x10
    case letterN = 0x11
    case letterO = 0x12
    case letterP = 0x13
    case letterQ = 0x14
    case letterR = 0x15
    case letterS = 0x16
    case letterT = 0x17
    case letterU = 0x18
    case letterV = 0x19
    case letterW = 0x1A
    case letterX = 0x1B
    case letterY = 0x1C
    case letterZ = 0x1D

    case number1 = 0x1E
    case number2 = 0x1F
    case number3 = 0x20
    case number4 = 0x21
    case number5 = 0x22
    case number6 = 0x23
    case number7 = 0x24
    case number8 = 0x25
    case number9 = 0x26
    case number0 = 0x27

    case returnOrEnter = 0x28
    case escape = 0x29
    case deleteOrBackspace = 0x2A
    case tab = 0x2B
    case spacebar = 0x2C
    case hyphen = 0x2D
    case equalSign = 0x2E
    case openBracket = 0x2F
    case closeBracket = 0x30
    case backslash = 0x31
    case semicolon = 0x33
    case quote = 0x34
    case graveAccentAndTilde = 0x35
    case comma = 0x36
    case period = 0x37
    case slash = 0x38
    case capsLock = 0x39

    case functionF1 = 0x3A
    case functionF2 = 0x3B
    case functionF3 = 0x3C
    case functionF4 = 0x3D
    case functionF5 = 0x3E
    case functionF6 = 0x3F
    case functionF7 = 0x40
    case functionF8 = 0x41
    case functionF9 = 0x42
    case functionF10 = 0x43
    case functionF11 = 0x44
    case functionF12 = 0x45

    case printScreen = 0x46
    case insert = 0x49
    case home = 0x4A
    case pageUp = 0x4B
    case deleteForward = 0x4C
    case end = 0x4D
    case pageDown = 0x4E

    case arrowRight = 0x4F
    case arrowLeft = 0x50
    case arrowDown = 0x51
    case arrowUp = 0x52

    case numLock = 0x53

    case leftControl = 0xE0
    case leftShift = 0xE1
    case leftAlt = 0xE2
    case leftGUI = 0xE3
    case rightControl = 0xE4
    case rightShift = 0xE5
    case rightAlt = 0xE6
    case rightGUI = 0xE7
}

// MARK: - Character Support

private let kShiftSymbolCharacters: [Character] = [
    "!", "@", "#", "$", "%", "^", "&", "*", "(", ")", "_", "+",
    "{", "}", "|", ":", "\"", "<", ">", "?", "~",
]

private let kAlternateCharacterKeys: [Character: KeyboardKey] = [
    "`": .graveAccentAndTilde,
    "~": .graveAccentAndTilde,
    "!": .number1,
    "@": .number2,
    "#": .number3,
    "$": .number4,
    "%": .number5,
    "^": .number6,
    "&": .number7,
    "*": .number8,
    "(": .number9,
    ")": .number0,
    "0": .number0,
    "-": .hyphen,
    "_": .hyphen,
    "=": .equalSign,
    "+": .equalSign,
    "[": .openBracket,
    "{": .openBracket,
    "]": .closeBracket,
    "}": .closeBracket,
    "\\": .backslash,
    "|": .backslash,
    ";": .semicolon,
    ":": .semicolon,
    "\'": .quote,
    "\"": .quote,
    ",": .comma,
    "<": .comma,
    ".": .period,
    ">": .period,
    "/": .slash,
    "?": .slash,
    " ": .spacebar,
    "\r": .returnOrEnter,
    "\n": .returnOrEnter,
    "\t": .tab,
]

extension KeyboardKey {
    static func fromCharacter(_ character: Character) throws -> (key: KeyboardKey, shift: Bool) {
        guard character.isASCII else {
            throw HammerError.unknownKeyForCharacter(character)
        }

        let uppercaseAlphabeticOffset = UInt32(Character("A").asciiValue ?? 0) - KeyboardKey.letterA.rawValue
        let lowercaseAlphabeticOffset = UInt32(Character("a").asciiValue ?? 0) - KeyboardKey.letterA.rawValue
        let numericNonZeroOffset = UInt32(Character("1").asciiValue ?? 0) - KeyboardKey.number1.rawValue
        let characterCode = UInt32(character.asciiValue ?? 0)

        // Handle alphanumeric characters and basic symbols.
        if characterCode >= 97 && characterCode <= 122 { // Handle a-z.
            if let key = KeyboardKey(rawValue: characterCode - lowercaseAlphabeticOffset) {
                return (key: key, shift: false)
            }
        } else if characterCode >= 65 && characterCode <= 90 { // Handle A-Z.
            if let key = KeyboardKey(rawValue: characterCode - uppercaseAlphabeticOffset) {
                return (key: key, shift: true)
            }
        } else if characterCode >= 49 && characterCode <= 57 { // Handle 1-9.
            if let key = KeyboardKey(rawValue: characterCode - numericNonZeroOffset) {
                return (key: key, shift: false)
            }
        }

        // Handle all other cases.
        guard let key = kAlternateCharacterKeys[character] else {
            throw HammerError.unknownKeyForCharacter(character)
        }

        return (key: key, shift: kShiftSymbolCharacters.contains(character))
    }
}
