import SwiftUI

/// Offline sync with the desktop bridge (SL Sync Bridge.html) using the SLSYNC1
/// protocol. Two modes:
///   - Send: show this phone's save as an animated QR + a copyable code.
///   - Receive: scan the desktop's animated QR (or paste its code) and replace
///     the local save after confirming.
struct SyncView: View {
    @EnvironmentObject var store: GameStore
    @State private var mode: Mode = .send

    enum Mode: String, CaseIterable { case send = "Send", receive = "Receive" }

    var body: some View {
        ZStack {
            Theme.bgGradient.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if mode == .send {
                        SendPanel()
                    } else {
                        ReceivePanel()
                    }
                }
                .padding(16)
            }
        }
    }
}

// MARK: - Send

private struct SendPanel: View {
    @EnvironmentObject var store: GameStore
    @State private var payload: SyncProtocol.BuiltPayload?
    @State private var frameIndex = 0
    @State private var copied = false

    // ~5 frames/sec animated QR.
    private let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    var body: some View {
        SystemPanel {
            VStack(spacing: 14) {
                SectionHeader("Send to Desktop")
                Text("On your Mac/PC, open SL Sync Bridge.html and choose Receive. Point its camera at this animated code until it collects every frame.")
                    .font(Theme.mono(11))
                    .foregroundColor(Theme.cyanSoft)
                    .fixedSize(horizontal: false, vertical: true)

                if let payload {
                    qrArea(payload)
                    Text(frameCaption(payload))
                        .font(Theme.mono(11, weight: .bold))
                        .foregroundColor(Theme.gold)

                    Button {
                        UIPasteboard.general.string = payload.manualCode
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    } label: {
                        Label(copied ? "Copied!" : "Copy code (manual paste)",
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(SystemButtonStyle(accent: Theme.cyan, filled: false))
                } else {
                    ProgressView().tint(Theme.cyan)
                }

                Button {
                    rebuild()
                } label: {
                    Label("Rebuild from current save", systemImage: "arrow.clockwise")
                }
                .buttonStyle(SystemButtonStyle(accent: Theme.gold, filled: false))
            }
        }
        .onAppear { if payload == nil { rebuild() } }
        .onReceive(timer) { _ in advance() }
    }

    private func qrArea(_ payload: SyncProtocol.BuiltPayload) -> some View {
        let frame = payload.frames[min(frameIndex, payload.frames.count - 1)]
        return ZStack {
            RoundedRectangle(cornerRadius: 12).fill(Color.white)
            if let img = QRCodeGenerator.image(from: frame, size: 480, correction: "M") {
                Image(uiImage: img)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(14)
            }
        }
        .frame(width: 260, height: 260)
        .shadow(color: Theme.cyan.opacity(0.4), radius: 12)
    }

    private func frameCaption(_ payload: SyncProtocol.BuiltPayload) -> String {
        if payload.total <= 1 {
            return "Single frame - hold steady (\(payload.flag == "D" ? "compressed" : "raw"))"
        }
        return "Frame \(frameIndex + 1) / \(payload.total) - looping (\(payload.flag == "D" ? "compressed" : "raw"))"
    }

    private func rebuild() {
        let json = store.exportJSONString()
        payload = SyncProtocol.build(fromJSON: json)
        frameIndex = 0
    }

    private func advance() {
        guard let payload, payload.total > 1 else { return }
        frameIndex = (frameIndex + 1) % payload.total
    }
}

// MARK: - Receive

private struct ReceivePanel: View {
    @EnvironmentObject var store: GameStore

    @StateObject private var model = ReceiveModel()
    @State private var pasteText = ""
    @State private var showConfirm = false
    @State private var incomingJSON: String?
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 18) {
            SystemPanel {
                VStack(spacing: 14) {
                    SectionHeader("Receive from Desktop")
                    Text("On your desktop, open SL Sync Bridge.html and choose Send. Aim this scanner at its animated code.")
                        .font(Theme.mono(11))
                        .foregroundColor(Theme.cyanSoft)
                        .fixedSize(horizontal: false, vertical: true)

                    scannerArea

                    Text(model.progressText)
                        .font(Theme.mono(12, weight: .bold))
                        .foregroundColor(model.isComplete ? Theme.success : Theme.gold)

                    if let msg = model.cameraError {
                        Text(msg)
                            .font(Theme.mono(10))
                            .foregroundColor(Theme.danger)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        model.reset()
                    } label: {
                        Label("Reset scan", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(SystemButtonStyle(accent: Theme.gold, filled: false))
                }
            }

            pastePanel
        }
        .onChange(of: model.completedJSON) { json in
            if let json {
                incomingJSON = json
                showConfirm = true
            }
        }
        .alert("Replace local save?", isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) { model.reset() }
            Button("Replace", role: .destructive) { applyIncoming() }
        } message: {
            Text("This will overwrite the save on this phone with the data received from the desktop. This cannot be undone.")
        }
        .alert("Import failed", isPresented: Binding(
            get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("OK", role: .cancel) { errorText = nil }
        } message: {
            Text(errorText ?? "")
        }
    }

    private var scannerArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(Color.black)
            QRScannerView(
                onCode: { model.ingest($0) },
                onError: { model.cameraError = $0 })
                .clipShape(RoundedRectangle(cornerRadius: 12))
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.cyan.opacity(0.6), lineWidth: 2)
        }
        .frame(height: 260)
    }

    private var pastePanel: some View {
        SystemPanel(accent: Theme.gold) {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader("Manual Code", accent: Theme.gold)
                Text("No camera? Paste the desktop's SLSYNC1 code here.")
                    .font(Theme.mono(11))
                    .foregroundColor(Theme.cyanSoft)
                TextEditor(text: $pasteText)
                    .font(Theme.mono(11))
                    .foregroundColor(Theme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(height: 90)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bg))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                Button {
                    importPasted()
                } label: {
                    Label("Import pasted code", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(SystemButtonStyle(accent: Theme.gold, filled: true))
            }
        }
    }

    private func importPasted() {
        let text = pasteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            let json = try SyncProtocol.decodeManualCode(text)
            incomingJSON = json
            showConfirm = true
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func applyIncoming() {
        guard let json = incomingJSON else { return }
        do {
            try store.replaceSave(fromJSONString: json)
            model.reset()
            pasteText = ""
            incomingJSON = nil
        } catch {
            errorText = "The received data was not valid save JSON."
        }
    }
}

// MARK: - Receive model

/// Holds the reassembler and publishes live progress. Marshals scanner
/// callbacks onto the main queue.
private final class ReceiveModel: ObservableObject {
    @Published var progressText = "Waiting for frames..."
    @Published var isComplete = false
    @Published var completedJSON: String?
    @Published var cameraError: String?

    private let reassembler = SyncProtocol.Reassembler()

    func ingest(_ raw: String) {
        guard !isComplete else { return }
        let accepted = reassembler.ingest(raw)
        guard accepted else { return }

        if reassembler.total > 0 {
            progressText = "Collected \(reassembler.collectedCount) / \(reassembler.total)"
        }
        if reassembler.isComplete {
            isComplete = true
            if let json = try? reassembler.assembleJSON() {
                progressText = "Complete - confirm to import"
                completedJSON = json
            } else {
                progressText = "Reassembly failed - reset and retry"
                isComplete = false
                reassembler.reset()
            }
        }
    }

    func reset() {
        reassembler.reset()
        isComplete = false
        completedJSON = nil
        cameraError = nil
        progressText = "Waiting for frames..."
    }
}
