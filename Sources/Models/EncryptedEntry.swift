import Foundation

struct EncryptedEntry: Codable, Identifiable {
    let id: UUID
    let nonce: Data
    let ciphertext: Data
    let tag: Data
    let wrappedEntryKey: Data
    let modifiedAt: Date
}
