import SwiftUI

struct UnlockView: View {
    @State private var vault = VaultService.shared
    @State private var masterPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var biometric = BiometricService.shared

    private var isCreating: Bool { !vault.vaultExists }

    private var canUseBiometric: Bool {
        !isCreating && biometric.isBiometricAvailable && biometric.isEnabled && biometric.hasStoredCredential
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.blue)
                        .symbolEffect(.pulse, isActive: isLoading)

                    Text("PassVault")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text(isCreating ? "Create your master password" : "Enter your master password to unlock")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    SecureField("Master Password", text: $masterPassword)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 360)
                        .onSubmit { unlock() }

                    if isCreating {
                        SecureField("Confirm Password", text: $confirmPassword)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 360)
                            .onSubmit { unlock() }

                        if !masterPassword.isEmpty {
                            EntropyMeter(password: masterPassword)
                                .frame(maxWidth: 360)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }

                    Button(action: unlock) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(isCreating ? "Create Vault" : "Unlock")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: 360, minHeight: 36)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(masterPassword.isEmpty || isLoading)
                    .keyboardShortcut(.return, modifiers: [])

                    if canUseBiometric {
                        Button {
                            biometricUnlock()
                        } label: {
                            Label("Unlock with \(biometric.biometricLabel)", systemImage: "touchid")
                        }
                        .buttonStyle(.borderless)
                        .disabled(isLoading)
                    }
                }
            }

            Spacer()

            Text("Your vault is encrypted with AES-256-GCM")
                .font(.caption2)
                .foregroundStyle(.quaternary)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .onAppear {
            if canUseBiometric {
                biometricUnlock()
            }
        }
    }

    private func unlock() {
        guard !masterPassword.isEmpty else { return }

        if isCreating {
            guard masterPassword == confirmPassword else {
                errorMessage = "Passwords do not match"
                return
            }
            guard masterPassword.count >= 8 else {
                errorMessage = "Password must be at least 8 characters"
                return
            }
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                if isCreating {
                    try vault.createVault(masterPassword: masterPassword)
                } else {
                    try vault.unlock(masterPassword: masterPassword)
                    if biometric.isEnabled && biometric.isBiometricAvailable {
                        try? biometric.enable(masterPassword: masterPassword)
                    }
                }
                masterPassword = ""
                confirmPassword = ""
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func biometricUnlock() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let password = try await biometric.retrieveMasterPassword()
                try vault.unlock(masterPassword: password)
            } catch BiometricError.cancelled {
                errorMessage = nil
            } catch BiometricError.noStoredCredential {
                errorMessage = "Touch ID not configured. Please enter your master password."
            } catch BiometricError.authenticationFailed {
                errorMessage = "Touch ID failed. Try again or enter your master password."
            } catch BiometricError.notAvailable {
                errorMessage = "Touch ID is not available on this Mac."
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
