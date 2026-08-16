import SwiftUI

/// The player "Status" window: identity header, XP bar, the six stats, and
/// gold + streak readouts.
struct DashboardView: View {
    @EnvironmentObject var store: GameStore

    private var save: SaveState { store.save }

    var body: some View {
        ZStack {
            Theme.bgGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    header
                    xpPanel
                    statsPanel
                    resourcesPanel
                }
                .padding(16)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        SystemPanel {
            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(save.playerName.uppercased())
                            .font(Theme.title(24))
                            .foregroundColor(Theme.textPrimary)
                        Text(save.classTitle)
                            .font(Theme.mono(13))
                            .foregroundColor(Theme.cyanSoft)
                    }
                    Spacer()
                    rankBadge
                }
                Divider().overlay(Theme.border)
                HStack {
                    labelStat("LEVEL", "\(save.level)")
                    Spacer()
                    labelStat("RANK", save.hunterRank)
                    Spacer()
                    labelStat("STREAK", "\(save.streak)d")
                    Spacer()
                    labelStat("QUESTS", "\(save.totalQuestsCompleted)")
                }
            }
        }
    }

    private var rankBadge: some View {
        VStack(spacing: 2) {
            Text(save.hunterRank)
                .font(Theme.title(28))
                .foregroundColor(Theme.gold)
            Text("HUNTER")
                .font(Theme.mono(9, weight: .bold))
                .tracking(2)
                .foregroundColor(Theme.textDim)
        }
        .frame(width: 64, height: 64)
        .background(Circle().fill(Theme.bg))
        .overlay(Circle().stroke(Theme.gold.opacity(0.6), lineWidth: 1.5))
        .shadow(color: Theme.gold.opacity(0.4), radius: 8)
    }

    private func labelStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.mono(16, weight: .bold))
                .foregroundColor(Theme.cyan)
            Text(label)
                .font(Theme.mono(9, weight: .bold))
                .tracking(1)
                .foregroundColor(Theme.textDim)
        }
    }

    // MARK: - XP

    private var xpPanel: some View {
        SystemPanel {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader("Experience")
                HStack {
                    Text("XP \(save.xp) / \(save.xpToNext)")
                        .font(Theme.mono(13))
                        .foregroundColor(Theme.cyanSoft)
                    Spacer()
                    Text("NEXT LV \(save.level + 1)")
                        .font(Theme.mono(11))
                        .foregroundColor(Theme.textDim)
                }
                GlowBar(value: xpFraction, color: Theme.cyan, height: 12)
                if save.statPoints > 0 {
                    Text("\(save.statPoints) stat point\(save.statPoints == 1 ? "" : "s") available — allocate below")
                        .font(Theme.mono(11))
                        .foregroundColor(Theme.gold)
                }
            }
        }
    }

    private var xpFraction: Double {
        guard save.xpToNext > 0 else { return 0 }
        return Double(save.xp) / Double(save.xpToNext)
    }

    // MARK: - Stats

    private var statsPanel: some View {
        SystemPanel {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Attributes")
                ForEach(GameData.stats) { stat in
                    statRow(stat)
                }
            }
        }
    }

    private func statRow(_ stat: GameData.Stat) -> some View {
        let value = save.stat(stat.key)
        // Bars scale relative to a soft ceiling of 100.
        let fraction = Double(min(value, 100)) / 100.0
        return VStack(spacing: 4) {
            HStack {
                Text(stat.label)
                    .font(Theme.mono(12, weight: .bold))
                    .foregroundColor(Theme.cyanSoft)
                    .frame(width: 34, alignment: .leading)
                Text(stat.fullName)
                    .font(Theme.mono(11))
                    .foregroundColor(Theme.textDim)
                Spacer()
                Text("\(value)")
                    .font(Theme.mono(14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                if save.statPoints > 0 {
                    Button {
                        store.allocateStatPoint(stat.key)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Theme.gold)
                    }
                }
            }
            GlowBar(value: fraction, color: barColor(for: stat.key), height: 8)
        }
    }

    private func barColor(for key: String) -> Color {
        key == "faith" ? Theme.gold : Theme.cyan
    }

    // MARK: - Resources

    private var resourcesPanel: some View {
        SystemPanel(accent: Theme.gold) {
            HStack(spacing: 20) {
                resource(icon: "\u{1FA99}", label: "GOLD", value: "\(save.gold)", color: Theme.gold)
                Divider().frame(height: 40).overlay(Theme.border)
                resource(icon: "\u{1F525}", label: "STREAK", value: "\(save.streak) days", color: Theme.cyan)
                Divider().frame(height: 40).overlay(Theme.border)
                resource(icon: "\u{2694}", label: "BOSSES", value: "\(save.bossesDefeated)", color: Theme.danger)
            }
        }
    }

    private func resource(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(icon).font(.system(size: 22))
            Text(value)
                .font(Theme.mono(15, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(Theme.mono(9, weight: .bold))
                .tracking(1)
                .foregroundColor(Theme.textDim)
        }
        .frame(maxWidth: .infinity)
    }
}
