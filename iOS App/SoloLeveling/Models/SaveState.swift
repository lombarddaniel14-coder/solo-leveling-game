import Foundation

/// A view over the desktop save. The underlying `root` is a `JSONValue` that
/// holds the ENTIRE state (including keys the phone doesn't use), so
/// re-serializing is byte-faithful to the desktop format.
///
/// All getters tolerate missing keys and fall back to sensible defaults.
/// All setters mutate `root` in place so the save stays complete.
public struct SaveState: Equatable {
    public var root: JSONValue

    public init(root: JSONValue) {
        self.root = root
    }

    // MARK: - Generic nested access

    private func number(_ path: [String], default def: Double = 0) -> Double {
        root.value(at: path)?.doubleValue ?? def
    }

    private func int(_ path: [String], default def: Int = 0) -> Int {
        root.value(at: path)?.intValue ?? def
    }

    private func string(_ path: [String], default def: String = "") -> String {
        root.value(at: path)?.stringValue ?? def
    }

    private func bool(_ path: [String], default def: Bool = false) -> Bool {
        root.value(at: path)?.boolValue ?? def
    }

    private mutating func setInt(_ path: [String], _ value: Int) {
        root.set(path, to: .number(Double(value)))
    }

    private mutating func setDouble(_ path: [String], _ value: Double) {
        root.set(path, to: .number(value))
    }

    private mutating func setString(_ path: [String], _ value: String) {
        root.set(path, to: .string(value))
    }

    private mutating func setBool(_ path: [String], _ value: Bool) {
        root.set(path, to: .bool(value))
    }

    // MARK: - Player scalars

    public var playerName: String {
        get { string(["player", "name"], default: "Hunter") }
        set { setString(["player", "name"], newValue) }
    }

    public var level: Int {
        get { int(["player", "level"], default: 1) }
        set { setInt(["player", "level"], newValue) }
    }

    public var xp: Int {
        get { int(["player", "xp"]) }
        set { setInt(["player", "xp"], newValue) }
    }

    public var xpToNext: Int {
        get { int(["player", "xpToNext"], default: 100) }
        set { setInt(["player", "xpToNext"], newValue) }
    }

    public var statPoints: Int {
        get { int(["player", "statPoints"]) }
        set { setInt(["player", "statPoints"], newValue) }
    }

    public var streak: Int {
        get { int(["player", "streak"]) }
        set { setInt(["player", "streak"], newValue) }
    }

    public var gold: Int {
        get { int(["player", "gold"]) }
        set { setInt(["player", "gold"], newValue) }
    }

    public var goldFromIncome: Int {
        get { int(["player", "goldFromIncome"]) }
        set { setInt(["player", "goldFromIncome"], newValue) }
    }

    public var totalQuestsCompleted: Int {
        get { int(["player", "totalQuestsCompleted"]) }
        set { setInt(["player", "totalQuestsCompleted"], newValue) }
    }

    public var mainQuestsCompleted: Int {
        get { int(["player", "mainQuestsCompleted"]) }
        set { setInt(["player", "mainQuestsCompleted"], newValue) }
    }

    public var bossesDefeated: Int {
        get { int(["player", "bossesDefeated"]) }
        set { setInt(["player", "bossesDefeated"], newValue) }
    }

    public var purchaseCount: Int {
        get { int(["player", "purchaseCount"]) }
        set { setInt(["player", "purchaseCount"], newValue) }
    }

    public var hunterRank: String {
        get { string(["player", "hunterRank"], default: "E") }
        set { setString(["player", "hunterRank"], newValue) }
    }

    public var activeTitle: String {
        get { string(["player", "activeTitle"]) }
        set { setString(["player", "activeTitle"], newValue) }
    }

    public var fatigued: Bool {
        get { bool(["player", "fatigued"]) }
        set { setBool(["player", "fatigued"], newValue) }
    }

