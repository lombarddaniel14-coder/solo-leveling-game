import SwiftUI

/// A grid of achievement "records". Locked achievements are dimmed; secret
/// ones show ??? until unlocked.
struct AchievementsView: View {
    @EnvironmentObject var store: GameStore

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    private var unlockedCount: Int {
        GameData.achievements.filter { store.save.isAchievementUnlocked($0.id) }.count
    }

    var body: some View {
        ZStack {
            Theme.bgGradient.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    header
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(GameData.achievements) { ach in
                            cell(ach)
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    private var header: some View {
        SystemPanel {
            HStack {
                SectionHeader("Records")
                Text("\(unlockedCount)/\(GameData.achievements.count)")
                    .font(Theme.mono(14, weight: .bold))
                    .foregroundColor(Theme.gold)
            }
        }
    }

    private func cell(_ ach: GameData.Achievement) -> some View {
        let unlocked = store.save.isAchievementUnlocked(ach.id)
        let showSecret = ach.secret && !unlocked

        return VStack(spacing: 8) {
            Text(showSecret ? "\u{2753}" : ach.icon)
                .font(.system(size: 34))
                .opacity(unlocked ? 1 : 0.4)
            Text(showSecret ? "???" : ach.name)
                .font(Theme.mono(12, weight: .bold))
                .foregroundColor(unlocked ? Theme.textPrimary : Theme.textDim)
                .multilineTextAlignment(.center)
            Text(showSecret ? "Hidden record" : ach.desc)
                .font(Theme.mono(9))
                .foregroundColor(Theme.textDim)
                .multilineTextAlignment(.center)
                .lineLimit(3)
            if unlocked {
                Label("UNLOCKED", systemImage: "checkmark.seal.fill")
                    .font(Theme.mono(8, weight: .bold))
                    .foregroundColor(Theme.success)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.bgPanel))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(unlocked ? Theme.gold.opacity(0.6) : Theme.border,
                        lineWidth: 1))
        .shadow(color: unlocked ? Theme.gold.opacity(0.25) : .clear, radius: 8)
    }
}
