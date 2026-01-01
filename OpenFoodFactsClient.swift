//
//  OpenFoodFactsClient.swift
//  MealTracker
//
//  Minimal OFF client to fetch product nutriments by barcode.
//  Prefers per-serving values when available and sensible; otherwise falls back to per-100g/100ml.
//  Maps into LocalBarcodeDB.Entry units (kcal, grams, mg).
//

import Foundation

// MARK: - Minimal Open Food Facts models (only fields used below)

struct Product: Codable {
    let code: String?
    let product_name: String?
    let nutriments: Nutriments?
}

struct Nutriments: Codable {
    // Energy (kcal preferred; kJ fallback)
    let energy_kcal_serving: Double?
    let energy_kcal_100g: Double?
    let energy_serving: Double?    // kJ per serving
    let energy_100g: Double?       // kJ per 100 g/ml

    // Macros (g)
    let carbohydrates_serving: Double?
    let carbohydrates_100g: Double?
    let proteins_serving: Double?
    let proteins_100g: Double?
    let fat_serving: Double?
    let fat_100g: Double?

    // Sodium/salt (g). OFF commonly encodes sodium in grams.
    let sodium_serving: Double?
    let sodium_100g: Double?
    let salt_serving: Double?
    let salt_100g: Double?

    // Sub-macros (g)
    let sugars_serving: Double?
    let sugars_100g: Double?
    let fiber_serving: Double?
    let fiber_100g: Double?

    // Fats breakdown (g)
    let monounsaturated_fat_serving: Double?
    let monounsaturated_fat_100g: Double?
    let polyunsaturated_fat_serving: Double?
    let polyunsaturated_fat_100g: Double?
    let saturated_fat_serving: Double?
    let saturated_fat_100g: Double?
    let trans_fat_serving: Double?
    let trans_fat_100g: Double?

    // Minerals (serving/100g) with units (mg/µg typically in unit fields)
    let calcium_serving: Double?
    let calcium_100g: Double?
    let calcium_unit: String?

    let iron_serving: Double?
    let iron_100g: Double?
    let iron_unit: String?

    let potassium_serving: Double?
    let potassium_100g: Double?
    let potassium_unit: String?

    let zinc_serving: Double?
    let zinc_100g: Double?
    let zinc_unit: String?

    let magnesium_serving: Double?
    let magnesium_100g: Double?
    let magnesium_unit: String?

    // Vitamins (serving/100g) with units
    let vitamin_a_serving: Double?
    let vitamin_a_100g: Double?
    let vitamin_a_unit: String?

    let vitamin_c_serving: Double?
    let vitamin_c_100g: Double?
    let vitamin_c_unit: String?

    let vitamin_d_serving: Double?
    let vitamin_d_100g: Double?
    let vitamin_d_unit: String?

    let vitamin_e_serving: Double?
    let vitamin_e_100g: Double?
    let vitamin_e_unit: String?

    let vitamin_k_serving: Double?
    let vitamin_k_100g: Double?
    let vitamin_k_unit: String?
}

struct OpenFoodFactsClient {

    // Normalize barcode string similarly to LocalBarcodeDB and BarcodeRepository
    private static func normalizedCode(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
    }

    // Networking: fetch product by barcode from OFF (v2 with v1 fallback)
    struct V2Response: Decodable {
        let status: Int?
        let status_verbose: String?
        let product: Product?
    }

    struct V1Response: Decodable {
        let status: Int?
        let status_verbose: String?
        let product: Product?
    }

    static func fetchProduct(by rawCode: String, logger: ((String) -> Void)? = nil) async throws -> Product {
        let code = normalizedCode(rawCode)

        // Try v2 first
        if let prod = try await fetchProductV2(code: code, logger: logger) {
            return prod
        }
        // Fallback to v1 if v2 not found
        if let prod = try await fetchProductV1(code: code, logger: logger) {
            return prod
        }

        let err = NSError(domain: "OpenFoodFactsClient", code: 404, userInfo: [NSLocalizedDescriptionKey: "Product \(code) not found"])
        #if DEBUG
        if let logger { logger("OFF: not found \(code)") }
        await BarcodeLogStore.shared.append("OFF: not found \(code)")
        #endif
        throw err
    }

