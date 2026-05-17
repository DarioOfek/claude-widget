import SwiftUI

struct UsageRow: View {
    let label: String
    let value: String
    var accent: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.55))
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: accent ? .semibold : .regular,
                              design: .monospaced))
                .foregroundColor(accent ? Color(red: 0.93, green: 0.63, blue: 0.42) : .white.opacity(0.9))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.35))
                .tracking(1.0)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }
}
