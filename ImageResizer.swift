//
//  ImageResizer.swift
//  MealTracker
//
//  Resizing and JPEG export for iOS.
//

import UIKit
import CoreImage
import CryptoKit

struct ImageResizer {

    struct ResizeResult {
        let image: UIImage
        let jpegData: Data
        let width: Int
        let height: Int
        let byteSize: Int
    }

    // Resize to fit within maxLongEdge while preserving aspect ratio.
    // Returns the resized UIImage and JPEG data at the given quality.
    static func resizeToLongEdge(_ maxLongEdge: CGFloat,
                                 image: UIImage,
                                 jpegQuality: CGFloat = 0.72) -> ResizeResult? {
        guard let cgImage = image.cgImage ?? image.ciImage?.toCGImage() else {
            return nil
        }

        let originalSize = CGSize(width: cgImage.width, height: cgImage.height)
        let scale = min(1.0, maxLongEdge / max(originalSize.width, originalSize.height))
        let targetSize = CGSize(width: floor(originalSize.width * scale),
                                height: floor(originalSize.height * scale))

        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 1 // we’re working in pixels
        rendererFormat.opaque = true

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: rendererFormat)
        let resized = renderer.image { _ in
            UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: targetSize))
        }

        guard let data = resized.jpegData(compressionQuality: jpegQuality) else { return nil }
        return ResizeResult(image: resized,
                            jpegData: data,
                            width: Int(targetSize.width),
                            height: Int(targetSize.height),
                            byteSize: data.count)
    }

    // Compute SHA-256 of data as hex string
    static func sha256Hex(of data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

private extension CIImage {
    func toCGImage() -> CGImage? {
        let context = CIContext(options: nil)
        return context.createCGImage(self, from: extent)
    }
}

