import SwiftUI

struct UsageBar: View {
    let label: String
    let usage: RollingUsage
    var warningThreshold: Double = 0.8

    private var barColor: Color {
        if usage.pct >= 1.0    { return .red }
        if usage.pct >= warningThreshold { return Color(red: 0.93, green: 0.63, blue: 0.42) }
        return Color(red: 0.38, green: 0.78, blue: 0.62)   // teal-green when safe
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.35))
                    .tracking(1.0)
                Spacer()
                Text("\(usage.turns) / \(usage.limit)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))
                Text(String(format: "%.0f%%", usage.pct * 100))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(barColor)
                    .frame(width: 34, alignment: .trailing)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 5)
                    Capsule()
                        .fill(barColor)
                        .frame(width: max(0, geo.size.width * usage.pct), height: 5)
                        .animation(.easeInOut(duration: 0.4), value: usage.pct)
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 12)
    }
}
