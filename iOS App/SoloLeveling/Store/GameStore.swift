import Foundation
import Combine

/// The single source of truth for game state. Owns the `SaveState`, persists it
/// to Documents, and implements the exact desktop formulas so mutations on the
/// phone are identical to mutations on the desktop.
public final class GameStore: ObservableObject {

    @Published public var save: SaveState

    /// Set when a level-up happens so the UI can present a celebration.
    @Published public var pendingLevelUps: Int = 0

    private let filename = "soloLevelingSave.json"

    private var saveURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory,
                                            in: .userDomainMask)[0]
        return docs.appendingPathComponent(filename)
    }

    public init() {
        if let loaded = GameStore.loadFromDisk(filename: "soloLevelingSave.json") {
            save = loaded
        } else {
            save = SaveState.defaultState()
        }
    }

    // MARK: - Persistence

    private static func loadFromDisk(filename: String) -> SaveState? {
        let docs = FileManager.default.urls(for: .documentDirectory,
                                            in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url),
              let str = String(data: data, encoding: .utf8),
              let root = try? JSONValue.parse(str) else {
            return nil
        }
        return SaveState(root: root)
    }

    /// Writes the current save to Documents (pretty-printed, desktop-style).
    public func persist() {
        let str = save.root.prettyString()
        try? str.data(using: .utf8)?.write(to: saveURL, options: .atomic)
    }

    /// Convenience: mutate, recompute derived fields, publish and persist.
    private func commit(_ mutate: (inout SaveState) -> Void) {
        var s = save
        mutate(&s)
        recomputeDerived(&s)
        save = s
        persist()
    }

    /// Recomputes fields that are pure functions of the rest of the state.
    private func recomputeDerived(_ s: inout SaveState) {
        s.hunterRank = GameData.rank(forScore: s.hunterScore)
    }

    // MARK: - XP multiplier (passives)

    /// Mirrors desktop xpMult: additive passives, then multiplicative buffs.
    public func xpMult(_ s: SaveState) -> Double {
        var mult = 1.0
        if s.stat("disc") >= 20 { mult += 0.10 }
        if s.stat("int") >= 25 { mult += 0.05 }
        if s.stat("str") >= 30 { mult += 0.10 }
        if s.level >= 20 { mult += 0.10 } // "gold" level passive
        if s.purchaseCount >= 5 { mult += 0.05 }
        if s.fullArmorEquipped { mult += 0.10 }

        let today = DateFmt.todayLocal()
        if s.buffDate("doubleXpDate") == today { mult *= 2 }
        if s.fatigued { mult *= 0.9 }
        return mult
    }

    /// Mirrors desktop gold multiplier / flat passives.
    public func goldMultiplier(_ s: SaveState) -> Double {
        var mult = 1.0
        if s.level >= 20 { mult += 0.10 }
        if s.bossesDefeated >= 5 { mult += 0.15 }
        if s.buffDate("tripleGoldDate") == DateFmt.todayLocal() { mult += 2 }
        return mult
    }

    /// Flat gold bonus per gold-earning event, from stat passives.
    public func goldFlatBonus(_ s: SaveState) -> Int {
        var flat = 0
        if s.stat("wealth") >= 20 { flat += 1 }
        if s.stat("faith") >= 25 { flat += 1 }
        if s.stat("influence") >= 30 { flat += 1 }
        return flat
    }

    // MARK: - XP / leveling

    /// Adds XP (after multiplier), leveling up as needed. Grants +3 stat points
    /// per level and records level-ups for the UI.
    private func addXp(_ amount: Int, to s: inout SaveState) {
        let scaled = Int((Double(amount) * xpMult(s)).rounded())
        s.xp += scaled
        var leveled = 0
        while s.xp >= s.xpToNext {
            s.xp -= s.xpToNext
            s.level += 1
            s.xpToNext = GameData.xpToNext(forLevel: s.level)
            s.statPoints += 3
            leveled += 1
        }
        if leveled > 0 {
            DispatchQueue.main.async { [weak self] in
                self?.pendingLevelUps += leveled
            }
        }
    }

    /// Public XP grant (used by generic actions/tests).
    public func addXp(_ amount: Int) {
        commit { addXp(amount, to: &$0) }
    }

    // MARK: - Gold

    private func awardGold(base: Int, to s: inout SaveState) {
        let amount = Int((Double(base) * goldMultiplier(s)).rounded()) + goldFlatBonus(s)
        s.gold += amount
    }

    // MARK: - Daily quests

    /// Completes the daily quest at `index`: stamps completedDate, awards XP +
    /// stat gain, bumps counters and history, then checks the keystone bonus.
    public func completeDailyQuest(index: Int) {
        commit { s in
            guard s.dailyQuests.indices.contains(index) else { return }
            let today = DateFmt.todayLocal()
            var quest = s.dailyQuests[index]

            // Already complete today? no-op.
            if quest["completedDate"]?.stringValue == today { return }

            let difficulty = GameData.Difficulty(
                rawValue: quest["difficulty"]?.stringValue ?? "easy") ?? .easy
            let statKey = quest["stat"]?.stringValue ?? "disc"

            quest["completedDate"] = .string(today)
            quest["xpEarnedDate"] = .string(today)
            s.dailyQuests[index] = quest

            addXp(difficulty.xp, to: &s)
            s.addStat(statKey, difficulty.statGain)
            s.totalQuestsCompleted += 1
            s.addHistory(date: today, key: "daily", delta: 1)

            checkKeystoneBonus(&s, today: today)
        }
    }

    /// Uncompletes a daily quest: flips completedDate back to null. Kept simple
    /// and safe — does not perfectly reverse XP/stat gains.
    public func uncompleteDailyQuest(index: Int) {
        commit { s in
            guard s.dailyQuests.indices.contains(index) else { return }
            var quest = s.dailyQuests[index]
            quest["completedDate"] = .null
            s.dailyQuests[index] = quest
        }
    }

    public func isDailyComplete(_ quest: JSONValue) -> Bool {
        quest["completedDate"]?.stringValue == DateFmt.todayLocal()
    }

    /// Full-keystone-clear bonus: when every keystone daily is done today and it
    /// wasn't already credited, award +40 XP and +5 gold and clear fatigue.
    private func checkKeystoneBonus(_ s: inout SaveState, today: String) {
        let keystones = s.dailyQuests.filter { $0["keystone"]?.boolValue == true }
        guard !keystones.isEmpty else { return }
        let allDone = keystones.allSatisfy { $0["completedDate"]?.stringValue == today }
        guard allDone, s.lastKeystoneClearDate != today else { return }

        s.lastKeystoneClearDate = today
        // push today into keystoneClearDates
        var dates = s.root.value(at: ["player", "keystoneClearDates"])?.arrayValue ?? []
        dates.append(.string(today))
        s.root.set(["player", "keystoneClearDates"], to: .array(dates))

        s.fatigued = false
        addXp(40, to: &s)
        awardGold(base: 5, to: &s)
    }

    // MARK: - Weekly quests

    /// Advances a weekly quest by one tick: +current, tick XP + tick stat, and
    /// on reaching target awards the completion bonus once.
    public func tickWeeklyQuest(index: Int) {
        commit { s in
            guard s.weeklyQuests.indices.contains(index) else { return }
            var q = s.weeklyQuests[index]

            if q["completed"]?.boolValue == true { return }

            let target = q["target"]?.intValue ?? 1
            let current = (q["current"]?.intValue ?? 0) + 1
            q["current"] = .int(min(current, target))

            let tickXp = q["tickXp"]?.intValue ?? 0
            let tickStat = q["tickStat"]?.intValue ?? 0
            let statKey = q["stat"]?.stringValue ?? "disc"

            addXp(tickXp, to: &s)
            if tickStat > 0 { s.addStat(statKey, tickStat) }

            if current >= target {
                q["completed"] = .bool(true)
                let completionXp = q["completionXp"]?.intValue ?? 0
                let completionStat = q["completionStat"]?.intValue ?? 0
                addXp(completionXp, to: &s)
                if completionStat > 0 { s.addStat(statKey, completionStat) }
                s.addHistory(date: DateFmt.todayLocal(), key: "weekly", delta: 1)
            }
            s.weeklyQuests[index] = q
        }
    }

    // MARK: - Armor

    /// Equips a piece if the faith gate is met. Returns whether it succeeded.
    @discardableResult
    public func equipArmor(_ id: String) -> Bool {
        guard let piece = GameData.armorPieces.first(where: { $0.id == id }) else {
            return false
        }
        guard save.faith >= piece.req else { return false }
        commit { $0.setEquipped(id, true) }
        return true
    }

    public func unequipArmor(_ id: String) {
        commit { $0.setEquipped(id, false) }
    }

    public func canEquip(_ id: String) -> Bool {
        guard let piece = GameData.armorPieces.first(where: { $0.id == id }) else {
            return false
        }
        return save.faith >= piece.req
    }

    public var fullArmorEquipped: Bool { save.fullArmorEquipped }

    // MARK: - Stat allocation

    /// Spends one stat point on a stat (no-op if none available).
    public func allocateStatPoint(_ key: String) {
        commit { s in
            guard s.statPoints > 0 else { return }
            s.statPoints -= 1
            s.addStat(key, 1)
        }
    }

    // MARK: - Rank

    public func computeRank() -> String {
        GameData.rank(forScore: save.hunterScore)
    }

    // MARK: - Sync import / export

    /// Replaces the entire local save with an imported JSON tree.
    public func replaceSave(from root: JSONValue) {
        var s = SaveState(root: root)
        recomputeDerived(&s)
        save = s
        persist()
    }

    /// Replaces the local save from a raw JSON string. Throws on parse failure.
    public func replaceSave(fromJSONString json: String) throws {
        let root = try JSONValue.parse(json)
        replaceSave(from: root)
    }

    /// The current save as a compact JSON string (for sync payload build).
    public func exportJSONString() -> String {
        save.root.compactString()
    }

    /// The current save as a pretty JSON string (for manual copy / backup).
    public func exportPrettyJSONString() -> String {
        save.root.prettyString()
    }

    // MARK: - Reset

    public func resetToDefault() {
        save = SaveState.defaultState()
        persist()
    }

    public func clearLevelUps() {
        pendingLevelUps = 0
    }
}
