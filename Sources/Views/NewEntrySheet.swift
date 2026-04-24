import SwiftUI

struct NewEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    let type: EntryType
    let onSave: (VaultEntry) -> Void

    @State private var entry: VaultEntry
    @State private var showPasswordGenerator = false

    init(type: EntryType, onSave: @escaping (VaultEntry) -> Void) {
        self.type = type
        self.onSave = onSave
        self._entry = State(initialValue: VaultEntry.new(type: type))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Spacer()
                Text("New \(type.label)")
                    .font(.headline)
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .disabled(entry.title.isEmpty)
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    EditableField(label: "Title", text: $entry.title, icon: "textformat")

                    switch type {
                    case .login:
                        loginFields
                    case .secureNote:
                        noteFields
                    case .creditCard:
                        cardFields
                    case .identity:
                        identityFields
                    case .sshKey:
                        sshFields
                    case .apiCredential:
                        apiFields
                    }

                    // Tags
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tags (comma-separated)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("work, personal, finance", text: tagsBinding)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: Binding(
                            get: { entry.notes ?? "" },
                            set: { entry.notes = $0.isEmpty ? nil : $0 }
                        ))
                        .frame(minHeight: 60)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                    }

                    Toggle("Favorite", isOn: $entry.favorite)
                }
                .padding()
            }
        }
        .frame(width: 480, height: 560)
        .sheet(isPresented: $showPasswordGenerator) {
            PasswordGeneratorView()
        }
    }

    // MARK: - Login Fields

    private var loginFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditableField(label: "URL", text: urlBinding, icon: "globe")
            EditableField(label: "Username", text: loginBinding(\.username), icon: "person")

            VStack(alignment: .leading, spacing: 4) {
                Text("Password")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Image(systemName: "lock")
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    SecureField("Password", text: loginBinding(\.password))
                        .textFieldStyle(.plain)
                    Button {
                        if let generated = try? PasswordGenerator.generate() {
                            entry.login?.password = generated.value
                        }
                    } label: {
                        Image(systemName: "wand.and.stars")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("Generate password")
                }
                .padding(8)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))

                if let password = entry.login?.password, !password.isEmpty {
                    EntropyMeter(password: password)
                }
            }

            EditableField(label: "Email", text: optionalLoginBinding(\.email), icon: "envelope")
        }
    }

    // MARK: - Note Fields

    private var noteFields: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Content")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: Binding(
                get: { entry.secureNote?.content ?? "" },
                set: { entry.secureNote?.content = $0 }
            ))
            .frame(minHeight: 150)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Card Fields

    private var cardFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditableField(label: "Cardholder Name", text: cardBinding(\.cardholderName), icon: "person")
            EditableField(label: "Card Number", text: cardBinding(\.number), icon: "creditcard", isSecure: true)
            HStack(spacing: 12) {
                EditableField(label: "Exp Month", text: cardBinding(\.expirationMonth), icon: "calendar")
                EditableField(label: "Exp Year", text: cardBinding(\.expirationYear), icon: "calendar")
            }
            EditableField(label: "CVV", text: cardBinding(\.cvv), icon: "lock", isSecure: true)
        }
    }

    // MARK: - Identity Fields

    private var identityFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditableField(label: "First Name", text: identityBinding(\.firstName), icon: "person")
            EditableField(label: "Last Name", text: identityBinding(\.lastName), icon: "person")
            EditableField(label: "Email", text: optionalIdentityBinding(\.email), icon: "envelope")
            EditableField(label: "Phone", text: optionalIdentityBinding(\.phone), icon: "phone")
            EditableField(label: "Company", text: optionalIdentityBinding(\.company), icon: "building.2")
        }
    }

    // MARK: - SSH Fields

    private var sshFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditableField(label: "Key Type", text: sshBinding(\.keyType), icon: "key")
            EditableField(label: "Public Key", text: sshBinding(\.publicKey), icon: "doc.on.doc")
            EditableField(label: "Private Key", text: sshBinding(\.privateKey), icon: "lock", isSecure: true)
            EditableField(label: "Fingerprint", text: sshBinding(\.fingerprint), icon: "textformat.abc")
        }
    }

    // MARK: - API Fields

    private var apiFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditableField(label: "API Key", text: apiBinding(\.apiKey), icon: "key", isSecure: true)
            EditableField(label: "API Secret", text: optionalAPIBinding(\.apiSecret), icon: "lock", isSecure: true)
            EditableField(label: "Endpoint", text: optionalAPIBinding(\.endpoint), icon: "link")
            EditableField(label: "Auth Type", text: optionalAPIBinding(\.authType), icon: "lock.shield")
        }
    }

    // MARK: - Actions

    private func save() {
        guard !entry.title.isEmpty else { return }
        onSave(entry)
        dismiss()
    }

    // MARK: - Bindings

    private var tagsBinding: Binding<String> {
        Binding(
            get: { entry.tags.joined(separator: ", ") },
            set: { entry.tags = $0.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        )
    }

    private var urlBinding: Binding<String> {
        Binding(
            get: { entry.login?.urls.first?.url ?? "" },
            set: {
                if entry.login?.urls.isEmpty == true {
                    entry.login?.urls = [URLEntry(url: $0)]
                } else {
                    entry.login?.urls[0].url = $0
                }
            }
        )
    }

    private func loginBinding(_ keyPath: WritableKeyPath<LoginData, String>) -> Binding<String> {
        Binding(
            get: { entry.login?[keyPath: keyPath] ?? "" },
            set: { entry.login?[keyPath: keyPath] = $0 }
        )
    }

    private func optionalLoginBinding(_ keyPath: WritableKeyPath<LoginData, String?>) -> Binding<String> {
        Binding(
            get: { entry.login?[keyPath: keyPath] ?? "" },
            set: { entry.login?[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    private func cardBinding(_ keyPath: WritableKeyPath<CreditCardData, String>) -> Binding<String> {
        Binding(
            get: { entry.creditCard?[keyPath: keyPath] ?? "" },
            set: { entry.creditCard?[keyPath: keyPath] = $0 }
        )
    }

    private func identityBinding(_ keyPath: WritableKeyPath<IdentityData, String>) -> Binding<String> {
        Binding(
            get: { entry.identity?[keyPath: keyPath] ?? "" },
            set: { entry.identity?[keyPath: keyPath] = $0 }
        )
    }

    private func optionalIdentityBinding(_ keyPath: WritableKeyPath<IdentityData, String?>) -> Binding<String> {
        Binding(
            get: { entry.identity?[keyPath: keyPath] ?? "" },
            set: { entry.identity?[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    private func sshBinding(_ keyPath: WritableKeyPath<SSHKeyData, String>) -> Binding<String> {
        Binding(
            get: { entry.sshKey?[keyPath: keyPath] ?? "" },
            set: { entry.sshKey?[keyPath: keyPath] = $0 }
        )
    }

    private func apiBinding(_ keyPath: WritableKeyPath<APICredentialData, String>) -> Binding<String> {
        Binding(
            get: { entry.apiCredential?[keyPath: keyPath] ?? "" },
            set: { entry.apiCredential?[keyPath: keyPath] = $0 }
        )
    }

    private func optionalAPIBinding(_ keyPath: WritableKeyPath<APICredentialData, String?>) -> Binding<String> {
        Binding(
            get: { entry.apiCredential?[keyPath: keyPath] ?? "" },
            set: { entry.apiCredential?[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }
}
