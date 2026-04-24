import SwiftUI

struct SecureFieldView: View {
    let label: String
    let value: String
    var masked: String?
    @State private var isRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                if isRevealed {
                    Text(value)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(1)
                } else {
                    Text(masked ?? String(repeating: "•", count: min(value.count, 24)))
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.caption)
                }
                .buttonStyle(.borderless)

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
