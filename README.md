<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.0%2B-000000?style=for-the-badge&logo=apple&logoColor=white" alt="macOS 14+"/>
  <img src="https://img.shields.io/badge/Swift-6.0-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift 6"/>
  <img src="https://img.shields.io/badge/SwiftUI-Framework-0071E3?style=for-the-badge&logo=swift&logoColor=white" alt="SwiftUI"/>
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License MIT"/>
</p>

<h1 align="center">
  <br>
  🔐 PassVault
  <br>
</h1>

<h4 align="center">An ultra-modern, zero-knowledge password manager for macOS.</h4>

<p align="center">
  <a href="https://github.com/simonpierreboucher02/passvault/releases/latest/download/PassVault.dmg">
    <img src="https://img.shields.io/badge/Download-PassVault.dmg-blue?style=for-the-badge&logo=apple&logoColor=white" alt="Download DMG"/>
  </a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Encryption-AES--256--GCM-blue?style=flat-square&logo=letsencrypt&logoColor=white" alt="AES-256-GCM"/>
  <img src="https://img.shields.io/badge/KDF-PBKDF2--SHA256-blue?style=flat-square&logo=keybase&logoColor=white" alt="PBKDF2"/>
  <img src="https://img.shields.io/badge/Hardened_Runtime-Enabled-brightgreen?style=flat-square&logo=apple&logoColor=white" alt="Hardened Runtime"/>
  <img src="https://img.shields.io/badge/Notarized-Apple-brightgreen?style=flat-square&logo=apple&logoColor=white" alt="Notarized"/>
  <img src="https://img.shields.io/badge/Code_Signed-Developer_ID-brightgreen?style=flat-square&logo=apple&logoColor=white" alt="Code Signed"/>
  <img src="https://img.shields.io/badge/Architecture-arm64-lightgrey?style=flat-square&logo=arm&logoColor=white" alt="arm64"/>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/build-passing-brightgreen?style=flat-square" alt="Build"/>
  <img src="https://img.shields.io/badge/tests-passing-brightgreen?style=flat-square" alt="Tests"/>
  <img src="https://img.shields.io/badge/dependencies-1_(CryptoKit)-blue?style=flat-square" alt="Dependencies"/>
  <img src="https://img.shields.io/badge/lines_of_code-4K%2B-blue?style=flat-square" alt="LOC"/>
  <img src="https://img.shields.io/badge/zero_knowledge-100%25-purple?style=flat-square" alt="Zero Knowledge"/>
  <img src="https://img.shields.io/badge/third_party_deps-0-brightgreen?style=flat-square" alt="No Third Party"/>
</p>

---

## About

**PassVault** is a security-first password manager built entirely in **Swift 6 + SwiftUI** without Xcode (CLI-only via Swift Package Manager). All encryption and decryption happens client-side — your master password never leaves your machine.

**Author:** Simon-Pierre Boucher

---

## Features

| Feature | Description |
|---------|-------------|
| **AES-256-GCM Encryption** | Hardware-accelerated AEAD encryption via Apple CryptoKit |
| **PBKDF2-SHA256 KDF** | 600,000 iterations for key derivation |
| **Per-Entry Encryption** | Each credential is independently encrypted |
| **Touch ID Unlock** | Biometric authentication via LocalAuthentication |
| **TOTP (2FA)** | RFC 6238 time-based one-time passwords |
| **Password Generator** | CSPRNG-based with entropy meter |
| **Auto-Lock** | Locks on screen lock, sleep, idle, and user switch |
| **Secure Clipboard** | Auto-clear with concealed/transient markers |
| **Import/Export** | Bitwarden JSON, 1Password, Chrome/Firefox CSV |
| **Dark Mode** | Full support with system adaptive colors |

---

## Security Architecture

```
Master Password + Salt (32 bytes)
        │
        ▼  [PBKDF2-SHA256: 600K iterations]
   Master Key (256-bit)
        │
        ├── [HKDF "encryption"]     → Encryption Key → decrypts Vault Key
        ├── [HKDF "authentication"] → Auth Key       → HMAC vault integrity
        └── [HKDF "verification"]   → Verify Key     → master password check
                                          │
                                     Vault Key (random 256-bit, wrapped)
                                          │
                                     Per-Entry Keys (random, wrapped by Vault Key)
                                          │
                                     Entry Ciphertext (AES-256-GCM)
```

<p align="center">
  <img src="https://img.shields.io/badge/HKDF-Domain_Separation-informational?style=flat-square" alt="HKDF"/>
  <img src="https://img.shields.io/badge/HMAC-SHA256_Integrity-informational?style=flat-square" alt="HMAC"/>
  <img src="https://img.shields.io/badge/CSPRNG-SecRandomCopyBytes-informational?style=flat-square" alt="CSPRNG"/>
  <img src="https://img.shields.io/badge/Memory-memset__s_Zeroing-informational?style=flat-square" alt="Memory"/>
