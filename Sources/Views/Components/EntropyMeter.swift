import SwiftUI

struct EntropyMeter: View {
    var password: String?
    var entropy: Double?

    private var calculatedEntropy: Double {
        if let entropy { return entropy }
        if let password { return PasswordGenerator.calculateEntropy(password) }
        return 0
    }

    private var strengthLabel: String {
        switch calculatedEntropy {
        case ..<40: "Very Weak"
        case 40..<60: "Weak"
        case 60..<80: "Fair"
        case 80..<100: "Strong"
        case 100..<128: "Very Strong"
        default: "Excellent"
        }
    }

    private var strengthColor: Color {
        switch calculatedEntropy {
        case ..<40: .red
        case 40..<60: .orange
        case 60..<80: .yellow
        case 80..<100: .green
        default: .blue
        }
    }

    private var progress: Double {
        min(calculatedEntropy / 128.0, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                        .frame(height: 6)
                    Capsule()
                        .fill(strengthColor)
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 6)

            HStack {
                Text(strengthLabel)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(strengthColor)
                Spacer()
                Text("\(Int(calculatedEntropy)) bits")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}
