import SwiftUI

struct ContentView: View {
    @State private var vault = VaultService.shared
    @State private var autoLock = AutoLockService.shared

    var body: some View {
        Group {
            if vault.isUnlocked {
                MainView()
            } else {
                UnlockView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: vault.isUnlocked)
        .onAppear {
            autoLock.onLock = { [vault] in
                vault.lock()
            }
            autoLock.start()
        }
    }
}

struct MainView: View {
    @State private var vault = VaultService.shared
    @State private var appearance = AppearanceService.shared
    @State private var selectedCategory: SidebarCategory? = .allItems
    @State private var selectedEntryID: UUID?
    @State private var searchText = ""
    @State private var showingNewEntry = false
    @State private var newEntryType: EntryType = .login
    @State private var showingPasswordGenerator = false
    @State private var showingImportExport = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedCategory: $selectedCategory)
                .navigationSplitViewColumnWidth(min: 150, ideal: appearance.sidebarSize.width, max: 280)
        } content: {
            VaultListView(
                selectedCategory: selectedCategory,
                selectedEntryID: $selectedEntryID,
                searchText: $searchText
            )
            .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
        } detail: {
            if let entryID = selectedEntryID,
               let entry = vault.entries.first(where: { $0.id == entryID }) {
                EntryDetailView(entry: entry)
                    .id(entryID)
            } else {
                emptyState
            }
        }
        .searchable(text: $searchText, prompt: "Search vault...")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showingPasswordGenerator = true
                } label: {
                    Label("Generate Password", systemImage: "wand.and.stars")
                }
                .keyboardShortcut("g", modifiers: .command)

                Menu {
                    ForEach(EntryType.allCases) { type in
                        Button {
                            newEntryType = type
                            showingNewEntry = true
                        } label: {
                            Label(type.label, systemImage: type.systemImage)
                        }
                    }
                } label: {
                    Label("New Entry", systemImage: "plus")
                }

                Menu {
                    Button("Import...") {
                        showingImportExport = true
                    }
                    Button("Lock Vault") {
                        vault.lock()
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingNewEntry) {
            NewEntrySheet(type: newEntryType) { entry in
                try? vault.addEntry(entry)
                selectedEntryID = entry.id
            }
        }
        .sheet(isPresented: $showingPasswordGenerator) {
            PasswordGeneratorView()
        }
        .sheet(isPresented: $showingImportExport) {
            ImportExportView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .createNewEntry)) { notif in
            if let type = notif.object as? EntryType {
                newEntryType = type
                showingNewEntry = true
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            Text("Select an entry")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Choose an entry from the list or create a new one")
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
