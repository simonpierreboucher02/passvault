import SwiftUI
import UniformTypeIdentifiers

struct ImportExportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vault = VaultService.shared
    @State private var mode: Mode = .import_
    @State private var importFormat: ImportFormat = .bitwardenJSON
    @State private var exportFormat: ExportFormat = .bitwardenJSON
    @State private var exportPassword = ""
    @State private var statusMessage: String?
    @State private var isError = false
    @State private var importCount = 0

    enum Mode: String, CaseIterable {
        case import_ = "Import"
        case export_ = "Export"
    }

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Import / Export")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.escape)
            }

            Picker("Mode", selection: $mode) {
                Text("Import").tag(Mode.import_)
                Text("Export").tag(Mode.export_)
            }
            .pickerStyle(.segmented)

            if mode == .import_ {
                importSection
            } else {
                exportSection
            }

            if let statusMessage {
                HStack {
                    Image(systemName: isError ? "exclamationmark.triangle" : "checkmark.circle")
                        .foregroundStyle(isError ? .red : .green)
                    Text(statusMessage)
                        .foregroundStyle(isError ? .red : .green)
                }
                .font(.callout)
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 480, height: 380)
    }

    private var importSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Format", selection: $importFormat) {
                ForEach(ImportFormat.allCases) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .frame(maxWidth: 300)

            Text("Select a file exported from your previous password manager.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button("Choose File...") {
                openImportFile()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Format", selection: $exportFormat) {
                ForEach(ExportFormat.allCases) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .frame(maxWidth: 300)

            if exportFormat == .encryptedJSON {
                SecureField("Export Password", text: $exportPassword)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
            }

            if exportFormat == .csv || exportFormat == .bitwardenJSON {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Exported file will contain plaintext credentials.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Button("Export \(vault.entries.count) entries...") {
                openExportFile()
            }
            .buttonStyle(.borderedProminent)
            .disabled(vault.entries.isEmpty)
        }
    }

    private func openImportFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = importFormat.fileExtension == "json"
            ? [UTType.json]
            : [UTType.commaSeparatedText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let entries = try ImportService.importFile(data: data, format: importFormat)
            try vault.importEntries(entries)
            importCount = entries.count
            statusMessage = "Successfully imported \(entries.count) entries"
            isError = false
        } catch {
            statusMessage = error.localizedDescription
            isError = true
        }
    }

    private func openExportFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = exportFormat.fileExtension == "json"
            ? [UTType.json]
            : [UTType.commaSeparatedText]
        panel.nameFieldStringValue = "passvault-export.\(exportFormat.fileExtension)"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let password = exportFormat == .encryptedJSON ? exportPassword : nil
            let data = try ExportService.export(entries: vault.entries, format: exportFormat, password: password)
            try data.write(to: url, options: .atomic)
            statusMessage = "Successfully exported \(vault.entries.count) entries"
            isError = false
        } catch {
            statusMessage = error.localizedDescription
            isError = true
        }
    }
}
