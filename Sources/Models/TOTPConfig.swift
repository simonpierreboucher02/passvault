import Foundation

struct TOTPConfig: Codable, Hashable {
    var secret: Data
    var issuer: String
    var account: String
    var algorithm: TOTPAlgorithm
    var digits: Int
    var period: TimeInterval

    init(secret: Data, issuer: String = "", account: String = "", algorithm: TOTPAlgorithm = .sha1, digits: Int = 6, period: TimeInterval = 30) {
        self.secret = secret
        self.issuer = issuer
        self.account = account
        self.algorithm = algorithm
        self.digits = digits
        self.period = period
    }
}

enum TOTPAlgorithm: Int, Codable, CaseIterable, Hashable {
    case sha1 = 0
    case sha256 = 1
    case sha512 = 2

    var label: String {
        switch self {
        case .sha1: "SHA-1"
        case .sha256: "SHA-256"
        case .sha512: "SHA-512"
        }
    }
}
