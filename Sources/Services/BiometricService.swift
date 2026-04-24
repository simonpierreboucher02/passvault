import Foundation
import LocalAuthentication
import CryptoKit

enum BiometricError: LocalizedError {
    case notAvailable
    case authenticationFailed
    case cancelled
    case noStoredCredential
    case storeFailed

    var errorDescription: String? {
        switch self {
        case .notAvailable: "Biometric authentication not available"
        case .authenticationFailed: "Biometric authentication failed"
        case .cancelled: "Authentication cancelled"
        case .noStoredCredential: "No biometric credential stored"
        case .storeFailed: "Failed to store biometric credential"
        }
    }
}

@MainActor
final class BiometricService {
    static let shared = BiometricService()

    private static let enabledKey = "biometricEnabled"

    private var credentialFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("PassVault", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(".biometric_credential")
    }

    var isBiometricAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    var biometricType: LABiometryType {
        let context = LAContext()
        var error: NSError?
        context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return context.biometryType
    }

    var biometricLabel: String {
        switch biometricType {
        case .touchID: "Touch ID"
        case .opticID: "Optic ID"
        default: "Biometrics"
        }
    }

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    var hasStoredCredential: Bool {
        FileManager.default.fileExists(atPath: credentialFileURL.path)
    }

    // MARK: - Enable / Disable

    func enable(masterPassword: String) throws {
        let key = SymmetricKey(size: .bits256)
        let passwordData = Data(masterPassword.utf8)
        let sealedBox = try AES.GCM.seal(passwordData, using: key)
        guard let combined = sealedBox.combined else {
            throw BiometricError.storeFailed
        }

        let keyData = key.withUnsafeBytes { Data($0) }
        let stored = BiometricCredential(wrappingKey: keyData, ciphertext: combined)
        let encoded = try JSONEncoder().encode(stored)
        try encoded.write(to: credentialFileURL, options: [.atomic, .completeFileProtection])

        isEnabled = true
    }

    func disable() {
        try? FileManager.default.removeItem(at: credentialFileURL)
        isEnabled = false
    }

    // MARK: - Retrieve Stored Password

    func retrieveMasterPassword() async throws -> String {
        guard isEnabled, hasStoredCredential else {
            throw BiometricError.noStoredCredential
        }

        let authenticated = try await authenticate()
        guard authenticated else {
            throw BiometricError.authenticationFailed
        }

        let data = try Data(contentsOf: credentialFileURL)
        let stored = try JSONDecoder().decode(BiometricCredential.self, from: data)
        let key = SymmetricKey(data: stored.wrappingKey)
        let sealedBox = try AES.GCM.SealedBox(combined: stored.ciphertext)
        let decrypted = try AES.GCM.open(sealedBox, using: key)

        guard let password = String(data: decrypted, encoding: .utf8) else {
            throw BiometricError.authenticationFailed
        }
        return password
    }

    // MARK: - Authenticate

    func authenticate(reason: String = "Unlock your PassVault") async throws -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Use Master Password"
        context.touchIDAuthenticationAllowableReuseDuration = 0

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw BiometricError.notAvailable
        }

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel, .systemCancel:
                throw BiometricError.cancelled
            default:
                throw BiometricError.authenticationFailed
            }
        }
    }
}

private struct BiometricCredential: Codable {
    let wrappingKey: Data
    let ciphertext: Data
}
