import Foundation

struct LoginData: Codable, Hashable {
    var urls: [URLEntry]
    var username: String
    var password: String
    var email: String?
    var totp: TOTPConfig?

    init(urls: [URLEntry] = [], username: String = "", password: String = "", email: String? = nil, totp: TOTPConfig? = nil) {
        self.urls = urls
        self.username = username
        self.password = password
        self.email = email
        self.totp = totp
    }
}

struct URLEntry: Codable, Hashable, Identifiable {
    let id: UUID
    var url: String
    var matchType: URLMatchType

    init(id: UUID = UUID(), url: String = "", matchType: URLMatchType = .domain) {
        self.id = id
        self.url = url
        self.matchType = matchType
    }

    enum URLMatchType: Int, Codable, CaseIterable {
        case domain = 0
        case host = 1
        case startsWith = 2
        case exact = 3
        case regex = 4
        case never = 5

        var label: String {
            switch self {
            case .domain: "Base Domain"
            case .host: "Exact Host"
            case .startsWith: "Starts With"
            case .exact: "Exact URL"
            case .regex: "Regex"
            case .never: "Never"
            }
        }
    }
}
