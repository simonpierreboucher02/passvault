# PassVault — macOS Password Manager

## Project Overview

PassVault is an ultra-modern, security-first password manager for macOS, built entirely in **Swift 6 + SwiftUI** without Xcode (CLI-only via Swift Package Manager). It follows a zero-knowledge architecture where all encryption/decryption happens client-side.

**Bundle ID:** `com.spboucher.passvault`
**Min macOS:** 13.0 (Ventura)
**Target:** arm64-apple-macosx

---

## Build System (No Xcode)

### Commands

```bash
swift build                          # Debug build
swift build -c release               # Release build
swift run                            # Build + run
swift test                           # Run tests
```

### Creating .app Bundle

```bash
./Scripts/build-app.sh               # Build + bundle
./Scripts/build-app.sh --sign        # Build + bundle + code sign
```

### Code Signing

```bash
# Ad-hoc (dev)
codesign --force --sign - \
    --entitlements Entitlements/PassVault.entitlements \
    --options runtime \
    .build/PassVault.app

# Distribution (Developer ID)
codesign --force --sign "Developer ID Application: Simon-Pierre Boucher (3YM54G49SN)" \
    --entitlements Entitlements/PassVault.entitlements \
    --options runtime --timestamp \
    .build/PassVault.app
```

### Notarization

```bash
zip -r PassVault.zip .build/PassVault.app
xcrun notarytool submit PassVault.zip --keychain-profile "PassVault-Notary" --wait
xcrun stapler staple .build/PassVault.app
```

---

## Project Structure

```
PassVault/
├── Package.swift
├── CLAUDE.md
├── Entitlements/
│   └── PassVault.entitlements
├── Scripts/
│   ├── build-app.sh
│   └── sign-app.sh
├── Sources/
│   ├── App/
│   │   ├── PassVaultApp.swift            # @main entry point
│   │   └── AppDelegate.swift             # NSApplicationDelegateAdaptor
│   ├── Views/
│   │   ├── ContentView.swift             # Main window
│   │   ├── SidebarView.swift             # Navigation sidebar
│   │   ├── VaultListView.swift           # Entry list
│   │   ├── EntryDetailView.swift         # Entry detail/edit
│   │   ├── UnlockView.swift              # Master password / biometric unlock
│   │   ├── PasswordGeneratorView.swift   # Password generator sheet
│   │   ├── SettingsView.swift            # Preferences
│   │   ├── ImportExportView.swift        # Import/export UI
│   │   └── Components/
│   │       ├── SecureFieldView.swift     # Show/hide password field
│   │       ├── EntropyMeter.swift        # Password strength indicator
│   │       ├── TOTPCodeView.swift        # TOTP countdown display
│   │       ├── TagView.swift             # Tag chips
│   │       └── SearchBar.swift           # Search/filter
│   ├── Models/
│   │   ├── VaultEntry.swift              # Core credential model
│   │   ├── EntryType.swift               # login, note, card, identity, ssh, api
│   │   ├── LoginData.swift               # URL + username + password + TOTP
│   │   ├── CreditCardData.swift
│   │   ├── IdentityData.swift
│   │   ├── SecureNoteData.swift
│   │   ├── SSHKeyData.swift
│   │   ├── APICredentialData.swift
│   │   ├── CustomField.swift
│   │   ├── VaultHeader.swift             # Vault file header (KDF params, salt)
│   │   ├── TOTPConfig.swift              # TOTP parameters
│   │   └── EncryptedEntry.swift          # Encrypted entry wrapper
│   ├── Services/
│   │   ├── CryptoService.swift           # AES-256-GCM / ChaCha20-Poly1305
│   │   ├── KDFService.swift              # Argon2id key derivation
│   │   ├── KeychainService.swift         # Apple Keychain read/write
│   │   ├── BiometricService.swift        # Touch ID / Secure Enclave
│   │   ├── VaultService.swift            # Vault file CRUD operations
│   │   ├── ClipboardService.swift        # Secure copy + auto-clear
│   │   ├── AutoLockService.swift         # Idle/sleep/screen-lock detection
│   │   ├── PasswordGenerator.swift       # CSPRNG password + diceware
│   │   ├── TOTPService.swift             # RFC 6238 TOTP generation
│   │   ├── ImportService.swift           # CSV, Bitwarden JSON, 1Password
│   │   ├── ExportService.swift           # Encrypted + plaintext export
│   │   └── SecureMemory.swift            # Memory zeroing utilities
│   └── Resources/
│       ├── AppIcon.iconset/              # App icon PNGs
│       └── eff-large-wordlist.txt        # Diceware wordlist (7776 words)
└── Tests/
    └── PassVaultTests/
        ├── CryptoServiceTests.swift
        ├── KDFServiceTests.swift
        ├── PasswordGeneratorTests.swift
        ├── TOTPServiceTests.swift
        ├── VaultServiceTests.swift
        └── ImportExportTests.swift
```

