import Testing
import Foundation
@testable import PassVault

@Suite("Models")
struct ModelTests {

    // MARK: - VaultEntry

    @Test("VaultEntry.new creates correct type-specific data")
    func newEntryCreation() {
        let login = VaultEntry.new(type: .login)
        #expect(login.login != nil)
        #expect(login.secureNote == nil)
        #expect(login.type == .login)

        let note = VaultEntry.new(type: .secureNote)
        #expect(note.secureNote != nil)
        #expect(note.login == nil)

        let card = VaultEntry.new(type: .creditCard)
        #expect(card.creditCard != nil)

        let identity = VaultEntry.new(type: .identity)
        #expect(identity.identity != nil)

        let ssh = VaultEntry.new(type: .sshKey)
        #expect(ssh.sshKey != nil)

        let api = VaultEntry.new(type: .apiCredential)
        #expect(api.apiCredential != nil)
    }

    @Test("VaultEntry display subtitle for login shows username")
    func displaySubtitleLogin() {
        var entry = VaultEntry.new(type: .login)
        entry.login = LoginData(username: "alice@test.com", password: "pass")
        #expect(entry.displaySubtitle == "alice@test.com")
    }

    @Test("VaultEntry display subtitle for card shows masked number")
    func displaySubtitleCard() {
        var entry = VaultEntry.new(type: .creditCard)
        entry.creditCard = CreditCardData(number: "4111111111111111")
        #expect(entry.displaySubtitle.contains("1111"))
        #expect(entry.displaySubtitle.contains("••••"))
    }

    @Test("VaultEntry display subtitle for identity shows full name")
    func displaySubtitleIdentity() {
        var entry = VaultEntry.new(type: .identity)
        entry.identity = IdentityData(firstName: "John", lastName: "Doe")
        #expect(entry.displaySubtitle == "John Doe")
    }

    @Test("VaultEntry custom subtitle overrides default")
    func customSubtitle() {
        var entry = VaultEntry.new(type: .login)
        entry.login = LoginData(username: "user", password: "pass")
        entry.subtitle = "Custom subtitle"
        #expect(entry.displaySubtitle == "Custom subtitle")
    }

    @Test("VaultEntry defaults are correct")
    func entryDefaults() {
        let entry = VaultEntry.new(type: .login)
        #expect(!entry.favorite)
        #expect(entry.tags.isEmpty)
        #expect(entry.customFields.isEmpty)
        #expect(entry.passwordHistory.isEmpty)
        #expect(entry.accessCount == 0)
        #expect(entry.notes == nil)
        #expect(entry.expiresAt == nil)
    }

    // MARK: - Codable Round-Trip

    @Test("VaultEntry Codable round-trip for login")
    func codableLogin() throws {
        var entry = VaultEntry.new(type: .login)
        entry.title = "Test Login"
        entry.login = LoginData(
            urls: [URLEntry(url: "https://example.com")],
            username: "user",
            password: "pass123",
            email: "user@test.com"
        )
        entry.tags = ["work", "dev"]
        entry.favorite = true
        entry.notes = "Some notes"

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(VaultEntry.self, from: data)

        #expect(decoded.title == "Test Login")
        #expect(decoded.login?.username == "user")
        #expect(decoded.login?.password == "pass123")
        #expect(decoded.login?.email == "user@test.com")
        #expect(decoded.login?.urls.count == 1)
        #expect(decoded.tags == ["work", "dev"])
        #expect(decoded.favorite == true)
        #expect(decoded.notes == "Some notes")
        #expect(decoded.type == .login)
    }