    public var lastKeystoneClearDate: String {
        get { string(["player", "lastKeystoneClearDate"]) }
        set { setString(["player", "lastKeystoneClearDate"], newValue) }
    }

    // MARK: - Stats

    /// Reads a stat value (base 10 if absent).
    public func stat(_ key: String) -> Int {
        int(["player", "stats", key], default: GameData.baseStat)
    }

    /// Writes a stat value.
    public mutating func setStat(_ key: String, _ value: Int) {
        setInt(["player", "stats", key], value)
    }

    public mutating func addStat(_ key: String, _ delta: Int) {
        setStat(key, stat(key) + delta)
    }

    public var faith: Int { stat("faith") }

    // MARK: - Equipment

    public func isEquipped(_ id: String) -> Bool {
        bool(["equipment", id])
    }

    public mutating func setEquipped(_ id: String, _ value: Bool) {
        setBool(["equipment", id], value)
    }

    /// True when all six armor pieces are equipped.
    public var fullArmorEquipped: Bool {
        GameData.armorPieces.allSatisfy { isEquipped($0.id) }
    }

    // MARK: - Buffs (date-keyed)

    public func buffDate(_ key: String) -> String {
        string(["buffs", key])
    }

    // MARK: - Quests

    public var dailyQuests: [JSONValue] {
        get { root.value(at: ["dailyQuests"])?.arrayValue ?? [] }
        set { root.set(["dailyQuests"], to: .array(newValue)) }
    }

    public var weeklyQuests: [JSONValue] {
        get { root.value(at: ["weeklyQuests"])?.arrayValue ?? [] }
        set { root.set(["weeklyQuests"], to: .array(newValue)) }
    }

    // MARK: - Achievements

    public var unlockedAchievements: [String] {
        (root.value(at: ["unlockedAchievements"])?.arrayValue ?? [])
            .compactMap { $0.stringValue }
    }

    public func isAchievementUnlocked(_ id: String) -> Bool {
        unlockedAchievements.contains(id)
    }

    // MARK: - History

    /// Increments a history counter, e.g. history[today].daily += n.
    public mutating func addHistory(date: String, key: String, delta: Int) {
        let path = ["history", date, key]
        let current = int(path)
        setInt(path, current + delta)
    }

    // MARK: - Derived

    /// hunterScore = level*2 + streak + mainQuestsCompleted*3 + bossesDefeated*4
    public var hunterScore: Int {
        level * 2 + streak + mainQuestsCompleted * 3 + bossesDefeated * 4
    }

    public var classTitle: String {
        GameData.classTitle(forLevel: level)
    }

    // MARK: - Default state

