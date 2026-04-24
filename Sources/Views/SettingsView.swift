import SwiftUI

struct SettingsView: View {
    @State private var autoLock = AutoLockService.shared
    @State private var clipboard = ClipboardService.shared
    @State private var biometric = BiometricService.shared
    @State private var appearance = AppearanceService.shared

    @State private var lockTimeoutMinutes: Double = 5
    @State private var clipboardClearSeconds: Double = 30
    @State private var useBiometrics = false
    @State private var showBiometricSetup = false
    @State private var biometricPassword = ""
    @State private var biometricError: String?
    @State private var biometricSuccess = false
    @State private var isVerifying = false

    var body: some View {
        TabView {
            securityTab
                .tabItem { Label("Security", systemImage: "lock.shield") }

            appearanceTab
                .tabItem { Label("Appearance", systemImage: "paintbrush") }

            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }

            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 440)
        .onAppear {
            lockTimeoutMinutes = autoLock.lockTimeout / 60
            clipboardClearSeconds = clipboard.clearDelay
            useBiometrics = biometric.isEnabled
        }
    }

    // MARK: - Security Tab

    private var securityTab: some View {
        Form {
            Section("Auto-Lock") {
                HStack {
                    Text("Lock after inactivity")
                    Spacer()
                    Picker("", selection: $lockTimeoutMinutes) {
                        Text("1 minute").tag(1.0)
                        Text("5 minutes").tag(5.0)
                        Text("15 minutes").tag(15.0)
                        Text("30 minutes").tag(30.0)
                        Text("1 hour").tag(60.0)
                    }
                    .frame(width: 150)
                    .onChange(of: lockTimeoutMinutes) { _, newValue in
                        autoLock.lockTimeout = newValue * 60
                    }
                }
            }

            Section("Clipboard") {
                HStack {
                    Text("Clear clipboard after")
                    Spacer()
                    Picker("", selection: $clipboardClearSeconds) {
                        Text("10 seconds").tag(10.0)
                        Text("30 seconds").tag(30.0)
                        Text("1 minute").tag(60.0)
                        Text("2 minutes").tag(120.0)
                        Text("Never").tag(0.0)
                    }
                    .frame(width: 150)
                    .onChange(of: clipboardClearSeconds) { _, newValue in
                        clipboard.clearDelay = newValue
                    }
                }
            }

            Section {
                if biometric.isBiometricAvailable {
                    Toggle("Unlock with \(biometric.biometricLabel)", isOn: $useBiometrics)
                        .onChange(of: useBiometrics) { _, newValue in
                            if newValue {
                                showBiometricSetup = true
                            } else {
                                biometric.disable()
                                biometricSuccess = false
                            }
                        }

                    if biometric.isEnabled {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text("\(biometric.biometricLabel) is active")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "touchid")
                            .foregroundStyle(.secondary)
                        Text("No biometric authentication available on this Mac")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Biometrics")
            } footer: {
                if biometric.isBiometricAvailable {
                    Text("Your master password is stored in the Keychain, protected by \(biometric.biometricLabel). Changing fingerprints will require re-enabling.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .sheet(isPresented: $showBiometricSetup, onDismiss: {
            if !biometric.isEnabled {
                useBiometrics = false
            }
        }) {
            biometricSetupSheet
        }
    }

    // MARK: - Biometric Setup Sheet

    private var biometricSetupSheet: some View {
        VStack(spacing: 20) {
            Image(systemName: "touchid")
                .font(.system(size: 48))
                .foregroundStyle(appearance.accentColor.color)

            Text("Enable \(biometric.biometricLabel)")
                .font(.title2)
                .fontWeight(.bold)

            Text("Enter your master password to enable \(biometric.biometricLabel) unlock.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 320)

            SecureField("Master Password", text: $biometricPassword)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)
                .disabled(isVerifying)
                .onSubmit { confirmBiometricSetup() }

            if let biometricError {
                Label(biometricError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            if biometricSuccess {
                Label("\(biometric.biometricLabel) enabled!", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .fontWeight(.medium)
            }

            HStack(spacing: 16) {
                Button("Cancel") {
                    resetBiometricSheet()
                }
                .keyboardShortcut(.escape)

                Button {
                    confirmBiometricSetup()
                } label: {
                    HStack(spacing: 6) {
                        if isVerifying {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Enable")
                    }
                    .frame(minWidth: 80)
                }
                .buttonStyle(.borderedProminent)
                .disabled(biometricPassword.isEmpty || isVerifying)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(32)
        .frame(width: 420, height: 340)
    }

    private func confirmBiometricSetup() {
        guard !biometricPassword.isEmpty, !isVerifying else { return }
        biometricError = nil
        isVerifying = true

        let password = biometricPassword

        Task {
            // Step 1: Verify password (does NOT change vault lock state)
            let isValid: Bool
            do {
                isValid = try VaultService.shared.verifyPassword(password)
            } catch {
                biometricError = "Could not verify password"
                isVerifying = false
                return
            }

            guard isValid else {
                biometricError = "Invalid master password"
                biometricPassword = ""
                isVerifying = false
                return
            }

            // Step 2: Store in Keychain with biometric protection
            do {
                try biometric.enable(masterPassword: password)
            } catch {
                biometricError = "Keychain error: \(error.localizedDescription)"
                isVerifying = false
                return
            }

            // Success
            biometricSuccess = true
            biometricPassword = ""
            isVerifying = false

            try? await Task.sleep(for: .seconds(1.2))
            showBiometricSetup = false
            biometricSuccess = false
        }
    }

    private func resetBiometricSheet() {
        biometricPassword = ""
        biometricError = nil
        biometricSuccess = false
        isVerifying = false
        showBiometricSetup = false
    }

    // MARK: - Appearance Tab

    private var appearanceTab: some View {
        Form {
            Section("Theme") {
                Picker("Appearance", selection: $appearance.theme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Accent Color") {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(48)), count: 8), spacing: 12) {
                    ForEach(AccentColorOption.allCases) { option in
                        Button {
                            appearance.accentColor = option
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 32, height: 32)
                                if appearance.accentColor == option {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .help(option.rawValue)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Text Size") {
                Picker("Font Size", selection: $appearance.fontSize) {
                    ForEach(AppFontSize.allCases) { size in
                        Text(size.rawValue).tag(size)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 8) {
                    Text("Aa")
                        .font(.system(size: 11 * appearance.fontSize.scale))
                        .foregroundStyle(.secondary)
                    Text("Aa")
                        .font(.system(size: 14 * appearance.fontSize.scale))
                    Text("Aa")
                        .font(.system(size: 18 * appearance.fontSize.scale))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)
            }

            Section("Layout") {
                Picker("Sidebar Width", selection: $appearance.sidebarSize) {
                    ForEach(SidebarSize.allCases) { size in
                        Text(size.rawValue).tag(size)
                    }
                }

                Toggle("Show entry icons", isOn: $appearance.showEntryIcons)

                Toggle("Compact list", isOn: $appearance.compactList)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section("Vault") {
                LabeledContent("Location") {
                    Text(VaultService.shared.vaultFileURL.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                LabeledContent("Entries") {
                    Text("\(VaultService.shared.entries.count)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(appearance.accentColor.color)
            Text("PassVault")
                .font(.title)
                .fontWeight(.bold)
            Text("Version 1.0.0")
                .foregroundStyle(.secondary)
            Text("Ultra-modern, zero-knowledge password manager")
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            VStack(spacing: 4) {
                Text("Encryption: AES-256-GCM")
                Text("Key Derivation: PBKDF2-SHA256 (600K iterations)")
            }
            .font(.caption)
            .foregroundStyle(.quaternary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
