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
    var turns: Int = 0
    var limit: Int
    var pct: Double  { limit > 0 ? min(1.0, Double(turns) / Double(limit)) : 0 }
    var remaining: Int { max(0, limit - turns) }
}

@MainActor
class AnthropicUsageService: ObservableObject {
    @Published var today    = TurnUsage()
    @Published var month    = TurnUsage()
    @Published var fiveHour = RollingUsage(limit: 225)
    @Published var weekly   = RollingUsage(limit: 2450)
    @Published var modelBreakdown: [String: Int] = [:]
    @Published var isLoading: Bool = false
    @Published var lastUpdated: String = "Never refreshed"

    var fiveHourLimit: Int {
        get { UserDefaults.standard.integer(forKey: "fiveHourLimit").nonZero ?? 225 }
        set { UserDefaults.standard.set(newValue, forKey: "fiveHourLimit") }
    }
    var weeklyLimit: Int {
        get { UserDefaults.standard.integer(forKey: "weeklyLimit").nonZero ?? 2450 }
        set { UserDefaults.standard.set(newValue, forKey: "weeklyLimit") }
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
        let limits = (fiveHr: fiveHourLimit, weekly: weeklyLimit)
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
        limits: (fiveHr: Int, weekly: Int)
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

                    // ── Token accounting (assistant API responses) ───────────
                    if let uRaw = msg["usage"] as? [String: Any], ts >= monthStart {
                        let inp   = uRaw["input_tokens"]               as? Int ?? 0
                        let out   = uRaw["output_tokens"]              as? Int ?? 0
                        let cRead = uRaw["cache_read_input_tokens"]    as? Int ?? 0
                        let cCr   = uRaw["cache_creation_input_tokens"] as? Int ?? 0
                        let model = msg["model"] as? String ?? "unknown"

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

                    // ── Turn counting: unique user-initiated prompt IDs ───────
                    // Only count "user" entries whose content is a plain string
                    // (tool-result entries have array content and don't count as turns).
                    if let entryType = obj["type"] as? String,
                       entryType == "user",
                       (msg["content"] as? String) != nil,   // real human text, not tool results
                       let pid = obj["promptId"] as? String, !pid.isEmpty,
                       ts >= monthStart {
                        monthIDs.insert(pid)
                        if ts >= todayStart  { todayIDs.insert(pid) }
                        if ts >= fiveHrStart { fiveHrIDs.insert(pid) }
                        if ts >= weekStart   { weekIDs.insert(pid) }
                    }
                }
            }
        }

        todayAcc.turns = todayIDs.count
        monthAcc.turns = monthIDs.count

        var fhr = RollingUsage(limit: limits.fiveHr); fhr.turns = fiveHrIDs.count
        var wk  = RollingUsage(limit: limits.weekly); wk.turns  = weekIDs.count

        return (todayAcc, monthAcc, fhr, wk, models)
    }

    // Last Thursday midnight in current timezone (Claude.ai weekly reset day)
    private static func lastThursday(cal: Calendar, from now: Date) -> Date {
        let todayStart = cal.startOfDay(for: now)
        let weekday    = cal.component(.weekday, from: todayStart)  // 1=Sun…7=Sat
        let daysBack   = (weekday + 1) % 7  // 0 on Thu, 1 on Fri, 2 on Sat, 3 on Sun…
        return cal.date(byAdding: .day, value: -daysBack, to: todayStart)!
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
