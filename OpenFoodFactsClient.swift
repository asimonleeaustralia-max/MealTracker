//
//  OpenFoodFactsClient.swift
//  MealTracker
//
//  Minimal OFF client to fetch product nutriments by barcode.
//  Prefers per-serving values when available and sensible; otherwise falls back to per-100g/100ml.
//  Maps into LocalBarcodeDB.Entry units (kcal, grams, mg).
//

import Foundation

struct OpenFoodFactsClient {

    // MARK: - Lossy numeric decoding helpers

    // Decode Double? from Double/Int/String (accepts "1.2", "1,2", trims, ignores non-numeric tails)
    private static func decodeLossyDouble(from container: KeyedDecodingContainer<Nutriments.CodingKeys>, forKey key: Nutriments.CodingKeys) -> Double? {
        // Try Double
        if let v = try? container.decodeIfPresent(Double.self, forKey: key) {
            return v
        }
        // Try Int
        if let v = try? container.decodeIfPresent(Int.self, forKey: key) {
            return Double(v)
        }
        // Try String -> Double
        if let s = try? container.decodeIfPresent(String.self, forKey: key) {
            return parseLooseDouble(s)
        }
        return nil
    }

    private static func decodeLossyDouble(from container: KeyedDecodingContainer<Product.CodingKeys>, forKey key: Product.CodingKeys) -> Double? {
        if let v = try? container.decodeIfPresent(Double.self, forKey: key) {
            return v
        }
        if let v = try? container.decodeIfPresent(Int.self, forKey: key) {
            return Double(v)
        }
        if let s = try? container.decodeIfPresent(String.self, forKey: key) {
            return parseLooseDouble(s)
        }
        return nil
    }

    // Very permissive numeric parser: handles "1,23", " 1.23 ", "1.23g", "trace", etc.
    private static func parseLooseDouble(_ raw: String?) -> Double? {
        guard var s = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        // Common textual tokens that mean "very small" -> treat as ~0
        let lower = s.lowercased()
        if lower == "trace" || lower == "<0.1" || lower == "< 0.1" { return 0.0 }
        // Replace comma decimal with dot; keep digits, one dot, and optional leading minus
        s = s.replacingOccurrences(of: ",", with: ".")
        var result = ""
        var seenDot = false
        var seenDigit = false
        for (i, ch) in s.enumerated() {
            if ch.isNumber {
                result.append(ch)
                seenDigit = true
            } else if ch == "." {
                if !seenDot {
                    seenDot = true
                    result.append(ch)
                } else {
                    break
                }
            } else if ch == "-" && i == 0 {
                result.append(ch)
            } else if ch.isWhitespace {
                if seenDigit { break }
            } else {
                if seenDigit { break }
            }
        }
        if result == "" || result == "-" || result == "." || result == "-." { return nil }
        return Double(result)
    }

    struct Response: Decodable {
        let status: Int?
        let product: Product?
    }

    struct Product: Decodable {
        let code: String?
        let product_name: String?
        let categories: String?
        let serving_size: String?
        let serving_quantity: Double? // Often missing; not always reliable
        let nutriments: Nutriments?

        enum CodingKeys: String, CodingKey {
            case code, product_name, categories, serving_size, serving_quantity, nutriments
        }

