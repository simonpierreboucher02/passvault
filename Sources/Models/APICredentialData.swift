import Foundation

struct APICredentialData: Codable, Hashable {
    var apiKey: String
    var apiSecret: String?
    var endpoint: String?
    var authType: String?

    init(apiKey: String = "", apiSecret: String? = nil, endpoint: String? = nil, authType: String? = nil) {
        self.apiKey = apiKey
        self.apiSecret = apiSecret
        self.endpoint = endpoint
        self.authType = authType
    }
}
