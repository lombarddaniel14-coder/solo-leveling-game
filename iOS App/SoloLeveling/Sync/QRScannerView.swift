import SwiftUI
import AVFoundation

/// A SwiftUI wrapper around an AVCaptureSession configured for QR detection.
/// Decoded strings are streamed back through `onCode`. Handles camera
/// permission and degrades gracefully on the simulator (no camera).
public struct QRScannerView: UIViewControllerRepresentable {

    /// Called on the main queue for every decoded metadata string.
    public var onCode: (String) -> Void
    /// Called with a human-readable message if the camera can't start.
    public var onError: (String) -> Void

    public init(onCode: @escaping (String) -> Void,
                onError: @escaping (String) -> Void = { _ in }) {
        self.onCode = onCode
        self.onError = onError
    }

    public func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onCode = onCode
        vc.onError = onError
        return vc
    }

    public func updateUIViewController(_ uiViewController: ScannerViewController,
                                       context: Context) {}
}

/// The UIKit controller that owns the capture session and preview layer.
public final class ScannerViewController: UIViewController,
                                          AVCaptureMetadataOutputObjectsDelegate {

    var onCode: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let sessionQueue = DispatchQueue(label: "sl.qr.session")

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        requestAccessAndConfigure()
    }

    private func requestAccessAndConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.configureSession()
                } else {
                    self?.reportError("Camera access denied. Enable it in Settings > Solo Leveling.")
                }
            }
        default:
            reportError("Camera access is off. Enable it in Settings > Solo Leveling.")
        }
    }

    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                self.reportError("No camera available (running on a simulator?). Use the paste box below to import a code.")
                return
            }

            self.session.beginConfiguration()
            self.session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard self.session.canAddOutput(output) else {
                self.session.commitConfiguration()
                self.reportError("Could not attach QR detector.")
                return
            }
            self.session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            output.metadataObjectTypes = [.qr]
            self.session.commitConfiguration()

            DispatchQueue.main.async { self.attachPreview() }
            self.session.startRunning()
        }
    }

    private func attachPreview() {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer
    }

    private func reportError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.onError?(message)
        }
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [weak self] in
            if self?.session.isRunning == true {
                self?.session.stopRunning()
            }
        }
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate

    public func metadataOutput(_ output: AVCaptureMetadataOutput,
                               didOutput metadataObjects: [AVMetadataObject],
                               from connection: AVCaptureConnection) {
        for obj in metadataObjects {
            guard let readable = obj as? AVMetadataMachineReadableCodeObject,
                  readable.type == .qr,
                  let value = readable.stringValue else { continue }
            onCode?(value)
        }
    }
}
