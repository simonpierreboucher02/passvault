import SwiftUI

enum SidebarCategory: Hashable, Identifiable {
    case allItems
    case favorites
    case type(EntryType)
    case tag(String)

    var id: String {
        switch self {
        case .allItems: "all"
        case .favorites: "favorites"
        case .type(let t): "type-\(t.rawValue)"
        case .tag(let t): "tag-\(t)"
        }
    }

    var label: String {
        switch self {
        case .allItems: "All Items"
        case .favorites: "Favorites"
        case .type(let t): t.label
        case .tag(let t): t
        }
    }

    var systemImage: String {
        switch self {
        case .allItems: "tray.full.fill"
        case .favorites: "star.fill"
        case .type(let t): t.systemImage
        case .tag: "tag.fill"
        }
    }
}

struct SidebarView: View {
    @Binding var selectedCategory: SidebarCategory?
    @State private var vault = VaultService.shared

    var body: some View {
        List(selection: $selectedCategory) {
            Section("Vault") {
                sidebarRow(.allItems, count: vault.entries.count)
                sidebarRow(.favorites, count: vault.favorites.count)
            }

            Section("Categories") {
                ForEach(EntryType.allCases) { type in
                    sidebarRow(.type(type), count: vault.entries(for: type).count)
                }
            }

            if !vault.allTags.isEmpty {
                Section("Tags") {
                    ForEach(vault.allTags, id: \.self) { tag in
                        sidebarRow(.tag(tag), count: vault.entries(tag: tag).count)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(.green)
                Text("\(vault.entries.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
    }

    private func sidebarRow(_ category: SidebarCategory, count: Int) -> some View {
        Label {
            HStack {
                Text(category.label)
                Spacer()
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        } icon: {
            Image(systemName: category.systemImage)
        }
        .tag(category)
    }
}
