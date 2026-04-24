import SwiftUI

struct TOTPCodeView: View {
    let config: TOTPConfig
    @State private var code = ""
    @State private var remainingSeconds = 30
    @State private var progress: Double = 0
    @State private var timer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Two-Factor Code")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Image(systemName: "clock.badge.checkmark")
                    .foregroundStyle(.green)
                    .frame(width: 16)

                Text(formattedCode)
                    .font(.system(.title2, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Spacer()

                ZStack {
                    Circle()
                        .stroke(.quaternary, lineWidth: 3)
                        .frame(width: 28, height: 28)
                    Circle()
                        .trim(from: 0, to: 1 - progress)
                        .stroke(timerColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 28, height: 28)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: progress)
                    Text("\(remainingSeconds)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .monospacedDigit()
                }

                Button {
                    ClipboardService.shared.copySecurely(code)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            .padding(8)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
        }
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
    }

    private var formattedCode: String {
        guard code.count == 6 else { return code }
        return "\(code.prefix(3)) \(code.suffix(3))"
    }

    private var timerColor: Color {
        remainingSeconds <= 5 ? .red : .green
    }

    private func startTimer() {
        updateCode()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                updateCode()
            }
        }
    }

    private func updateCode() {
        code = TOTPService.generateCode(config: config)
        remainingSeconds = TOTPService.remainingSeconds(period: config.period)
        progress = TOTPService.progress(period: config.period)
    }
}
