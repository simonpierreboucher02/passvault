import SwiftUI

@main
struct PassVaultApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appearance = AppearanceService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .preferredColorScheme(appearance.theme.colorScheme)
                .tint(appearance.accentColor.color)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {
                Menu("New Entry") {
                    ForEach(EntryType.allCases) { type in
                        Button(type.label) {
                            NotificationCenter.default.post(
                                name: .createNewEntry,
                                object: type
                            )
                        }
                    }
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .appInfo) {
                Button("Lock Vault") {
                    VaultService.shared.lock()
                }
                .keyboardShortcut("l", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .preferredColorScheme(appearance.theme.colorScheme)
                .tint(appearance.accentColor.color)
        }
    }
}

extension Notification.Name {
    static let createNewEntry = Notification.Name("createNewEntry")
}
