import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers
import CoreLocation
import ImageIO
import MobileCoreServices

struct PhotoLibraryPickerView: UIViewControllerRepresentable {
    struct Payload {
        let data: Data
        let suggestedExt: String? // "jpg", "heic", or "png"
        let location: CLLocation?
    }

    enum PickError: LocalizedError {
        case exportFailed
        var errorDescription: String? {
            switch self {
            case .exportFailed: return NSLocalizedString("photo_export_failed_error", comment: "")
            }
        }
    }

    typealias Completion = (Result<Payload, Error>?) -> Void

    let completion: Completion

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        if #available(iOS 14.0, *) {
            var config = PHPickerConfiguration(photoLibrary: .shared())
            config.selectionLimit = 1
            config.filter = .images
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = context.coordinator
            return picker
        } else {
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.allowsEditing = false
            picker.delegate = context.coordinator
            return picker
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, PHPickerViewControllerDelegate, UIImagePickerControllerDelegate {
        let completion: Completion

        init(completion: @escaping Completion) {
            self.completion = completion
        }

        // iOS 14+ path
        @available(iOS 14.0, *)
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let item = results.first else {
                DispatchQueue.main.async {
                    picker.dismiss(animated: true) { self.completion(nil) }
                }
                return
            }

            let provider = item.itemProvider

            // Try to resolve location via PHAsset (iOS 15+ using assetIdentifier)
            func fetchLocationFromAssetIdentifier(_ id: String?, completion: @escaping (CLLocation?) -> Void) {
                guard #available(iOS 15.0, *), let id else {
                    completion(nil)
                    return
                }
                let assets = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
                guard let asset = assets.firstObject else {
                    completion(nil)
                    return
                }
                completion(asset.location)
            }

            func extractEXIFLocation(from data: Data) -> CLLocation? {
                guard let src = CGImageSourceCreateWithData(data as CFData, nil),
                      let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
                      let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any] else {
                    return nil
                }

                func deg(_ key: CFString) -> Double? {
                    if let v = gps[key] as? Double { return v }
                    if let v = gps[key] as? NSNumber { return v.doubleValue }
                    if let s = gps[key] as? String, let d = Double(s) { return d }
                    return nil
                }

                guard let lat = deg(kCGImagePropertyGPSLatitude),
                      let lon = deg(kCGImagePropertyGPSLongitude) else { return nil }

                // Respect N/S and E/W references
                var finalLat = lat
                var finalLon = lon
                if let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String, latRef.uppercased() == "S" {
                    finalLat = -abs(finalLat)
                }
                if let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String, lonRef.uppercased() == "W" {
                    finalLon = -abs(finalLon)
                }

                let alt: Double? = deg(kCGImagePropertyGPSAltitude)
                let ts: Date? = {
                    if let dateStamp = gps[kCGImagePropertyGPSDateStamp] as? String,
                       let timeStamp = gps[kCGImagePropertyGPSTimeStamp] as? String {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                        formatter.timeZone = TimeZone(secondsFromGMT: 0)
                        let combined = "\(dateStamp) \(timeStamp)"
                        return formatter.date(from: combined)
                    }
                    return nil
                }()

                if let alt {
                    return CLLocation(coordinate: CLLocationCoordinate2D(latitude: finalLat, longitude: finalLon),
                                      altitude: alt,
                                      horizontalAccuracy: kCLLocationAccuracyHundredMeters,
                                      verticalAccuracy: kCLLocationAccuracyHundredMeters,
                                      timestamp: ts ?? Date())
                } else {
                    return CLLocation(latitude: finalLat, longitude: finalLon)
                }
            }

            func finishWithData(_ data: Data, ext: String?, assetLocation: CLLocation?) {
                // If asset location is nil, fall back to EXIF GPS
                let loc = assetLocation ?? extractEXIFLocation(from: data)
                DispatchQueue.main.async {
                    picker.dismiss(animated: true) {
                        self.completion(.success(Payload(data: data, suggestedExt: ext, location: loc)))
                    }
                }
            }

            // Resolve PHAsset location (if possible) in parallel with data loading
            var assetLocation: CLLocation?
            if #available(iOS 15.0, *) {
                fetchLocationFromAssetIdentifier(results.first?.assetIdentifier) { loc in
                    assetLocation = loc
                }
            }

            // Prefer loading as Data in original type if possible
            let targetTypes: [UTType] = {
                if #available(iOS 14.0, *) {
                    return [UTType.heic, UTType.jpeg, UTType.png]
                } else {
                    return []
                }
            }()

            // Try HEIC/JPEG/PNG in order without recompressing
            for t in targetTypes {
                if provider.hasItemConformingToTypeIdentifier(t.identifier) {
                    provider.loadDataRepresentation(forTypeIdentifier: t.identifier) { data, _ in
                        if let data = data {
                            let ext: String? = {
                                if t == .heic { return "heic" }
                                if t == .jpeg { return "jpg" }
                                if t == .png { return "png" }
                                return nil
                            }()
                            finishWithData(data, ext: ext, assetLocation: assetLocation)
                        } else {
                            // Fall back to UIImage path
                            self.loadAsUIImage(provider: provider, picker: picker, assetLocation: assetLocation)
                        }
                    }
                    return
                }
            }

            // Fallback: load as UIImage and export JPEG
            loadAsUIImage(provider: provider, picker: picker, assetLocation: assetLocation)
        }

        @available(iOS 14.0, *)
        private func loadAsUIImage(provider: NSItemProvider, picker: PHPickerViewController, assetLocation: CLLocation?) {
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    guard let image = object as? UIImage,
                          let data = image.jpegData(compressionQuality: 0.95) else {
                        DispatchQueue.main.async {
                            picker.dismiss(animated: true) {
                                self.completion(.failure(PickError.exportFailed))
                            }
                        }
                        return
                    }
                    DispatchQueue.main.async {
                        picker.dismiss(animated: true) {
                            self.completion(.success(Payload(data: data, suggestedExt: "jpg", location: assetLocation)))
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    picker.dismiss(animated: true) {
                        self.completion(.failure(PickError.exportFailed))
                    }
                }
            }
        }

        // iOS 13 fallback path
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) { self.completion(nil) }
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            defer { picker.dismiss(animated: true, completion: nil) }
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.95) {
                // UIImagePickerController (old API) doesn’t expose PHAsset; EXIF fallback only
                let loc = extractEXIFLocation(from: data)
                completion(.success(Payload(data: data, suggestedExt: "jpg", location: loc)))
            } else {
                completion(.failure(PickError.exportFailed))
            }
        }

        // EXIF GPS extraction for iOS 13 path
        private func extractEXIFLocation(from data: Data) -> CLLocation? {
            guard let src = CGImageSourceCreateWithData(data as CFData, nil),
                  let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
                  let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any] else {
                return nil
            }
            func deg(_ key: CFString) -> Double? {
                if let v = gps[key] as? Double { return v }
                if let v = gps[key] as? NSNumber { return v.doubleValue }
                if let s = gps[key] as? String, let d = Double(s) { return d }
                return nil
            }
            guard let lat = deg(kCGImagePropertyGPSLatitude),
                  let lon = deg(kCGImagePropertyGPSLongitude) else { return nil }

            var finalLat = lat
            var finalLon = lon
            if let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String, latRef.uppercased() == "S" {
                finalLat = -abs(finalLat)
            }
            if let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String, lonRef.uppercased() == "W" {
                finalLon = -abs(finalLon)
            }
            return CLLocation(latitude: finalLat, longitude: finalLon)
        }
    }
}

