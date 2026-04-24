import Foundation

enum ExportFormat: String, CaseIterable, Identifiable {
    case bitwardenJSON = "Bitwarden JSON"
    case csv = "CSV"
    case encryptedJSON = "Encrypted JSON"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .bitwardenJSON: "json"
        case .csv: "csv"
        case .encryptedJSON: "pvlt.json"
        }
    }
}

enum ExportService {
    static func export(entries: [VaultEntry], format: ExportFormat, password: String? = nil) throws -> Data {
        switch format {
        case .bitwardenJSON:
            return try exportBitwardenJSON(entries: entries)
        case .csv:
            return exportCSV(entries: entries)
        case .encryptedJSON:
            guard let password else {
                throw CryptoError.encryptionFailed
            }
            return try exportEncryptedJSON(entries: entries, password: password)
        }
    }

    // MARK: - Bitwarden JSON

    private static func exportBitwardenJSON(entries: [VaultEntry]) throws -> Data {
        let items: [[String: Any]] = entries.map { entry in
            var item: [String: Any] = [
                "id": entry.id.uuidString,
                "name": entry.title,
                "favorite": entry.favorite
            ]

            if let notes = entry.notes {
                item["notes"] = notes
            }

            switch entry.type {
            case .login:
                item["type"] = 1
                if let login = entry.login {
                    var loginDict: [String: Any] = [
                        "username": login.username,
                        "password": login.password
                    ]
                    if !login.urls.isEmpty {
                        loginDict["uris"] = login.urls.map { ["uri": $0.url, "match": $0.matchType.rawValue] }
                    }
                    if let totp = login.totp {
                        loginDict["totp"] = TOTPService.base32Encode(totp.secret)
                    }
                    item["login"] = loginDict
                }
            case .secureNote:
                item["type"] = 2
                item["notes"] = entry.secureNote?.content ?? entry.notes ?? ""
                item["secureNote"] = ["type": 0]
            case .creditCard:
                item["type"] = 3
                if let card = entry.creditCard {
                    item["card"] = [
                        "cardholderName": card.cardholderName,
                        "number": card.number,
                        "expMonth": card.expirationMonth,
                        "expYear": card.expirationYear,
                        "code": card.cvv,
                        "brand": card.brand ?? ""
                    ]
                }
            case .identity:
                item["type"] = 4
                if let identity = entry.identity {
                    item["identity"] = [
                        "firstName": identity.firstName,
                        "lastName": identity.lastName,
                        "email": identity.email ?? "",
                        "phone": identity.phone ?? "",
                        "company": identity.company ?? ""
                    ]
                }
            default:
                item["type"] = 1
            }

            return item
        }

        let export: [String: Any] = [
            "encrypted": false,
            "items": items
        ]

        return try JSONSerialization.data(withJSONObject: export, options: [.prettyPrinted, .sortedKeys])
    }

    // MARK: - CSV

    private static func exportCSV(entries: [VaultEntry]) -> Data {
        var csv = "name,url,username,password,notes,type\n"
        for entry in entries {
            let url = entry.login?.urls.first?.url ?? ""
            let username = entry.login?.username ?? ""
            let password = entry.login?.password ?? ""
            let notes = entry.notes ?? ""
            let row = [
                escapeCSV(entry.title),
                escapeCSV(url),
                escapeCSV(username),
                escapeCSV(password),
                escapeCSV(notes),
                escapeCSV(entry.type.label)
            ].joined(separator: ",")
            csv += row + "\n"
        }
        return Data(csv.utf8)
    }

    // MARK: - Encrypted JSON

    private static func exportEncryptedJSON(entries: [VaultEntry], password: String) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let plaintext = try encoder.encode(entries)

        let salt = try KDFService.generateSalt()
        let key = try KDFService.deriveKey(password: password, salt: salt, params: .default)
        let encryptionKey = CryptoService.deriveEncryptionKey(from: key)
        let encrypted = try CryptoService.encrypt(data: plaintext, using: encryptionKey)

        let wrapper: [String: String] = [
            "format": "PassVault-encrypted-v1",
            "salt": salt.base64EncodedString(),
            "data": encrypted.base64EncodedString()
        ]

        return try JSONSerialization.data(withJSONObject: wrapper, options: .prettyPrinted)
    }

    // MARK: - Helpers

    private static func escapeCSV(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }
}
