import Foundation

struct VaultHeader: Codable {
    let version: UInt16
    let vaultId: UUID
    let createdAt: Date
    let kdfParams: KDFParams
    let salt: Data
    let encryptedVaultKey: Data
    let encryptedAuthKey: Data

    init(version: UInt16 = 1, vaultId: UUID = UUID(), createdAt: Date = Date(), kdfParams: KDFParams = .default, salt: Data, encryptedVaultKey: Data, encryptedAuthKey: Data) {
        self.version = version
        self.vaultId = vaultId
        self.createdAt = createdAt
        self.kdfParams = kdfParams
        self.salt = salt
        self.encryptedVaultKey = encryptedVaultKey
        self.encryptedAuthKey = encryptedAuthKey
    }
}

struct KDFParams: Codable {
    let algorithm: KDFAlgorithm
    let memory: UInt32
    let iterations: UInt32
    let parallelism: UInt32

    static let `default` = KDFParams(
        algorithm: .argon2id,
        memory: 131072,
        iterations: 3,
        parallelism: 4
    )

    static let lightweight = KDFParams(
        algorithm: .pbkdf2,
        memory: 0,
        iterations: 600_000,
        parallelism: 1
    )
}

enum KDFAlgorithm: Int, Codable {
    case argon2id = 0
    case pbkdf2 = 1
}
