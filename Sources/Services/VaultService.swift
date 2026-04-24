import Foundation
import CryptoKit

enum VaultError: LocalizedError {
    case notUnlocked
    case invalidPassword
    case integrityCheckFailed
    case vaultNotFound
    case corruptedVault
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notUnlocked: "Vault is locked"
        case .invalidPassword: "Invalid master password"
        case .integrityCheckFailed: "Vault integrity check failed"
        case .vaultNotFound: "Vault file not found"
        case .corruptedVault: "Vault file is corrupted"
        case .saveFailed(let e): "Failed to save vault: \(e.localizedDescription)"
        }
    }
}

struct VaultFile: Codable {
    var header: VaultHeader
    var entries: [VaultEntry]
    var verificationTag: Data
}

struct VaultEnvelope: Codable {
    let salt: Data
    let kdfParams: KDFParams
    let payload: Data
}

@MainActor
@Observable
final class VaultService {
    static let shared = VaultService()

    private(set) var isUnlocked = false
    private(set) var entries: [VaultEntry] = []
    private var vaultKey: SymmetricKey?
    private var masterKey: SymmetricKey?
    private var currentHeader: VaultHeader?

    var vaultFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("PassVault", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("vault.pvlt")
    }

    var vaultExists: Bool {
        FileManager.default.fileExists(atPath: vaultFileURL.path)
    }

    // MARK: - Create Vault

    func createVault(masterPassword: String) throws {
        let salt = try KDFService.generateSalt()
        let derivedKey = try KDFService.deriveKey(password: masterPassword, salt: salt, params: .default)

        let vaultKey = try CryptoService.randomKey()
        let authKey = try CryptoService.randomKey()

        let encryptionKey = CryptoService.deriveEncryptionKey(from: derivedKey)
        let encryptedVaultKey = try CryptoService.wrapKey(vaultKey, with: encryptionKey)
        let encryptedAuthKey = try CryptoService.wrapKey(authKey, with: encryptionKey)

        let header = VaultHeader(
            salt: salt,
            encryptedVaultKey: encryptedVaultKey,
            encryptedAuthKey: encryptedAuthKey
        )

        let verificationTag = CryptoService.createVerificationTag(from: derivedKey)
        let vaultFile = VaultFile(header: header, entries: [], verificationTag: verificationTag)

        self.masterKey = derivedKey
        self.vaultKey = vaultKey
        self.currentHeader = header
        self.entries = []
        self.isUnlocked = true

        try saveToFile(vaultFile: vaultFile, masterKey: derivedKey, salt: salt)
    }

    // MARK: - Unlock