    private static func fetchProductV2(code: String, logger: ((String) -> Void)?) async throws -> Product? {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(code).json") else {
            return nil
        }
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            return nil
        }
        do {
            let decoded = try JSONDecoder().decode(V2Response.self, from: data)
            if let status = decoded.status, status == 1 {
                return decoded.product
            } else {
                let msg = "OFF v2: status \(decoded.status ?? -1) \(decoded.status_verbose ?? "") for code \(code)"
                logger?(msg)
                #if DEBUG
                await BarcodeLogStore.shared.append(msg)
                #endif
                return nil
            }
        } catch {
            let msg = "OFF v2: decode error for \(code): \(error.localizedDescription)"
            logger?(msg)
            #if DEBUG
            await BarcodeLogStore.shared.append(msg)
            #endif
            return nil
        }
    }

    private static func fetchProductV1(code: String, logger: ((String) -> Void)?) async throws -> Product? {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v0/product/\(code).json") else {
            return nil
        }
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            return nil
        }
        do {
            let decoded = try JSONDecoder().decode(V1Response.self, from: data)
            if let status = decoded.status, status == 1 {
                return decoded.product
            } else {
                let msg = "OFF v1: status \(decoded.status ?? -1) \(decoded.status_verbose ?? "") for code \(code)"
                logger?(msg)
                #if DEBUG
                await BarcodeLogStore.shared.append(msg)
                #endif
                return nil
            }
        } catch {
            let msg = "OFF v1: decode error for \(code): \(error.localizedDescription)"
            logger?(msg)
            #if DEBUG
            await BarcodeLogStore.shared.append(msg)
            #endif
            return nil
        }
    }

    // Map OFF Product -> LocalBarcodeDB.Entry (units: kcal, g, mg)
    static func mapToEntry(from product: Product) -> LocalBarcodeDB.Entry? {
        guard let nutr = product.nutriments else { return nil }

        func toIntNonNegative(_ d: Double?) -> Int? {
            guard let d else { return nil }
            return max(0, Int((d).rounded()))
        }

        // Energy kcal: prefer kcal fields; fall back to kJ -> kcal
        let kcal: Int? = {
            if let v = nutr.energy_kcal_serving ?? nutr.energy_kcal_100g {
                return toIntNonNegative(v)
            }
            if let kj = nutr.energy_serving ?? nutr.energy_100g {
                return toIntNonNegative(kj / 4.184)
            }
            return nil
        }()

        // Macros in grams
        let carbs = toIntNonNegative(nutr.carbohydrates_serving ?? nutr.carbohydrates_100g)
        let protein = toIntNonNegative(nutr.proteins_serving ?? nutr.proteins_100g)
        let fat = toIntNonNegative(nutr.fat_serving ?? nutr.fat_100g)

        // Sodium mg: OFF gives sodium (g) or salt (g). Convert g->mg; salt g -> mg sodium (~400 mg per g salt)
        let sodiumMg: Int? = {
            if let sG = nutr.sodium_serving ?? nutr.sodium_100g {
                return toIntNonNegative(sG * 1000.0)
            }
            if let saltG = nutr.salt_serving ?? nutr.salt_100g {
                return toIntNonNegative(saltG * 400.0) // 1 g salt ≈ 400 mg sodium
            }
            return nil
        }()

        // Sub-macros in grams
        let sugars = toIntNonNegative(nutr.sugars_serving ?? nutr.sugars_100g)
        let fibre = toIntNonNegative(nutr.fiber_serving ?? nutr.fiber_100g)

        // Starch is not commonly provided by OFF; keep nil (no field in Nutriments). Leave as nil.
        let starch: Int? = nil

        // Fat breakdown in grams
        let monounsaturatedFat = toIntNonNegative(nutr.monounsaturated_fat_serving ?? nutr.monounsaturated_fat_100g)
        let polyunsaturatedFat = toIntNonNegative(nutr.polyunsaturated_fat_serving ?? nutr.polyunsaturated_fat_100g)
        let saturatedFat = toIntNonNegative(nutr.saturated_fat_serving ?? nutr.saturated_fat_100g)
        let transFat = toIntNonNegative(nutr.trans_fat_serving ?? nutr.trans_fat_100g)

        // Protein breakdown not provided by OFF
        let animalProtein: Int? = nil
        let plantProtein: Int? = nil
        let proteinSupplements: Int? = nil

        // Helper: convert vitamin/mineral value with its unit to mg
        func toMg(_ value: Double?, unit: String?) -> Int? {
            guard let value else { return nil }
            let u = (unit ?? "").lowercased()
            if u.contains("µg") || u.contains("mcg") || u.contains("ug") {
                return toIntNonNegative(value / 1000.0)
            }
            // Default assume mg if unit missing or says mg
            return toIntNonNegative(value)
        }

        // Vitamins (mg base)
        let vitaminA = toMg(nutr.vitamin_a_serving ?? nutr.vitamin_a_100g, unit: nutr.vitamin_a_unit)
        let vitaminB: Int? = nil // OFF has many B subtypes; without a single field, keep nil.
        let vitaminC = toMg(nutr.vitamin_c_serving ?? nutr.vitamin_c_100g, unit: nutr.vitamin_c_unit)
        let vitaminD = toMg(nutr.vitamin_d_serving ?? nutr.vitamin_d_100g, unit: nutr.vitamin_d_unit)
        let vitaminE = toMg(nutr.vitamin_e_serving ?? nutr.vitamin_e_100g, unit: nutr.vitamin_e_unit)
        let vitaminK = toMg(nutr.vitamin_k_serving ?? nutr.vitamin_k_100g, unit: nutr.vitamin_k_unit)

        // Minerals (mg base)
        let calcium = toMg(nutr.calcium_serving ?? nutr.calcium_100g, unit: nutr.calcium_unit)
        let iron = toMg(nutr.iron_serving ?? nutr.iron_100g, unit: nutr.iron_unit)
        let potassium = toMg(nutr.potassium_serving ?? nutr.potassium_100g, unit: nutr.potassium_unit)
        let zinc = toMg(nutr.zinc_serving ?? nutr.zinc_100g, unit: nutr.zinc_unit)
        let magnesium = toMg(nutr.magnesium_serving ?? nutr.magnesium_100g, unit: nutr.magnesium_unit)

        // If nothing meaningful, return nil
        let hasAny =
            kcal != nil || carbs != nil || protein != nil || fat != nil || sodiumMg != nil ||
            sugars != nil || fibre != nil || monounsaturatedFat != nil || polyunsaturatedFat != nil ||
            saturatedFat != nil || transFat != nil || vitaminA != nil || vitaminC != nil ||
            vitaminD != nil || vitaminE != nil || vitaminK != nil || calcium != nil || iron != nil ||
            potassium != nil || zinc != nil || magnesium != nil

        guard hasAny else { return nil }

        let code = normalizedCode(product.code ?? "")

        return LocalBarcodeDB.Entry(
            code: code.isEmpty ? (product.code ?? "") : code,
            calories: kcal,
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
}
