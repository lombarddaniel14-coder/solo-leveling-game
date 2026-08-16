import SwiftUI

/// Daily and weekly quests. Tapping a daily toggles completion; weekly quests
/// advance one tick per press. All mutations go through the store so the exact
/// formulas apply.
struct QuestsView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        ZStack {
            Theme.bgGradient.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    dailySection
                    weeklySection
                }
                .padding(16)
            }
        }
    }

    // MARK: - Daily

    private var dailySection: some View {
        SystemPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader("Daily Quests")
                    Text(keystoneStatus)
                        .font(Theme.mono(10, weight: .bold))
                        .foregroundColor(allKeystonesDone ? Theme.success : Theme.textDim)
                }
                if store.save.dailyQuests.isEmpty {
                    emptyRow("No daily quests. Sync from desktop to load your board.")
                }
                ForEach(Array(store.save.dailyQuests.enumerated()), id: \.offset) { idx, quest in
                    dailyRow(index: idx, quest: quest)
                }
            }
        }
    }

    private func dailyRow(index: Int, quest: JSONValue) -> some View {
        let done = store.isDailyComplete(quest)
        let text = quest["text"]?.stringValue ?? "Quest"
        let statKey = quest["stat"]?.stringValue ?? ""
        let statLabel = GameData.stats.first { $0.key == statKey }?.label ?? statKey.uppercased()
        let difficulty = GameData.Difficulty(
            rawValue: quest["difficulty"]?.stringValue ?? "easy") ?? .easy
        let keystone = quest["keystone"]?.boolValue == true

        return Button {
            if done { store.uncompleteDailyQuest(index: index) }
            else { store.completeDailyQuest(index: index) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(done ? Theme.success : Theme.cyanDeep)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if keystone {
                            Image(systemName: "key.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.gold)
                        }
                        Text(text)
                            .font(Theme.mono(14, weight: .medium))
                            .strikethrough(done, color: Theme.textDim)
                            .foregroundColor(done ? Theme.textDim : Theme.textPrimary)
                            .multilineTextAlignment(.leading)
                    }
                    HStack(spacing: 8) {
                        tag(statLabel, color: Theme.cyan)
                        tag(difficulty.label, color: difficultyColor(difficulty))
                        tag("+\(difficulty.xp) XP", color: Theme.gold)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var allKeystonesDone: Bool {
        let ks = store.save.dailyQuests.filter { $0["keystone"]?.boolValue == true }
        guard !ks.isEmpty else { return false }
        return ks.allSatisfy { store.isDailyComplete($0) }
    }

    private var keystoneStatus: String {
        let ks = store.save.dailyQuests.filter { $0["keystone"]?.boolValue == true }
        let done = ks.filter { store.isDailyComplete($0) }.count
        return "KEYSTONE \(done)/\(ks.count)"
    }

    // MARK: - Weekly

    private var weeklySection: some View {
        SystemPanel(accent: Theme.gold) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Weekly Quests", accent: Theme.gold)
                if store.save.weeklyQuests.isEmpty {
                    emptyRow("No weekly quests yet.")
                }
                ForEach(Array(store.save.weeklyQuests.enumerated()), id: \.offset) { idx, quest in
                    weeklyRow(index: idx, quest: quest)
                }
            }
        }
    }

    private func weeklyRow(index: Int, quest: JSONValue) -> some View {
        let text = quest["text"]?.stringValue ?? "Quest"
        let target = quest["target"]?.intValue ?? 1
        let current = quest["current"]?.intValue ?? 0
        let completed = quest["completed"]?.boolValue == true
        let fraction = target > 0 ? Double(current) / Double(target) : 0

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(text)
                    .font(Theme.mono(14, weight: .medium))
                    .foregroundColor(completed ? Theme.textDim : Theme.textPrimary)
                Spacer()
                Text("\(current)/\(target)")
                    .font(Theme.mono(13, weight: .bold))
                    .foregroundColor(completed ? Theme.success : Theme.gold)
            }
            GlowBar(value: fraction, color: completed ? Theme.success : Theme.gold, height: 8)
            HStack {
                if completed {
                    Label("Complete", systemImage: "checkmark.seal.fill")
                        .font(Theme.mono(11, weight: .bold))
                        .foregroundColor(Theme.success)
                } else {
                    Button {
                        store.tickWeeklyQuest(index: index)
                    } label: {
                        Label("+1 Progress", systemImage: "plus")
                            .font(Theme.mono(12, weight: .bold))
                    }
                    .buttonStyle(SystemButtonStyle(accent: Theme.gold, filled: false))
                    .frame(maxWidth: 160)
                }
                Spacer()
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Helpers

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(Theme.mono(9, weight: .bold))
            .tracking(0.5)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(color.opacity(0.4), lineWidth: 0.5))
    }

    private func difficultyColor(_ d: GameData.Difficulty) -> Color {
        switch d {
        case .easy: return Theme.success
        case .medium: return Theme.cyan
        case .hard: return Theme.danger
        }
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .font(Theme.mono(12))
            .foregroundColor(Theme.textDim)
            .padding(.vertical, 8)
    }
}
