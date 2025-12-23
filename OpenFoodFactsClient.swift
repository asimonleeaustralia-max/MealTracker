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

        // Minerals (mg basis when possible; OFF sometimes uses different units)
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

        // Vitamins (mg base when possible; OFF may use µg — we’ll convert)
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

        // Units for vitamins/minerals (rarely present; if present and micrograms, convert)
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
    }

    enum OFFError: Error {
        case notFound
        case invalidResponse
    }

    // Fetch a product by barcode from OFF
    static func fetchProduct(by barcode: String) async throws -> Product {
        // Country subdomain can vary; use world as default
        let normalized = barcode.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "")
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(normalized).json") else {
            throw OFFError.invalidResponse
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 15

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw OFFError.invalidResponse
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard decoded.status == 1, let product = decoded.product else {
            throw OFFError.notFound
        }
        return product
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
}

