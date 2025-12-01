import SwiftUI
import UIKit
import AVFoundation
import UniformTypeIdentifiers

struct CameraCaptureView: UIViewControllerRepresentable {
    struct Payload {
        let data: Data
        let suggestedExt: String? // "jpg" or "heic" typically
    }

    enum CaptureError: LocalizedError {
        case cameraUnavailable
        case permissionDenied
        case exportFailed
        var errorDescription: String? {
            switch self {
            case .cameraUnavailable: return "Camera not available on this device."
            case .permissionDenied: return "Camera permission denied."
            case .exportFailed: return "Failed to capture photo."
            }
        }
    }

    typealias Completion = (Result<Payload, Error>?) -> Void

    let completion: Completion

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
            picker.allowsEditing = false
            // Prefer HEIC if available; UIImagePickerController will decide actual format.
        } else {
            // If camera not available, immediately return an error
            DispatchQueue.main.async {
                completion(.failure(CaptureError.cameraUnavailable))
            }
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let completion: Completion

        init(completion: @escaping Completion) {
            self.completion = completion
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) {
                self.completion(nil)
            }
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            defer {
                picker.dismiss(animated: true, completion: nil)
            }

            // Prefer original image
            if let image = info[.originalImage] as? UIImage {
                // Try to export without heavy recompression: if the underlying data is available via PHAsset this API doesn't expose it.
                // So we’ll choose JPEG with quality 0.95 as a near-original fallback.
                let suggestedExt = "jpg"
                if let data = image.jpegData(compressionQuality: 0.95) {
                    completion(.success(Payload(data: data, suggestedExt: suggestedExt)))
                    return
                }
            }

            completion(.failure(CaptureError.exportFailed))
        }
    }
}

