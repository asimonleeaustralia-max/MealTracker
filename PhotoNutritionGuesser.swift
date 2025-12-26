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
            if let code = await detectFirstBarcode(in: img) {
                // DuckDB first, then fallback JSON
                if let entry = await BarcodeRepository.shared.lookup(code: code) ?? LocalBarcodeDB.lookup(code: code) {
                    return map(entry: entry)
                }
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
    static func rotationVariants(of image: UIImage) -> [UIImage] {
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
    static func detectFirstBarcode(in image: UIImage) async -> String? {
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

            // Accept all supported languages for the given level/revision, optionally biasing with provided code.
            request.recognitionLanguages = recognitionLanguagesFor(level: level, preferredCode: languageCode)

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

    // Build a comprehensive language list for Vision OCR, including non-Latin scripts,
    // and bias it by placing the preferred code first when available.
    private static func recognitionLanguagesFor(level: VNRequestTextRecognitionLevel, preferredCode: String?) -> [String] {
        let normalizedPreferred = normalizedLanguageCode(preferredCode)

        // Query supported languages for the current revision and requested level.
        let supported: [String] = {
            // Always call the revision-based API; choose a revision based on availability.
            let revision: Int
            if #available(iOS 15.0, *) {
                revision = VNRecognizeTextRequest.currentRevision
            } else {
                // First public revision available on iOS 13+
                revision = VNRecognizeTextRequestRevision1
            }
            return (try? VNRecognizeTextRequest.supportedRecognitionLanguages(for: level, revision: revision)) ?? []
        }()

        // Deduplicate while preserving order
        func unique(_ array: [String]) -> [String] {
            var seen = Set<String>()
            var result: [String] = []
            for code in array {
                if !seen.contains(code) {
                    seen.insert(code)
                    result.append(code)
                }
            }
            return result
        }

        var languages = unique(supported)

        // If a preferred code is supplied, try to bias by moving it to the front.
        if let pref = normalizedPreferred {
            if let idx = languages.firstIndex(of: pref) {
                languages.remove(at: idx)
            }
            languages.insert(pref, at: 0)
        }

        // Ensure English is present (common labels) but avoid duplicates.
        if !languages.contains("en") {
            languages.append("en")
        }

        return languages
    }

    private static func normalizedLanguageCode(_ code: String?) -> String? {
        guard var c = code?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !c.isEmpty else { return nil }
        c = c.replacingOccurrences(of: "_", with: "-")
        return c
    }

    // MARK: - Parsing

    static func parseNutrition(from rawText: String) -> GuessResult {
        // Normalize OCR text robustly for multilingual matching
        let lines = rawText
            .components(separatedBy: .newlines)
            .map { TextNormalizer.normalize($0) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var result = GuessResult()

        // Regex helpers with non-Latin-aware boundaries
        func firstMatch(_ pattern: String, in text: String) -> NSTextCheckingResult? {
            let options: NSRegularExpression.Options = []
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
            // normalize decimal comma to dot
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

        // Boundary pattern: start or separator before; separator or end after
        let BSTART = "(?:(?<=^)|(?<=[\\s:：•·\\-\\(\\)\\[\\]，。、，、|/]))"
        let BEND = "(?:(?=$)|(?=[\\s:：•·\\-\\(\\)\\[\\]，。、 、|/]))"

        // Localized unit fragments
        let grams = LocalizedUnits.gramsPattern
        let milligrams = LocalizedUnits.milligramsPattern
        let micrograms = LocalizedUnits.microgramsPattern
        let kcalUnits = LocalizedUnits.kcalPattern
        let kJUnits = LocalizedUnits.kjPattern

        // Build a single alternation for keywords safely escaped
        func alternation(_ words: [String]) -> String {
            words.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        }

        func parseGramValue(_ line: String, keywords: [String]) -> Int? {
            let joined = alternation(keywords)
            let pattern = "\(BSTART)(?:\(joined))\(BEND)[^\\n\\r\\d]{0,20}([0-9]+[\\.,]?[0-9]*)\\s*(?:\(grams))\(BEND)"
            if let m = firstMatch(pattern, in: line) {
                return toInt(extractNumber(from: line, group: 1, in: m))
            }
            return nil
        }

        func parseMilligramValue(_ line: String, keywords: [String]) -> Int? {
            let joined = alternation(keywords)
            let pattern = "\(BSTART)(?:\(joined))\(BEND)[^\\n\\r\\d]{0,20}([0-9]+[\\.,]?[0-9]*)\\s*(?:\(milligrams))\(BEND)"
            if let m = firstMatch(pattern, in: line) {
                return toInt(extractNumber(from: line, group: 1, in: m))
            }
            return nil
        }

        func parseMicrogramValue(_ line: String, keywords: [String]) -> Int? {
            let joined = alternation(keywords)
            let pattern = "\(BSTART)(?:\(joined))\(BEND)[^\\n\\r\\d]{0,20}([0-9]+[\\.,]?[0-9]*)\\s*(?:\(micrograms))\(BEND)"
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
            if let mg = parseMilligramValue(line, keywords: sodiumKeys) {
                return mg
            }
            if let g = parseGramValue(line, keywords: sodiumKeys) {
                return g * 1000
            }
            // Salt line (convert g of salt to mg sodium: 1 g salt ≈ 400 mg sodium)
            if let gSalt = parseGramValue(line, keywords: saltKeys) {
                let sodiumMg = Int(round(Double(gSalt) * 400.0))
                return sodiumMg
            }
            return nil
        }

        func parseEnergy(_ line: String) -> Int? {
            // kcal direct with localized tokens
            if let mKcal = firstMatch("\(BSTART)(?:\(energyKeysKcal))\(BEND)[^\\d]{0,20}([0-9]+[\\.,]?[0-9]*)\\s*(?:\(kcalUnits))\(BEND)", in: line) {
                if let val = toInt(extractNumber(from: line, group: 1, in: mKcal)) {
                    return val
                }
            }
            // kJ conversion
            if let mKJ = firstMatch("\(BSTART)(?:\(energyKeysKJ))\(BEND)[^\\d]{0,20}([0-9]+[\\.,]?[0-9]*)\\s*(?:\(kJUnits))\(BEND)", in: line) {
                if let kj = toInt(extractNumber(from: line, group: 1, in: mKJ)) {
                    let kcal = Int(round(Double(kj) / 4.184))
                    return kcal
                }
            }
            // Bare "xxx kcal" localized
            if let mBare = firstMatch("([0-9]+[\\.,]?[0-9]*)\\s*(?:\(kcalUnits))\(BEND)", in: line),
               let val = toInt(extractNumber(from: line, group: 1, in: mBare)) {
                return val
            }
            return nil
        }

        // MARK: Multilingual keyword aliases

        // Carbohydrates
        let carbsKeys: [String] = [
            // English
            "carb","carbs","carbohydrate","carbohydrates",
            // French
            "glucide","glucides","dont sucres",
            // German
            "kohlenhydrat","kohlenhydrate","davon zucker",
            // Spanish/Portuguese
            "hidratos de carbono","hidratos","carbohidrato","carbohidratos","carboidrato","carboidratos",
            // Italian
            "carboidrati","di cui zuccheri",
            // Dutch
            "koolhydraten","waarvan suikers",
            // Nordic
            "kolhydrater","kulhydrater","karbohydrater",
            // Polish/Czech/Slovak/Hungarian/Romanian
            "węglowodany","cukry","sacharidy","cukry z toho","sacharidov","cukry z toho","szénhidrát","zaharuri","carbohidrați",
            // Greek
            "υδατάνθρακες","εκ των οποίων σάκχαρα",
            // Turkish
            "karbonhidrat","şekerler",
            // Russian/Ukrainian/Bulgarian (Cyrillic)
            "углеводы","в том числе сахара","вуглеводи","в т.ч. цукри","въглехидрати","от които захари",
            // Arabic
            "كربوهيدرات","نشويات","منها سكريات","منها سكر",
            // Hebrew
            "פחמימות","מתוכן סוכרים",
            // Hindi/Bengali
            "कार्बोहाइड्रेट","कार्ब्स","शर्करा","जिसमें शर्करा","কার্বোহাইড্রেট","কার্বস","চিনি","যার মধ্যে চিনি",
            // Thai
            "คาร์โบไฮเดรต","คาร์บ","น้ำตาลรวม","ซึ่งน้ำตาล",
            // Vietnamese
            "carbohydrat","carb","tinh bột","đường trong đó",
            // Indonesian/Malay
            "karbohidrat","karbo","gula termasuk",
            // Chinese (Simplified/Traditional)
            "碳水化合物","碳水","其中糖","糖",
            // Japanese
            "炭水化物","糖質","うち糖類",
            // Korean
            "탄수화물","당류","그중 당류","그중당류"
        ]

        // Protein
        let proteinKeys: [String] = [
            "protein","proteins","proteína","proteínas","proteine","eiweiß","eiweiss","eiweıß",
            "proteína","proteine","proteínas",
            "proteine","протеин","белки","білки","протеини",
            "البروتين","بروتين",
            "חלבון",
            "प्रोटीन","প্রোটিন",
            "โปรตีน",
            "proteină","proteine","proteínas",
            "蛋白质","蛋白","たんぱく質","蛋白質","단백질"
        ]

        // Fat
        let fatKeys: [String] = [
            "fat","fats","lipid","lipids",
            "grasas","grasa","grassi","matières grasses","matiere grasse",
            "fett","fette","fette gesamt",
            "vet","vetten",
            "yağ","yağlar",
            "жиры","жир","жиры всего","жири",
            "دهون","دهن",
            "שומן",
            "वसा","চর্বি",
            "ไขมัน",
            "lemak","lemak total",
            "脂肪","總脂肪","總脂","脂質","脂肪総量",
            "지방"
        ]

        // Sugars
        let sugarKeys: [String] = [
            "sugars","sugar","incl. sugars","of which sugars",
            "sucre","sucres","dont sucres",
            "zucker","davon zucker",
            "azúcares","azucar","de los cuales azúcares",
            "zuccheri","di cui zuccheri",
            "açúcares","açúcar",
            "sukker","hvorav sukkerarter","sockerarter",
            "cukry","z toho cukry","z toho cukrů",
            "cukry z toho",
            "zaharuri","din care zaharuri",
            "şekerler","şeker",
            "сахара","в т.ч. сахара","цукри",
            "سكريات","سكر",
            "סוכרים",
            "शर्करा","चीनी",
            "น้ำตาล",
            "đường","đường trong đó",
            "gula",
            "糖","其中糖","糖類","うち糖類",
            "당류","그중 당류"
        ]

        // Fibre
        let fibreKeys: [String] = [
            "fibre","fiber","fibra","faser",
            "fibres alimentaires","fibres",
            "балластные вещества","клетчатка","харчові волокна",
            "ألياف","الياف",
            "סיבים תזונתיים","סיבים",
            "रेशा","फाइबर","আঁশ","ফাইবার",
            "ใยอาหาร",
            "chất xơ",
            "serat",
            "膳食纤维","膳食纖維","食物繊維",
            "식이섬유"
        ]

        // Starch
        let starchKeys: [String] = [
            "starch","almidón","amido","stärke","amidon",
            "féculents","féculent",
            "skrobia","škrob","škroby","škroboviny",
            "نشا","النشا",
            "עמילן",
            "स्टार्च","मांडा","স্টার্চ",
            "แป้ง",
            "tinh bột",
            "pati","kanji",
            "淀粉","澱粉",
            "でんぷん",
            "전분"
        ]

        // Saturated fat
        let satKeys: [String] = [
            "saturated","sat fat","saturates","of which saturates",
            "acides gras saturés","dont acides gras saturés",
            "gesättigte","davon gesättigte fettsäuren","gesättigte fettsäuren",
            "ácidos grasos saturados","de los cuales saturados",
            "grassi saturi","di cui acidi grassi saturi",
            "ácidos graxos saturados",
            "mættede fedtsyrer","mättat fett","mettede fettsyrer",
            "kwasy tłuszczowe nasycone","z toho nasýtené mastné kyseliny",
            "grăsimi saturate",
            "doymuş yağ asitleri","doymuş yağ",
            "насыщенные жирные кислоты","в т.ч. насыщенные",
            "دهون مشبعة",
            "שומן רווי",
            "संतृप्त वसा","স্যাচুরेटেড ফ্যাট",
            "ไขมันอิ่มตัว",
            "chất béo bão hòa",
            "lemak jenuh",
            "饱和脂肪","飽和脂肪","飽和脂肪酸",
            "飽和脂肪酸","飽和脂肪",
            "飽和脂肪酸","飽和脂肪",
            "飽和脂肪酸","飽和脂肪",
            "飽和脂肪酸",
            "飽和脂肪酸",
            "飽和脂肪酸",
            "飽和脂肪酸",
            "飽和脂肪酸",
            "飽和脂肪酸",
            "飽和脂肪酸",
            "飽和脂肪酸",
            "飽和脂肪酸",
            "飽和脂肪酸",
            "飽和脂肪酸",
            "飽和脂肪酸",
            // Japanese/Korean concise
            "飽和脂肪酸","飽和脂肪","飽和脂肪酸",
            "포화지방"
        ]

        // Trans fat
        let transKeys: [String] = [
            "trans","trans fat","acides gras trans","grassi trans",
            "ácidos grasos trans","ácidos graxos trans",
            "transfett","trans-fettsäuren",
            "kwasy tłuszczowe trans",
            "grasimi trans",
            "트랜스지방","trans yağ",
            "трансжиры","транс-жиры",
            "دهون متحولة",
            "שומן טרנס",
            "ट्रांस वसा","ট্রান্স ফ্যাট",
            "ไขมันทรานส์",
            "chất béo chuyển hóa",
            "lemak trans",
            "反式脂肪","反式脂肪酸","反式",
            "トランス脂肪酸"
        ]

        // Mono
        let monoKeys: [String] = [
            "monounsaturated","mono",
            "acides gras monoinsaturés","monoinsaturés",
            "einfach ungesättigt","einfach ungesättigte fettsäuren",
            "monoinsaturi","acidi grassi monoinsaturi",
            "ácidos grasos monoinsaturados",
            "ácidos graxos monoinsaturados",
            "mättade enkelomättade","enkelomättat fett",
            "jednonienasycone kwasy tłuszczowe",
            "grăsimi mononesaturate",
            "tekli doymamış yağlar",
            "мононенасыщенные жирные кислоты",
            "دهون أحادية غير مشبعة",
            "שומן חד-בלתי רווי",
            "एकल असंतृप्त वसा",
            "ไขมันไม่อิ่มตัวเชิงเดี่ยว",
            "chất béo đơn không bão hòa",
            "lemak tak jenuh tunggal",
            "单不饱和脂肪","單不飽和脂肪",
            "一価不飽和脂肪酸",
            "단일불포화지방"
        ]

        // Poly
        let polyKeys: [String] = [
            "polyunsaturated","poly",
            "acides gras polyinsaturés","polyinsaturés",
            "mehrfach ungesättigt","mehrfach ungesättigte fettsäuren",
            "polinsaturi","acidi grassi polinsaturi",
            "ácidos grasos poliinsaturados",
            "ácidos graxos poliinsaturados",
            "fleromättat fett",
            "wielonienasycone kwasy tłuszczowe",
            "grăsimi polinesaturate",
            "çoklu doymamış yağlar",
            "полиненасыщенные жирные кислоты",
            "دهون متعددة غير مشبعة",
            "שומן רב-בלתי רווי",
            "बहु असंतृप्त वसा",
            "ไขมันไม่อิ่มตัวเชิงซ้อน",
            "chất béo đa không bão hòa",
            "lemak tak jenuh ganda",
            "多不饱和脂肪","多不飽和脂肪",
            "多価不飽和脂肪酸",
            "다중불포화지방"
        ]

        // Vitamins/minerals keywords
        let vitAKeys = ["vitamin a","vit a","retinol","retinyl","витамин a","retinolo","retinal","维生素a","維生素a","ビタミンa","비타민a","فيتامين a","ויטמין a","विटामिन a","ভিটামিন a"]
        let vitBKeys = ["vitamin b","vit b","b-complex","b complex","b group","b-group","витамин b","complexo b","grupo b","维生素b","維生素b","ビタミンb","비타민b","فيتامين b","ויטמין b","विटामिन b","ভিটামিন b"]
        let vitCKeys = ["vitamin c","vit c","ascorbic","ascorbate","ácido ascórbico","витамин c","维生素c","維生素c","ビタミンc","비타민c","فيتامين c","ויטמין c","विटामिन c","ভিটামিন c"]
        let vitDKeys = ["vitamin d","vit d","cholecalciferol","витамин d","维生素d","維生素d","ビタミンd","비타민d","فيتامين d","ויטמין d","विटामिन d","ভিটামিন d"]
        let vitEKeys = ["vitamin e","vit e","tocopherol","витамин e","维生素e","維生素e","ビタミンe","비타민e","فيتامين e","ויטמין e","विटामिन e","ভিটামিন e"]
        let vitKKeys = ["vitamin k","vit k","phylloquinone","menaquinone","витамин k","维生素k","維生素k","ビタミンk","비타민k","فيتامين k","ויטמין k","विटामिन k","ভিটামিন k"]

        let calciumKeys = ["calcium","ca","кальций","кальций (ca)","钙","鈣","カルシウム","칼슘","كالسيوم","סידן","कैल्शियम","ক্যালসিয়াম"]
        let ironKeys = ["iron","fe","железо","залізо","铁","鐵","鉄","철","حديد","ברזל","लोहा","আয়রন"]
        let potassiumKeys = ["potassium","kalium","k","калий","калій","钾","鉀","カリウム","칼륨","بوتاسيوم","אשלגן","पोटैशियम","পটাশিয়াম"]
        let zincKeys = ["zinc","zn","цинк","цинк (zn)","锌","鋅","亜鉛","아연","زنك","אבץ","जिंक","দস্তা"]
        let magnesiumKeys = ["magnesium","mg","магний","магній","镁","鎂","マグネシウム","마그네슘","مगनيسيوم","מגנזיום","मैग्नीशियम","ম্যাগনেসিয়াম"]

        // Sodium and salt
        let sodiumKeys = ["sodium","na","sodio","natrium","ナトリウム","나트륨","钠","鈉","натрий","натрій","صوديوم","נתרן","सोडियम","সোডিয়াম","natrium (na)"]
        let saltKeys = ["salt","sel","salz","sale","sal","salzgehalt","盐","鹽","塩分","소금","соль","сіль","ملح","מלח","नमक","লবণ"]

        // Energy label aliases
        let energyKeysKcal = alternation([
            "energy","calorie","calories","kcal",
            "énergie","énergie kcal",
            "energie","energie kcal",
            "energía","calorías","kcal",
            "energia","calorie","chilocalorie","kcal",
            "energia","calorias","quilocalorias","kcal",
            "energia","kalorien","kilokalorien","kcal",
            "energia","kcal","kalorii",
            "energia","kcal","калории","ккал",
            "طاقة","كيلوكالوري","سعرات","سعرات حرارية","كيلو كالوري","كيلो-كالوري","kcal",
            "אנרגיה","קק\"ל","קק״ל","kcal",
            "ऊर्जा","किलो कैलोरी","किलो-कैलोरी","kcal",
            "শক্তি","কিলোক্যালোরি","kcal",
            "พลังงาน","กิโลแคลอรี","กกcal","kcal",
            "năng lượng","kcal",
            "tenaga","kalori","kcal",
            "能量","千卡","大卡","kcal",
            "エネルギー","キロカロリー","kcal",
            "에너지","킬로칼로리","kcal"
        ])

        let energyKeysKJ = alternation([
            "energy","kJ","kilojoule","kilojoules",
            "énergie","kJ",
            "energie","kJ",
            "energía","kJ",
            "energia","kJ",
            "energia","kJ",
            "energia","kJ","кДж","килоджоуль","килоджоули",
            "طاقة","كيلوجول","kJ",
            "אנרגיה","ק\"ג'","קג׳","kJ",
            "ऊर्जा","किलो जूल","kJ",
            "শক্তি","কিলোজুল","kJ",
            "พลังงาน","กิโลจูล","kJ",
            "năng lượng","kJ",
            "tenaga","kilojoule","kJ",
            "能量","千焦","kJ",
            "エネルギー","キロジュール","kJ",
            "에너지","킬로줄","kJ"
        ])

        for raw in lines {
            let line = raw

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
extension PhotoNutritionGuesser.GuessResult {
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

// MARK: - Text Normalization and Localized Units

private enum TextNormalizer {
    static func normalize(_ s: String) -> String {
        // NFKC to compose compatibility forms, width folding, etc.
        var t = s.precomposedStringWithCompatibilityMapping

        // Replace common punctuation variants with ASCII
        t = t.replacingOccurrences(of: "：", with: ":")
        t = t.replacingOccurrences(of: "・", with: "·")
        t = t.replacingOccurrences(of: "．", with: ".")
        t = t.replacingOccurrences(of: "，", with: ",")
        t = t.replacingOccurrences(of: "／", with: "/")
        t = t.replacingOccurrences(of: "－", with: "-")
        t = t.replacingOccurrences(of: "–", with: "-")
        t = t.replacingOccurrences(of: "—", with: "-")
        t = t.replacingOccurrences(of: "•", with: "•") // keep bullet
        t = t.replacingOccurrences(of: "·", with: "·")

        // Map micro symbols and common OCR confusions
        t = t.replacingOccurrences(of: "µ", with: "u") // µg -> ug
        t = t.replacingOccurrences(of: "μ", with: "u") // Greek mu
        t = t.replacingOccurrences(of: "㎎", with: "mg")
        t = t.replacingOccurrences(of: "㎏", with: "kg")
        t = t.replacingOccurrences(of: "㏄", with: "cc")
        t = t.replacingOccurrences(of: "㎉", with: "kcal")
        t = t.replacingOccurrences(of: "㎈", with: "kcal")
        t = t.replacingOccurrences(of: "㎖", with: "ml")
        t = t.replacingOccurrences(of: "㎍", with: "ug")
        t = t.replacingOccurrences(of: "㎜", with: "mm")
        t = t.replacingOccurrences(of: "０", with: "0")
        t = t.replacingOccurrences(of: "１", with: "1")
        t = t.replacingOccurrences(of: "２", with: "2")
        t = t.replacingOccurrences(of: "３", with: "3")
        t = t.replacingOccurrences(of: "４", with: "4")
        t = t.replacingOccurrences(of: "５", with: "5")
        t = t.replacingOccurrences(of: "６", with: "6")
        t = t.replacingOccurrences(of: "７", with: "7")
        t = t.replacingOccurrences(of: "８", with: "8")
        t = t.replacingOccurrences(of: "９", with: "9")

        // Lowercase (safe for scripts with case; others unaffected)
        t = t.lowercased()

        // Remove diacritics for Latin/Greek/Cyrillic only to aid matching; keep other scripts untouched.
        // Heuristic: if string contains only Latin/Greek/Cyrillic ranges, strip diacritics.
        if t.range(of: #"^[\p{Latin}\p{Greek}\p{Cyrillic}\s\p{Number}\p{Punctuation}]+$"#, options: .regularExpression) != nil {
            t = t.folding(options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive], locale: .current)
        }

        // Collapse whitespace
        t = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        return t
    }
}

private enum LocalizedUnits {
    // grams
    static let gramsPattern: String = {
        alternation([
            "g","gram","grams","gramme","grammes","grammi",
            "гр","г","грамм","грамма",
            "克","公克",
            "グラム",
            "그램",
            "กรัม",
            "גרם",
            "ग्राम",
            "গ্রাম",
            "غ","غرام","جرام"
        ])
    }()

    // milligrams
    static let milligramsPattern: String = {
        alternation([
            "mg","milligram","milligrams","milligramme","milligrammes","milligrammi",
            "мг","миллиграмм","миллиграмма",
            "毫克",
            "ミリグラム",
            "밀리그램",
            "มก\\.","มิลลิกรัม",
            "מ\"ג","מג","מיליגרם",
            "मि\\.ग्रा","मिलीग्राम",
            "মিগ্রা","মিলিগ্রাম",
            "ملغم","ميليغرام","مليغرام"
        ])
    }()

    // micrograms
    static let microgramsPattern: String = {
        alternation([
            "ug","mcg","µg","microgram","micrograms","microgramme","microgrammes","microgrammi",
            "мкг","микрограмм","микрограмма",
            "微克",
            "マイクログラム",
            "마이크로그램",
            "ไมโครกรัม",
            "מק\"ג","מקג","מיקרוגרם",
            "माइक्रोग्राम",
            "মাইক্রোগ্রাম",
            "ميكروغرام"
        ])
    }()

    // kcal
    static let kcalPattern: String = {
        alternation([
            "kcal","ккал","千卡","大卡","キロカロリー","킬로칼로리","กิโลแคลอรี","كيلوكالوري","קק\"ל","קק״ל"
        ])
    }()

    // kJ
    static let kjPattern: String = {
        alternation([
            "kj","кдж","千焦","キロジュール","킬로줄","กิโลจูล","كيلوجول","ק\"ג'","קג׳"
        ])
    }()

    private static func alternation(_ words: [String]) -> String {
        words.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
    }
}
