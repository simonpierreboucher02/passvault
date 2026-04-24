import Testing
import Foundation
import CryptoKit
@testable import PassVault

@Suite("CryptoService")
struct CryptoServiceTests {

    // MARK: - AES-256-GCM

    @Test("AES-GCM encrypt/decrypt round-trip")
    func aesGCMRoundTrip() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("Hello PassVault! This is a secret message.".utf8)

        let encrypted = try CryptoService.encrypt(data: plaintext, using: key)
        let decrypted = try CryptoService.decrypt(combined: encrypted, using: key)

        #expect(decrypted == plaintext)
    }

    @Test("AES-GCM produces different ciphertext each time (unique nonce)")
    func aesGCMUniqueNonce() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("same data".utf8)

        let encrypted1 = try CryptoService.encrypt(data: plaintext, using: key)
        let encrypted2 = try CryptoService.encrypt(data: plaintext, using: key)

        #expect(encrypted1 != encrypted2)
    }

    @Test("AES-GCM decrypt with wrong key fails")
    func aesGCMWrongKey() throws {
        let key1 = SymmetricKey(size: .bits256)
        let key2 = SymmetricKey(size: .bits256)
        let plaintext = Data("secret".utf8)

        let encrypted = try CryptoService.encrypt(data: plaintext, using: key1)

        #expect(throws: (any Error).self) {
            try CryptoService.decrypt(combined: encrypted, using: key2)
        }
    }

    @Test("AES-GCM detects tampered ciphertext")
    func aesGCMTampered() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("important data".utf8)

        var encrypted = try CryptoService.encrypt(data: plaintext, using: key)
        encrypted[encrypted.count / 2] ^= 0xFF

        #expect(throws: (any Error).self) {
            try CryptoService.decrypt(combined: encrypted, using: key)
        }
    }

    @Test("AES-GCM handles empty data")
    func aesGCMEmptyData() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data()

        let encrypted = try CryptoService.encrypt(data: plaintext, using: key)
        let decrypted = try CryptoService.decrypt(combined: encrypted, using: key)

        #expect(decrypted == plaintext)
    }

    @Test("AES-GCM handles large data")
    func aesGCMLargeData() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = try CryptoService.randomBytes(count: 1_000_000)

        let encrypted = try CryptoService.encrypt(data: plaintext, using: key)
        let decrypted = try CryptoService.decrypt(combined: encrypted, using: key)

        #expect(decrypted == plaintext)
    }

    // MARK: - ChaCha20-Poly1305

    @Test("ChaCha20 encrypt/decrypt round-trip")
    func chacha20RoundTrip() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("ChaCha20 test message".utf8)

        let encrypted = try CryptoService.encryptChaCha(data: plaintext, using: key)
        let decrypted = try CryptoService.decryptChaCha(combined: encrypted, using: key)

        #expect(decrypted == plaintext)
    }

    @Test("ChaCha20 decrypt with wrong key fails")
    func chacha20WrongKey() throws {
        let key1 = SymmetricKey(size: .bits256)
        let key2 = SymmetricKey(size: .bits256)
        let plaintext = Data("secret".utf8)

        let encrypted = try CryptoService.encryptChaCha(data: plaintext, using: key1)

        #expect(throws: (any Error).self) {
            try CryptoService.decryptChaCha(combined: encrypted, using: key2)
        }
    }

    // MARK: - HKDF Key Derivation

    @Test("HKDF derives deterministic sub-keys")
    func hkdfDeterministic() {
        let master = SymmetricKey(size: .bits256)
        let key1 = CryptoService.deriveSubKey(from: master, salt: "test", info: "info1")
        let key2 = CryptoService.deriveSubKey(from: master, salt: "test", info: "info1")

        let data1 = key1.withUnsafeBytes { Data($0) }
        let data2 = key2.withUnsafeBytes { Data($0) }
        #expect(data1 == data2)
    }

    @Test("HKDF different info produces different keys")
    func hkdfDifferentInfo() {
        let master = SymmetricKey(size: .bits256)
        let encKey = CryptoService.deriveEncryptionKey(from: master)
        let authKey = CryptoService.deriveAuthKey(from: master)

        let encData = encKey.withUnsafeBytes { Data($0) }
        let authData = authKey.withUnsafeBytes { Data($0) }
        #expect(encData != authData)
    }

    @Test("All three derived keys are distinct")
    func allDerivedKeysDistinct() {
        let master = SymmetricKey(size: .bits256)
        let enc = CryptoService.deriveEncryptionKey(from: master).withUnsafeBytes { Data($0) }
        let auth = CryptoService.deriveAuthKey(from: master).withUnsafeBytes { Data($0) }
        let verify = CryptoService.deriveVerificationKey(from: master).withUnsafeBytes { Data($0) }

        #expect(enc != auth)
        #expect(auth != verify)
        #expect(enc != verify)
    }

    // MARK: - HMAC

    @Test("HMAC compute and verify")
    func hmacRoundTrip() {
        let key = SymmetricKey(size: .bits256)
        let data = Data("test data for HMAC".utf8)

        let mac = CryptoService.computeHMAC(for: data, using: key)
        #expect(CryptoService.verifyHMAC(mac, for: data, using: key))
    }

    @Test("HMAC fails with wrong data")
    func hmacWrongData() {
        let key = SymmetricKey(size: .bits256)
        let data = Data("original".utf8)
        let tampered = Data("tampered".utf8)

        let mac = CryptoService.computeHMAC(for: data, using: key)
        #expect(!CryptoService.verifyHMAC(mac, for: tampered, using: key))
    }

    @Test("HMAC fails with wrong key")
    func hmacWrongKey() {
        let key1 = SymmetricKey(size: .bits256)
        let key2 = SymmetricKey(size: .bits256)
        let data = Data("test".utf8)

        let mac = CryptoService.computeHMAC(for: data, using: key1)
        #expect(!CryptoService.verifyHMAC(mac, for: data, using: key2))
    }

    // MARK: - Verification Tag

    @Test("Verification tag is deterministic")
    func verificationTagDeterministic() {
        let key = SymmetricKey(size: .bits256)
        let tag1 = CryptoService.createVerificationTag(from: key)
        let tag2 = CryptoService.createVerificationTag(from: key)

        #expect(tag1 == tag2)
    }

    @Test("Different keys produce different verification tags")
    func verificationTagDifferentKeys() {
        let key1 = SymmetricKey(size: .bits256)
        let key2 = SymmetricKey(size: .bits256)

        let tag1 = CryptoService.createVerificationTag(from: key1)
        let tag2 = CryptoService.createVerificationTag(from: key2)

        #expect(tag1 != tag2)
    }

    // MARK: - Random Bytes

    @Test("Random bytes generates correct length")
    func randomBytesLength() throws {
        for size in [16, 32, 64, 128] {
            let bytes = try CryptoService.randomBytes(count: size)
            #expect(bytes.count == size)
        }
    }

    @Test("Random bytes are non-deterministic")
    func randomBytesUnique() throws {
        let a = try CryptoService.randomBytes(count: 32)
        let b = try CryptoService.randomBytes(count: 32)
        #expect(a != b)
    }

    @Test("Random key is 256-bit")
    func randomKeySize() throws {
        let key = try CryptoService.randomKey()
        let size = key.withUnsafeBytes { $0.count }
        #expect(size == 32)
    }

    // MARK: - Key Wrapping

    @Test("Key wrap/unwrap round-trip")
    func keyWrapRoundTrip() throws {
        let wrappingKey = SymmetricKey(size: .bits256)
        let originalKey = try CryptoService.randomKey()

        let wrapped = try CryptoService.wrapKey(originalKey, with: wrappingKey)
        let unwrapped = try CryptoService.unwrapKey(wrapped, with: wrappingKey)

        let originalData = originalKey.withUnsafeBytes { Data($0) }
        let unwrappedData = unwrapped.withUnsafeBytes { Data($0) }
        #expect(originalData == unwrappedData)
    }

    @Test("Key unwrap with wrong key fails")
    func keyUnwrapWrongKey() throws {
        let wrappingKey1 = SymmetricKey(size: .bits256)
        let wrappingKey2 = SymmetricKey(size: .bits256)
        let originalKey = try CryptoService.randomKey()

        let wrapped = try CryptoService.wrapKey(originalKey, with: wrappingKey1)

        #expect(throws: (any Error).self) {
            try CryptoService.unwrapKey(wrapped, with: wrappingKey2)
        }
    }
}
