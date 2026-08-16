# Solo Leveling — iOS Companion App

A native **SwiftUI** iOS companion to the desktop "Solo Leveling" life-RPG
(`solo-leveling-system-v2.html`). It shows your character status, quests, Armor
of God loadout, and achievements, and it **syncs to the desktop fully offline**
using animated QR codes + copy/paste codes — no servers, no accounts.

> ⚠️ **UNVERIFIED BUILD.** This source was written on a Windows machine with **no
> Mac and no Xcode**, so it has **not been compiled or run**. The code is
> idiomatic, compile-oriented Swift, but you should expect to fix minor issues
> on first build. In particular, the **animated-QR interop must be validated
> on-device** against the desktop bridge (`SL Sync Bridge.html`). Camera
> features require a **real device** (the simulator has no camera — the app
> falls back to the paste box).

- **Target:** iOS 16.0+
- **UI:** SwiftUI lifecycle, dark "System" aesthetic (near-black bg, cyan +
  gold accents).
- **No third-party dependencies** — CoreImage for QR encode, AVFoundation for
  QR scan, the Compression framework for DEFLATE.

---

## What it does

| Tab      | Contents |
|----------|----------|
| Status   | Player header (name, level, class title, hunter rank), XP bar, the 6 stats as bars, gold + streak, stat-point allocation. |
| Quests   | Daily quests (tap to complete/uncomplete; stat + difficulty + XP + keystone marker) and weekly quests (tick progress). Applies the exact desktop formulas. |
| Armor    | The 6 Armor-of-God pieces, locked until Faith ≥ requirement; equip/unequip; a "FULL ARMOR" +10% XP aura banner; a drawn hunter silhouette with equip glow. |
| Records  | Grid of achievements; locked/secret shown as ??? until unlocked. |
| Sync     | Send (animated QR of this phone's save + copy code) / Receive (scan desktop's QR with live progress, or paste its code) with a confirm-before-replace step. |

The **entire desktop save** is stored as a lossless `JSONValue` tree
(`Models/JSONValue.swift`), so unknown fields are never dropped — a save edited
on the phone re-serializes byte-faithfully and stays compatible with the desktop
app.

---

## Build — Option A (recommended): XcodeGen

