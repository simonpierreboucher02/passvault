import Foundation

struct SecureNoteData: Codable, Hashable {
    var content: String
    var contentType: NoteType

    init(content: String = "", contentType: NoteType = .plaintext) {
        self.content = content
        self.contentType = contentType
    }

    enum NoteType: Int, Codable, CaseIterable {
        case plaintext = 0
        case markdown = 1

        var label: String {
            switch self {
            case .plaintext: "Plain Text"
            case .markdown: "Markdown"
            }
        }
    }
}
