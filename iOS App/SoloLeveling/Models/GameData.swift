import Foundation

/// Static game definitions mirroring the desktop app
/// (solo-leveling-system-v2.html). Keep these in sync with the desktop so the
/// two clients agree on labels, gates, thresholds and titles.
public enum GameData {

    // MARK: - Stats

    /// A single character stat.
    public struct Stat: Identifiable {
        public let key: String      // storage key inside player.stats
        public let label: String    // short label shown on bars (e.g. "STR")
        public let fullName: String // long name (e.g. "Strength")
        public var id: String { key }
    }

    /// The six stats, in desktop display order.
    public static let stats: [Stat] = [
        Stat(key: "str",       label: "STR", fullName: "Strength"),
        Stat(key: "wealth",    label: "WLT", fullName: "Wealth"),
        Stat(key: "int",       label: "INT", fullName: "Intelligence"),
        Stat(key: "influence", label: "INF", fullName: "Influence"),
        Stat(key: "faith",     label: "FTH", fullName: "Faith"),
        Stat(key: "disc",      label: "DIS", fullName: "Discipline"),
    ]

    /// Base value every stat starts at.
    public static let baseStat = 10

    // MARK: - Difficulty

    public enum Difficulty: String, CaseIterable {
        case easy, medium, hard

        public var xp: Int {
            switch self {
            case .easy: return 10
            case .medium: return 20
            case .hard: return 35
            }
        }

        public var statGain: Int {
            switch self {
            case .easy: return 1
            case .medium: return 2
            case .hard: return 3
            }
        }

        public var label: String { rawValue.uppercased() }
    }

    // MARK: - Armor of God

    /// One equippable Armor-of-God piece. Unlock gate = player.stats.faith >= req.
    public struct ArmorPiece: Identifiable {
        public let id: String       // equipment key: helmet, breastplate, ...
        public let part: String     // body part / slot description
        public let name: String
        public let req: Int         // faith requirement to unlock
        public let verse: String    // scripture reference
        public let sfSymbol: String // SF Symbol used as the icon
    }

    /// The ONLY equippable gear, in canonical order.
    public static let armorPieces: [ArmorPiece] = [
        ArmorPiece(id: "helmet",      part: "Head",  name: "Helmet of Salvation",
                   req: 25, verse: "Ephesians 6:17", sfSymbol: "shield.lefthalf.filled"),
        ArmorPiece(id: "breastplate", part: "Chest", name: "Breastplate of Righteousness",
                   req: 35, verse: "Ephesians 6:14", sfSymbol: "figure.stand"),
        ArmorPiece(id: "belt",        part: "Waist", name: "Belt of Truth",
                   req: 15, verse: "Ephesians 6:14", sfSymbol: "minus.rectangle.fill"),
        ArmorPiece(id: "shoes",       part: "Feet",  name: "Shoes of the Gospel of Peace",
                   req: 20, verse: "Ephesians 6:15", sfSymbol: "shoeprints.fill"),
        ArmorPiece(id: "shield",      part: "Arm",   name: "Shield of Faith",
                   req: 45, verse: "Ephesians 6:16", sfSymbol: "shield.fill"),
        ArmorPiece(id: "sword",       part: "Hand",  name: "Sword of the Spirit",
                   req: 60, verse: "Ephesians 6:17", sfSymbol: "bolt.fill"),
    ]

    // MARK: - Achievements

    public struct Achievement: Identifiable {
        public let id: String
        public let icon: String    // emoji icon (as on desktop)
        public let name: String
        public let desc: String
        public let secret: Bool
    }

    /// Inferred achievement set mirroring the desktop milestones. Secret ones
    /// render as ??? until unlocked. Extend to match desktop exactly when the
    /// full list is confirmed on-device.
    public static let achievements: [Achievement] = [
        Achievement(id: "first_quest", icon: "\u{2728}", name: "First Steps",
                    desc: "Complete your first quest.", secret: false),
        Achievement(id: "level_5", icon: "\u{1F31F}", name: "Faithful Steward",
                    desc: "Reach level 5.", secret: false),
        Achievement(id: "level_10", icon: "\u{1F3D7}", name: "The Builder",
                    desc: "Reach level 10.", secret: false),
        Achievement(id: "level_20", icon: "\u{1F451}", name: "Man of Purpose",
                    desc: "Reach level 20.", secret: false),
        Achievement(id: "streak_7", icon: "\u{1F525}", name: "Week of Fire",
                    desc: "Hold a 7-day streak.", secret: false),
        Achievement(id: "streak_30", icon: "\u{2604}", name: "Unbroken",
                    desc: "Hold a 30-day streak.", secret: false),
        Achievement(id: "full_armor", icon: "\u{1F6E1}", name: "Full Armor of God",
                    desc: "Equip all six pieces of armor.", secret: false),
        Achievement(id: "faith_60", icon: "\u{271D}", name: "Sword Bearer",
                    desc: "Raise Faith to 60.", secret: false),
        Achievement(id: "gold_1000", icon: "\u{1FA99}", name: "Treasurer",
                    desc: "Accumulate 1,000 gold.", secret: false),
        Achievement(id: "boss_first", icon: "\u{2694}", name: "Giant Slayer",
                    desc: "Defeat your first boss raid.", secret: false),
        Achievement(id: "rank_s", icon: "\u{1F3C5}", name: "S-Rank Hunter",
                    desc: "Reach Hunter Rank S.", secret: false),
        Achievement(id: "hundred_quests", icon: "\u{1F4AF}", name: "Centurion",
                    desc: "Complete 100 quests.", secret: false),
        Achievement(id: "keystone_clear", icon: "\u{1F5DD}", name: "Keystone Clear",
                    desc: "Clear all keystone quests in a single day.", secret: false),
        Achievement(id: "night_owl", icon: "\u{1F989}", name: "Night Owl",
                    desc: "Hidden.", secret: true),
        Achievement(id: "national_rank", icon: "\u{1F310}", name: "National Level",
                    desc: "Hidden.", secret: true),
    ]

    // MARK: - Hunter Rank

    public struct RankThreshold {
        public let rank: String
        public let min: Int
    }

    /// Ordered high → low; first match wins.
    public static let rankThresholds: [RankThreshold] = [
        RankThreshold(rank: "NATIONAL", min: 120),
        RankThreshold(rank: "S",        min: 80),
        RankThreshold(rank: "A",        min: 55),
        RankThreshold(rank: "B",        min: 35),
        RankThreshold(rank: "C",        min: 20),
        RankThreshold(rank: "D",        min: 10),
        RankThreshold(rank: "E",        min: 0),
    ]

    /// Computes hunter rank letter from a raw hunter score.
    public static func rank(forScore score: Int) -> String {
        for t in rankThresholds where score >= t.min {
            return t.rank
        }
        return "E"
    }

    // MARK: - Class titles

    /// Class title shown for a given level.
    public static func classTitle(forLevel level: Int) -> String {
        switch level {
        case 40...: return "Servant King"
        case 30..<40: return "Servant Leader"
        case 20..<30: return "Man of Purpose"
        case 15..<20: return "Kingdom Entrepreneur"
        case 10..<15: return "The Builder"
        case 5..<10:  return "Faithful Steward"
        default:      return "Disciple in Training"
        }
    }

    // MARK: - XP curve

    /// XP required to advance from `level` to `level + 1`.
    public static func xpToNext(forLevel level: Int) -> Int {
        100 + (level - 1) * 40
    }
}
