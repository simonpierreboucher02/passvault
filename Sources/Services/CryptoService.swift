import Foundation
import CryptoKit

enum CryptoError: LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case invalidData
    case keyDerivationFailed
    case randomGenerationFailed

    var errorDescription: String? {
        switch self {
        case .encryptionFailed: "Encryption failed"
        case .decryptionFailed: "Decryption failed"
        case .invalidData: "Invalid data"
        case .keyDerivationFailed: "Key derivation failed"
        case .randomGenerationFailed: "Secure random generation failed"
        }
    }
}

enum CryptoService {
    // MARK: - AES-256-GCM

    static func encrypt(data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw CryptoError.encryptionFailed
        }
        return combined
    }

    static func decrypt(combined: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(sealedBox, using: key)
    }

    // MARK: - ChaCha20-Poly1305

    static func encryptChaCha(data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try ChaChaPoly.seal(data, using: key)
        return sealedBox.combined
    }

    static func decryptChaCha(combined: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try ChaChaPoly.SealedBox(combined: combined)
        return try ChaChaPoly.open(sealedBox, using: key)
    }

    // MARK: - HKDF Key Derivation

    static func deriveSubKey(from masterKey: SymmetricKey, salt: String, info: String, outputByteCount: Int = 32) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: masterKey,
            salt: Data(salt.utf8),
            info: Data(info.utf8),
            outputByteCount: outputByteCount
        )
    }

    static func deriveEncryptionKey(from masterKey: SymmetricKey) -> SymmetricKey {
        deriveSubKey(from: masterKey, salt: "encryption", info: "PassVault-v1-encryption")
    }

    static func deriveAuthKey(from masterKey: SymmetricKey) -> SymmetricKey {
        deriveSubKey(from: masterKey, salt: "authentication", info: "PassVault-v1-auth")
    }

    static func deriveVerificationKey(from masterKey: SymmetricKey) -> SymmetricKey {
        deriveSubKey(from: masterKey, salt: "verification", info: "PassVault-v1-verify")
    }

    // MARK: - HMAC

    static func computeHMAC(for data: Data, using key: SymmetricKey) -> Data {
        let mac = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return Data(mac)
    }

    static func verifyHMAC(_ mac: Data, for data: Data, using key: SymmetricKey) -> Bool {
        HMAC<SHA256>.isValidAuthenticationCode(mac, authenticating: data, using: key)
    }

    // MARK: - Verification Tag

    static func createVerificationTag(from masterKey: SymmetricKey) -> Data {
        let verificationKey = deriveVerificationKey(from: masterKey)
        return computeHMAC(for: Data("PassVault-verification-constant".utf8), using: verificationKey)
    }

    // MARK: - Random Data

    static func randomBytes(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else {
            throw CryptoError.randomGenerationFailed
        }
        return Data(bytes)
    }

    static func randomKey() throws -> SymmetricKey {
        SymmetricKey(data: try randomBytes(count: 32))
    }

    // MARK: - Key Wrapping

    static func wrapKey(_ keyToWrap: SymmetricKey, with wrappingKey: SymmetricKey) throws -> Data {
        let keyData = keyToWrap.withUnsafeBytes { Data($0) }
        return try encrypt(data: keyData, using: wrappingKey)
    }

    static func unwrapKey(_ wrappedKey: Data, with wrappingKey: SymmetricKey) throws -> SymmetricKey {
        let keyData = try decrypt(combined: wrappedKey, using: wrappingKey)
        return SymmetricKey(data: keyData)
    }
}
