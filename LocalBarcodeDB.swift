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
        // All values are in the same units your UI expects to display (kcal for calories, grams for macros, mg for sodium, mg base for vitamins/minerals).
        let calories: Int?
        let carbohydrates: Int?
        let protein: Int?
        let fat: Int?
        let sodiumMg: Int?

        // Optional subfields
        let sugars: Int?
        let starch: Int?
        let fibre: Int?

        let monounsaturatedFat: Int?
        let polyunsaturatedFat: Int?
        let saturatedFat: Int?
        let transFat: Int?

        let animalProtein: Int?
        let plantProtein: Int?
        let proteinSupplements: Int?

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