    @Test("VaultEntry Codable round-trip for all types")
    func codableAllTypes() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for type in EntryType.allCases {
            let entry = VaultEntry.new(type: type)
            let data = try encoder.encode(entry)
            let decoded = try decoder.decode(VaultEntry.self, from: data)
            #expect(decoded.type == type)
            #expect(decoded.id == entry.id)
        }
    }

    @Test("VaultEntry Codable round-trip with TOTP config")
    func codableTOTP() throws {
        var entry = VaultEntry.new(type: .login)
        entry.login = LoginData(
            username: "user",
            password: "pass",
            totp: TOTPConfig(
                secret: Data("secretsecret1234".utf8),
                issuer: "GitHub",
                account: "user@example.com",
                algorithm: .sha256,
                digits: 8,
                period: 60
            )
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(VaultEntry.self, from: data)

        #expect(decoded.login?.totp?.issuer == "GitHub")
        #expect(decoded.login?.totp?.algorithm == .sha256)
        #expect(decoded.login?.totp?.digits == 8)
        #expect(decoded.login?.totp?.period == 60)
    }

    @Test("PasswordHistoryEntry Codable round-trip")
    func codablePasswordHistory() throws {
        let history = PasswordHistoryEntry(password: "oldpass123")

        let data = try JSONEncoder().encode(history)
        let decoded = try JSONDecoder().decode(PasswordHistoryEntry.self, from: data)

        #expect(decoded.password == "oldpass123")
        #expect(decoded.id == history.id)
    }

    // MARK: - CreditCardData

    @Test("CreditCard masked number")
    func maskedNumber() {
        let card = CreditCardData(number: "4111222233334444")
        #expect(card.maskedNumber == "•••• •••• •••• 4444")
    }

    @Test("CreditCard masked number short")
    func maskedNumberShort() {
        let card = CreditCardData(number: "123")
        #expect(card.maskedNumber == "123")
    }

    @Test("CreditCard brand detection")
    func brandDetection() {
        #expect(CreditCardData(number: "4111111111111111").detectedBrand == "Visa")
        #expect(CreditCardData(number: "5111111111111111").detectedBrand == "Mastercard")
        #expect(CreditCardData(number: "3711111111111111").detectedBrand == "Amex")
        #expect(CreditCardData(number: "6011111111111111").detectedBrand == "Discover")
        #expect(CreditCardData(number: "9999999999999999").detectedBrand == "Unknown")
    }

    @Test("CreditCard explicit brand overrides detection")
    func explicitBrand() {
        let card = CreditCardData(number: "4111111111111111", brand: "Custom")
        #expect(card.detectedBrand == "Custom")
    }

    // MARK: - IdentityData

    @Test("Identity full name")
    func fullName() {
        let identity = IdentityData(firstName: "John", middleName: "Paul", lastName: "Doe")
        #expect(identity.fullName == "John Paul Doe")
    }

    @Test("Identity full name without middle name")
    func fullNameNoMiddle() {
        let identity = IdentityData(firstName: "Jane", lastName: "Smith")
        #expect(identity.fullName == "Jane Smith")
    }

    @Test("Identity full name with empty parts")
    func fullNameEmpty() {
        let identity = IdentityData(firstName: "", lastName: "")
        #expect(identity.fullName.isEmpty)
    }

    // MARK: - EntryType

    @Test("EntryType all cases")
    func allCases() {
        #expect(EntryType.allCases.count == 6)
    }

    @Test("EntryType labels are non-empty")
    func labels() {
        for type in EntryType.allCases {
            #expect(!type.label.isEmpty)
            #expect(!type.systemImage.isEmpty)
        }
    }

    // MARK: - CustomField

    @Test("CustomField defaults")
    func customFieldDefaults() {
        let field = CustomField(name: "API Key", value: "abc123")
        #expect(field.type == .text)
        #expect(!field.isHidden)
    }

    @Test("CustomField hidden type")
    func customFieldHidden() {
        let field = CustomField(name: "Secret", value: "hidden", type: .hidden, isHidden: true)
        #expect(field.type == .hidden)
        #expect(field.isHidden)
    }

    // MARK: - KDFParams

    @Test("Default KDF params")
    func defaultKDFParams() {
        let params = KDFParams.default
        #expect(params.algorithm == .argon2id)
        #expect(params.memory == 131072)
        #expect(params.iterations == 3)
        #expect(params.parallelism == 4)
    }

    @Test("Lightweight KDF params")
    func lightweightKDFParams() {
        let params = KDFParams.lightweight
        #expect(params.algorithm == .pbkdf2)
        #expect(params.iterations == 600_000)
    }

    // MARK: - VaultHeader

    @Test("VaultHeader Codable round-trip")
    func vaultHeaderCodable() throws {
        let header = VaultHeader(
            salt: Data(repeating: 0xAB, count: 32),
            encryptedVaultKey: Data(repeating: 0xCD, count: 60),
            encryptedAuthKey: Data(repeating: 0xEF, count: 60)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(header)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(VaultHeader.self, from: data)

        #expect(decoded.version == 1)
        #expect(decoded.salt.count == 32)
        #expect(decoded.kdfParams.algorithm == .argon2id)
    }

    // MARK: - URLEntry

    @Test("URLEntry match types")
    func urlMatchTypes() {
        let entry = URLEntry(url: "https://github.com", matchType: .domain)
        #expect(entry.matchType == .domain)
        #expect(entry.matchType.label == "Base Domain")
    }
}
