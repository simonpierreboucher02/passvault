import Testing
import Foundation
@testable import PassVault

@Suite("Import/Export")
struct ImportExportTests {

    // MARK: - Bitwarden JSON Import

    @Test("Import Bitwarden JSON with logins")
    func importBitwardenLogins() throws {
        let json = """
        {
            "encrypted": false,
            "items": [
                {
                    "id": "test-1",
                    "type": 1,
                    "name": "GitHub",
                    "favorite": true,
                    "notes": "My GitHub account",
                    "login": {
                        "uris": [{"uri": "https://github.com", "match": 0}],
                        "username": "alice",
                        "password": "secret123",
                        "totp": null
                    }
                },
                {
                    "id": "test-2",
                    "type": 1,
                    "name": "GitLab",
                    "favorite": false,
                    "login": {
                        "uris": [{"uri": "https://gitlab.com"}],
                        "username": "bob",
                        "password": "pass456"
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let entries = try ImportService.importFile(data: json, format: .bitwardenJSON)

        #expect(entries.count == 2)
        #expect(entries[0].title == "GitHub")
        #expect(entries[0].login?.username == "alice")
        #expect(entries[0].login?.password == "secret123")
        #expect(entries[0].login?.urls.first?.url == "https://github.com")
        #expect(entries[0].favorite == true)
        #expect(entries[0].notes == "My GitHub account")
        #expect(entries[1].title == "GitLab")
        #expect(entries[1].login?.username == "bob")
    }

    @Test("Import Bitwarden JSON with secure note")
    func importBitwardenSecureNote() throws {
        let json = """
        {
            "encrypted": false,
            "items": [
                {
                    "type": 2,
                    "name": "WiFi Password",
                    "notes": "The WiFi password is SuperSecret",
                    "secureNote": {"type": 0}
                }
            ]
        }
        """.data(using: .utf8)!

        let entries = try ImportService.importFile(data: json, format: .bitwardenJSON)

        #expect(entries.count == 1)
        #expect(entries[0].type == .secureNote)
        #expect(entries[0].title == "WiFi Password")
        #expect(entries[0].secureNote?.content == "The WiFi password is SuperSecret")
    }

    @Test("Import Bitwarden JSON with credit card")
    func importBitwardenCard() throws {
        let json = """
        {
            "encrypted": false,
            "items": [
                {
                    "type": 3,
                    "name": "Visa Card",
                    "card": {
                        "cardholderName": "John Doe",
                        "number": "4111111111111111",
                        "expMonth": "12",
                        "expYear": "2025",
                        "code": "123",
                        "brand": "Visa"
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let entries = try ImportService.importFile(data: json, format: .bitwardenJSON)

        #expect(entries.count == 1)
        #expect(entries[0].type == .creditCard)
        #expect(entries[0].creditCard?.cardholderName == "John Doe")
        #expect(entries[0].creditCard?.number == "4111111111111111")
        #expect(entries[0].creditCard?.cvv == "123")
    }

    @Test("Import Bitwarden JSON with identity")
    func importBitwardenIdentity() throws {
        let json = """
        {
            "encrypted": false,
            "items": [
                {
                    "type": 4,
                    "name": "Personal ID",
                    "identity": {
                        "firstName": "Jane",
                        "middleName": null,
                        "lastName": "Smith",
                        "email": "jane@example.com",
                        "phone": "+1234567890",
                        "company": "Acme Corp"
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let entries = try ImportService.importFile(data: json, format: .bitwardenJSON)

        #expect(entries.count == 1)
        #expect(entries[0].type == .identity)
        #expect(entries[0].identity?.firstName == "Jane")
        #expect(entries[0].identity?.lastName == "Smith")
        #expect(entries[0].identity?.email == "jane@example.com")
    }

    @Test("Import Bitwarden JSON with custom fields")
    func importBitwardenCustomFields() throws {
        let json = """
        {
            "encrypted": false,
            "items": [
                {
                    "type": 1,
                    "name": "Service",
                    "login": {"username": "user", "password": "pass"},
                    "fields": [
                        {"name": "Recovery Key", "value": "abc-123-def", "type": 1},
                        {"name": "Pin", "value": "4321", "type": 0}
                    ]
                }
            ]
        }
        """.data(using: .utf8)!

        let entries = try ImportService.importFile(data: json, format: .bitwardenJSON)

        #expect(entries[0].customFields.count == 2)
        #expect(entries[0].customFields[0].name == "Recovery Key")
        #expect(entries[0].customFields[0].type == .hidden)
        #expect(entries[0].customFields[1].name == "Pin")
        #expect(entries[0].customFields[1].type == .text)
    }

    @Test("Import Bitwarden JSON with empty items")
    func importBitwardenEmpty() throws {
        let json = """
        {"encrypted": false, "items": []}
        """.data(using: .utf8)!

        let entries = try ImportService.importFile(data: json, format: .bitwardenJSON)
        #expect(entries.isEmpty)
    }

    @Test("Import Bitwarden JSON skips items without name")
    func importBitwardenSkipsUnnamed() throws {
        let json = """
        {
            "encrypted": false,
            "items": [
                {"type": 1, "login": {"username": "u", "password": "p"}},
                {"type": 1, "name": "Valid", "login": {"username": "u", "password": "p"}}
            ]
        }
        """.data(using: .utf8)!

        let entries = try ImportService.importFile(data: json, format: .bitwardenJSON)
        #expect(entries.count == 1)
        #expect(entries[0].title == "Valid")
    }

    // MARK: - Chrome CSV Import

    @Test("Import Chrome CSV")
    func importChromeCSV() throws {
        let csv = """
        name,url,username,password
        GitHub,https://github.com,alice,secret123
        Gmail,https://mail.google.com,alice@gmail.com,mailpass
        """.data(using: .utf8)!

        let entries = try ImportService.importFile(data: csv, format: .chromeCSV)

        #expect(entries.count == 2)
        #expect(entries[0].title == "GitHub")
        #expect(entries[0].login?.urls.first?.url == "https://github.com")
        #expect(entries[0].login?.username == "alice")
        #expect(entries[0].login?.password == "secret123")
    }

    @Test("Import Chrome CSV with quoted fields")
    func importChromeCSVQuoted() throws {
        let csv = """
        name,url,username,password
        "My, Site",https://example.com,user,"pass,word"
        """.data(using: .utf8)!

        let entries = try ImportService.importFile(data: csv, format: .chromeCSV)

        #expect(entries.count == 1)
        #expect(entries[0].title == "My, Site")
        #expect(entries[0].login?.password == "pass,word")
    }

    // MARK: - Firefox CSV Import

    @Test("Import Firefox CSV")
    func importFirefoxCSV() throws {
        let csv = """
        url,username,password
        https://github.com,alice,secret123
        https://gitlab.com,bob,pass456
        """.data(using: .utf8)!

        let entries = try ImportService.importFile(data: csv, format: .firefoxCSV)

        #expect(entries.count == 2)
        #expect(entries[0].login?.urls.first?.url == "https://github.com")
        #expect(entries[0].login?.username == "alice")
    }

    // MARK: - Generic CSV Import

    @Test("Import Generic CSV auto-detects columns")
    func importGenericCSV() throws {
        let csv = """
        Title,Website,Username,Password,Notes
        GitHub,https://github.com,alice,secret,My dev account
        """.data(using: .utf8)!

        let entries = try ImportService.importFile(data: csv, format: .genericCSV)

        #expect(entries.count == 1)
        #expect(entries[0].title == "GitHub")
        #expect(entries[0].login?.username == "alice")
        #expect(entries[0].notes == "My dev account")
    }

    @Test("Import Generic CSV with alternate column names")
    func importGenericCSVAlternateNames() throws {
        let csv = """
        entry,uri,login,pass
        Test,https://test.com,user,pw
        """.data(using: .utf8)!

        let entries = try ImportService.importFile(data: csv, format: .genericCSV)
        // "entry" is a recognized name for title, "uri" for url, "login" for username, "pass" for password
        #expect(entries.count == 1)
    }

    @Test("Import empty CSV throws")
    func importEmptyCSV() throws {
        let csv = "".data(using: .utf8)!
        #expect(throws: ImportError.self) {
            try ImportService.importFile(data: csv, format: .genericCSV)
        }
    }

    // MARK: - CSV Export

    @Test("Export to CSV")
    func exportCSV() throws {
        var entry = VaultEntry.new(type: .login)
        entry.title = "Test Export"
        entry.login = LoginData(
            urls: [URLEntry(url: "https://example.com")],
            username: "user",
            password: "pass123"
        )

        let data = try ExportService.export(entries: [entry], format: .csv)
        let csv = String(data: data, encoding: .utf8)!

        #expect(csv.contains("name,url,username,password,notes,type"))
        #expect(csv.contains("Test Export"))
        #expect(csv.contains("https://example.com"))
        #expect(csv.contains("user"))
        #expect(csv.contains("pass123"))
    }

    @Test("Export CSV escapes commas")
    func exportCSVEscapes() throws {
        var entry = VaultEntry.new(type: .login)
        entry.title = "Title, with comma"
        entry.login = LoginData(username: "user", password: "pass")

        let data = try ExportService.export(entries: [entry], format: .csv)
        let csv = String(data: data, encoding: .utf8)!

        #expect(csv.contains("\"Title, with comma\""))
    }

    // MARK: - Bitwarden JSON Export

    @Test("Export to Bitwarden JSON")
    func exportBitwardenJSON() throws {
        var entry = VaultEntry.new(type: .login)
        entry.title = "GitHub"
        entry.login = LoginData(
            urls: [URLEntry(url: "https://github.com")],
            username: "alice",
            password: "secret"
        )
        entry.favorite = true

        let data = try ExportService.export(entries: [entry], format: .bitwardenJSON)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["encrypted"] as? Bool == false)
        let items = json["items"] as! [[String: Any]]
        #expect(items.count == 1)
        #expect(items[0]["name"] as? String == "GitHub")
        #expect(items[0]["type"] as? Int == 1)
        #expect(items[0]["favorite"] as? Bool == true)
    }

    // MARK: - Encrypted Export

    @Test("Encrypted export/import round-trip")
    func encryptedExportRoundTrip() throws {
        var entry = VaultEntry.new(type: .login)
        entry.title = "Secret Entry"
        entry.login = LoginData(username: "user", password: "pass")

        let exported = try ExportService.export(
            entries: [entry], format: .encryptedJSON, password: "ExportPass123"
        )

        // Verify it's a valid JSON wrapper
        let wrapper = try JSONSerialization.jsonObject(with: exported) as! [String: String]
        #expect(wrapper["format"] == "PassVault-encrypted-v1")
        #expect(wrapper["salt"] != nil)
        #expect(wrapper["data"] != nil)

        // Verify we can decrypt it
        let salt = Data(base64Encoded: wrapper["salt"]!)!
        let encryptedData = Data(base64Encoded: wrapper["data"]!)!
        let key = try KDFService.deriveKey(password: "ExportPass123", salt: salt, params: .default)
        let encryptionKey = CryptoService.deriveEncryptionKey(from: key)
        let decrypted = try CryptoService.decrypt(combined: encryptedData, using: encryptionKey)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = try decoder.decode([VaultEntry].self, from: decrypted)

        #expect(entries.count == 1)
        #expect(entries[0].title == "Secret Entry")
        #expect(entries[0].login?.username == "user")
    }

    @Test("Encrypted export without password throws")
    func encryptedExportNoPassword() {
        let entry = VaultEntry.new(type: .login)
        #expect(throws: (any Error).self) {
            try ExportService.export(entries: [entry], format: .encryptedJSON, password: nil)
        }
    }

    // MARK: - KDFService

    @Test("KDF derives key from password")
    func kdfDeriveKey() throws {
        let salt = try KDFService.generateSalt()
        let key = try KDFService.deriveKey(password: "TestPassword", salt: salt, params: .default)
        let keyData = key.withUnsafeBytes { Data($0) }
        #expect(keyData.count == 32)
    }

    @Test("KDF is deterministic with same inputs")
    func kdfDeterministic() throws {
        let salt = try KDFService.generateSalt()
        let key1 = try KDFService.deriveKey(password: "SamePassword", salt: salt, params: .default)
        let key2 = try KDFService.deriveKey(password: "SamePassword", salt: salt, params: .default)

        let data1 = key1.withUnsafeBytes { Data($0) }
        let data2 = key2.withUnsafeBytes { Data($0) }
        #expect(data1 == data2)
    }

    @Test("KDF different passwords produce different keys")
    func kdfDifferentPasswords() throws {
        let salt = try KDFService.generateSalt()
        let key1 = try KDFService.deriveKey(password: "Password1", salt: salt, params: .default)
        let key2 = try KDFService.deriveKey(password: "Password2", salt: salt, params: .default)

        let data1 = key1.withUnsafeBytes { Data($0) }
        let data2 = key2.withUnsafeBytes { Data($0) }
        #expect(data1 != data2)
    }

    @Test("KDF different salts produce different keys")
    func kdfDifferentSalts() throws {
        let salt1 = try KDFService.generateSalt()
        let salt2 = try KDFService.generateSalt()
        let key1 = try KDFService.deriveKey(password: "SamePass", salt: salt1, params: .default)
        let key2 = try KDFService.deriveKey(password: "SamePass", salt: salt2, params: .default)

        let data1 = key1.withUnsafeBytes { Data($0) }
        let data2 = key2.withUnsafeBytes { Data($0) }
        #expect(data1 != data2)
    }

    @Test("Salt is 32 bytes")
    func saltSize() throws {
        let salt = try KDFService.generateSalt()
        #expect(salt.count == 32)
    }
}
