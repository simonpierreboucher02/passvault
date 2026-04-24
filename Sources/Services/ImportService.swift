import Foundation

enum ImportError: LocalizedError {
    case invalidFormat
    case invalidEncoding
    case emptyFile
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .invalidFormat: "Invalid import format"
        case .invalidEncoding: "Invalid file encoding"
        case .emptyFile: "File is empty"
        case .parseError(let msg): "Parse error: \(msg)"
        }
    }
}

enum ImportFormat: String, CaseIterable, Identifiable {
    case bitwardenJSON = "Bitwarden JSON"
    case chromeCSV = "Chrome CSV"
    case firefoxCSV = "Firefox CSV"
    case genericCSV = "Generic CSV"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .bitwardenJSON: "json"
        case .chromeCSV, .firefoxCSV, .genericCSV: "csv"
        }
    }
}

// MARK: - Bitwarden JSON Structs

struct BitwardenExport: Codable {
    let encrypted: Bool?
    let folders: [BitwardenFolder]?
    let items: [BitwardenItem]?
}

struct BitwardenFolder: Codable {
    let id: String?
    let name: String?
}

struct BitwardenItem: Codable {
    let id: String?
    let type: Int?
    let name: String?
    let notes: String?
    let favorite: Bool?
    let login: BitwardenLogin?
    let card: BitwardenCard?
    let identity: BitwardenIdentity?
    let secureNote: BitwardenSecureNote?
    let fields: [BitwardenField]?
}

struct BitwardenLogin: Codable {
    let uris: [BitwardenURI]?
    let username: String?
    let password: String?
    let totp: String?
}

struct BitwardenURI: Codable {
    let match: Int?
    let uri: String?
}

struct BitwardenCard: Codable {
    let cardholderName: String?
    let brand: String?
    let number: String?
    let expMonth: String?
    let expYear: String?
    let code: String?
}

struct BitwardenIdentity: Codable {
    let title: String?
    let firstName: String?
    let middleName: String?
    let lastName: String?
    let email: String?
    let phone: String?
    let address1: String?
    let city: String?
    let state: String?
    let postalCode: String?
    let country: String?
    let company: String?
}

struct BitwardenSecureNote: Codable {
    let type: Int?
}

struct BitwardenField: Codable {
    let name: String?
    let value: String?
    let type: Int?
}

// MARK: - Import Engine

enum ImportService {
    static func importFile(data: Data, format: ImportFormat) throws -> [VaultEntry] {
        switch format {
        case .bitwardenJSON:
            return try importBitwardenJSON(data: data)
        case .chromeCSV:
            return try importCSV(data: data, columns: ["name", "url", "username", "password"])
        case .firefoxCSV:
            return try importCSV(data: data, columns: ["url", "username", "password"])
        case .genericCSV:
            return try importGenericCSV(data: data)
        }
    }

    // MARK: - Bitwarden JSON

    private static func importBitwardenJSON(data: Data) throws -> [VaultEntry] {
        let export = try JSONDecoder().decode(BitwardenExport.self, from: data)
        guard let items = export.items else { return [] }

        return items.compactMap { item -> VaultEntry? in
            guard let name = item.name else { return nil }
            let itemType = item.type ?? 1

            switch itemType {
            case 1: // Login
                var entry = VaultEntry.new(type: .login)
                entry.title = name
                entry.notes = item.notes
                entry.favorite = item.favorite ?? false
                entry.login = LoginData(
                    urls: (item.login?.uris ?? []).compactMap { uri in
                        guard let url = uri.uri, !url.isEmpty else { return nil }
                        return URLEntry(url: url)
                    },
                    username: item.login?.username ?? "",
                    password: item.login?.password ?? ""
                )
                if let totpSecret = item.login?.totp,
                   let secret = TOTPService.base32Decode(totpSecret) {
                    entry.login?.totp = TOTPConfig(secret: secret, issuer: name)
                }
                entry.customFields = (item.fields ?? []).map { field in
                    CustomField(
                        name: field.name ?? "",
                        value: field.value ?? "",
                        type: field.type == 1 ? .hidden : .text
                    )
                }
                return entry

            case 2: // Secure Note
                var entry = VaultEntry.new(type: .secureNote)
                entry.title = name
                entry.secureNote = SecureNoteData(content: item.notes ?? "")
                entry.favorite = item.favorite ?? false
                return entry

            case 3: // Card
                var entry = VaultEntry.new(type: .creditCard)
                entry.title = name
                entry.notes = item.notes
                entry.favorite = item.favorite ?? false
                entry.creditCard = CreditCardData(
                    cardholderName: item.card?.cardholderName ?? "",
                    number: item.card?.number ?? "",
                    expirationMonth: item.card?.expMonth ?? "",
                    expirationYear: item.card?.expYear ?? "",
                    cvv: item.card?.code ?? "",
                    brand: item.card?.brand
                )
                return entry

            case 4: // Identity
                var entry = VaultEntry.new(type: .identity)
                entry.title = name
                entry.notes = item.notes
                entry.favorite = item.favorite ?? false
                entry.identity = IdentityData(
                    firstName: item.identity?.firstName ?? "",
                    middleName: item.identity?.middleName,
                    lastName: item.identity?.lastName ?? "",
                    email: item.identity?.email,
                    phone: item.identity?.phone,
                    address: item.identity?.address1 != nil ? Address(
                        street1: item.identity?.address1 ?? "",
                        city: item.identity?.city ?? "",
                        state: item.identity?.state ?? "",
                        postalCode: item.identity?.postalCode ?? "",
                        country: item.identity?.country ?? ""
                    ) : nil,
                    company: item.identity?.company
                )
                return entry

            default:
                return nil
            }
        }
    }

