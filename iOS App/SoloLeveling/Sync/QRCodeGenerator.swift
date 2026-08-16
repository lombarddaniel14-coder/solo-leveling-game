import UIKit
import CoreImage.CIFilterBuiltins

/// Generates crisp QR-code images from strings using CoreImage's
/// CIQRCodeGenerator. Images are nearest-neighbour scaled so the modules stay
/// sharp at display size.
public enum QRCodeGenerator {

    private static let context = CIContext()

    /// Returns a QR image for `string`, scaled up to roughly `size` points.
    /// `correction` is one of "L", "M", "Q", "H" (default "M" for capacity).
    public static func image(from string: String,
                             size: CGFloat = 320,
                             correction: String = "M") -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = correction

        guard let output = filter.outputImage else { return nil }

        // Scale from the native module size up to the requested point size.
        let scaleX = size / output.extent.width
        let scaleY = size / output.extent.height
        let transformed = output.transformed(
            by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        guard let cg = context.createCGImage(transformed,
                                             from: transformed.extent) else {
            return nil
        }
        return UIImage(cgImage: cg)
    }
}
