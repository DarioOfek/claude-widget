import SwiftUI

struct SettingsView: View {
    @Binding var isPresented: Bool
    var onSave: () -> Void

    @State private var fiveHourLimit: String = ""
    @State private var weeklyLimit: String = ""

    private let presets: [(label: String, fiveHr: Int, weekly: Int)] = [
        ("Pro",         45,   250),
        ("Max 5x",     225,  2450),
        ("Max 20x",    900,  5000),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                ClaudeLogoGroup(size: 28)
                Text("Claude Widget Settings")
                    .font(.headline)
            }

            Divider()

            Text("Set your plan's turn limits so the progress bars show % remaining.")
                .font(.caption)
                .foregroundColor(.secondary)

            // Presets
            HStack(spacing: 8) {
                ForEach(presets, id: \.label) { p in
                    Button(p.label) {
                        fiveHourLimit = "\(p.fiveHr)"
                        weeklyLimit   = "\(p.weekly)"
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("5-hour window limit")
                        .font(.subheadline).fontWeight(.medium)
                    TextField("45", text: $fiveHourLimit)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly limit")
                        .font(.subheadline).fontWeight(.medium)
                    TextField("200", text: $weeklyLimit)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                }
            }

            HStack {
                Button("Cancel") { isPresented = false }.keyboardShortcut(.escape)
                Spacer()
                Button("Save") {
                    if let f = Int(fiveHourLimit), f > 0 {
                        UserDefaults.standard.set(f, forKey: "fiveHourLimit")
                    }
                    if let w = Int(weeklyLimit), w > 0 {
                        UserDefaults.standard.set(w, forKey: "weeklyLimit")
                    }
                    isPresented = false
                    onSave()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear {
            fiveHourLimit = "\(UserDefaults.standard.integer(forKey: "fiveHourLimit").nonZero ?? 45)"
            weeklyLimit   = "\(UserDefaults.standard.integer(forKey: "weeklyLimit").nonZero ?? 200)"
        }
    }
}

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
