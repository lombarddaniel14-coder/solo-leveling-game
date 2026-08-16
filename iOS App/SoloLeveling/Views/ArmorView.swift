import SwiftUI

/// The Armor of God loadout. Pieces unlock once Faith meets their requirement;
/// equipping all six grants a +10% XP aura.
struct ArmorView: View {
    @EnvironmentObject var store: GameStore

    private var faith: Int { store.save.faith }

    var body: some View {
        ZStack {
            Theme.bgGradient.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    if store.fullArmorEquipped {
                        fullArmorBanner
                    }
                    silhouettePanel
                    ForEach(GameData.armorPieces) { piece in
                        armorRow(piece)
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Full armor banner

    private var fullArmorBanner: some View {
        SystemPanel(accent: Theme.gold) {
            HStack(spacing: 12) {
                Text("\u{1F6E1}").font(.system(size: 30))
                VStack(alignment: .leading, spacing: 2) {
                    Text("FULL ARMOR OF GOD")
                        .font(Theme.mono(15, weight: .bold))
                        .tracking(1)
                        .foregroundColor(Theme.gold)
                    Text("+10% XP aura active — all six pieces equipped.")
                        .font(Theme.mono(11))
                        .foregroundColor(Theme.cyanSoft)
                }
                Spacer()
            }
        }
    }

    // MARK: - Silhouette

    private var silhouettePanel: some View {
        SystemPanel {
            VStack(spacing: 8) {
                SectionHeader("Loadout")
                HunterSilhouette(equipped: equippedSet)
                    .frame(height: 200)
                HStack {
                    Text("FAITH \(faith)")
                        .font(Theme.mono(12, weight: .bold))
                        .foregroundColor(Theme.gold)
                    Spacer()
                    Text("\(equippedSet.count)/6 EQUIPPED")
                        .font(Theme.mono(12, weight: .bold))
                        .foregroundColor(Theme.cyan)
                }
            }
        }
    }

    private var equippedSet: Set<String> {
        Set(GameData.armorPieces.map(\.id).filter { store.save.isEquipped($0) })
    }

    // MARK: - Armor row

    private func armorRow(_ piece: GameData.ArmorPiece) -> some View {
        let unlocked = faith >= piece.req
        let equipped = store.save.isEquipped(piece.id)
        let accent: Color = equipped ? Theme.gold : (unlocked ? Theme.cyan : Theme.textDim)

        return SystemPanel(accent: accent) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Theme.bg)
                        .frame(width: 48, height: 48)
                        .overlay(Circle().stroke(accent.opacity(0.6), lineWidth: 1))
                    Image(systemName: unlocked ? piece.sfSymbol : "lock.fill")
                        .foregroundColor(accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(piece.name)
                        .font(Theme.mono(14, weight: .bold))
                        .foregroundColor(unlocked ? Theme.textPrimary : Theme.textDim)
                    Text("\(piece.part) - \(piece.verse)")
                        .font(Theme.mono(10))
                        .foregroundColor(Theme.textDim)
                    if !unlocked {
                        Text("Requires Faith \(piece.req) (\(piece.req - faith) to go)")
                            .font(Theme.mono(10, weight: .bold))
                            .foregroundColor(Theme.danger)
                    }
                }
                Spacer()
                actionButton(piece: piece, unlocked: unlocked, equipped: equipped)
            }
        }
    }

    @ViewBuilder
    private func actionButton(piece: GameData.ArmorPiece, unlocked: Bool, equipped: Bool) -> some View {
        if !unlocked {
            Image(systemName: "lock.fill")
                .foregroundColor(Theme.textDim)
        } else if equipped {
            Button {
                store.unequipArmor(piece.id)
            } label: {
                Text("UNEQUIP").font(Theme.mono(11, weight: .bold))
            }
            .buttonStyle(SystemButtonStyle(accent: Theme.gold, filled: false))
            .frame(width: 110)
        } else {
            Button {
                store.equipArmor(piece.id)
            } label: {
                Text("EQUIP").font(Theme.mono(11, weight: .bold))
            }
            .buttonStyle(SystemButtonStyle(accent: Theme.cyan, filled: true))
            .frame(width: 110)
        }
    }
}

/// A simple SwiftUI-drawn hunter silhouette. Equipped slots glow.
struct HunterSilhouette: View {
    let equipped: Set<String>

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cx = w / 2

            ZStack {
                // Body outline
                Path { p in
                    // Head
                    p.addEllipse(in: CGRect(x: cx - h * 0.09, y: h * 0.02,
                                            width: h * 0.18, height: h * 0.18))
                    // Torso
                    p.move(to: CGPoint(x: cx - h * 0.12, y: h * 0.22))
                    p.addLine(to: CGPoint(x: cx + h * 0.12, y: h * 0.22))
                    p.addLine(to: CGPoint(x: cx + h * 0.10, y: h * 0.55))
                    p.addLine(to: CGPoint(x: cx - h * 0.10, y: h * 0.55))
                    p.closeSubpath()
                    // Legs
                    p.move(to: CGPoint(x: cx - h * 0.09, y: h * 0.55))
                    p.addLine(to: CGPoint(x: cx - h * 0.07, y: h * 0.95))
                    p.move(to: CGPoint(x: cx + h * 0.09, y: h * 0.55))
                    p.addLine(to: CGPoint(x: cx + h * 0.07, y: h * 0.95))
                    // Arms
                    p.move(to: CGPoint(x: cx - h * 0.12, y: h * 0.25))
                    p.addLine(to: CGPoint(x: cx - h * 0.20, y: h * 0.48))
                    p.move(to: CGPoint(x: cx + h * 0.12, y: h * 0.25))
                    p.addLine(to: CGPoint(x: cx + h * 0.20, y: h * 0.48))
                }
                .stroke(Theme.cyanDeep.opacity(0.6), lineWidth: 2)

                // Slot glows
                slotGlow("helmet", at: CGPoint(x: cx, y: h * 0.11), size: h * 0.2)
                slotGlow("breastplate", at: CGPoint(x: cx, y: h * 0.38), size: h * 0.22)
                slotGlow("belt", at: CGPoint(x: cx, y: h * 0.53), size: h * 0.16)
                slotGlow("shoes", at: CGPoint(x: cx, y: h * 0.92), size: h * 0.14)
                slotGlow("shield", at: CGPoint(x: cx - h * 0.20, y: h * 0.46), size: h * 0.14)
                slotGlow("sword", at: CGPoint(x: cx + h * 0.20, y: h * 0.46), size: h * 0.14)
            }
        }
    }

    @ViewBuilder
    private func slotGlow(_ id: String, at point: CGPoint, size: CGFloat) -> some View {
        if equipped.contains(id) {
            Circle()
                .fill(Theme.gold.opacity(0.25))
                .frame(width: size, height: size)
                .overlay(Circle().stroke(Theme.gold, lineWidth: 1))
                .shadow(color: Theme.gold.opacity(0.7), radius: 8)
                .position(point)
        }
    }
}
