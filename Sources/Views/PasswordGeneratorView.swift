import SwiftUI

struct PasswordGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var mode: GeneratorMode = .password
    @State private var passwordLength: Double = 20
    @State private var useLowercase = true
    @State private var useUppercase = true
    @State private var useDigits = true
    @State private var useSymbols = true
    @State private var passphraseWordCount: Double = 6
    @State private var passphraseSeparator = "-"
    @State private var generatedPassword = ""
    @State private var entropy: Double = 0
    @State private var copied = false

    enum GeneratorMode: String, CaseIterable {
        case password = "Password"
        case passphrase = "Passphrase"
    }

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Password Generator")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.escape)
            }

            // Output
            VStack(spacing: 12) {
                HStack {
                    Text(generatedPassword)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        copyPassword()
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(copied ? .green : .secondary)
                    }
                    .buttonStyle(.borderless)

                    Button {
                        regenerate()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(12)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))

                EntropyMeter(entropy: entropy)
            }

            // Mode picker
            Picker("Mode", selection: $mode) {
                ForEach(GeneratorMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // Options
            switch mode {
            case .password:
                passwordOptions
            case .passphrase:
                passphraseOptions
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 480, height: 460)
        .onAppear { regenerate() }
        .onChange(of: mode) { _, _ in regenerate() }
    }

    private var passwordOptions: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Length")
                    Spacer()
                    Text("\(Int(passwordLength))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $passwordLength, in: 8...64, step: 1) {
                    Text("Length")
                } onEditingChanged: { _ in
                    regenerate()
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                charSetToggle("Lowercase (a-z)", isOn: $useLowercase)
                charSetToggle("Uppercase (A-Z)", isOn: $useUppercase)
                charSetToggle("Digits (0-9)", isOn: $useDigits)
                charSetToggle("Symbols (!@#$...)", isOn: $useSymbols)
            }
        }
    }

    private func charSetToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(label, isOn: isOn)
            .onChange(of: isOn.wrappedValue) { _, _ in regenerate() }
    }

    private var passphraseOptions: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Word Count")
                    Spacer()
                    Text("\(Int(passphraseWordCount))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $passphraseWordCount, in: 3...10, step: 1) {
                    Text("Words")
                } onEditingChanged: { _ in
                    regenerate()
                }
            }

            HStack {
                Text("Separator")
                Spacer()
                Picker("Separator", selection: $passphraseSeparator) {
                    Text("Hyphen (-)").tag("-")
                    Text("Space ( )").tag(" ")
                    Text("Period (.)").tag(".")
                    Text("Underscore (_)").tag("_")
                    Text("None").tag("")
                }
                .frame(width: 160)
                .onChange(of: passphraseSeparator) { _, _ in regenerate() }
            }
        }
    }

    private func regenerate() {
        do {
            switch mode {
            case .password:
                var charSets: PasswordCharacterSet = []
                if useLowercase { charSets.insert(.lowercase) }
                if useUppercase { charSets.insert(.uppercase) }
                if useDigits { charSets.insert(.digits) }
                if useSymbols { charSets.insert(.symbols) }
                if charSets.isEmpty { charSets = .all }
                let result = try PasswordGenerator.generate(length: Int(passwordLength), characterSets: charSets)
                generatedPassword = result.value
                entropy = result.entropy
            case .passphrase:
                let wordList = defaultWordList
                let result = try PasswordGenerator.generatePassphrase(
                    wordCount: Int(passphraseWordCount),
                    separator: passphraseSeparator,
                    wordList: wordList
                )
                generatedPassword = result.value
                entropy = result.entropy
            }
        } catch {
            generatedPassword = "Error generating password"
            entropy = 0
        }
        copied = false
    }

    private func copyPassword() {
        ClipboardService.shared.copySecurely(generatedPassword)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }

    private var defaultWordList: [String] {
        // Compact EFF-inspired word list for diceware
        let words = "abandon,ability,able,about,above,absent,absorb,abstract,absurd,abuse,access,accident,account,accuse,achieve,acid,acoustic,acquire,across,act,action,actor,actress,actual,adapt,add,addict,address,adjust,admit,adult,advance,advice,aerobic,affair,afford,afraid,again,age,agent,agree,ahead,aim,air,airport,aisle,alarm,album,alcohol,alert,alien,all,alley,allow,almost,alone,alpha,already,also,alter,always,amateur,amazing,among,amount,amused,analyst,anchor,ancient,anger,angle,angry,animal,ankle,announce,annual,another,answer,antenna,antique,anxiety,any,apart,apology,appear,apple,approve,april,arch,arctic,area,arena,argue,arm,armed,armor,army,around,arrange,arrest,arrive,arrow,art,artefact,artist,artwork,ask,aspect,assault,asset,assist,assume,asthma,athlete,atom,attack,attend,attitude,attract,auction,audit,august,aunt,author,auto,autumn,average,avocado,avoid,awake,aware,awesome,awful,awkward,axis"
        return words.components(separatedBy: ",")
    }
}
