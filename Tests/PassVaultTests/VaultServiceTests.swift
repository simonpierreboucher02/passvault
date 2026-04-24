import Testing
import Foundation
@testable import PassVault

@Suite("VaultService", .serialized)
@MainActor
struct VaultServiceTests {

    private func cleanVault() {
        let vault = VaultService.shared
        if vault.isUnlocked { vault.lock() }
        try? FileManager.default.removeItem(at: vault.vaultFileURL)
    }

    // MARK: - Create Vault

    @Test("Create vault successfully")
    func createVault() throws {
        cleanVault()
        defer { cleanVault() }

        let vault = VaultService.shared
        #expect(!vault.vaultExists)

        try vault.createVault(masterPassword: "TestPassword123!")
        #expect(vault.isUnlocked)
        #expect(vault.vaultExists)
        #expect(vault.entries.isEmpty)
    }

    // MARK: - Unlock / Lock

    @Test("Unlock vault with correct password")
    func unlockCorrectPassword() throws {
        cleanVault()
        defer { cleanVault() }

        let vault = VaultService.shared
        try vault.createVault(masterPassword: "MySecurePass!")
        vault.lock()

        #expect(!vault.isUnlocked)

        try vault.unlock(masterPassword: "MySecurePass!")
        #expect(vault.isUnlocked)
    }

