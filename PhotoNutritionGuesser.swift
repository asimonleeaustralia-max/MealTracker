//
//  PhotoNutritionGuesser.swift
//  MealTracker
//
//  iOS 13+ on-device pipeline: detect barcodes with Vision, look up in LocalBarcodeDB,
//  OCR nutrition labels, then FeaturePrint (no-training) fallback, and as a last resort,
//  a visual heuristic guess from the photo.
//

import Foundation
import Vision
import UIKit
import CoreImage

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

    // Debug flag to print OCR text
    private static let debugOCR = false

    // Public API: try barcode first; if no hit, OCR; if still no hit, FeaturePrint; if still no hit, visual guess
    static func guess(from imageData: Data, languageCode: String? = nil) async throws -> GuessResult? {
        guard let image = UIImage(data: imageData) else {
            throw GuessError.invalidImage
        }
        // Prefer a downscaled image to reduce CPU on older devices
        let baseImage = downscaleIfNeeded(image, maxLongEdge: 1280)

        // Prepare rotation variants to improve robustness to angle/pose:
        // 0°, 90°, 180°, 270°
        let variants = rotationVariants(of: baseImage)

        // 1) Try barcode detection on each rotation (stop on first hit)
        for img in variants {
            if let code = await detectFirstBarcode(in: img),
               let entry = LocalBarcodeDB.lookup(code: code) {
                // Packaged item: keep as-is (may imply multiple servings; do not force single-dish)
                return map(entry: entry)
            }
        }

        // 2) OCR nutrition parsing (dual-pass) on each rotation, pick the best parse
        // Packaged item / label text: keep as-is (may imply multiple servings)
        var bestParsed: GuessResult?
        var bestParsedScore = -1
        for img in variants {
            if let text = await recognizeTextDualPass(in: img, languageCode: languageCode) {
                if debugOCR {
                    print("OCR text (rotation variant):\n\(text)\n--- end OCR ---")
                }
                let result = parseNutrition(from: text)
                let score = result.parsedFieldCount
                if score > bestParsedScore {
                    bestParsedScore = score
                    bestParsed = result.hasAnyValue ? result : bestParsed
                    if score >= 10 { break }
                }
            }
        }
        if let parsed = bestParsed, parsed.hasAnyValue {
            return parsed
        }

        // 3) FeaturePrint (no-training) fallback: classify to a label and use priors.
        // Choose the most confident among rotations.
        var bestFP: GuessResult?
        var bestFPConfidence: Double = -1.0
        for img in variants {
            if let match = await FeaturePrintClassifier.classify(image: img) {
                // Portion proxy from saliency (largest salient object area ratio)
                let area = (img.cgImage).map { largestSalientObjectAreaRatio(cgImage: $0) } ?? 0.35
                if let guess = FoodClassPriors.guess(for: match.label, areaRatio: area) {
                    // Keep the most confident
                    if match.confidence > bestFPConfidence {
                        bestFPConfidence = match.confidence
                        bestFP = guess
                    }
                }
            }
        }
        if let fp = bestFP {
            return fp
        }

        // 4) Visual heuristic guess as a last resort; choose the most confident among rotations.
        // Enforce SINGLE-DISH interpretation: use the largest salient object only to estimate portion.
        var bestVisual: GuessResult?
        var bestVisualConfidence = -Double.infinity
        for img in variants {
            if let visual = visualGuessSingleDish(in: img) {
                // Use single-dish confidence
                let conf = visualConfidenceSingleDish(in: img, guess: visual)
                if conf > bestVisualConfidence {
                    bestVisualConfidence = conf
                    bestVisual = visual
                }
            }
        }
        return bestVisual
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

    // Create 0°, 90°, 180°, 270° rotation variants
    private static func rotationVariants(of image: UIImage) -> [UIImage] {
        var list: [UIImage] = [image]
        if let r90 = rotate90(image, times: 1) { list.append(r90) }
        if let r180 = rotate90(image, times: 2) { list.append(r180) }
        if let r270 = rotate90(image, times: 3) { list.append(r270) }
        return list
    }

    // Rotate by 90° increments efficiently
    private static func rotate90(_ image: UIImage, times: Int) -> UIImage? {
        let t = ((times % 4) + 4) % 4
        guard t != 0 else { return image }
        var transform = CGAffineTransform.identity
        var newSize = image.size

        switch t {
        case 1: // 90°
            transform = CGAffineTransform(rotationAngle: .pi / 2).translatedBy(x: 0, y: -image.size.height)
            newSize = CGSize(width: image.size.height, height: image.size.width)
        case 2: // 180°
            transform = CGAffineTransform(rotationAngle: .pi).translatedBy(x: -image.size.width, y: -image.size.height)
        case 3: // 270°
            transform = CGAffineTransform(rotationAngle: 3 * .pi / 2).translatedBy(x: -image.size.width, y: 0)
            newSize = CGSize(width: image.size.height, height: image.size.width)
        default:
            break
        }

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { ctx in
            ctx.cgContext.translateBy(x: 0, y: newSize.height)
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
            ctx.cgContext.concatenate(transform)
            if let cg = image.cgImage {
                ctx.cgContext.draw(cg, in: CGRect(origin: .zero, size: image.size))
            } else {
                image.draw(in: CGRect(origin: .zero, size: image.size))
            }
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
                if let _ = error {
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

    // MARK: - OCR

    // Try .fast first; if the text is empty/too short, try .accurate
    private static func recognizeTextDualPass(in image: UIImage, languageCode: String?) async -> String? {
        if let tFast = await recognizeText(in: image, languageCode: languageCode, level: .fast), tFast.count > 20 {
            return tFast
        }
        return await recognizeText(in: image, languageCode: languageCode, level: .accurate)
    }

    private static func recognizeText(in image: UIImage, languageCode: String?, level: VNRequestTextRecognitionLevel) async -> String? {
        guard let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let _ = error {
                    continuation.resume(returning: nil)
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation], !observations.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                let lines: [String] = observations.compactMap { obs in
                    obs.topCandidates(1).first?.string
                }
                let joined = lines.joined(separator: "\n")
                continuation.resume(returning: joined)
            }

            request.recognitionLevel = level
            request.usesLanguageCorrection = true

            // Language hints if provided
            if let code = normalizedLanguageCode(languageCode) {
                request.recognitionLanguages = [code, "en"]
            } else {
                request.recognitionLanguages = ["en"]
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func normalizedLanguageCode(_ code: String?) -> String? {
        guard var c = code?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !c.isEmpty else { return nil }
        c = c.replacingOccurrences(of: "_", with: "-")
        return c
    }

    // MARK: - Parsing

    private static func parseNutrition(from rawText: String) -> GuessResult {
        // Normalize whitespace, lowercase for matching; keep original lines for numeric extraction
        let lines = rawText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var result = GuessResult()

        // Regex helpers
        func firstMatch(_ pattern: String, in text: String) -> NSTextCheckingResult? {
            let options: NSRegularExpression.Options = [.caseInsensitive]
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            return regex.firstMatch(in: text, options: [], range: range)
        }

        func extractNumber(from line: String, group: Int, in match: NSTextCheckingResult) -> String? {
            guard let r = Range(match.range(at: group), in: line) else { return nil }
            return String(line[r])
        }

        func toInt(_ s: String?) -> Int? {
            guard var str = s?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty else { return nil }
            str = str.replacingOccurrences(of: ",", with: ".")
            if let val = Double(str) {
                return Int(round(val))
            }
            let allowed = Set("0123456789.")
            let filtered = String(str.filter { allowed.contains($0) })
            if let val = Double(filtered) {
                return Int(round(val))
            }
            return nil
        }

        func parseGramValue(_ line: String, keywords: [String]) -> Int? {
            let joined = keywords.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
            let pattern = "(?:^|\\b)(?:\(joined))\\b[^\\n\\r\\d]{0,15}([0-9]+[\\.,]?[0-9]*)\\s*(g|grams?)\\b"
            if let m = firstMatch(pattern, in: line) {
                return toInt(extractNumber(from: line, group: 1, in: m))
            }
            return nil
        }

        func parseMilligramValue(_ line: String, keywords: [String]) -> Int? {
            let joined = keywords.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
            let pattern = "(?:^|\\b)(?:\(joined))\\b[^\\n\\r\\d]{0,15}([0-9]+[\\.,]?[0-9]*)\\s*(mg|milligrams?)\\b"
            if let m = firstMatch(pattern, in: line) {
                return toInt(extractNumber(from: line, group: 1, in: m))
            }
            return nil
        }

        func parseMicrogramValue(_ line: String, keywords: [String]) -> Int? {
            let joined = keywords.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
            // match "µg" or "ug" or "micrograms"
            let pattern = "(?:^|\\b)(?:\(joined))\\b[^\\n\\r\\d]{0,15}([0-9]+[\\.,]?[0-9]*)\\s*(µg|ug|micrograms?)\\b"
            if let m = firstMatch(pattern, in: line) {
                if let micro = toInt(extractNumber(from: line, group: 1, in: m)) {
                    // convert µg to mg
                    let mg = Int(round(Double(micro) / 1000.0))
                    return mg
                }
            }
            return nil
        }

        func parseSodiumOrSalt(_ line: String) -> Int? {
            if let mg = parseMilligramValue(line, keywords: ["sodium", "na", "sodio", "natrium"]) {
                return mg
            }
            if let g = parseGramValue(line, keywords: ["sodium", "na", "sodio", "natrium"]) {
                return g * 1000
            }
            // Salt line (convert g of salt to mg sodium: 1 g salt ≈ 400 mg sodium)
            if let gSalt = parseGramValue(line, keywords: ["salt", "sel", "salz", "sale", "sal"]) {
                let sodiumMg = Int(round(Double(gSalt) * 400.0))
                return sodiumMg
            }
            return nil
        }

        func parseEnergy(_ line: String) -> Int? {
            // kcal direct
            if let mKcal = firstMatch("(?:\\benergy\\b|\\bcalories?\\b|\\bkcal\\b)[^\\d]{0,15}([0-9]+[\\.,]?[0-9]*)\\s*(kcal|cal)?\\b", in: line) {
                if let val = toInt(extractNumber(from: line, group: 1, in: mKcal)) {
                    return val
                }
            }
            // kJ conversion
            if let mKJ = firstMatch("(?:\\benergy\\b|\\bkJ\\b)[^\\d]{0,15}([0-9]+[\\.,]?[0-9]*)\\s*(kJ)\\b", in: line) {
                if let kj = toInt(extractNumber(from: line, group: 1, in: mKJ)) {
                    let kcal = Int(round(Double(kj) / 4.184))
                    return kcal
                }
            }
            // Bare "xxx kcal"
            if let mBare = firstMatch("([0-9]+[\\.,]?[0-9]*)\\s*kcal\\b", in: line),
               let val = toInt(extractNumber(from: line, group: 1, in: mBare)) {
                return val
            }
            return nil
        }

        // Known keyword sets (includes "of which ..." phrases seen on EU labels)
        let carbsKeys = ["carb", "carbs", "carbohydrate", "carbohydrates", "glucides", "kohlenhydrate", "hidratos", "carboidrati"]
        let proteinKeys = ["protein", "proteins", "proteína", "proteine", "eiweiß", "eiweiss"]
        let fatKeys = ["fat", "fats", "lipid", "lipids", "grasas", "grassi", "matières grasses"]
        let sugarKeys = ["sugars", "sugar", "of which sugars", "incl. sugars", "sucre", "zucker", "azúcares", "zuccheri"]
        let fibreKeys = ["fibre", "fiber", "fibra", "faser"]
        let starchKeys = ["starch", "almidón", "amido", "stärke", "amidon"]
        let satKeys = ["saturated", "sat fat", "saturates", "of which saturates", "acides gras saturés", "gesättigte", "grassi saturi"]
        let transKeys = ["trans", "trans fat", "acides gras trans", "grassi trans"]
        let monoKeys = ["monounsaturated", "mono", "acides gras monoinsaturés", "einfach ungesättigt", "monoinsaturi"]
        let polyKeys = ["polyunsaturated", "poly", "acides gras polyinsaturés", "mehrfach ungesättigt", "polinsaturi"]

        // Vitamins/minerals keywords
        let vitAKeys = ["vitamin a", "vit a", "retinol", "retinyl"]
        let vitBKeys = ["vitamin b", "vit b", "b-complex", "b complex", "b group", "b-group"]
        let vitCKeys = ["vitamin c", "vit c", "ascorbic"]
        let vitDKeys = ["vitamin d", "vit d", "cholecalciferol"]
        let vitEKeys = ["vitamin e", "vit e", "tocopherol"]
        let vitKKeys = ["vitamin k", "vit k", "phylloquinone", "menaquinone"]

        let calciumKeys = ["calcium", "ca"]
        let ironKeys = ["iron", "fe"]
        let potassiumKeys = ["potassium", "kalium", "k"]
        let zincKeys = ["zinc", "zn"]
        let magnesiumKeys = ["magnesium", "mg"] // note: "mg" is also unit; rely on context around keywords

        for raw in lines {
            let line = raw.lowercased()

            if result.calories == nil, let kcal = parseEnergy(line) {
                result.calories = kcal
                continue
            }

            if result.carbohydrates == nil, let v = parseGramValue(line, keywords: carbsKeys) {
                result.carbohydrates = v
                continue
            }
            if result.protein == nil, let v = parseGramValue(line, keywords: proteinKeys) {
                result.protein = v
                continue
            }
            if result.fat == nil, let v = parseGramValue(line, keywords: fatKeys) {
                result.fat = v
            }

            if result.sodiumMg == nil, let mg = parseSodiumOrSalt(line) {
                result.sodiumMg = mg
                continue
            }

            if result.sugars == nil, let v = parseGramValue(line, keywords: sugarKeys) {
                result.sugars = v
                continue
            }
            if result.fibre == nil, let v = parseGramValue(line, keywords: fibreKeys) {
                result.fibre = v
                continue
            }
            if result.starch == nil, let v = parseGramValue(line, keywords: starchKeys) {
                result.starch = v
                continue
            }

            if result.saturatedFat == nil, let v = parseGramValue(line, keywords: satKeys) {
                result.saturatedFat = v
            }
            if result.transFat == nil, let v = parseGramValue(line, keywords: transKeys) {
                result.transFat = v
            }
            if result.monounsaturatedFat == nil, let v = parseGramValue(line, keywords: monoKeys) {
                result.monounsaturatedFat = v
            }
            if result.polyunsaturatedFat == nil, let v = parseGramValue(line, keywords: polyKeys) {
                result.polyunsaturatedFat = v
            }

            // Vitamins (mg or µg → mg)
            if result.vitaminA == nil {
                if let mg = parseMilligramValue(line, keywords: vitAKeys) {
                    result.vitaminA = mg
                } else if let mgFromMicro = parseMicrogramValue(line, keywords: vitAKeys) {
                    result.vitaminA = mgFromMicro
                }
            }
            if result.vitaminB == nil {
                if let mg = parseMilligramValue(line, keywords: vitBKeys) {
                    result.vitaminB = mg
                } else if let mgFromMicro = parseMicrogramValue(line, keywords: vitBKeys) {
                    result.vitaminB = mgFromMicro
                }
            }
            if result.vitaminC == nil {
                if let mg = parseMilligramValue(line, keywords: vitCKeys) {
                    result.vitaminC = mg
                } else if let mgFromMicro = parseMicrogramValue(line, keywords: vitCKeys) {
                    result.vitaminC = mgFromMicro
                }
            }
            if result.vitaminD == nil {
                if let mg = parseMilligramValue(line, keywords: vitDKeys) {
                    result.vitaminD = mg
                } else if let mgFromMicro = parseMicrogramValue(line, keywords: vitDKeys) {
                    result.vitaminD = mgFromMicro
                }
            }
            if result.vitaminE == nil {
                if let mg = parseMilligramValue(line, keywords: vitEKeys) {
                    result.vitaminE = mg
                } else if let mgFromMicro = parseMicrogramValue(line, keywords: vitEKeys) {
                    result.vitaminE = mgFromMicro
                }
            }
            if result.vitaminK == nil {
                if let mg = parseMilligramValue(line, keywords: vitKKeys) {
                    result.vitaminK = mg
                } else if let mgFromMicro = parseMicrogramValue(line, keywords: vitKKeys) {
                    result.vitaminK = mgFromMicro
                }
            }

            // Minerals (mg or µg → mg)
            if result.calcium == nil {
                if let mg = parseMilligramValue(line, keywords: calciumKeys) {
                    result.calcium = mg
                } else if let mgFromMicro = parseMicrogramValue(line, keywords: calciumKeys) {
                    result.calcium = mgFromMicro
                }
            }
            if result.iron == nil {
                if let mg = parseMilligramValue(line, keywords: ironKeys) {
                    result.iron = mg
                } else if let mgFromMicro = parseMicrogramValue(line, keywords: ironKeys) {
                    result.iron = mgFromMicro
                }
            }
            if result.potassium == nil {
                if let mg = parseMilligramValue(line, keywords: potassiumKeys) {
                    result.potassium = mg
                } else if let mgFromMicro = parseMicrogramValue(line, keywords: potassiumKeys) {
                    result.potassium = mgFromMicro
                }
            }
            if result.zinc == nil {
                if let mg = parseMilligramValue(line, keywords: zincKeys) {
                    result.zinc = mg
                } else if let mgFromMicro = parseMicrogramValue(line, keywords: zincKeys) {
                    result.zinc = mgFromMicro
                }
            }
            if result.magnesium == nil {
                if let mg = parseMilligramValue(line, keywords: magnesiumKeys) {
                    result.magnesium = mg
                } else if let mgFromMicro = parseMicrogramValue(line, keywords: magnesiumKeys) {
                    result.magnesium = mgFromMicro
                }
            }
        }

        return result
    }

    // Single-dish confidence: based on largest salient object only
    private static func visualConfidenceSingleDish(in image: UIImage, guess: GuessResult) -> Double {
        guard let cg = image.cgImage else { return -Double.infinity }
        let area = largestSalientObjectAreaRatio(cgImage: cg)
        let macroPresence = (guess.carbohydrates ?? 0) + (guess.protein ?? 0) + (guess.fat ?? 0)
        return area * 1.0 + (macroPresence > 0 ? 0.1 : 0.0)
    }

    // MARK: - Visual fallback guess (heuristic) with single-dish constraint
    // Produces conservative estimates for calories/carbs/protein/fat only.
    // Enhanced for fried, beige, large-plate scenes (e.g., fish & chips).
    private static func visualGuessSingleDish(in image: UIImage) -> GuessResult? {
        guard let cgImage = image.cgImage else { return nil }

        // 1) Estimate area of the LARGEST salient object (single dish proxy)
        let rawAreaRatio = largestSalientObjectAreaRatio(cgImage: cgImage) // 0.0 ... 1.0

        // 2) Color features for category and “hearty fried plate” detection
        let stats = colorFeatures(from: image)
        let category = dominantFoodCategory(fromStats: stats)

        // Hearty fried plate signal: warm + neutral dominate, very little green
        let heartyPlate = (stats.warm + stats.neutral) > 0.70 && stats.green < 0.10
        let isDessert = (category == .dessertOrCake)

        // 3) Portion proxy with override: for hearty plates, raise the area floor
        let clampedAreaBase = max(0.12, min(0.85, rawAreaRatio))
        let clampedArea = heartyPlate ? max(0.55, clampedAreaBase) : clampedAreaBase

        // Slightly stronger scaling, benefits large single-dish scenes
        let scale = 0.70 + 1.00 * (clampedArea - 0.30) // area 0.30 -> 0.70x, 0.85 -> ~1.25x

        // Base kcal per serving (raised where appropriate)
        let baseKcal: Double
        let macroSplit: (carb: Double, protein: Double, fat: Double)
        switch category {
        case .dessertOrCake:
            baseKcal = 420
            macroSplit = (carb: 0.55, protein: 0.07, fat: 0.38)
        case .carbHeavy:
            baseKcal = 540
            macroSplit = (carb: 0.64, protein: 0.12, fat: 0.24)
        case .proteinHeavy:
            baseKcal = 460
            macroSplit = (carb: 0.12, protein: 0.48, fat: 0.40)
        case .vegOrSalad:
            baseKcal = 180
            macroSplit = (carb: 0.45, protein: 0.15, fat: 0.40)
        }

        // Fried bonus scaled by warm+neutral dominance
        let friedSignal = stats.warm + stats.neutral
        let friedBonus: Double = {
            guard clampedArea > 0.35 else { return 0 }
            if friedSignal > 0.78 { return 320 }
            if friedSignal > 0.65 { return 220 }
            if friedSignal > 0.52 { return 140 }
            return 0
        }()

        // Compute kcal
        var kcal = Int((baseKcal * scale + friedBonus).rounded())

        // Apply “hearty floor” ONLY for non-dessert categories to avoid cupcakes hitting 700 kcal.
        if heartyPlate && !isDessert {
            kcal = max(kcal, 680)
        }
        let kcalClamped = max(180, min(1400, kcal))

        // Convert macro proportions to grams using kcal factors (4/4/9)
        let carbKcal = Double(kcalClamped) * macroSplit.carb
        let proteinKcal = Double(kcalClamped) * macroSplit.protein
        let fatKcal = Double(kcalClamped) * macroSplit.fat

        let carbG = Int((carbKcal / 4.0).rounded())
        let proteinG = Int((proteinKcal / 4.0).rounded())
        let fatG = Int((fatKcal / 9.0).rounded())

        var guess = GuessResult()
        guess.calories = max(50, kcalClamped)
        guess.carbohydrates = max(0, carbG)
        guess.protein = max(0, proteinG)
        guess.fat = max(0, fatG)

        // Minimal vitamin/mineral fallback (mg), category-based conservative values (unchanged)
        switch category {
        case .dessertOrCake:
            guess.vitaminA = 0; guess.vitaminB = 0; guess.vitaminC = 0; guess.vitaminD = 0; guess.vitaminE = 0; guess.vitaminK = 0
            guess.calcium = 20; guess.iron = 0; guess.potassium = 40; guess.zinc = 0; guess.magnesium = 5
        case .carbHeavy:
            guess.vitaminA = 0; guess.vitaminB = 0; guess.vitaminC = 0; guess.vitaminD = 0; guess.vitaminE = 0; guess.vitaminK = 0
            guess.calcium = 10; guess.iron = 0; guess.potassium = 50; guess.zinc = 0; guess.magnesium = 10
        case .proteinHeavy:
            guess.vitaminA = 0; guess.vitaminB = 0; guess.vitaminC = 0; guess.vitaminD = 0; guess.vitaminE = 0; guess.vitaminK = 0
            guess.calcium = 15; guess.iron = 1; guess.potassium = 80; guess.zinc = 1; guess.magnesium = 12
        case .vegOrSalad:
            guess.vitaminA = 0; guess.vitaminB = 0; guess.vitaminC = 12; guess.vitaminD = 0; guess.vitaminE = 0; guess.vitaminK = 0
            guess.calcium = 40; guess.iron = 1; guess.potassium = 200; guess.zinc = 0; guess.magnesium = 20
        }

        return guess
    }

    // Food category buckets for heuristic
    private enum FoodCategory {
        case dessertOrCake
        case carbHeavy
        case proteinHeavy
        case vegOrSalad
    }

    // Largest salient object ratio (single-dish proxy)
    private static func largestSalientObjectAreaRatio(cgImage: CGImage) -> Double {
        if #available(iOS 13.0, *) {
            let request = VNGenerateAttentionBasedSaliencyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                if let result = request.results?.first as? VNSaliencyImageObservation,
                   let salient = result.salientObjects, !salient.isEmpty {
                    // Take the largest salient object's area (normalized)
                    let largest = salient.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height })!
                    let area = Double(largest.boundingBox.width * largest.boundingBox.height)
                    return max(0.0, min(1.0, area))
                }
            } catch {
                // fall through to simple fallback
            }
        }
        // Fallback: modest single-dish assumption if saliency unavailable
        return 0.35
    }

    // Extract coarse color features used by category/bias rules
    private static func colorFeatures(from image: UIImage) -> (warm: Double, green: Double, neutral: Double, dark: Double, bright: Double) {
        // Downscale and compute average + histogram-ish buckets
        let size = CGSize(width: 64, height: 64)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let small = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let img = small, let cg = img.cgImage else { return (0,0,0,0,0) }
        let width = cg.width
        let height = cg.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        var data = [UInt8](repeating: 0, count: Int(bytesPerRow * height))
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return (0,0,0,0,0) }
        guard let ctx = CGContext(data: &data,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: bitsPerComponent,
                                  bytesPerRow: bytesPerRow,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return (0,0,0,0,0) }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        var warmCount = 0, greenCount = 0, neutralCount = 0, darkCount = 0, brightCount = 0

        for y in 0..<height {
            for x in 0..<width {
                let idx = (y * bytesPerRow) + (x * bytesPerPixel)
                let r = Double(data[idx + 0])
                let g = Double(data[idx + 1])
                let b = Double(data[idx + 2])
                let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b

                if r > g && r > b { warmCount += 1 } // browns/reds -> baked/fried/dessert
                if g > r && g > b { greenCount += 1 } // greens -> veg/salad
                if abs(r - g) < 20 && abs(g - b) < 20 { neutralCount += 1 } // beige/neutral -> carbs/grains
                if luma < 60 { darkCount += 1 }
                if luma > 200 { brightCount += 1 }
            }
        }

        let total = max(1, width * height)
        return (warm: Double(warmCount)/Double(total),
                green: Double(greenCount)/Double(total),
                neutral: Double(neutralCount)/Double(total),
                dark: Double(darkCount)/Double(total),
                bright: Double(brightCount)/Double(total))
    }

    // Category using precomputed stats (so we don't recompute twice)
    private static func dominantFoodCategory(fromStats stats: (warm: Double, green: Double, neutral: Double, dark: Double, bright: Double)) -> FoodCategory {
        let warmRatio = stats.warm
        let greenRatio = stats.green
        let neutralRatio = stats.neutral
        let darkRatio = stats.dark
        let brightRatio = stats.bright

        // Dessert/cake: warm colors + either bright highlights (frosting) or dark (chocolate)
        if warmRatio > 0.35 && (brightRatio > 0.08 || darkRatio > 0.10) {
            return .dessertOrCake
        }
        // Veg/salad: a lot of green
        if greenRatio > 0.28 {
            return .vegOrSalad
        }
        // Carb-heavy: neutral/beige dominates (bread, pasta, rice, fried potatoes)
        if neutralRatio > 0.30 {
            return .carbHeavy
        }
        // Protein-heavy fallback (meats often warm but without extreme highlights)
        if warmRatio > 0.28 {
            return .proteinHeavy
        }
        // Default to carb-heavy if uncertain
        return .carbHeavy
    }
}

