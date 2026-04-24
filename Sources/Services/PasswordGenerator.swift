import Foundation
import Security

enum GeneratorError: LocalizedError {
    case randomGenerationFailed

    var errorDescription: String? {
        "Secure random generation failed"
    }
}

struct GeneratedPassword {
    let value: String
    let entropy: Double

    var strengthLabel: String {
        switch entropy {
        case ..<40: "Very Weak"
        case 40..<60: "Weak"
        case 60..<80: "Fair"
        case 80..<100: "Strong"
        case 100..<128: "Very Strong"
        default: "Excellent"
        }
    }

    var strengthColor: String {
        switch entropy {
        case ..<40: "red"
        case 40..<60: "orange"
        case 60..<80: "yellow"
        case 80..<100: "green"
        default: "blue"
        }
    }
}

struct PasswordCharacterSet: OptionSet {
    let rawValue: Int
    static let lowercase  = PasswordCharacterSet(rawValue: 1 << 0)
    static let uppercase  = PasswordCharacterSet(rawValue: 1 << 1)
    static let digits     = PasswordCharacterSet(rawValue: 1 << 2)
    static let symbols    = PasswordCharacterSet(rawValue: 1 << 3)
    static let all: PasswordCharacterSet = [.lowercase, .uppercase, .digits, .symbols]
}

enum PasswordGenerator {
    private static let lowercaseChars = "abcdefghijklmnopqrstuvwxyz"
    private static let uppercaseChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    private static let digitChars = "0123456789"
    private static let symbolChars = "!@#$%^&*()_+-=[]{}|;:,.<>?"

    // MARK: - Character-Based Password

    static func generate(length: Int = 20, characterSets: PasswordCharacterSet = .all) throws -> GeneratedPassword {
        var pool = ""
        if characterSets.contains(.lowercase) { pool += lowercaseChars }
        if characterSets.contains(.uppercase) { pool += uppercaseChars }
        if characterSets.contains(.digits)    { pool += digitChars }
        if characterSets.contains(.symbols)   { pool += symbolChars }

        guard !pool.isEmpty else {
            return GeneratedPassword(value: "", entropy: 0)
        }

        let poolArray = Array(pool)
        var password = ""

        for _ in 0..<length {
            let index = try secureRandomUniform(UInt32(poolArray.count))
            password.append(poolArray[Int(index)])
        }

        let entropy = Double(length) * log2(Double(poolArray.count))
        return GeneratedPassword(value: password, entropy: entropy)
    }

    // MARK: - Diceware Passphrase

    static func generatePassphrase(wordCount: Int = 6, separator: String = "-", wordList: [String]) throws -> GeneratedPassword {
        guard !wordList.isEmpty else {
            return GeneratedPassword(value: "", entropy: 0)
        }

        var words: [String] = []
        for _ in 0..<wordCount {
            let index = try secureRandomUniform(UInt32(wordList.count))
            words.append(wordList[Int(index)])
        }

        let passphrase = words.joined(separator: separator)
        let entropy = Double(wordCount) * log2(Double(wordList.count))
        return GeneratedPassword(value: passphrase, entropy: entropy)
    }

    // MARK: - Entropy Calculation

    static func calculateEntropy(_ password: String) -> Double {
        guard !password.isEmpty else { return 0 }
        var poolSize = 0
        let chars = Set(password)

        if chars.contains(where: { $0.isLowercase })  { poolSize += 26 }
        if chars.contains(where: { $0.isUppercase })  { poolSize += 26 }
        if chars.contains(where: { $0.isNumber })     { poolSize += 10 }
        if chars.contains(where: { !$0.isLetter && !$0.isNumber }) { poolSize += 32 }

        guard poolSize > 0 else { return 0 }
        return Double(password.count) * log2(Double(poolSize))
    }

    // MARK: - Secure Random

    private static func secureRandomUniform(_ upperBound: UInt32) throws -> UInt32 {
        guard upperBound > 0 else { return 0 }
        let range = UInt32.max - (UInt32.max % upperBound)
        while true {
            var result: UInt32 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, MemoryLayout<UInt32>.size, &result)
            guard status == errSecSuccess else {
                throw GeneratorError.randomGenerationFailed
            }
            if result < range {
                return result % upperBound
            }
        }
    }
}
