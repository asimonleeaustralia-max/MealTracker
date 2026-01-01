//
//  LocalBarcodeDB.swift
//  MealTracker
//
//  Simple offline UPC/EAN -> nutrition lookup loaded from a bundled JSON.
//

import Foundation

struct LocalBarcodeDB {

    struct Entry: Codable, Equatable {
        // Standard identifiers
        let code: String // UPC/EAN as digits, no spaces

        // Per-serving or per-package values (you decide how you populate JSON)
        // Units: kcal for calories (Int), grams for macros (Double), mg for sodium and vitamins/minerals (Int, mg base).
        let calories: Int?
        let carbohydrates: Double?
        let protein: Double?
        let fat: Double?
        let sodiumMg: Int?

        // Optional subfields (grams as Double)
        let sugars: Double?
        let starch: Double?
        let fibre: Double?

        let monounsaturatedFat: Double?
        let polyunsaturatedFat: Double?
        let saturatedFat: Double?
        let transFat: Double?

        let animalProtein: Double?
        let plantProtein: Double?
        let proteinSupplements: Double?

        // Optional vitamins (mg base)
        let vitaminA: Int?
        let vitaminB: Int?
        let vitaminC: Int?
        let vitaminD: Int?
        let vitaminE: Int?
        let vitaminK: Int?

        // Optional minerals (mg base)
        let calcium: Int?
        let iron: Int?
        let potassium: Int?
        let zinc: Int?
        let magnesium: Int?
    }

    private static var cached: [String: Entry] = {
        guard let url = Bundle.main.url(forResource: "LocalBarcodeDB", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Entry].self, from: data)
        else {
            return [:]
        }
        var dict: [String: Entry] = [:]
        for e in list {
            dict[e.code] = e
        }
        return dict
    }()

    static func lookup(code: String) -> Entry? {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
        return cached[normalized]
    }
}