// Convenience to check if anything was parsed
private extension PhotoNutritionGuesser.GuessResult {
    var hasAnyValue: Bool {
        return calories != nil
        || carbohydrates != nil
        || protein != nil
        || fat != nil
        || sodiumMg != nil
        || sugars != nil
        || starch != nil
        || fibre != nil
        || monounsaturatedFat != nil
        || polyunsaturatedFat != nil
        || saturatedFat != nil
        || transFat != nil
        || animalProtein != nil
        || plantProtein != nil
        || proteinSupplements != nil
        || vitaminA != nil
        || vitaminB != nil
        || vitaminC != nil
        || vitaminD != nil
        || vitaminE != nil
        || vitaminK != nil
        || calcium != nil
        || iron != nil
        || potassium != nil
        || zinc != nil
        || magnesium != nil
    }

    // Count how many fields were parsed to score OCR variants
    var parsedFieldCount: Int {
        var c = 0
        if calories != nil { c += 1 }
        if carbohydrates != nil { c += 1 }
        if protein != nil { c += 1 }
        if fat != nil { c += 1 }
        if sodiumMg != nil { c += 1 }
        if sugars != nil { c += 1 }
        if starch != nil { c += 1 }
        if fibre != nil { c += 1 }
        if monounsaturatedFat != nil { c += 1 }
        if polyunsaturatedFat != nil { c += 1 }
        if saturatedFat != nil { c += 1 }
        if transFat != nil { c += 1 }
        if animalProtein != nil { c += 1 }
        if plantProtein != nil { c += 1 }
        if proteinSupplements != nil { c += 1 }
        if vitaminA != nil { c += 1 }
        if vitaminB != nil { c += 1 }
        if vitaminC != nil { c += 1 }
        if vitaminD != nil { c += 1 }
        if vitaminE != nil { c += 1 }
        if vitaminK != nil { c += 1 }
        if calcium != nil { c += 1 }
        if iron != nil { c += 1 }
        if potassium != nil { c += 1 }
        if zinc != nil { c += 1 }
        if magnesium != nil { c += 1 }
        return c
    }
}

