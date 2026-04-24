import SwiftUI

struct EntryDetailView: View {
    @State var entry: VaultEntry
    @State private var vault = VaultService.shared
    @State private var isEditing = false
    @State private var editedEntry: VaultEntry
    @State private var showDeleteConfirm = false

    init(entry: VaultEntry) {
        self._entry = State(initialValue: entry)
        self._editedEntry = State(initialValue: entry)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                Divider()

                if isEditing {
                    editableContent
                } else {
                    readOnlyContent
                }

                if !entry.customFields.isEmpty && !isEditing {
                    customFieldsSection
                }

                if let notes = isEditing ? nil : entry.notes, !notes.isEmpty {
                    notesSection(notes)
                }

                if isEditing {
                    editableNotesSection
                }

                metadataSection
            }
            .padding(24)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if isEditing {
                    Button("Cancel") {
                        editedEntry = entry
                        isEditing = false
                    }
                    Button("Save") {
                        saveEntry()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        editedEntry = entry
                        isEditing = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .alert("Delete Entry", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                try? vault.deleteEntry(id: entry.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(entry.title)\"? This cannot be undone.")
        }
        .onChange(of: entry) { _, newValue in
            if !isEditing { editedEntry = newValue }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 16) {
            Image(systemName: entry.type.systemImage)
                .font(.title)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(iconColor, in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                if isEditing {
                    TextField("Title", text: $editedEntry.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .textFieldStyle(.plain)
                } else {
                    Text(entry.title)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                Text(entry.type.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !isEditing {
                Button {
                    var updated = entry
                    updated.favorite.toggle()
                    try? vault.updateEntry(updated)
                    entry = updated
                } label: {
                    Image(systemName: entry.favorite ? "star.fill" : "star")
                        .foregroundStyle(entry.favorite ? .yellow : .secondary)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    // MARK: - Read-Only Content

    @ViewBuilder
    private var readOnlyContent: some View {
        switch entry.type {
        case .login:
            if let login = entry.login {
                loginReadOnly(login)
            }
        case .secureNote:
            if let note = entry.secureNote {
                noteReadOnly(note)
            }
        case .creditCard:
            if let card = entry.creditCard {
                cardReadOnly(card)
            }
        case .identity:
            if let identity = entry.identity {
                identityReadOnly(identity)
            }
        case .sshKey:
            if let ssh = entry.sshKey {
                sshReadOnly(ssh)
            }
        case .apiCredential:
            if let api = entry.apiCredential {
                apiReadOnly(api)
            }
        }
    }

    private func loginReadOnly(_ login: LoginData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !login.urls.isEmpty {
                ForEach(login.urls) { url in
                    CopyableField(label: "URL", value: url.url, systemImage: "globe")
                }
            }
            CopyableField(label: "Username", value: login.username, systemImage: "person")
            SecureFieldView(label: "Password", value: login.password)

            if let email = login.email, !email.isEmpty {
                CopyableField(label: "Email", value: email, systemImage: "envelope")
            }

            if let totp = login.totp {
                TOTPCodeView(config: totp)
            }
        }
    }

    private func noteReadOnly(_ note: SecureNoteData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Content")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(note.content)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func cardReadOnly(_ card: CreditCardData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            CopyableField(label: "Cardholder", value: card.cardholderName, systemImage: "person")
            SecureFieldView(label: "Card Number", value: card.number, masked: card.maskedNumber)
            HStack(spacing: 16) {
                CopyableField(label: "Expiry", value: "\(card.expirationMonth)/\(card.expirationYear)", systemImage: "calendar")
                SecureFieldView(label: "CVV", value: card.cvv)
            }
            if !card.detectedBrand.isEmpty {
                CopyableField(label: "Brand", value: card.detectedBrand, systemImage: "creditcard")
            }
        }
    }

    private func identityReadOnly(_ identity: IdentityData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            CopyableField(label: "Name", value: identity.fullName, systemImage: "person")
            if let email = identity.email, !email.isEmpty {
                CopyableField(label: "Email", value: email, systemImage: "envelope")
            }
            if let phone = identity.phone, !phone.isEmpty {
                CopyableField(label: "Phone", value: phone, systemImage: "phone")
            }
            if let company = identity.company, !company.isEmpty {
                CopyableField(label: "Company", value: company, systemImage: "building.2")
            }
            if let ssn = identity.socialSecurityNumber, !ssn.isEmpty {
                SecureFieldView(label: "SSN", value: ssn)
            }
        }
    }

    private func sshReadOnly(_ ssh: SSHKeyData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            CopyableField(label: "Key Type", value: ssh.keyType, systemImage: "key")
            CopyableField(label: "Fingerprint", value: ssh.fingerprint, systemImage: "textformat.abc")
            CopyableField(label: "Public Key", value: ssh.publicKey, systemImage: "doc.on.doc")
            SecureFieldView(label: "Private Key", value: ssh.privateKey)
        }
    }

    private func apiReadOnly(_ api: APICredentialData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SecureFieldView(label: "API Key", value: api.apiKey)
            if let secret = api.apiSecret, !secret.isEmpty {
                SecureFieldView(label: "API Secret", value: secret)
            }
            if let endpoint = api.endpoint, !endpoint.isEmpty {
                CopyableField(label: "Endpoint", value: endpoint, systemImage: "link")
            }
            if let authType = api.authType, !authType.isEmpty {
                CopyableField(label: "Auth Type", value: authType, systemImage: "lock")
            }
        }
    }

    // MARK: - Editable Content

    @ViewBuilder
    private var editableContent: some View {
        switch editedEntry.type {
        case .login:
            loginEditable
        case .secureNote:
            noteEditable
        case .creditCard:
            cardEditable
        case .identity:
            identityEditable
        case .sshKey:
            sshEditable
        case .apiCredential:
            apiEditable
        }
    }

    private var loginEditable: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditableField(label: "Username", text: loginEditBinding(\.username), icon: "person")
            EditableField(label: "Password", text: loginEditBinding(\.password), icon: "lock", isSecure: true)
            EditableField(label: "Email", text: loginOptionalEditBinding(\.email), icon: "envelope")
            EditableField(label: "URL", text: urlBinding, icon: "globe")
        }
    }

    private var noteEditable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Content")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: Binding(
                get: { editedEntry.secureNote?.content ?? "" },
                set: { editedEntry.secureNote?.content = $0 }
            ))
            .frame(minHeight: 200)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var cardEditable: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditableField(label: "Cardholder Name", text: cardEditBinding(\.cardholderName), icon: "person")
            EditableField(label: "Card Number", text: cardEditBinding(\.number), icon: "creditcard", isSecure: true)
            HStack(spacing: 12) {
                EditableField(label: "Exp Month", text: cardEditBinding(\.expirationMonth), icon: "calendar")
                EditableField(label: "Exp Year", text: cardEditBinding(\.expirationYear), icon: "calendar")
            }
            EditableField(label: "CVV", text: cardEditBinding(\.cvv), icon: "lock", isSecure: true)
        }
    }

    private var identityEditable: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditableField(label: "First Name", text: identityEditBinding(\.firstName), icon: "person")
            EditableField(label: "Last Name", text: identityEditBinding(\.lastName), icon: "person")
            EditableField(label: "Email", text: identityOptionalEditBinding(\.email), icon: "envelope")
            EditableField(label: "Phone", text: identityOptionalEditBinding(\.phone), icon: "phone")
            EditableField(label: "Company", text: identityOptionalEditBinding(\.company), icon: "building.2")
        }
    }

    private var sshEditable: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditableField(label: "Key Type", text: sshEditBinding(\.keyType), icon: "key")
            EditableField(label: "Public Key", text: sshEditBinding(\.publicKey), icon: "doc.on.doc")
            EditableField(label: "Private Key", text: sshEditBinding(\.privateKey), icon: "lock", isSecure: true)
            EditableField(label: "Fingerprint", text: sshEditBinding(\.fingerprint), icon: "textformat.abc")
        }
    }

    private var apiEditable: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditableField(label: "API Key", text: apiEditBinding(\.apiKey), icon: "key", isSecure: true)
            EditableField(label: "API Secret", text: apiOptionalEditBinding(\.apiSecret), icon: "lock", isSecure: true)
            EditableField(label: "Endpoint", text: apiOptionalEditBinding(\.endpoint), icon: "link")
            EditableField(label: "Auth Type", text: apiOptionalEditBinding(\.authType), icon: "lock.shield")
        }
    }

    // MARK: - Sections

    private var customFieldsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Fields")
                .font(.headline)
            ForEach(entry.customFields) { field in
                if field.type == .hidden {
                    SecureFieldView(label: field.name, value: field.value)
                } else {
                    CopyableField(label: field.name, value: field.value, systemImage: "text.alignleft")
                }
            }
        }
    }

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)
            Text(notes)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var editableNotesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)
            TextEditor(text: Binding(
                get: { editedEntry.notes ?? "" },
                set: { editedEntry.notes = $0.isEmpty ? nil : $0 }
            ))
            .frame(minHeight: 80)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack(spacing: 24) {
                metadataItem("Created", date: entry.createdAt)
                metadataItem("Modified", date: entry.modifiedAt)
                if let accessed = entry.lastAccessedAt {
                    metadataItem("Last accessed", date: accessed)
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
    }

    private func metadataItem(_ label: String, date: Date) -> some View {
        VStack(alignment: .leading) {
            Text(label)
            Text(date, format: .dateTime.month().day().year().hour().minute())
        }
    }

    // MARK: - Actions

    private func saveEntry() {
        editedEntry.modifiedAt = Date()
        if let oldPassword = entry.login?.password,
           let newPassword = editedEntry.login?.password,
           oldPassword != newPassword && !oldPassword.isEmpty {
            editedEntry.passwordHistory.append(
                PasswordHistoryEntry(password: oldPassword)
            )
        }
        try? vault.updateEntry(editedEntry)
        entry = editedEntry
        isEditing = false
    }

    // MARK: - Binding Helpers

    private func loginEditBinding(_ keyPath: WritableKeyPath<LoginData, String>) -> Binding<String> {
        Binding(
            get: { editedEntry.login?[keyPath: keyPath] ?? "" },
            set: { editedEntry.login?[keyPath: keyPath] = $0 }
        )
    }

    private func loginOptionalEditBinding(_ keyPath: WritableKeyPath<LoginData, String?>) -> Binding<String> {
        Binding(
            get: { editedEntry.login?[keyPath: keyPath] ?? "" },
            set: { editedEntry.login?[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    private func cardEditBinding(_ keyPath: WritableKeyPath<CreditCardData, String>) -> Binding<String> {
        Binding(
            get: { editedEntry.creditCard?[keyPath: keyPath] ?? "" },
            set: { editedEntry.creditCard?[keyPath: keyPath] = $0 }
        )
    }

    private func identityEditBinding(_ keyPath: WritableKeyPath<IdentityData, String>) -> Binding<String> {
        Binding(
            get: { editedEntry.identity?[keyPath: keyPath] ?? "" },
            set: { editedEntry.identity?[keyPath: keyPath] = $0 }
        )
    }

    private func identityOptionalEditBinding(_ keyPath: WritableKeyPath<IdentityData, String?>) -> Binding<String> {
        Binding(
            get: { editedEntry.identity?[keyPath: keyPath] ?? "" },
            set: { editedEntry.identity?[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    private func sshEditBinding(_ keyPath: WritableKeyPath<SSHKeyData, String>) -> Binding<String> {
        Binding(
            get: { editedEntry.sshKey?[keyPath: keyPath] ?? "" },
            set: { editedEntry.sshKey?[keyPath: keyPath] = $0 }
        )
    }

    private func apiEditBinding(_ keyPath: WritableKeyPath<APICredentialData, String>) -> Binding<String> {
        Binding(
            get: { editedEntry.apiCredential?[keyPath: keyPath] ?? "" },
            set: { editedEntry.apiCredential?[keyPath: keyPath] = $0 }
        )
    }

    private func apiOptionalEditBinding(_ keyPath: WritableKeyPath<APICredentialData, String?>) -> Binding<String> {
        Binding(
            get: { editedEntry.apiCredential?[keyPath: keyPath] ?? "" },
            set: { editedEntry.apiCredential?[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    private var urlBinding: Binding<String> {
        Binding(
            get: { editedEntry.login?.urls.first?.url ?? "" },
            set: { newValue in
                if editedEntry.login?.urls.isEmpty == true || editedEntry.login?.urls == nil {
                    editedEntry.login?.urls = [URLEntry(url: newValue)]
                } else {
                    editedEntry.login?.urls[0].url = newValue
                }
            }
        )
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

// MARK: - Editable Field

struct EditableField: View {
    let label: String
    @Binding var text: String
    var icon: String = "text.alignleft"
    var isSecure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                if isSecure {
                    SecureField(label, text: $text)
                        .textFieldStyle(.plain)
                } else {
                    TextField(label, text: $text)
                        .textFieldStyle(.plain)
                }
            }
            .padding(8)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
        }
    }
}

// MARK: - Copyable Field

struct CopyableField: View {
    let label: String
    let value: String
    var systemImage: String = "doc.on.doc"

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(value)
                    .textSelection(.enabled)
                    .lineLimit(1)
                Spacer()
                Button {
                    ClipboardService.shared.copySecurely(value)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            .padding(8)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
        }
    }
}
