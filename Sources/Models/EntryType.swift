import Foundation

enum EntryType: Int, Codable, CaseIterable, Identifiable {
    case login = 1
    case secureNote = 2
    case creditCard = 3
    case identity = 4
    case sshKey = 5
    case apiCredential = 6

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .login: "Login"
        case .secureNote: "Secure Note"
        case .creditCard: "Credit Card"
        case .identity: "Identity"
        case .sshKey: "SSH Key"
        case .apiCredential: "API Credential"
        }
    }

    var systemImage: String {
        switch self {
        case .login: "person.crop.circle.fill"
        case .secureNote: "lock.doc.fill"
        case .creditCard: "creditcard.fill"
        case .identity: "person.text.rectangle.fill"
        case .sshKey: "terminal.fill"
        case .apiCredential: "key.fill"
        }
    }
}