---

## Package.swift Configuration

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PassVault",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "PassVault", targets: ["PassVault"])
    ],
    dependencies: [
        .package(url: "https://github.com/jedisct1/swift-sodium", from: "0.9.1"),
    ],
    targets: [
        .executableTarget(
            name: "PassVault",
            dependencies: [
                .product(name: "Sodium", package: "swift-sodium"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PassVaultTests",
            dependencies: ["PassVault"],
            path: "Tests/PassVaultTests"
        )
    ]
)
```

**Rules:**
- Do NOT create `main.swift` — use `@main` on the App struct (mutually exclusive since Swift 5.4)
- Use `-parse-as-library` if compiling single files with `swiftc`
- SPM auto-links system frameworks (AppKit, SwiftUI, Security, CryptoKit, LocalAuthentication) — no linker flags needed

---

## App Entry Point Requirements

The SwiftUI app MUST include an `NSApplicationDelegateAdaptor` with:

```swift
NSApp.setActivationPolicy(.regular)     // Required: dock icon + menu bar
NSApp.activate(ignoringOtherApps: true) // Required: bring window to front
```

And:

```swift
func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
```

Without `setActivationPolicy(.regular)`, the process runs as a background agent with no dock presence.

---

## Security Architecture

### Cryptographic Stack

| Component | Algorithm | Library | Notes |
|-----------|-----------|---------|-------|
| **Symmetric encryption** | AES-256-GCM | Apple CryptoKit | AEAD, hardware-accelerated via AES-NI |
| **Fallback cipher** | ChaCha20-Poly1305 | Apple CryptoKit | Software-safe AEAD alternative |
| **Key derivation** | Argon2id | swift-sodium (libsodium) | Memory-hard, GPU-resistant, PHC winner |
| **KDF parameters** | 128 MiB / 3 iter / 4 parallel | — | ~300-500ms unlock time, high security tier |
| **Key expansion** | HKDF-SHA256 | Apple CryptoKit | Derive sub-keys from master key |
| **Integrity** | HMAC-SHA256 | Apple CryptoKit | Vault integrity verification |
| **Secure Enclave** | P256 ECDH | Apple CryptoKit | Biometric-gated key wrapping |
| **Random** | SecRandomCopyBytes | Security.framework | CSPRNG for all key/nonce/salt generation |

### Key Hierarchy (Envelope Encryption)

```
Master Password + Salt (32 bytes)
        │
        ▼  [Argon2id: 128 MiB, 3 iter, 4 parallel]
   Master Key (256-bit)
        │
        ├── [HKDF "encryption"] ──▶ Encryption Key → decrypts Vault Key
        ├── [HKDF "authentication"] ──▶ Auth Key → HMAC vault integrity
        └── [HKDF "verification"] ──▶ Verify Key → master password check
                                          │
                                     Vault Key (random 256-bit, wrapped)
                                          │
                                     Per-Entry Keys (random, wrapped by Vault Key)
                                          │
                                     Entry Ciphertext (AES-256-GCM)
```

### Vault File Format

```
┌──────────────────────────────────────────────┐
│ MAGIC: "PVLT" (4 bytes)                      │  Unencrypted
│ VERSION: uint16 (2 bytes)                    │  preamble
│ SALT: 32 bytes                               │
│ KDF PARAMS: memory, iterations, parallelism  │
│ NONCE: 12 bytes (header encryption)          │
├──────────────────────────────────────────────┤
│ ENCRYPTED HEADER (AES-256-GCM):              │  Encrypted with
│   - Vault UUID                               │  Master Key
│   - Creation date                            │
│   - Vault Key (wrapped)                      │
│   - Auth Key (wrapped)                       │
│   - Entry count                              │
├──────────────────────────────────────────────┤
│ ENTRY INDEX (encrypted):                     │
│   - Entry UUID → offset, size                │
│   - Entry titles (encrypted)                 │
├──────────────────────────────────────────────┤
│ ENTRY DATA:                                  │
│   Entry 1: nonce + AES-GCM(data, entry_key)  │
│   Entry 2: nonce + AES-GCM(data, entry_key)  │
│   ...                                        │
├──────────────────────────────────────────────┤
│ VAULT HMAC (32 bytes)                        │  Integrity
└──────────────────────────────────────────────┘
```

Per-entry encryption limits blast radius, enables efficient sync, and keeps memory footprint low.

### Zero-Knowledge Principles

1. **Never transmit** the master password
2. **Never store** the master password — only derived keys
3. **Separate keys** for encryption vs authentication (HKDF domain separation)
4. **Optional 2SKD** (Two-Secret Key Derivation) for cloud sync: combine password-derived key with a 128-bit device-bound secret key via XOR + HKDF

---

## Memory Security Rules

1. **Never use Swift `String` for passwords** — use `[UInt8]` or `Data`, zero after use
2. **Use `memset_s()` or `sodium_memzero()`** to zero sensitive buffers — `memset()` can be optimized away
3. **Use `mlock()` / `sodium_mlock()`** to prevent sensitive pages from swapping to disk
4. **Disable core dumps**: `setrlimit(RLIMIT_CORE, &rlimit(rlim_cur: 0, rlim_max: 0))`
5. **Hardened Runtime** is mandatory (prevents debugger attach, DYLD injection)
6. Implement `SecureBuffer` (~Copyable) that auto-zeros in `deinit`

---

## Feature Specifications

### Keychain Integration

- Store derived vault key (NOT master password) in Keychain
- Use `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` (most restrictive)
- Set `kSecAttrSynchronizable: false` (no iCloud sync)
- Set `kSecUseDataProtectionKeychain: true`
- Use `SecAccessControlCreateWithFlags` with `.biometryCurrentSet` (invalidates on enrollment change)

### Biometric Auth (Touch ID)

- `LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)`
- Store vault key via Secure Enclave `P256.KeyAgreement.PrivateKey`
- Use `.biometryCurrentSet` (NOT `.biometryAny`) — forces re-auth if fingerprints change
- The Secure Enclave key wraps the vault key via ECDH + HKDF

### Clipboard Security

- Use `NSPasteboard` with concealment markers:
  - `org.nspasteboard.ConcealedType` — password managers obfuscate display
  - `org.nspasteboard.TransientType` — clipboard history apps skip it
  - `org.nspasteboard.AutoGeneratedType` — marks as app-generated
- Auto-clear after 30 seconds (configurable)
- Only clear if `changeCount` matches (don't erase user's content)

### Auto-Lock

Monitor these events:
- `com.apple.screenIsLocked` — screen locked
- `NSWorkspace.willSleepNotification` — system sleep
- `com.apple.screensaver.didstart` — screensaver
- `NSWorkspace.sessionDidResignActiveNotification` — fast user switch
- `CGEventSource.secondsSinceLastEventType` — idle timer (configurable, default 5 min)

On lock: zero all sensitive data in memory, require re-authentication.

### Password Generator

- **Character-based**: configurable length (default 20), character sets (upper/lower/digits/symbols)
- **Diceware passphrase**: EFF large wordlist (7776 words), configurable word count (default 6 = 77.5 bits entropy)
- Always use `SecRandomCopyBytes` (Apple CSPRNG) — never `Int.random(in:)` or `arc4random`
- Eliminate modulo bias with rejection sampling
- Display real-time entropy calculation: `length * log2(pool_size)`

### TOTP (RFC 6238)

- Support SHA-1, SHA-256, SHA-512 algorithms
- Parse `otpauth://totp/...` URIs (QR code scanning)
- Base32 decode secrets
- Display countdown timer with remaining seconds
- Dynamic truncation per RFC 4226 section 5.4

