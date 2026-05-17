import SwiftUI

/// Two-logo header: [pixel-art bot] + [Claude circle]
struct ClaudeLogoGroup: View {
    var size: CGFloat = 26

    var body: some View {
        HStack(spacing: 5) {
            ClaudeCodeBotView(size: size)
            ClaudeAvatarView(size: size)
        }
    }
}

// ── Claude Code pixel-art robot ──────────────────────────────────────────────
struct ClaudeCodeBotView: View {
    var size: CGFloat = 26

    // 12×13 pixel grid  0=transparent  1=dark  2=orange body  3=lighter accent
    private static let grid: [[UInt8]] = [
        [0,0,0,1,1,0,0,1,1,0,0,0],  //  0  antenna bumps
        [0,0,0,1,2,0,0,2,1,0,0,0],  //  1
        [0,0,0,1,1,0,0,1,1,0,0,0],  //  2
        [0,1,1,1,1,1,1,1,1,1,1,0],  //  3  head top
        [0,1,2,2,2,2,2,2,2,2,1,0],  //  4
        [0,1,2,1,1,2,2,1,1,2,1,0],  //  5  eyes
        [0,1,2,1,1,2,2,1,1,2,1,0],  //  6
        [0,1,2,2,2,2,2,2,2,2,1,0],  //  7
        [0,1,2,2,1,1,1,1,2,2,1,0],  //  8  mouth (slight frown)
        [0,1,2,2,2,2,2,2,2,2,1,0],  //  9
        [0,1,1,2,2,2,2,2,2,1,1,0],  // 10  chin
        [0,0,1,1,1,1,1,1,1,1,0,0],  // 11
        [0,0,0,0,0,0,0,0,0,0,0,0],  // 12
    ]

    private let orange = Color(red: 0.85, green: 0.44, blue: 0.25)
    private let accent = Color(red: 0.94, green: 0.65, blue: 0.45)
    private let dark   = Color(red: 0.13, green: 0.10, blue: 0.09)

    var body: some View {
        Canvas { ctx, sz in
            let cols = CGFloat(Self.grid[0].count)
            let rows = CGFloat(Self.grid.count)
            let px   = min(sz.width / cols, sz.height / rows)
            let ox   = (sz.width  - px * cols) / 2
            let oy   = (sz.height - px * rows) / 2

            for (r, row) in Self.grid.enumerated() {
                for (c, val) in row.enumerated() {
                    guard val > 0 else { continue }
                    let color: Color = val == 1 ? dark : (val == 3 ? accent : orange)
                    let rect = CGRect(
                        x: ox + CGFloat(c) * px,
                        y: oy + CGFloat(r) * px,
                        width: px + 0.3,
                        height: px + 0.3
                    )
                    ctx.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// ── Standard Claude circle ───────────────────────────────────────────────────
struct ClaudeAvatarView: View {
    var size: CGFloat = 26

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color(red: 0.93, green: 0.63, blue: 0.42),
                             Color(red: 0.85, green: 0.44, blue: 0.28)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: size, height: size)
            ClaudeMark()
                .stroke(Color.white, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                .frame(width: size * 0.52, height: size * 0.52)
        }
    }
}

private struct ClaudeMark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX, cy = rect.midY, r = min(rect.width, rect.height) / 2
        p.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                 startAngle: .degrees(40), endAngle: .degrees(320), clockwise: false)
        let topX = cx + r * cos(40 * .pi / 180), topY = cy + r * sin(40 * .pi / 180)
        p.move(to: CGPoint(x: topX, y: topY))
        p.addLine(to: CGPoint(x: topX - r * 0.3, y: topY))
        let botX = cx + r * cos(320 * .pi / 180), botY = cy + r * sin(320 * .pi / 180)
        p.move(to: CGPoint(x: botX, y: botY))
        p.addLine(to: CGPoint(x: botX - r * 0.3, y: botY))
        return p
    }
}