    // MARK: - CSV Import

    private static func importCSV(data: Data, columns: [String]) throws -> [VaultEntry] {
        guard let csvString = String(data: data, encoding: .utf8) else {
            throw ImportError.invalidEncoding
        }

        let rows = parseCSV(csvString)
        guard rows.count > 1 else { throw ImportError.emptyFile }

        return rows.dropFirst().compactMap { row -> VaultEntry? in
            guard row.count >= 3 else { return nil }

            var entry = VaultEntry.new(type: .login)

            if columns.first == "name" && row.count >= 4 {
                entry.title = row[0]
                entry.login = LoginData(
                    urls: row[1].isEmpty ? [] : [URLEntry(url: row[1])],
                    username: row[2],
                    password: row[3]
                )
            } else {
                let urlStr = row[0]
                entry.title = urlStr.isEmpty ? "Imported" : extractDomain(from: urlStr)
                entry.login = LoginData(
                    urls: urlStr.isEmpty ? [] : [URLEntry(url: urlStr)],
                    username: row[1],
                    password: row[2]
                )
            }

            return entry
        }
    }

    private static func importGenericCSV(data: Data) throws -> [VaultEntry] {
        guard let csvString = String(data: data, encoding: .utf8) else {
            throw ImportError.invalidEncoding
        }

        let rows = parseCSV(csvString)
        guard let header = rows.first, rows.count > 1 else {
            throw ImportError.emptyFile
        }

        let lowerHeader = header.map { $0.lowercased() }
        let nameIdx = lowerHeader.firstIndex(where: { ["name", "title", "entry"].contains($0) })
        let urlIdx = lowerHeader.firstIndex(where: { ["url", "website", "uri", "login_uri"].contains($0) })
        let userIdx = lowerHeader.firstIndex(where: { ["username", "user", "login", "email", "login_username"].contains($0) })
        let passIdx = lowerHeader.firstIndex(where: { ["password", "pass", "login_password"].contains($0) })
        let notesIdx = lowerHeader.firstIndex(where: { ["notes", "note", "extra", "comments"].contains($0) })

        return rows.dropFirst().compactMap { row -> VaultEntry? in
            var entry = VaultEntry.new(type: .login)

            let name = nameIdx.flatMap { $0 < row.count ? row[$0] : nil } ?? ""
            let url = urlIdx.flatMap { $0 < row.count ? row[$0] : nil } ?? ""
            let user = userIdx.flatMap { $0 < row.count ? row[$0] : nil } ?? ""
            let pass = passIdx.flatMap { $0 < row.count ? row[$0] : nil } ?? ""
            let notes = notesIdx.flatMap { $0 < row.count ? row[$0] : nil }

            if name.isEmpty && url.isEmpty && user.isEmpty && pass.isEmpty {
                return nil
            }

            entry.title = name.isEmpty ? (url.isEmpty ? "Imported" : extractDomain(from: url)) : name
            entry.login = LoginData(
                urls: url.isEmpty ? [] : [URLEntry(url: url)],
                username: user,
                password: pass
            )
            entry.notes = notes

            return entry
        }
    }

    // MARK: - CSV Parser

    private static func parseCSV(_ string: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var insideQuotes = false

        for char in string {
            if insideQuotes {
                if char == "\"" {
                    insideQuotes = false
                } else {
                    currentField.append(char)
                }
            } else {
                switch char {
                case "\"":
                    insideQuotes = true
                case ",":
                    currentRow.append(currentField)
                    currentField = ""
                case "\n", "\r\n":
                    currentRow.append(currentField)
                    currentField = ""
                    if !currentRow.allSatisfy({ $0.isEmpty }) {
                        rows.append(currentRow)
                    }
                    currentRow = []
                default:
                    currentField.append(char)
                }
            }
        }

        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            if !currentRow.allSatisfy({ $0.isEmpty }) {
                rows.append(currentRow)
            }
        }

        return rows
    }

    private static func extractDomain(from urlString: String) -> String {
        if let url = URL(string: urlString), let host = url.host {
            return host
        }
        return urlString
    }
}
