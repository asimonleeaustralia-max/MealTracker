//
//  PhotoNutritionGuesser.swift
//  MealTracker
//
//  iOS 13+ on-device pipeline: detect barcodes with Vision, look up in LocalBarcodeDB,
//  and (optionally) OCR nutrition labels (stubbed for now).
//

import Foundation
import Vision
import UIKit

struct PhotoNutritionGuesser {

    struct GuessResult {
        // All fields optional; values are Ints in UI units (kcal, grams, mg)
        var calories: Int?
        var carbohydrates: Int?
        var protein: Int?
        var fat: Int?
        var sodiumMg: Int?

        var sugars: Int?
        var starch: Int?
        var fibre: Int?

        var monounsaturatedFat: Int?
        var polyunsaturatedFat: Int?
        var saturatedFat: Int?
        var transFat: Int?

        var animalProtein: Int?
        var plantProtein: Int?
        var proteinSupplements: Int?

        var vitaminA: Int?
        var vitaminB: Int?
        var vitaminC: Int?
        var vitaminD: Int?
        var vitaminE: Int?
        var vitaminK: Int?

        var calcium: Int?
        var iron: Int?
        var potassium: Int?
        var zinc: Int?
        var magnesium: Int?
    }

    enum GuessError: Error {
        case invalidImage
        case processingFailed
    }

    // Public API: try barcode first; if no hit, OCR stub (returns nil for now)
    static func guess(from imageData: Data, languageCode: String? = nil) async throws -> GuessResult? {
        guard let image = UIImage(data: imageData) else {
            throw GuessError.invalidImage
        }
        // Prefer a downscaled image to reduce CPU on older devices
        let workingImage = downscaleIfNeeded(image, maxLongEdge: 1080)

        // 1) Try barcode detection
        if let code = await detectFirstBarcode(in: workingImage),
           let entry = LocalBarcodeDB.lookup(code: code) {
            return map(entry: entry)
        }

        // 2) OCR stub (you can implement later)
        // If you want, plug in VNRecognizeTextRequest here and parse.
        return nil
    }

    private static func downscaleIfNeeded(_ image: UIImage, maxLongEdge: CGFloat) -> UIImage {
        let size = image.size
        let longEdge = max(size.width, size.height)
        guard longEdge > maxLongEdge else { return image }
        let scale = maxLongEdge / longEdge
        let target = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    private static func map(entry: LocalBarcodeDB.Entry) -> GuessResult {
        GuessResult(
            calories: entry.calories,
            carbohydrates: entry.carbohydrates,
            protein: entry.protein,
            fat: entry.fat,
            sodiumMg: entry.sodiumMg,
            sugars: entry.sugars,
            starch: entry.starch,
            fibre: entry.fibre,
            monounsaturatedFat: entry.monounsaturatedFat,
            polyunsaturatedFat: entry.polyunsaturatedFat,
            saturatedFat: entry.saturatedFat,
            transFat: entry.transFat,
            animalProtein: entry.animalProtein,
            plantProtein: entry.plantProtein,
            proteinSupplements: entry.proteinSupplements,
            vitaminA: entry.vitaminA,
            vitaminB: entry.vitaminB,
            vitaminC: entry.vitaminC,
            vitaminD: entry.vitaminD,
            vitaminE: entry.vitaminE,
            vitaminK: entry.vitaminK,
            calcium: entry.calcium,
            iron: entry.iron,
            potassium: entry.potassium,
            zinc: entry.zinc,
            magnesium: entry.magnesium
        )
    }

    // Fixed: ensure the continuation is resumed exactly once.
    private static func detectFirstBarcode(in image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            var didResume = false
            func resumeOnce(_ value: String?) {
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: value)
            }

            let request = VNDetectBarcodesRequest { request, error in
                if let error = error {
                    // On error, resume with nil
                    resumeOnce(nil)
                    return
                }
                let payloads = (request.results as? [VNBarcodeObservation])?
                    .compactMap { $0.payloadStringValue }
                resumeOnce(payloads?.first)
            }

            // Limit symbologies to common UPC/EAN for speed (best-effort on iOS 15+)
            if #available(iOS 15.0, *) {
                request.symbologies = [.UPCE, .EAN13, .EAN8, .Code128, .Code39, .Code93, .ITF14]
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            // Perform the request on a background queue to avoid blocking
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                    // Do not resume here; completion handler will handle resume
                } catch {
                    // If perform throws before completion handler runs, resume here
                    resumeOnce(nil)
                }
            }
        }
    }
}

