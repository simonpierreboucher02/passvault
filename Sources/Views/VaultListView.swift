import SwiftUI

struct VaultListView: View {
    let selectedCategory: SidebarCategory?
    @Binding var selectedEntryID: UUID?
    @Binding var searchText: String
    @State private var vault = VaultService.shared
    @State private var sortOrder: SortOrder = .title

    enum SortOrder: String, CaseIterable {
        case title = "Title"
        case dateModified = "Date Modified"
        case dateCreated = "Date Created"
    }

    private var filteredEntries: [VaultEntry] {
        var result: [VaultEntry]

        if !searchText.isEmpty {
            result = vault.search(query: searchText)
        } else {
            switch selectedCategory {
            case .allItems, nil:
                result = vault.entries
            case .favorites:
                result = vault.favorites
            case .type(let type):
                result = vault.entries(for: type)
            case .tag(let tag):
                result = vault.entries(tag: tag)
            }
        }

        switch sortOrder {
        case .title:
            result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .dateModified:
            result.sort { $0.modifiedAt > $1.modifiedAt }
        case .dateCreated:
            result.sort { $0.createdAt > $1.createdAt }
        }

        return result
    }

    var body: some View {
        List(selection: $selectedEntryID) {
            ForEach(filteredEntries) { entry in
                EntryRowView(entry: entry)
                    .tag(entry.id)
                    .contextMenu {
                        if let password = entry.login?.password, !password.isEmpty {
                            Button("Copy Password") {
                                ClipboardService.shared.copySecurely(password)
                            }
                        }
                        if let username = entry.login?.username, !username.isEmpty {
                            Button("Copy Username") {
                                ClipboardService.shared.copySecurely(username)
                            }
                        }
                        Divider()
                        Button("Toggle Favorite") {
                            var updated = entry
                            updated.favorite.toggle()
                            try? vault.updateEntry(updated)
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            try? vault.deleteEntry(id: entry.id)
                            if selectedEntryID == entry.id {
                                selectedEntryID = nil
                            }
                        }
                    }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .overlay {
            if filteredEntries.isEmpty {
                ContentUnavailableView {
                    Label(searchText.isEmpty ? "No Entries" : "No Results", systemImage: "magnifyingglass")
                } description: {
                    Text(searchText.isEmpty ? "Create a new entry to get started" : "Try a different search term")
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Picker("Sort", selection: $sortOrder) {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }
}

struct EntryRowView: View {
    let entry: VaultEntry
    @State private var appearance = AppearanceService.shared

    var body: some View {
        HStack(spacing: appearance.compactList ? 8 : 12) {
            if appearance.showEntryIcons {
                Image(systemName: entry.type.systemImage)
                    .font(appearance.compactList ? .body : .title3)
                    .foregroundStyle(iconColor)
                    .frame(width: appearance.compactList ? 20 : 28, height: appearance.compactList ? 20 : 28)
            }

            VStack(alignment: .leading, spacing: appearance.compactList ? 1 : 2) {
                HStack(spacing: 4) {
                    Text(entry.title)
                        .font(.system(size: 13 * appearance.fontSize.scale))
                        .fontWeight(.medium)
                        .lineLimit(1)
                    if entry.favorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
                if !entry.displaySubtitle.isEmpty && !appearance.compactList {
                    Text(entry.displaySubtitle)
                        .font(.system(size: 11 * appearance.fontSize.scale))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if entry.login?.totp != nil {
                Image(systemName: "clock.badge.checkmark")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, appearance.compactList ? 1 : 4)
    }

    private var iconColor: Color {
        switch entry.type {
        case .login: .blue
        case .secureNote: .orange
        case .creditCard: .purple
        case .identity: .green
        case .sshKey: .red
        case .apiCredential: .cyan
        }
    }
}