    @Test("Unlock vault with wrong password fails")
    func unlockWrongPassword() throws {
        cleanVault()
        defer { cleanVault() }

        let vault = VaultService.shared
        try vault.createVault(masterPassword: "CorrectPassword")
        vault.lock()

        #expect(throws: VaultError.self) {
            try vault.unlock(masterPassword: "WrongPassword")
        }
        #expect(!vault.isUnlocked)
    }

    @Test("Lock vault clears state")
    func lockClearsState() throws {
        cleanVault()
        defer { cleanVault() }

        let vault = VaultService.shared
        try vault.createVault(masterPassword: "TestPass123")
        let entry = VaultEntry.new(type: .login)
        try vault.addEntry(entry)

        #expect(!vault.entries.isEmpty)

        vault.lock()
        #expect(!vault.isUnlocked)
        #expect(vault.entries.isEmpty)
    }

    // MARK: - CRUD Operations

    @Test("Add entry")
    func addEntry() throws {
        cleanVault()
        defer { cleanVault() }

        let vault = VaultService.shared
        try vault.createVault(masterPassword: "TestPass")

        var entry = VaultEntry.new(type: .login)
        entry.title = "GitHub"
        entry.login = LoginData(
            urls: [URLEntry(url: "https://github.com")],
            username: "user@example.com",
            password: "secretpass123"
        )

        try vault.addEntry(entry)
        #expect(vault.entries.count == 1)
        #expect(vault.entries.first?.title == "GitHub")
        #expect(vault.entries.first?.login?.username == "user@example.com")
    }

    @Test("Update entry")
    func updateEntry() throws {
        cleanVault()
        defer { cleanVault() }

        let vault = VaultService.shared
        try vault.createVault(masterPassword: "TestPass")

        var entry = VaultEntry.new(type: .login)
        entry.title = "Original"
        try vault.addEntry(entry)

        var updated = entry
        updated.title = "Updated"
        try vault.updateEntry(updated)

        #expect(vault.entries.count == 1)
        #expect(vault.entries.first?.title == "Updated")
    }

    @Test("Delete entry")
    func deleteEntry() throws {
        cleanVault()
        defer { cleanVault() }

        let vault = VaultService.shared
        try vault.createVault(masterPassword: "TestPass")

        let entry = VaultEntry.new(type: .login)
        try vault.addEntry(entry)
        #expect(vault.entries.count == 1)

        try vault.deleteEntry(id: entry.id)
        #expect(vault.entries.isEmpty)
    }

    @Test("Delete multiple entries")
    func deleteMultipleEntries() throws {
        cleanVault()
        defer { cleanVault() }

        let vault = VaultService.shared
        try vault.createVault(masterPassword: "TestPass")

        let e1 = VaultEntry.new(type: .login)
        let e2 = VaultEntry.new(type: .secureNote)
        let e3 = VaultEntry.new(type: .creditCard)
        try vault.addEntry(e1)
        try vault.addEntry(e2)
        try vault.addEntry(e3)

        try vault.deleteEntries(ids: [e1.id, e3.id])
        #expect(vault.entries.count == 1)
        #expect(vault.entries.first?.id == e2.id)
    }

    @Test("Operations on locked vault throw error")
    func lockedVaultOperations() throws {
        cleanVault()
        defer { cleanVault() }

        let vault = VaultService.shared
        try vault.createVault(masterPassword: "TestPass")
        vault.lock()

        #expect(throws: VaultError.self) {
            try vault.addEntry(VaultEntry.new(type: .login))
        }
    }

    // MARK: - Persistence

    @Test("Entries persist across unlock/lock cycles")
    func entriesPersist() throws {
        cleanVault()
        defer { cleanVault() }

        let vault = VaultService.shared
        try vault.createVault(masterPassword: "PersistTest")

        var entry = VaultEntry.new(type: .login)
        entry.title = "Persisted Entry"
        entry.login = LoginData(username: "user", password: "pass")
        try vault.addEntry(entry)

        vault.lock()
        try vault.unlock(masterPassword: "PersistTest")

        #expect(vault.entries.count == 1)
        #expect(vault.entries.first?.title == "Persisted Entry")
        #expect(vault.entries.first?.login?.username == "user")
    }

    // MARK: - Search

    @Test("Search by title")
    func searchByTitle() throws {
        cleanVault()
        defer { cleanVault() }

        let vault = VaultService.shared
        try vault.createVault(masterPassword: "TestPass")

        var e1 = VaultEntry.new(type: .login)
        e1.title = "GitHub Account"
        var e2 = VaultEntry.new(type: .login)
        e2.title = "GitLab Account"
        var e3 = VaultEntry.new(type: .login)
        e3.title = "Email"

        try vault.addEntry(e1)
        try vault.addEntry(e2)
        try vault.addEntry(e3)

        let results = vault.search(query: "git")
        #expect(results.count == 2)
    }

    @Test("Search by username")
    func searchByUsername() throws {
        cleanVault()
        defer { cleanVault() }

        let vault = VaultService.shared
        try vault.createVault(masterPassword: "TestPass")

        var e1 = VaultEntry.new(type: .login)
        e1.title = "Service A"
        e1.login = LoginData(username: "alice@example.com", password: "pass")
        var e2 = VaultEntry.new(type: .login)
        e2.title = "Service B"
        e2.login = LoginData(username: "bob@example.com", password: "pass")

        try vault.addEntry(e1)
        try vault.addEntry(e2)

        let results = vault.search(query: "alice")
        #expect(results.count == 1)
        #expect(results.first?.title == "Service A")
    }

    @Test("Search by tag")
    func searchByTag() throws {
        cleanVault()
        defer { cleanVault() }

        let vault = VaultService.shared
        try vault.createVault(masterPassword: "TestPass")

        var e1 = VaultEntry.new(type: .login)
        e1.title = "Work App"
        e1.tags = ["work", "important"]
        var e2 = VaultEntry.new(type: .login)
        e2.title = "Personal App"
        e2.tags = ["personal"]

        try vault.addEntry(e1)
        try vault.addEntry(e2)

        let results = vault.search(query: "work")
        #expect(results.count == 1)
    }

    @Test("Empty search returns all entries")
    func emptySearchReturnsAll() throws {
        cleanVault()
        defer { cleanVault() }

        let vault = VaultService.shared
        try vault.createVault(masterPassword: "TestPass")

        try vault.addEntry(VaultEntry.new(type: .login))
        try vault.addEntry(VaultEntry.new(type: .secureNote))

        let results = vault.search(query: "")
        #expect(results.count == 2)
    }

    // MARK: - Favorites & Tags

    @Test("Favorites filter")
    func favoritesFilter() throws {
        cleanVault()
        defer { cleanVault() }

        let vault = VaultService.shared
        try vault.createVault(masterPassword: "TestPass")

        var fav = VaultEntry.new(type: .login)
        fav.title = "Favorite"
        fav.favorite = true
        var notFav = VaultEntry.new(type: .login)
        notFav.title = "Not Favorite"

        try vault.addEntry(fav)
        try vault.addEntry(notFav)

        #expect(vault.favorites.count == 1)
        #expect(vault.favorites.first?.title == "Favorite")
    }

    @Test("Tags collection")
    func tagsCollection() throws {
        cleanVault()
        defer { cleanVault() }

        let vault = VaultService.shared
        try vault.createVault(masterPassword: "TestPass")

        var e1 = VaultEntry.new(type: .login)
        e1.tags = ["work", "finance"]
        var e2 = VaultEntry.new(type: .login)
        e2.tags = ["personal", "work"]

        try vault.addEntry(e1)
        try vault.addEntry(e2)

        let tags = vault.allTags
        #expect(tags.contains("work"))
        #expect(tags.contains("finance"))
        #expect(tags.contains("personal"))
        #expect(tags.count == 3)
    }

    @Test("Entries by type")
    func entriesByType() throws {
        cleanVault()
        defer { cleanVault() }

        let vault = VaultService.shared
        try vault.createVault(masterPassword: "TestPass")

        try vault.addEntry(VaultEntry.new(type: .login))
        try vault.addEntry(VaultEntry.new(type: .login))
        try vault.addEntry(VaultEntry.new(type: .secureNote))
        try vault.addEntry(VaultEntry.new(type: .creditCard))

        #expect(vault.entries(for: .login).count == 2)
        #expect(vault.entries(for: .secureNote).count == 1)
        #expect(vault.entries(for: .creditCard).count == 1)
        #expect(vault.entries(for: .sshKey).count == 0)
    }

    // MARK: - Import

    @Test("Import entries adds to vault")
    func importEntries() throws {
        cleanVault()
        defer { cleanVault() }

        let vault = VaultService.shared
        try vault.createVault(masterPassword: "TestPass")

        try vault.addEntry(VaultEntry.new(type: .login))

        let imported = [
            VaultEntry.new(type: .login),
            VaultEntry.new(type: .secureNote),
        ]
        try vault.importEntries(imported)

        #expect(vault.entries.count == 3)
    }
}