### Import/Export

**Import formats:**
- Bitwarden JSON (unencrypted export)
- 1Password CSV / .1pux
- Chrome CSV (`name, url, username, password`)
- Firefox CSV (`url, username, password, httpRealm, ...`)
- Generic CSV (auto-detect columns)
- KeePass CSV

**Export formats:**
- Bitwarden-compatible JSON (interoperability)
- Encrypted JSON (AES-256-GCM with separate export password)
- CSV (with security warning: plaintext credentials)

### Entry Types

| Type | Fields |
|------|--------|
| **Login** | URLs (with match type), username, password, email, TOTP, passkey |
| **Secure Note** | Content (plaintext/markdown) |
| **Credit Card** | Number, cardholder, expiry, CVV, brand, billing address |
| **Identity** | Name, email, phone, address, company, SSN, passport, license |
| **SSH Key** | Public/private key, fingerprint, key type, comment |
| **API Credential** | API key, secret, endpoint, auth type |

All entries also support: tags, custom fields, file attachments, password history, expiration dates, favorites, notes.

---

## .app Bundle Structure

```
PassVault.app/
└── Contents/
    ├── Info.plist
    ├── PkgInfo                 # "APPL????"
    ├── MacOS/
    │   └── PassVault           # Executable binary
    └── Resources/
        └── AppIcon.icns        # App icon
```

