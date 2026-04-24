import Foundation
import CryptoKit
import CommonCrypto

enum KDFService {
    static func deriveKey(password: String, salt: Data, params: KDFParams) throws -> SymmetricKey {
        switch params.algorithm {
        case .argon2id:
            return try deriveKeyPBKDF2(password: password, salt: salt, iterations: 600_000)
        case .pbkdf2:
            return try deriveKeyPBKDF2(password: password, salt: salt, iterations: UInt32(params.iterations))
        }
    }

    private static func deriveKeyPBKDF2(password: String, salt: Data, iterations: UInt32) throws -> SymmetricKey {
        var derivedKey = [UInt8](repeating: 0, count: 32)
        let passwordBytes = Array(password.utf8)

        let status = salt.withUnsafeBytes { saltPtr -> Int32 in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                passwordBytes,
                passwordBytes.count,
                saltPtr.bindMemory(to: UInt8.self).baseAddress!,
                salt.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                iterations,
                &derivedKey,
                32
            )
        }

        guard status == kCCSuccess else {
            throw CryptoError.keyDerivationFailed
        }

        let key = SymmetricKey(data: Data(derivedKey))
        SecureMemory.zero(&derivedKey)
        return key
    }

    static func generateSalt() throws -> Data {
        try CryptoService.randomBytes(count: 32)
    }
}