        init(code: String?, product_name: String?, categories: String?, serving_size: String?, serving_quantity: Double?, nutriments: Nutriments?) {
            self.code = code
            self.product_name = product_name
            self.categories = categories
            self.serving_size = serving_size
            self.serving_quantity = serving_quantity
            self.nutriments = nutriments
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.code = try? c.decodeIfPresent(String.self, forKey: .code)
            self.product_name = try? c.decodeIfPresent(String.self, forKey: .product_name)
            self.categories = try? c.decodeIfPresent(String.self, forKey: .categories)
            self.serving_size = try? c.decodeIfPresent(String.self, forKey: .serving_size)
            self.serving_quantity = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .serving_quantity)
            self.nutriments = try? c.decodeIfPresent(Nutriments.self, forKey: .nutriments)
        }
    }

    // OFF nutriments keys are very wide; we only decode what we need.
    struct Nutriments: Decodable {
        // Energy
        let energy_kcal_serving: Double?
        let energy_kcal_100g: Double?
        let energy_serving: Double?     // sometimes kJ
        let energy_100g: Double?        // sometimes kJ
        let energy_unit: String?

        // Macros
        let carbohydrates_serving: Double?
        let carbohydrates_100g: Double?
        let proteins_serving: Double?
        let proteins_100g: Double?
        let fat_serving: Double?
        let fat_100g: Double?

        // Sub-macros
        let sugars_serving: Double?
        let sugars_100g: Double?
        let fiber_serving: Double?
        let fiber_100g: Double?

        // Fats breakdown
        let saturated_fat_serving: Double?
        let saturated_fat_100g: Double?
        let trans_fat_serving: Double?
        let trans_fat_100g: Double?
        let monounsaturated_fat_serving: Double?
        let monounsaturated_fat_100g: Double?
        let polyunsaturated_fat_serving: Double?
        let polyunsaturated_fat_100g: Double?

        // Sodium/salt (OFF mostly provides salt)
        let sodium_serving: Double?
        let sodium_100g: Double?
        let salt_serving: Double?
        let salt_100g: Double?

        // Minerals
        let calcium_serving: Double?
        let calcium_100g: Double?
        let iron_serving: Double?
        let iron_100g: Double?
        let potassium_serving: Double?
        let potassium_100g: Double?
        let zinc_serving: Double?
        let zinc_100g: Double?
        let magnesium_serving: Double?
        let magnesium_100g: Double?

        // Vitamins
        let vitamin_a_serving: Double?
        let vitamin_a_100g: Double?
        let vitamin_c_serving: Double?
        let vitamin_c_100g: Double?
        let vitamin_d_serving: Double?
        let vitamin_d_100g: Double?
        let vitamin_e_serving: Double?
        let vitamin_e_100g: Double?
        let vitamin_k_serving: Double?
        let vitamin_k_100g: Double?

        // Units
        let vitamin_a_unit: String?
        let vitamin_c_unit: String?
        let vitamin_d_unit: String?
        let vitamin_e_unit: String?
        let vitamin_k_unit: String?
        let calcium_unit: String?
        let iron_unit: String?
        let potassium_unit: String?
        let zinc_unit: String?
        let magnesium_unit: String?

        enum CodingKeys: String, CodingKey {
            case energy_kcal_serving, energy_kcal_100g, energy_serving, energy_100g, energy_unit
            case carbohydrates_serving, carbohydrates_100g, proteins_serving, proteins_100g, fat_serving, fat_100g
            case sugars_serving, sugars_100g, fiber_serving, fiber_100g
            case saturated_fat_serving, saturated_fat_100g, trans_fat_serving, trans_fat_100g, monounsaturated_fat_serving, monounsaturated_fat_100g, polyunsaturated_fat_serving, polyunsaturated_fat_100g
            case sodium_serving, sodium_100g, salt_serving, salt_100g
            case calcium_serving, calcium_100g, iron_serving, iron_100g, potassium_serving, potassium_100g, zinc_serving, zinc_100g, magnesium_serving, magnesium_100g
            case vitamin_a_serving, vitamin_a_100g, vitamin_c_serving, vitamin_c_100g, vitamin_d_serving, vitamin_d_100g, vitamin_e_serving, vitamin_e_100g, vitamin_k_serving, vitamin_k_100g
            case vitamin_a_unit, vitamin_c_unit, vitamin_d_unit, vitamin_e_unit, vitamin_k_unit, calcium_unit, iron_unit, potassium_unit, zinc_unit, magnesium_unit
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)

            // Energy
            self.energy_kcal_serving = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .energy_kcal_serving)
            self.energy_kcal_100g = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .energy_kcal_100g)
            self.energy_serving = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .energy_serving)
            self.energy_100g = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .energy_100g)
            self.energy_unit = try? c.decodeIfPresent(String.self, forKey: .energy_unit)

            // Macros
            self.carbohydrates_serving = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .carbohydrates_serving)
            self.carbohydrates_100g = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .carbohydrates_100g)
            self.proteins_serving = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .proteins_serving)
            self.proteins_100g = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .proteins_100g)
            self.fat_serving = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .fat_serving)
            self.fat_100g = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .fat_100g)

            // Sub-macros
            self.sugars_serving = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .sugars_serving)
            self.sugars_100g = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .sugars_100g)
            self.fiber_serving = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .fiber_serving)
            self.fiber_100g = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .fiber_100g)

            // Fats breakdown
            self.saturated_fat_serving = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .saturated_fat_serving)
            self.saturated_fat_100g = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .saturated_fat_100g)
            self.trans_fat_serving = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .trans_fat_serving)
            self.trans_fat_100g = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .trans_fat_100g)
            self.monounsaturated_fat_serving = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .monounsaturated_fat_serving)
            self.monounsaturated_fat_100g = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .monounsaturated_fat_100g)
            self.polyunsaturated_fat_serving = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .polyunsaturated_fat_serving)
            self.polyunsaturated_fat_100g = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .polyunsaturated_fat_100g)

            // Sodium/salt
            self.sodium_serving = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .sodium_serving)
            self.sodium_100g = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .sodium_100g)
            self.salt_serving = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .salt_serving)
            self.salt_100g = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .salt_100g)

            // Minerals
            self.calcium_serving = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .calcium_serving)
            self.calcium_100g = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .calcium_100g)
            self.iron_serving = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .iron_serving)
            self.iron_100g = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .iron_100g)
            self.potassium_serving = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .potassium_serving)
            self.potassium_100g = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .potassium_100g)
            self.zinc_serving = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .zinc_serving)
            self.zinc_100g = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .zinc_100g)
            self.magnesium_serving = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .magnesium_serving)
            self.magnesium_100g = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .magnesium_100g)

            // Vitamins
            self.vitamin_a_serving = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .vitamin_a_serving)
            self.vitamin_a_100g = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .vitamin_a_100g)
            self.vitamin_c_serving = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .vitamin_c_serving)
            self.vitamin_c_100g = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .vitamin_c_100g)
            self.vitamin_d_serving = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .vitamin_d_serving)
            self.vitamin_d_100g = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .vitamin_d_100g)
            self.vitamin_e_serving = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .vitamin_e_serving)
            self.vitamin_e_100g = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .vitamin_e_100g)
            self.vitamin_k_serving = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .vitamin_k_serving)
            self.vitamin_k_100g = OpenFoodFactsClient.decodeLossyDouble(from: c, forKey: .vitamin_k_100g)

            // Units
            self.vitamin_a_unit = try? c.decodeIfPresent(String.self, forKey: .vitamin_a_unit)
            self.vitamin_c_unit = try? c.decodeIfPresent(String.self, forKey: .vitamin_c_unit)
            self.vitamin_d_unit = try? c.decodeIfPresent(String.self, forKey: .vitamin_d_unit)
            self.vitamin_e_unit = try? c.decodeIfPresent(String.self, forKey: .vitamin_e_unit)
            self.vitamin_k_unit = try? c.decodeIfPresent(String.self, forKey: .vitamin_k_unit)
            self.calcium_unit = try? c.decodeIfPresent(String.self, forKey: .calcium_unit)
            self.iron_unit = try? c.decodeIfPresent(String.self, forKey: .iron_unit)
            self.potassium_unit = try? c.decodeIfPresent(String.self, forKey: .potassium_unit)
            self.zinc_unit = try? c.decodeIfPresent(String.self, forKey: .zinc_unit)
            self.magnesium_unit = try? c.decodeIfPresent(String.self, forKey: .magnesium_unit)
        }
    }

    enum OFFError: Error, LocalizedError {
        case notFound
        case invalidResponse(String) // include brief reason

        var errorDescription: String? {
            switch self {
            case .notFound:
                return "Product not found"
            case .invalidResponse(let reason):
                return reason
            }
        }
    }

    // Fetch a product by barcode from OFF
    static func fetchProduct(by barcode: String) async throws -> Product {
        let normalized = barcode.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "")
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(normalized).json") else {
            throw OFFError.invalidResponse("Invalid URL")
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 15

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw OFFError.invalidResponse("No HTTP response")
        }
        guard 200..<300 ~= http.statusCode else {
            // Log a small payload preview to help diagnose server-side errors
            let preview = Self.previewUTF8(data, limit: 500)
            throw OFFError.invalidResponse("HTTP \(http.statusCode). Payload: \(preview)")
        }

        do {
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            guard decoded.status == 1, let product = decoded.product else {
                throw OFFError.notFound
            }
            return product
        } catch {
            // Decode failed: include URL and payload preview for diagnostics
            let preview = Self.previewUTF8(data, limit: 500)
            let ct = http.value(forHTTPHeaderField: "Content-Type") ?? "unknown"
            let reason = "Decode failed for \(url.absoluteString). Content-Type: \(ct). Payload: \(preview)"
            throw OFFError.invalidResponse(reason)
        }
    }

    // Map OFF Product -> LocalBarcodeDB.Entry with per-serving preference when sensible
    static func mapToEntry(from product: Product) -> LocalBarcodeDB.Entry? {
        guard let code = product.code ?? product.product_name ?? product.nutriments?.energy_kcal_100g.map({ _ in product.code ?? "" }) else {
            return nil
        }
        let n = product.nutriments

        // Helper: choose per-serving if present and sensible, else per-100g/100ml
        func pick(_ serving: Double?, _ per100: Double?) -> Int? {
            if let s = serving, s > 0 {
                return Int((s).rounded())
            }
            if let p = per100, p > 0 {
                return Int((p).rounded())
            }
            return nil
        }

        // Energy: OFF sometimes reports energy in kJ; prefer kcal if present.
        let kcalServing = n?.energy_kcal_serving
        let kcal100g = n?.energy_kcal_100g
        var calories: Int? = pick(kcalServing, kcal100g)
        if calories == nil {
            // Try converting kJ if kcal missing
            let kJServing = n?.energy_serving
            let kJ100g = n?.energy_100g
            if let kJ = kJServing ?? kJ100g {
                calories = Int((kJ / 4.184).rounded())
            }
        }

        // Macros (g)
        let carbs = pick(n?.carbohydrates_serving, n?.carbohydrates_100g)
        let protein = pick(n?.proteins_serving, n?.proteins_100g)
        let fat = pick(n?.fat_serving, n?.fat_100g)

        // Sodium: prefer sodium directly; else convert salt(g) -> sodium mg ≈ g * 400
        let sodiumMg: Int? = {
            if let s = n?.sodium_serving ?? n?.sodium_100g, s > 0 {
                // OFF sodium is in g per 100g/serving; convert g -> mg
                return Int((s * 1000.0).rounded())
            }
            if let salt = n?.salt_serving ?? n?.salt_100g, salt > 0 {
                return Int((salt * 400.0).rounded())
            }
            return nil
        }()

        // Sub-macros (g)
        let sugars = pick(n?.sugars_serving, n?.sugars_100g)
        let fibre = pick(n?.fiber_serving, n?.fiber_100g)
        let starch: Int? = nil // OFF rarely provides starch explicitly

        // Fats breakdown (g)
        let monounsaturatedFat = pick(n?.monounsaturated_fat_serving, n?.monounsaturated_fat_100g)
        let polyunsaturatedFat = pick(n?.polyunsaturated_fat_serving, n?.polyunsaturated_fat_100g)
        let saturatedFat = pick(n?.saturated_fat_serving, n?.saturated_fat_100g)
        let transFat = pick(n?.trans_fat_serving, n?.trans_fat_100g)

        // Proteins breakdown not available from OFF
        let animalProtein: Int? = nil
        let plantProtein: Int? = nil
        let proteinSupplements: Int? = nil

        // Minerals (mg)
        func mgFrom(_ serving: Double?, _ per100: Double?, unit: String?) -> Int? {
            let raw = serving ?? per100
            guard let v = raw, v > 0 else { return nil }
            let u = (unit ?? "").lowercased()
            if u.contains("µg") || u.contains("mcg") || u.contains("ug") {
                // micrograms -> mg
                return Int((v / 1000.0).rounded())
            }
            // Assume mg otherwise; OFF often reports mg already
            return Int((v).rounded())
        }

        let calcium = mgFrom(n?.calcium_serving, n?.calcium_100g, unit: n?.calcium_unit)
        let iron = mgFrom(n?.iron_serving, n?.iron_100g, unit: n?.iron_unit)
        let potassium = mgFrom(n?.potassium_serving, n?.potassium_100g, unit: n?.potassium_unit)
        let zinc = mgFrom(n?.zinc_serving, n?.zinc_100g, unit: n?.zinc_unit)
        let magnesium = mgFrom(n?.magnesium_serving, n?.magnesium_100g, unit: n?.magnesium_unit)

        // Vitamins (mg base)
        let vitaminA = mgFrom(n?.vitamin_a_serving, n?.vitamin_a_100g, unit: n?.vitamin_a_unit)
        let vitaminB: Int? = nil // OFF aggregates B vitamins separately; skipping
        let vitaminC = mgFrom(n?.vitamin_c_serving, n?.vitamin_c_100g, unit: n?.vitamin_c_unit)
        let vitaminD = mgFrom(n?.vitamin_d_serving, n?.vitamin_d_100g, unit: n?.vitamin_d_unit)
        let vitaminE = mgFrom(n?.vitamin_e_serving, n?.vitamin_e_100g, unit: n?.vitamin_e_unit)
        let vitaminK = mgFrom(n?.vitamin_k_serving, n?.vitamin_k_100g, unit: n?.vitamin_k_unit)

        return LocalBarcodeDB.Entry(
            code: normalizedCode(code),
            calories: calories,
            carbohydrates: carbs,
            protein: protein,
            fat: fat,
            sodiumMg: sodiumMg,
            sugars: sugars,
            starch: starch,
            fibre: fibre,
            monounsaturatedFat: monounsaturatedFat,
            polyunsaturatedFat: polyunsaturatedFat,
            saturatedFat: saturatedFat,
            transFat: transFat,
            animalProtein: animalProtein,
            plantProtein: plantProtein,
            proteinSupplements: proteinSupplements,
            vitaminA: vitaminA,
            vitaminB: vitaminB,
            vitaminC: vitaminC,
            vitaminD: vitaminD,
            vitaminE: vitaminE,
            vitaminK: vitaminK,
            calcium: calcium,
            iron: iron,
            potassium: potassium,
            zinc: zinc,
            magnesium: magnesium
        )
    }

    private static func normalizedCode(_ raw: String?) -> String {
        (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "")
    }

    // Render a short, safe UTF-8 preview of the response body for diagnostics
    private static func previewUTF8(_ data: Data, limit: Int) -> String {
        if data.isEmpty { return "<empty>" }
        let prefix = data.prefix(limit)
        if let s = String(data: prefix, encoding: .utf8) {
            return s.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
        }
        // Fallback: hex preview if not UTF-8
        return prefix.map { String(format: "%02x", $0) }.joined()
    }
}