**Info.plist required keys:**
- `CFBundleExecutable`: PassVault
- `CFBundleIdentifier`: com.spboucher.passvault
- `NSHighResolutionCapable`: true
- `NSPrincipalClass`: NSApplication
- `LSMinimumSystemVersion`: 13.0

---

## Entitlements

```xml
<!-- Entitlements/PassVault.entitlements -->
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>keychain-access-groups</key>
    <array>
        <string>$(TeamIdentifierPrefix)com.spboucher.passvault</string>
    </array>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
```

---

## UI/UX Guidelines

- **Design language**: macOS native — use system colors, SF Symbols, standard controls
- **Layout**: 3-column NavigationSplitView (sidebar categories / entry list / detail)
- **Dark mode**: full support via system adaptive colors
- **Typography**: system fonts, monospaced for passwords/keys/codes
- **Animations**: subtle, purposeful — spring animations for transitions
- **Accessibility**: full VoiceOver support, keyboard navigation
- **Window**: resizable, remember size/position, minimum 800x600
- **Menu bar**: standard macOS menu with keyboard shortcuts (Cmd+N new entry, Cmd+L lock, Cmd+G generate password)

---

## Coding Conventions

- Swift 6 strict concurrency (`Sendable`, `@MainActor` for UI)
- Prefer `async/await` over callbacks
- Use `@Observable` (macOS 14+) or `@ObservableObject` (macOS 13)
- Error handling: typed errors with `enum XError: LocalizedError`
- No force unwraps (`!`) — use `guard let` or `if let`
- No `try!` or `fatalError` in production code
- Prefix private properties with no underscore (Swift convention)
- One type per file, file named after the type
- Use `@MainActor` for all view models
- Use `nonisolated` explicitly when crossing actor boundaries

---

## Testing

```bash
swift test                              # Run all tests
swift test --filter CryptoServiceTests  # Run specific test suite
```

Test coverage priorities:
1. CryptoService: encryption/decryption round-trip, key derivation
2. VaultService: create/read/update/delete entries, vault integrity
3. PasswordGenerator: entropy calculation, bias detection, character set compliance
4. TOTPService: RFC 6238 test vectors
5. ImportService: parse all supported formats correctly

---

## Dependencies

| Package | Purpose | Required |
|---------|---------|----------|
| **swift-sodium** | Argon2id KDF, `sodium_memzero`, `sodium_mlock` | Yes |

All other crypto (AES-GCM, ChaCha20, HKDF, HMAC, P256, Secure Enclave) uses Apple's built-in **CryptoKit** — no additional dependencies.

Minimize third-party dependencies. Prefer Apple frameworks for everything except Argon2id.

---

## Security Checklist

- [ ] AES-256-GCM with unique nonce per encryption
- [ ] Argon2id with 128 MiB / 3 iter / 4 parallel
- [ ] Per-entry encryption with envelope key hierarchy
- [ ] HKDF domain separation for encryption/auth/verification keys
- [ ] HMAC-SHA256 vault integrity check
- [ ] Keychain storage with `WhenPasscodeSetThisDeviceOnly`
- [ ] Secure Enclave for biometric key wrapping
- [ ] `memset_s` / `sodium_memzero` for all sensitive buffers
- [ ] `SecRandomCopyBytes` for all random generation
- [ ] Clipboard auto-clear with concealed/transient markers
- [ ] Auto-lock on screen lock, sleep, idle, user switch
- [ ] Hardened Runtime enabled
- [ ] Core dumps disabled
- [ ] No master password in logs, crash reports, or memory dumps
- [ ] Input validation on all imported data
- [ ] Constant-time comparison for HMAC verification