</p>

---

## Entry Types

<p align="center">
  <img src="https://img.shields.io/badge/Login-URL%20%2B%20Password%20%2B%20TOTP-blue?style=flat-square" alt="Login"/>
  <img src="https://img.shields.io/badge/Secure_Note-Encrypted_Text-orange?style=flat-square" alt="Note"/>
  <img src="https://img.shields.io/badge/Credit_Card-Number%20%2B%20CVV-purple?style=flat-square" alt="Card"/>
  <img src="https://img.shields.io/badge/Identity-Personal_Info-green?style=flat-square" alt="Identity"/>
  <img src="https://img.shields.io/badge/SSH_Key-Public%20%2B%20Private-red?style=flat-square" alt="SSH"/>
  <img src="https://img.shields.io/badge/API_Credential-Key%20%2B%20Secret-cyan?style=flat-square" alt="API"/>
</p>

---

## Installation

### Download

Download the latest **[PassVault.dmg](https://github.com/simonpierreboucher02/passvault/releases/latest)** from the Releases page.

The app is **code-signed** with a Developer ID certificate and **notarized** by Apple.

### Build from Source

```bash
# Clone
git clone https://github.com/simonpierreboucher02/passvault.git
cd passvault

# Build
swift build -c release

# Create .app bundle
./Scripts/build-app.sh app

# Run
swift run
```

---

## Requirements

| Requirement | Version |
|-------------|---------|
| **macOS** | 14.0 (Sonoma) or later |
| **Architecture** | Apple Silicon (arm64) |
| **Swift** | 6.0+ |
| **Xcode** | Not required (SPM only) |

---

## Project Structure

```
PassVault/
├── Package.swift              # SPM configuration
├── Entitlements/              # App sandbox & permissions
├── Scripts/                   # Build, sign, notarize scripts
├── Sources/
│   ├── App/                   # @main entry point, AppDelegate
│   ├── Models/                # VaultEntry, EntryType, data models
│   ├── Services/              # Crypto, KDF, Keychain, Biometric, Vault
│   ├── Views/                 # SwiftUI views & components
│   └── Resources/             # App icon
└── Tests/                     # Unit tests
```

---

## Security Checklist

<p align="center">
  <img src="https://img.shields.io/badge/✓-AES--256--GCM_unique_nonce-brightgreen?style=flat-square" alt=""/>
  <img src="https://img.shields.io/badge/✓-PBKDF2_600K_iterations-brightgreen?style=flat-square" alt=""/>
  <img src="https://img.shields.io/badge/✓-Per--entry_encryption-brightgreen?style=flat-square" alt=""/>
  <img src="https://img.shields.io/badge/✓-HKDF_domain_separation-brightgreen?style=flat-square" alt=""/>
  <img src="https://img.shields.io/badge/✓-HMAC--SHA256_integrity-brightgreen?style=flat-square" alt=""/>
</p>
<p align="center">
  <img src="https://img.shields.io/badge/✓-Touch_ID_biometric-brightgreen?style=flat-square" alt=""/>
  <img src="https://img.shields.io/badge/✓-memset__s_memory_zeroing-brightgreen?style=flat-square" alt=""/>
  <img src="https://img.shields.io/badge/✓-SecRandomCopyBytes_CSPRNG-brightgreen?style=flat-square" alt=""/>
  <img src="https://img.shields.io/badge/✓-Clipboard_auto--clear-brightgreen?style=flat-square" alt=""/>
  <img src="https://img.shields.io/badge/✓-Auto--lock_on_idle-brightgreen?style=flat-square" alt=""/>
</p>
<p align="center">
  <img src="https://img.shields.io/badge/✓-Hardened_Runtime-brightgreen?style=flat-square" alt=""/>
  <img src="https://img.shields.io/badge/✓-Core_dumps_disabled-brightgreen?style=flat-square" alt=""/>
  <img src="https://img.shields.io/badge/✓-Apple_Notarized-brightgreen?style=flat-square" alt=""/>
  <img src="https://img.shields.io/badge/✓-No_master_pw_in_memory-brightgreen?style=flat-square" alt=""/>
  <img src="https://img.shields.io/badge/✓-Constant--time_HMAC-brightgreen?style=flat-square" alt=""/>
</p>

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

<p align="center">
  <sub>Built with ❤️ by <strong>Simon-Pierre Boucher</strong></sub>
  <br>
  <sub>
    <img src="https://img.shields.io/badge/Made_with-Swift-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift"/>
    <img src="https://img.shields.io/badge/Platform-macOS-000000?style=flat-square&logo=apple&logoColor=white" alt="macOS"/>
    <img src="https://img.shields.io/badge/IDE-None_(CLI_only)-lightgrey?style=flat-square&logo=terminal&logoColor=white" alt="CLI"/>
  </sub>
</p>