    /// A fresh save matching the desktop schema. Used on first launch or reset.
    public static func defaultState() -> SaveState {
        let today = DateFmt.todayLocal()

        func quest(_ id: String, _ text: String, _ stat: String,
                   _ difficulty: String, keystone: Bool) -> JSONValue {
            .object([
                "id": .string(id),
                "text": .string(text),
                "stat": .string(stat),
                "difficulty": .string(difficulty),
                "completedDate": .null,
                "xpEarnedDate": .null,
                "keystone": .bool(keystone),
            ])
        }

        func weekly(_ id: String, _ text: String, _ stat: String, target: Int,
                    tickXp: Int, tickStat: Int, completionXp: Int,
                    completionStat: Int) -> JSONValue {
            .object([
                "id": .string(id),
                "text": .string(text),
                "stat": .string(stat),
                "target": .number(Double(target)),
                "current": .number(0),
                "completed": .bool(false),
                "weekKey": .string(DateFmt.weekKey()),
                "tickXp": .number(Double(tickXp)),
                "tickStat": .number(Double(tickStat)),
                "completionXp": .number(Double(completionXp)),
                "completionStat": .number(Double(completionStat)),
            ])
        }

        let stats: JSONValue = .object([
            "str": .int(GameData.baseStat),
            "wealth": .int(GameData.baseStat),
            "int": .int(GameData.baseStat),
            "influence": .int(GameData.baseStat),
            "faith": .int(GameData.baseStat),
            "disc": .int(GameData.baseStat),
        ])

        let player: JSONValue = .object([
            "name": .string("Hunter"),
            "level": .int(1),
            "xp": .int(0),
            "xpToNext": .int(100),
            "statPoints": .int(0),
            "stats": stats,
            "streak": .int(0),
            "lastActiveDate": .string(today),
            "totalQuestsCompleted": .int(0),
            "mainQuestsCompleted": .int(0),
            "gold": .int(0),
            "goldFromIncome": .int(0),
            "totalIncomeLogged": .int(0),
            "totalGoldSpent": .int(0),
            "purchaseCount": .int(0),
            "bossesDefeated": .int(0),
            "hunterRank": .string("E"),
            "activeTitle": .string(""),
            "fatigued": .bool(false),
            "nightOwl": .bool(false),
            "hadStreakReset": .bool(false),
            "keystoneClearDates": .array([]),
            "lastKeystoneClearDate": .null,
            "lastPenaltyDate": .null,
            "lastRolloverDay": .string(today),
            "seededEldenRing": .bool(false),
            "lastRotationWeek": .string(DateFmt.weekKey()),
        ])

        let root: JSONValue = .object([
            "player": player,
            "history": .object([:]),
            "dailyQuests": .array([
                quest("d_train", "Train / workout", "str", "medium", keystone: true),
                quest("d_read", "Read or study 20 min", "int", "easy", keystone: true),
                quest("d_pray", "Prayer & scripture", "faith", "easy", keystone: true),
                quest("d_deep", "One deep-work block", "disc", "hard", keystone: false),
                quest("d_reach", "Reach out / network", "influence", "easy", keystone: false),
            ]),
            "weeklyQuests": .array([
                weekly("w_workouts", "Complete 4 workouts", "str", target: 4,
                       tickXp: 10, tickStat: 1, completionXp: 40, completionStat: 2),
                weekly("w_income", "Log income 3 days", "wealth", target: 3,
                       tickXp: 12, tickStat: 1, completionXp: 40, completionStat: 2),
                weekly("w_read", "Read 5 chapters", "int", target: 5,
                       tickXp: 8, tickStat: 1, completionXp: 30, completionStat: 2),
            ]),
            "goals": .object([:]),
            "mainQuests": .array([]),
            "bossRaids": .array([]),
            "purchases": .array([]),
            "unlockedAchievements": .array([]),
            "unlockedTitles": .array([]),
            "buffs": .object([
                "doubleXpDate": .null,
                "doubleXpWeek": .null,
                "streakShield": .null,
                "streakShieldWeek": .null,
                "tripleGoldDate": .null,
                "tripleGoldWeek": .null,
                "bloodlustWeek": .null,
            ]),
            "equipment": .object([
                "helmet": .bool(false),
                "breastplate": .bool(false),
                "belt": .bool(false),
                "shoes": .bool(false),
                "shield": .bool(false),
                "sword": .bool(false),
            ]),
            "hiddenQuests": .object([
                "active": .null,
                "pending": .null,
                "completed": .array([]),
                "failed": .array([]),
                "lastEventDate": .null,
            ]),
        ])

        return SaveState(root: root)
    }
}

// MARK: - Date helpers

/// Local-date formatting shared across the app. Matches the desktop's
/// `YYYY-MM-DD` local-date convention and ISO week keys.
public enum DateFmt {
    /// Local `YYYY-MM-DD` for a given date (default: now).
    public static func todayLocal(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// ISO-8601 year + week key, e.g. "2026-W29". Used for weekly quests.
    public static func weekKey(_ date: Date = Date()) -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2 // Monday
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let year = comps.yearForWeekOfYear ?? 0
        let week = comps.weekOfYear ?? 0
        return String(format: "%04d-W%02d", year, week)
    }
}
