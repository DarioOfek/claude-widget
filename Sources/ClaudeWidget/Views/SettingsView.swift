import SwiftUI

struct SettingsView: View {
    @Binding var isPresented: Bool
    var onSave: () -> Void

    @State private var fiveHourBudget: String = ""
    @State private var weeklyBudget: String = ""

    // Budgets are an estimated compute cost ($) per plan tier, calibrated so the
    // bars approximate Claude.ai's token-weighted usage %. Tiers scale Max-5x by
    // the plan multiplier (Pro = 1×, Max 5x = 5×, Max 20x = 20×).
    private let presets: [(label: String, fiveHr: Double, weekly: Double)] = [
        ("Pro",       160,   3280),
        ("Max 5x",    800,  16400),
        ("Max 20x",  3200,  65600),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                ClaudeLogoGroup(size: 28)
                Text("Claude Widget Settings")
                    .font(.headline)
            }

            Divider()

            Text("These are estimated compute-cost budgets ($) per plan, used to "
               + "approximate the % of your plan consumed. The bars reflect Claude "
               + "Code usage only, so they read slightly lower than claude.ai.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Presets
            HStack(spacing: 8) {
                ForEach(presets, id: \.label) { p in
                    Button(p.label) {
                        fiveHourBudget = format(p.fiveHr)
                        weeklyBudget   = format(p.weekly)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("5-hour budget ($)")
                        .font(.subheadline).fontWeight(.medium)
                    TextField("800", text: $fiveHourBudget)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly budget ($)")
                        .font(.subheadline).fontWeight(.medium)
                    TextField("16400", text: $weeklyBudget)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                }
            }

            HStack {
                Button("Cancel") { isPresented = false }.keyboardShortcut(.escape)
                Spacer()
                Button("Save") {
                    if let f = Double(fiveHourBudget), f > 0 {
                        UserDefaults.standard.set(f, forKey: "fiveHourBudget")
                    }
                    if let w = Double(weeklyBudget), w > 0 {
                        UserDefaults.standard.set(w, forKey: "weeklyBudget")
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
            let f = UserDefaults.standard.double(forKey: "fiveHourBudget")
            let w = UserDefaults.standard.double(forKey: "weeklyBudget")
            fiveHourBudget = format(f > 0 ? f : 800)
            weeklyBudget   = format(w > 0 ? w : 16400)
        }
    }

    private func format(_ v: Double) -> String {
        String(format: "%.0f", v)
    }
}
