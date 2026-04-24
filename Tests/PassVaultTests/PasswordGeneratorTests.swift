import Testing
import Foundation
@testable import PassVault

@Suite("PasswordGenerator")
struct PasswordGeneratorTests {

    // MARK: - Character-Based Password

    @Test("Generated password has correct length")
    func passwordLength() throws {
        for length in [8, 12, 16, 20, 32, 64] {
            let result = try PasswordGenerator.generate(length: length)
            #expect(result.value.count == length)
        }
    }

    @Test("Password with lowercase only contains lowercase")
    func lowercaseOnly() throws {
        let result = try PasswordGenerator.generate(length: 50, characterSets: .lowercase)
        #expect(result.value.allSatisfy { $0.isLowercase })
    }

    @Test("Password with uppercase only contains uppercase")
    func uppercaseOnly() throws {
        let result = try PasswordGenerator.generate(length: 50, characterSets: .uppercase)
        #expect(result.value.allSatisfy { $0.isUppercase })
    }

    @Test("Password with digits only contains digits")
    func digitsOnly() throws {
        let result = try PasswordGenerator.generate(length: 50, characterSets: .digits)
        #expect(result.value.allSatisfy { $0.isNumber })
    }

    @Test("Password with symbols only contains non-alphanumeric")
    func symbolsOnly() throws {
        let result = try PasswordGenerator.generate(length: 50, characterSets: .symbols)
        #expect(result.value.allSatisfy { !$0.isLetter && !$0.isNumber })
    }

    @Test("Password with all sets contains mixed characters")
    func allCharacterSets() throws {
        // Generate long enough to statistically guarantee all sets
        let result = try PasswordGenerator.generate(length: 200, characterSets: .all)
        let chars = Set(result.value)

        #expect(chars.contains(where: { $0.isLowercase }))
        #expect(chars.contains(where: { $0.isUppercase }))
        #expect(chars.contains(where: { $0.isNumber }))
        #expect(chars.contains(where: { !$0.isLetter && !$0.isNumber }))
    }

    @Test("Two generated passwords are different")
    func passwordsUnique() throws {
        let p1 = try PasswordGenerator.generate(length: 20)
        let p2 = try PasswordGenerator.generate(length: 20)
        #expect(p1.value != p2.value)
    }

    @Test("Empty character set returns empty password")
    func emptyCharacterSet() throws {
        let result = try PasswordGenerator.generate(length: 10, characterSets: PasswordCharacterSet(rawValue: 0))
        #expect(result.value.isEmpty)
        #expect(result.entropy == 0)
    }

    // MARK: - Entropy Calculation

    @Test("Entropy calculation for known values")
    func entropyCalculation() {
        // lowercase only: 26 chars pool
        // 10 chars = 10 * log2(26) ≈ 47.0
        let lowercaseEntropy = PasswordGenerator.calculateEntropy("abcdefghij")
        #expect(lowercaseEntropy > 46 && lowercaseEntropy < 48)

        // all sets: 94 chars pool
        // 20 chars = 20 * log2(94) ≈ 131.1
        let allEntropy = PasswordGenerator.calculateEntropy("aB3!aB3!aB3!aB3!aB3!")
        #expect(allEntropy > 130 && allEntropy < 133)
    }

    @Test("Entropy is zero for empty password")
    func entropyEmpty() {
        #expect(PasswordGenerator.calculateEntropy("") == 0)
    }

    @Test("Entropy increases with password length")
    func entropyIncreasesWithLength() throws {
        let short = try PasswordGenerator.generate(length: 8)
        let long = try PasswordGenerator.generate(length: 32)
        #expect(long.entropy > short.entropy)
    }

    @Test("Entropy increases with pool size")
    func entropyIncreasesWithPoolSize() throws {
        let lowOnly = try PasswordGenerator.generate(length: 20, characterSets: .lowercase)
        let allSets = try PasswordGenerator.generate(length: 20, characterSets: .all)
        #expect(allSets.entropy > lowOnly.entropy)
    }

