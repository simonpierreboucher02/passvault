import Foundation

struct CustomField: Codable, Hashable, Identifiable {
    let id: UUID
    var name: String
    var value: String
    var type: FieldType
    var isHidden: Bool

    init(id: UUID = UUID(), name: String = "", value: String = "", type: FieldType = .text, isHidden: Bool = false) {
        self.id = id
        self.name = name
        self.value = value
        self.type = type
        self.isHidden = isHidden
    }

    enum FieldType: Int, Codable, CaseIterable {
        case text = 0
        case hidden = 1
        case boolean = 2

        var label: String {
            switch self {
            case .text: "Text"
            case .hidden: "Hidden"
            case .boolean: "Boolean"
            }
        }
    }
}
