import Foundation

struct TurnUsage {
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheReadTokens: Int = 0
    var cacheCreateTokens: Int = 0
    var turns: Int = 0
    var totalTokens: Int { inputTokens + outputTokens + cacheReadTokens + cacheCreateTokens }
}

struct RollingUsage {
    var used: Double = 0      // cost-weighted usage ($, estimated)
    var limit: Double         // plan budget ($, estimated)
    var turns: Int = 0        // raw prompt count (shown as context only)
    var pct: Double  { limit > 0 ? min(1.0, used / limit) : 0 }
    var remaining: Double { max(0, limit - used) }
}

@MainActor
class AnthropicUsageService: ObservableObject {
    @Published var today    = TurnUsage()
    @Published var month    = TurnUsage()
    @Published var fiveHour = RollingUsage(limit: 800)
    @Published var weekly   = RollingUsage(limit: 16400)
    @Published var modelBreakdown: [String: Int] = [:]
    @Published var isLoading: Bool = false
    @Published var lastUpdated: String = "Never refreshed"

    // Plan budgets are stored as an estimated compute cost ($) so the bars track
    // Claude.ai's token-weighted, model-differentiated metering rather than raw turns.
    // Defaults are calibrated to the Max-5x plan.
    var fiveHourBudget: Double {
        get { let v = UserDefaults.standard.double(forKey: "fiveHourBudget"); return v > 0 ? v : 800 }
        set { UserDefaults.standard.set(newValue, forKey: "fiveHourBudget") }
    }
    var weeklyBudget: Double {
        get { let v = UserDefaults.standard.double(forKey: "weeklyBudget"); return v > 0 ? v : 16400 }
        set { UserDefaults.standard.set(newValue, forKey: "weeklyBudget") }
    }