[XcodeGen](https://github.com/yonaskolb/XcodeGen) generates the `.xcodeproj`
from `project.yml`, so there's no fragile project file to hand-maintain.

```bash
# 1. Install XcodeGen (Homebrew)
brew install xcodegen

# 2. From THIS folder ("iOS App"), generate the project
cd "/path/to/Solo Leveling Game/iOS App"
xcodegen generate

# 3. Open it
open SoloLeveling.xcodeproj
```

Then in Xcode:

1. Select the **SoloLeveling** target → **Signing & Capabilities**.
2. Set your **Team** (Apple ID / Developer account).
3. Change the **Bundle Identifier** from the placeholder
   `com.daniel.sololeveling` to something unique to you
   (e.g. `com.yourname.sololeveling`).
4. Plug in an **iPhone**, select it as the run destination, and press **Run**
   (⌘R). The camera-based Receive mode needs a real device.

## Build — Option B: manual Xcode project

If you'd rather not use XcodeGen:

1. Xcode → **File ▸ New ▸ Project… ▸ iOS ▸ App**.
2. Interface **SwiftUI**, Language **Swift**, Product Name **Solo Leveling**.
3. Set the deployment target to **iOS 16.0**.
4. Delete the auto-generated `ContentView.swift` and the generated `App` file.
5. Drag the entire **`SoloLeveling/`** folder into the project ("Create groups",
   add to the app target).
6. Either use the provided **`Info.plist`** (set *Build Settings ▸ Info.plist
   File* to it and *Generate Info.plist File* = No), **or** add these keys to the
   generated Info settings:
   - `NSCameraUsageDescription` = `Scan your desktop's sync code to pull in your progress.`
   - `CFBundleDisplayName` = `Solo Leveling`
   - `UILaunchScreen` = (empty dictionary)
7. Set Team + a unique bundle id, then run on a device.

---

## Sync flow (step by step)

The protocol is **SLSYNC1** — it is implemented identically here
(`Sync/SyncProtocol.swift`) and on the desktop bridge `SL Sync Bridge.html`, so
the two interoperate offline.

**Phone → Desktop (push your phone progress up):**

1. On the phone, open the **Sync** tab → **Send**.
2. On the desktop, open **`SL Sync Bridge.html`** in Chrome → **Receive** (it
   uses the browser `BarcodeDetector` to read frames from the webcam).
3. Hold the phone's animated QR up to the desktop webcam. The bridge collects
   frames until it has all of them ("collected X / total").
4. The bridge decodes → replaces the desktop `localStorage` save (after you
   confirm) → reload the desktop app.

**Desktop → Phone (pull desktop progress down):**

1. On the desktop, open **`SL Sync Bridge.html`** → **Send** (it renders your
   `localStorage` save as an animated QR).
2. On the phone, **Sync** tab → **Receive**, and aim the camera at the desktop
   screen.
3. Watch **"Collected X / total"**. When complete, confirm **Replace** to
   overwrite the phone save.

**No camera on either side?** Use the **manual code**: tap **Copy code** (or the
bridge's copy button) and paste the `SLSYNC1R:`/`SLSYNC1D:` string into the other
device's paste box.

### Protocol details (must match the bridge)

- `body` = UTF-8 bytes of the compact save JSON.
- `flag` = `R` (raw, mandatory/default) or `D` (DEFLATE-raw / RFC 1951, optional
  size win). iOS uses the Compression framework `COMPRESSION_ZLIB`, which emits
  **raw DEFLATE** (no zlib header) — the same bytes as JS
  `CompressionStream('deflate-raw')`. If `D` isn't smaller or fails, it falls
  back to `R`.
- `b64` = base64 of the (possibly compressed) body.
- Split `b64` into chunks of **≤ 700 chars**; `total` = chunk count.
- Each QR frame is text:
  `SLSYNC1|<sessionId>|<index>|<total>|<flag>|<chunkData>` (index is 0-based).
- Animated QR loops all frames (~5 fps here). A single-frame payload shows
  statically.
- Manual code = one-line header `SLSYNC1R:` / `SLSYNC1D:` + the full base64.

---

## File map

```
iOS App/
├─ README.md               ← this file
├─ project.yml             ← XcodeGen spec
├─ Info.plist              ← camera usage string, display name, launch screen
└─ SoloLeveling/
   ├─ App/SoloLevelingApp.swift      ← @main, injects GameStore, RootView
   ├─ Theme.swift                    ← colors, fonts, reusable styles
   ├─ Models/
   │  ├─ JSONValue.swift             ← lossless Codable JSON, source of truth
   │  ├─ SaveState.swift             ← typed accessors + defaultState()
   │  └─ GameData.swift              ← stats, armor, achievements, ranks, titles
   ├─ Store/GameStore.swift          ← ObservableObject, exact formulas, persistence
   ├─ Sync/
   │  ├─ SyncProtocol.swift          ← SLSYNC1 build/parse/reassemble + DEFLATE
   │  ├─ QRCodeGenerator.swift       ← CIQRCodeGenerator → UIImage
   │  └─ QRScannerView.swift         ← AVCaptureSession QR scanner (UIViewControllerRepresentable)
   └─ Views/
      ├─ RootView.swift              ← TabView + level-up banner
      ├─ DashboardView.swift         ← status window
      ├─ QuestsView.swift            ← daily + weekly quests
      ├─ ArmorView.swift             ← Armor of God loadout + silhouette
      ├─ AchievementsView.swift      ← records grid
      └─ SyncView.swift              ← send / receive sync
```

Persistence: the save is stored at
`Documents/soloLevelingSave.json` (pretty-printed, same shape the desktop
`EXPORT SAVE` button produces), so the app is fully usable offline. First launch
seeds a default board via `SaveState.defaultState()`.

---

## Known caveats / things to validate on-device

- **QR interop with the desktop bridge is untested** — verify raw (`R`) frames
  first (mandatory path), then compressed (`D`). If a large save produces many
  frames, the animated scan may take a few loops; that's expected.
- Uncompleting a daily quest only flips `completedDate` back to `null`; it does
  **not** reverse the XP/stat already granted (matches the "keep it simple/safe"
  spec).
- Achievement definitions in `GameData.swift` are an **inferred** set; reconcile
  ids/text against the desktop `unlockedAchievements` list on-device for a
  perfect match. Unknown ids in the save are preserved regardless.
- Add an `AppIcon` asset in `Assets.xcassets` if you want a custom icon
  (referenced by `ASSETCATALOG_COMPILER_APPICON_NAME`); the app builds without
  one.
```
