import Foundation

struct SSHKeyData: Codable, Hashable {
    var publicKey: String
    var privateKey: String
    var fingerprint: String
    var keyType: String
    var comment: String?

    init(publicKey: String = "", privateKey: String = "", fingerprint: String = "", keyType: String = "ed25519", comment: String? = nil) {
        self.publicKey = publicKey
        self.privateKey = privateKey
        self.fingerprint = fingerprint
        self.keyType = keyType
        self.comment = comment
    }
}