    private var timer: Timer?
    private let projectsDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/projects")

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.refresh() }
        }
    }
    deinit { timer?.invalidate() }

    func refresh() async {
        isLoading = true
        let limits = (fiveHr: fiveHourBudget, weekly: weeklyBudget)
        let r = await Task.detached(priority: .userInitiated) {
            await Self.parse(projectsDir: self.projectsDir, limits: limits)
        }.value
        today          = r.today
        month          = r.month
        fiveHour       = r.fiveHour
        weekly         = r.weekly
        modelBreakdown = r.models
        let f = DateFormatter(); f.timeStyle = .short
        lastUpdated = "Updated \(f.string(from: Date()))"
        isLoading = false
    }

    // MARK: – Background parsing

    private static func parse(
        projectsDir: URL,
        limits: (fiveHr: Double, weekly: Double)
    ) async -> (today: TurnUsage, month: TurnUsage,
                fiveHour: RollingUsage, weekly: RollingUsage,
                models: [String: Int]) {

        let cal         = Calendar.current
        let now         = Date()
        let todayStart  = cal.startOfDay(for: now)
        let monthStart  = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let fiveHrStart = now.addingTimeInterval(-5 * 3600)
        // Weekly = since last Thursday midnight (Claude.ai resets Thu 00:00 local)
        let weekStart   = lastThursday(cal: cal, from: now)

        var todayAcc  = TurnUsage()
        var monthAcc  = TurnUsage()
        var fiveHrIDs = Set<String>()
        var weekIDs   = Set<String>()
        var todayIDs  = Set<String>()
        var monthIDs  = Set<String>()
        var models    = [String: Int]()
        var fiveHrCost = 0.0   // cost-weighted usage ($) in the 5-hour window
        var weekCost   = 0.0   // cost-weighted usage ($) since last Thursday

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fm = FileManager.default

        guard let projects = try? fm.contentsOfDirectory(
            at: projectsDir, includingPropertiesForKeys: nil) else {
            return (todayAcc, monthAcc,
                    RollingUsage(limit: limits.fiveHr),
                    RollingUsage(limit: limits.weekly), models)
        }

        for proj in projects {
            guard let files = try? fm.contentsOfDirectory(
                at: proj, includingPropertiesForKeys: nil) else { continue }
            for file in files where file.pathExtension == "jsonl" {
                guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
                for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
                    guard let data = line.data(using: .utf8),
                          let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let tsStr = obj["timestamp"] as? String,
                          let ts   = iso.date(from: tsStr)
                    else { continue }

                    let msg = obj["message"] as? [String: Any] ?? [:]

                    // ── Token & cost accounting (assistant API responses) ────
                    // Cost-weighted usage drives the 5-hour / weekly bars so they
                    // track Claude.ai's token-weighted, per-model metering rather
                    // than raw turn counts.
                    if let uRaw = msg["usage"] as? [String: Any] {
                        let model = msg["model"] as? String ?? "unknown"
                        let cost  = tokenCost(model: model, uRaw)
                        if ts >= fiveHrStart { fiveHrCost += cost }
                        if ts >= weekStart   { weekCost   += cost }

                        if ts >= monthStart {
                            let inp   = uRaw["input_tokens"]               as? Int ?? 0
                            let out   = uRaw["output_tokens"]              as? Int ?? 0
                            let cRead = uRaw["cache_read_input_tokens"]    as? Int ?? 0
                            let cCr   = uRaw["cache_creation_input_tokens"] as? Int ?? 0

                            monthAcc.inputTokens       += inp
                            monthAcc.outputTokens      += out
                            monthAcc.cacheReadTokens   += cRead
                            monthAcc.cacheCreateTokens += cCr
                            models[shortName(model), default: 0] += inp + out

                            if ts >= todayStart {
                                todayAcc.inputTokens       += inp
                                todayAcc.outputTokens      += out
                                todayAcc.cacheReadTokens   += cRead
                                todayAcc.cacheCreateTokens += cCr
                            }
                        }
                    }

                    // ── Turn counting: unique user-initiated prompt IDs ───────
                    // Only count "user" entries whose content is a plain string
                    // (tool-result entries have array content and don't count as turns).
                    // Windows are evaluated independently so the weekly window still
                    // counts turns that fall before the 1st of the month.
                    if let entryType = obj["type"] as? String,
                       entryType == "user",
                       (msg["content"] as? String) != nil,   // real human text, not tool results
                       let pid = obj["promptId"] as? String, !pid.isEmpty {
                        if ts >= monthStart  { monthIDs.insert(pid) }
                        if ts >= todayStart  { todayIDs.insert(pid) }
                        if ts >= fiveHrStart { fiveHrIDs.insert(pid) }
                        if ts >= weekStart   { weekIDs.insert(pid) }
                    }
                }
            }
        }

        todayAcc.turns = todayIDs.count
        monthAcc.turns = monthIDs.count

        var fhr = RollingUsage(limit: limits.fiveHr)
        fhr.used = fiveHrCost; fhr.turns = fiveHrIDs.count
        var wk  = RollingUsage(limit: limits.weekly)
        wk.used = weekCost; wk.turns = weekIDs.count

        return (todayAcc, monthAcc, fhr, wk, models)
    }

    // Last Thursday midnight in current timezone (Claude.ai weekly reset day)
    private static func lastThursday(cal: Calendar, from now: Date) -> Date {
        let todayStart = cal.startOfDay(for: now)
        let weekday    = cal.component(.weekday, from: todayStart)  // 1=Sun…7=Sat (Thu=5)
        let daysBack   = (weekday + 2) % 7  // 0 on Thu, 1 on Fri, 2 on Sat, 3 on Sun…
        return cal.date(byAdding: .day, value: -daysBack, to: todayStart)!
    }

    // Estimated compute cost ($) of one API response, using approximate Anthropic
    // list prices ($/Mtok) as per-model weights: input, output, cache-write, cache-read.
    private static func tokenCost(model: String, _ u: [String: Any]) -> Double {
        let pin: Double, pout: Double, pcw: Double, pcr: Double
        if model.contains("opus")        { pin = 15; pout = 75; pcw = 18.75; pcr = 1.50 }
        else if model.contains("haiku")  { pin = 1;  pout = 5;  pcw = 1.25;  pcr = 0.10 }
        else                             { pin = 3;  pout = 15; pcw = 3.75;  pcr = 0.30 } // sonnet / default
        let inp = Double(u["input_tokens"]                as? Int ?? 0)
        let out = Double(u["output_tokens"]               as? Int ?? 0)
        let cw  = Double(u["cache_creation_input_tokens"] as? Int ?? 0)
        let cr  = Double(u["cache_read_input_tokens"]     as? Int ?? 0)
        return (inp * pin + out * pout + cw * pcw + cr * pcr) / 1_000_000
    }

    private static func shortName(_ m: String) -> String {
        if m.contains("opus")   { return "Opus" }
        if m.contains("sonnet") { return "Sonnet" }
        if m.contains("haiku")  { return "Haiku" }
        return m
    }
}

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}

func formatTokens(_ n: Int) -> String {
    switch n {
    case ..<1_000:     return "\(n)"
    case ..<1_000_000: return String(format: "%.1fK", Double(n) / 1_000)
    default:           return String(format: "%.2fM", Double(n) / 1_000_000)
    }
}
