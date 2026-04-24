import Foundation

struct VaultEntry: Codable, Identifiable, Hashable {
    let id: UUID
    var type: EntryType
    var title: String
    var subtitle: String?
    var favorite: Bool
    var tags: [String]

    var login: LoginData?
    var secureNote: SecureNoteData?
    var creditCard: CreditCardData?
    var identity: IdentityData?
    var sshKey: SSHKeyData?
    var apiCredential: APICredentialData?

    var customFields: [CustomField]
    var notes: String?

    let createdAt: Date
    var modifiedAt: Date
    var lastAccessedAt: Date?
    var accessCount: Int

    var passwordHistory: [PasswordHistoryEntry]
    var expiresAt: Date?

    init(
        id: UUID = UUID(),
        type: EntryType,
        title: String = "",
        subtitle: String? = nil,
        favorite: Bool = false,
        tags: [String] = [],
        login: LoginData? = nil,
        secureNote: SecureNoteData? = nil,
        creditCard: CreditCardData? = nil,
        identity: IdentityData? = nil,
        sshKey: SSHKeyData? = nil,
        apiCredential: APICredentialData? = nil,
        customFields: [CustomField] = [],
        notes: String? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        lastAccessedAt: Date? = nil,
        accessCount: Int = 0,
        passwordHistory: [PasswordHistoryEntry] = [],
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.favorite = favorite
        self.tags = tags
        self.login = login
        self.secureNote = secureNote
        self.creditCard = creditCard
        self.identity = identity
        self.sshKey = sshKey
        self.apiCredential = apiCredential
        self.customFields = customFields
        self.notes = notes
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.lastAccessedAt = lastAccessedAt
        self.accessCount = accessCount
        self.passwordHistory = passwordHistory
        self.expiresAt = expiresAt
    }

    var displaySubtitle: String {
        if let subtitle { return subtitle }
        switch type {
        case .login: return login?.username ?? ""
        case .secureNote: return String(secureNote?.content.prefix(50) ?? "")
        case .creditCard: return creditCard?.maskedNumber ?? ""
        case .identity: return identity?.fullName ?? ""
        case .sshKey: return sshKey?.keyType ?? ""
        case .apiCredential: return apiCredential?.endpoint ?? ""
        }
    }

    static func new(type: EntryType) -> VaultEntry {
        var entry = VaultEntry(type: type)
        switch type {
        case .login: entry.login = LoginData()
        case .secureNote: entry.secureNote = SecureNoteData()
        case .creditCard: entry.creditCard = CreditCardData()
        case .identity: entry.identity = IdentityData()
        case .sshKey: entry.sshKey = SSHKeyData()
        case .apiCredential: entry.apiCredential = APICredentialData()
        }
        return entry
    }
}

struct PasswordHistoryEntry: Codable, Hashable, Identifiable {
    let id: UUID
    let password: String
    let changedAt: Date

    init(id: UUID = UUID(), password: String, changedAt: Date = Date()) {
        self.id = id
        self.password = password
        self.changedAt = changedAt
    }
}
