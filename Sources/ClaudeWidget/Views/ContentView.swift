import SwiftUI

struct ContentView: View {
    @StateObject private var service = AnthropicUsageService()
    @State private var showSettings = false

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow, cornerRadius: 20)

            VStack(spacing: 0) {

                // ── Header ──────────────────────────────────────────────
                HStack(spacing: 7) {
                    ClaudeLogoGroup(size: 24)
                    Text("Claude Usage")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Button { Task { await service.refresh() } } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.top, 11)
                .padding(.bottom, 9)

                Divider().background(Color.white.opacity(0.12))

                // ── Rolling limits ───────────────────────────────────────
                VStack(spacing: 10) {
                    UsageBar(label: "5-HOUR WINDOW", usage: service.fiveHour)
                    UsageBar(label: "SINCE THURSDAY", usage: service.weekly)
                }
                .padding(.top, 10)
                .padding(.bottom, 6)

                Divider().background(Color.white.opacity(0.08))

                // ── Today ────────────────────────────────────────────────
                SectionHeader(title: "TODAY")
                UsageRow(label: "Turns",       value: "\(service.today.turns)")
                UsageRow(label: "Output",      value: formatTokens(service.today.outputTokens))
                if service.today.cacheReadTokens > 0 {
                    UsageRow(label: "Cache read", value: formatTokens(service.today.cacheReadTokens))
                }

                Divider().background(Color.white.opacity(0.08)).padding(.top, 6)

                // ── This month ───────────────────────────────────────────
                SectionHeader(title: "THIS MONTH")
                UsageRow(label: "Turns",        value: "\(service.month.turns)")
                UsageRow(label: "Total tokens", value: formatTokens(service.month.totalTokens), accent: true)

                // ── Model breakdown ──────────────────────────────────────
                let topModels = service.modelBreakdown.sorted { $0.value > $1.value }.prefix(2)
                if !topModels.isEmpty {
                    Divider().background(Color.white.opacity(0.08)).padding(.top, 4)
                    SectionHeader(title: "MODELS")
                    ForEach(topModels, id: \.key) { m, t in
                        UsageRow(label: m, value: formatTokens(t))
                    }
                }

                Divider().background(Color.white.opacity(0.08)).padding(.top, 4)

                // ── Footer ───────────────────────────────────────────────
                HStack {
                    Text(service.lastUpdated)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.3))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
            }
        }
        .frame(width: 260)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
        .contextMenu {
            Button("Refresh")    { Task { await service.refresh() } }
            Button("Settings…")  { showSettings = true }
            Divider()
            Button("Quit")       { NSApplication.shared.terminate(nil) }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(isPresented: $showSettings) {
                Task { await service.refresh() }
            }
        }
        .task { await service.refresh() }
    }
}