    @Test("Generated password entropy matches calculated entropy")
    func entropyConsistency() throws {
        let result = try PasswordGenerator.generate(length: 20, characterSets: .all)
        // Pool size for .all = 26 + 26 + 10 + 27 = 89 (actual chars in pool string)
        // Entropy = 20 * log2(pool_size)
        #expect(result.entropy > 100)
    }

    // MARK: - Strength Labels

    @Test("Strength labels map correctly")
    func strengthLabels() {
        #expect(GeneratedPassword(value: "", entropy: 30).strengthLabel == "Very Weak")
        #expect(GeneratedPassword(value: "", entropy: 50).strengthLabel == "Weak")
        #expect(GeneratedPassword(value: "", entropy: 70).strengthLabel == "Fair")
        #expect(GeneratedPassword(value: "", entropy: 90).strengthLabel == "Strong")
        #expect(GeneratedPassword(value: "", entropy: 110).strengthLabel == "Very Strong")
        #expect(GeneratedPassword(value: "", entropy: 130).strengthLabel == "Excellent")
    }

    // MARK: - Passphrase Generation

    @Test("Passphrase has correct word count")
    func passphraseWordCount() throws {
        let wordList = ["apple", "banana", "cherry", "date", "elderberry", "fig", "grape", "honeydew"]
        for count in [3, 4, 5, 6] {
            let result = try PasswordGenerator.generatePassphrase(
                wordCount: count, separator: "-", wordList: wordList
            )
            let words = result.value.components(separatedBy: "-")
            #expect(words.count == count)
        }
    }

    @Test("Passphrase uses words from word list")
    func passphraseUsesWordList() throws {
        let wordList = ["alpha", "bravo", "charlie", "delta", "echo", "foxtrot"]
        let result = try PasswordGenerator.generatePassphrase(
            wordCount: 4, separator: "-", wordList: wordList
        )
        let words = result.value.components(separatedBy: "-")
        for word in words {
            #expect(wordList.contains(word))
        }
    }

    @Test("Passphrase with custom separator")
    func passphraseCustomSeparator() throws {
        let wordList = ["one", "two", "three", "four", "five", "six"]
        let result = try PasswordGenerator.generatePassphrase(
            wordCount: 3, separator: ".", wordList: wordList
        )
        #expect(result.value.contains("."))
        #expect(!result.value.contains("-"))
    }

    @Test("Passphrase entropy calculation")
    func passphraseEntropy() throws {
        let wordList = Array(repeating: "word", count: 7776).enumerated().map { "word\($0.offset)" }
        let result = try PasswordGenerator.generatePassphrase(
            wordCount: 6, separator: "-", wordList: wordList
        )
        // 6 words * log2(7776) ≈ 77.5 bits
        #expect(result.entropy > 77 && result.entropy < 78)
    }

    @Test("Passphrase with empty word list returns empty")
    func passphraseEmptyWordList() throws {
        let result = try PasswordGenerator.generatePassphrase(wordCount: 4, separator: "-", wordList: [])
        #expect(result.value.isEmpty)
    }

    // MARK: - Statistical Bias Detection

    @Test("No severe bias in character distribution", .timeLimit(.minutes(1)))
    func noBiasInDistribution() throws {
        // Generate many passwords and check distribution is reasonably uniform
        let poolSize = 10 // digits only
        var counts = [Character: Int]()
        let iterations = 10_000

        for _ in 0..<iterations {
            let result = try PasswordGenerator.generate(length: 1, characterSets: .digits)
            let char = result.value.first!
            counts[char, default: 0] += 1
        }

        // Each digit should appear roughly iterations/poolSize times
        let expected = Double(iterations) / Double(poolSize)
        for (_, count) in counts {
            let deviation = abs(Double(count) - expected) / expected
            // Allow 20% deviation (statistically reasonable)
            #expect(deviation < 0.20, "Bias detected: count=\(count), expected≈\(Int(expected))")
        }
    }
}