    func unlock(masterPassword: String) throws {
        guard FileManager.default.fileExists(atPath: vaultFileURL.path) else {
            throw VaultError.vaultNotFound
        }

        let fileData = try Data(contentsOf: vaultFileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let envelope: VaultEnvelope
        do {
            envelope = try decoder.decode(VaultEnvelope.self, from: fileData)
        } catch {
            throw VaultError.corruptedVault
        }

        let derivedKey = try KDFService.deriveKey(
            password: masterPassword,
            salt: envelope.salt,
            params: envelope.kdfParams
        )
        let encryptionKey = CryptoService.deriveEncryptionKey(from: derivedKey)

        let decryptedData: Data
        do {
            decryptedData = try CryptoService.decrypt(combined: envelope.payload, using: encryptionKey)
        } catch {
            throw VaultError.invalidPassword
        }

        let vaultFile: VaultFile
        do {
            vaultFile = try decoder.decode(VaultFile.self, from: decryptedData)
        } catch {
            throw VaultError.corruptedVault
        }

        let expectedTag = CryptoService.createVerificationTag(from: derivedKey)
        guard expectedTag == vaultFile.verificationTag else {
            throw VaultError.invalidPassword
        }

        let vaultKey = try CryptoService.unwrapKey(vaultFile.header.encryptedVaultKey, with: encryptionKey)

        self.masterKey = derivedKey
        self.vaultKey = vaultKey
        self.currentHeader = vaultFile.header
        self.entries = vaultFile.entries
        self.isUnlocked = true
    }

    // MARK: - Verify Password (without changing state)

    func verifyPassword(_ password: String) throws -> Bool {
        guard FileManager.default.fileExists(atPath: vaultFileURL.path) else {
            throw VaultError.vaultNotFound
        }

        let fileData = try Data(contentsOf: vaultFileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let envelope = try decoder.decode(VaultEnvelope.self, from: fileData)
        let derivedKey = try KDFService.deriveKey(
            password: password,
            salt: envelope.salt,
            params: envelope.kdfParams
        )
        let encryptionKey = CryptoService.deriveEncryptionKey(from: derivedKey)

        do {
            let _ = try CryptoService.decrypt(combined: envelope.payload, using: encryptionKey)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Lock

    func lock() {
        masterKey = nil
        vaultKey = nil
        currentHeader = nil
        entries = []
        isUnlocked = false
    }

    // MARK: - CRUD Operations

    func addEntry(_ entry: VaultEntry) throws {
        guard isUnlocked else { throw VaultError.notUnlocked }
        entries.append(entry)
        try save()
    }

    func updateEntry(_ entry: VaultEntry) throws {
        guard isUnlocked else { throw VaultError.notUnlocked }
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        var updated = entry
        updated.modifiedAt = Date()
        entries[index] = updated
        try save()
    }

    func deleteEntry(id: UUID) throws {
        guard isUnlocked else { throw VaultError.notUnlocked }
        entries.removeAll { $0.id == id }
        try save()
    }

    func deleteEntries(ids: Set<UUID>) throws {
        guard isUnlocked else { throw VaultError.notUnlocked }
        entries.removeAll { ids.contains($0.id) }
        try save()
    }

    // MARK: - Search

    func search(query: String) -> [VaultEntry] {
        guard !query.isEmpty else { return entries }
        let lowered = query.lowercased()
        return entries.filter { entry in
            entry.title.lowercased().contains(lowered) ||
            entry.displaySubtitle.lowercased().contains(lowered) ||
            entry.tags.contains { $0.lowercased().contains(lowered) } ||
            entry.notes?.lowercased().contains(lowered) == true ||
            entry.login?.urls.contains { $0.url.lowercased().contains(lowered) } == true
        }
    }

    func entries(for type: EntryType) -> [VaultEntry] {
        entries.filter { $0.type == type }
    }

    var favorites: [VaultEntry] {
        entries.filter(\.favorite)
    }

    var allTags: [String] {
        Array(Set(entries.flatMap(\.tags))).sorted()
    }

    func entries(tag: String) -> [VaultEntry] {
        entries.filter { $0.tags.contains(tag) }
    }

    // MARK: - Import

    func importEntries(_ newEntries: [VaultEntry]) throws {
        guard isUnlocked else { throw VaultError.notUnlocked }
        entries.append(contentsOf: newEntries)
        try save()
    }

    // MARK: - Persistence

    private func save() throws {
        guard let masterKey, let currentHeader else { throw VaultError.notUnlocked }
        let verificationTag = CryptoService.createVerificationTag(from: masterKey)
        let vaultFile = VaultFile(header: currentHeader, entries: entries, verificationTag: verificationTag)
        try saveToFile(vaultFile: vaultFile, masterKey: masterKey, salt: currentHeader.salt)
    }

    private func saveToFile(vaultFile: VaultFile, masterKey: SymmetricKey, salt: Data) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let vaultData = try encoder.encode(vaultFile)
        let encryptionKey = CryptoService.deriveEncryptionKey(from: masterKey)
        let encrypted = try CryptoService.encrypt(data: vaultData, using: encryptionKey)

        let envelope = VaultEnvelope(
            salt: salt,
            kdfParams: vaultFile.header.kdfParams,
            payload: encrypted
        )

        let envelopeData = try encoder.encode(envelope)
        try envelopeData.write(to: vaultFileURL, options: .atomic)
    }
}
