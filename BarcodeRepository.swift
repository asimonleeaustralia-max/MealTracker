//
//  BarcodeRepository.swift
//  MealTracker
//
//  DuckDB-backed repository for barcode -> nutrition lookups.
//  Returns LocalBarcodeDB.Entry so existing code paths can reuse PhotoNutritionGuesser.map(entry:).
//

import Foundation

actor BarcodeRepository {
    static let shared = BarcodeRepository()

    // Normalize barcode string to digits-only (your JSON used trimming+space removal)
    private func normalize(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
    }

    func lookup(code raw: String) async -> LocalBarcodeDB.Entry? {
        let code = normalize(raw)

        #if canImport(DuckDB)
        do {
            let entry = try await DuckDBManager.shared.withConnection { conn -> LocalBarcodeDB.Entry? in
                let sql = """
                SELECT
                    code,
                    calories, carbohydrates, protein, fat, sodiumMg,
                    sugars, starch, fibre,
                    monounsaturatedFat, polyunsaturatedFat, saturatedFat, transFat,
                    animalProtein, plantProtein, proteinSupplements,
                    vitaminA, vitaminB, vitaminC, vitaminD, vitaminE, vitaminK,
                    calcium, iron, potassium, zinc, magnesium
                FROM barcodes
                WHERE code = ?
                LIMIT 1;
                """
                let rs = try conn.query(sql, code)
                // Advance to first row; API surface assumed to allow row iteration
                guard rs.next() else { return nil }

                // Helpers to fetch nullable Int by column name; adapt to your row API if needed.
                func intOrNil(_ name: String) -> Int? {
                    // Assuming rs.get returns optional typed value by column name
                    return rs.get(name) as Int?
                }
                func stringOrNil(_ name: String) -> String? {
                    return rs.get(name) as String?
                }

                let codeVal = stringOrNil("code") ?? code

                return LocalBarcodeDB.Entry(
                    code: codeVal,
                    calories: intOrNil("calories"),
                    carbohydrates: intOrNil("carbohydrates"),
                    protein: intOrNil("protein"),
                    fat: intOrNil("fat"),
                    sodiumMg: intOrNil("sodiumMg"),
                    sugars: intOrNil("sugars"),
                    starch: intOrNil("starch"),
                    fibre: intOrNil("fibre"),
                    monounsaturatedFat: intOrNil("monounsaturatedFat"),
                    polyunsaturatedFat: intOrNil("polyunsaturatedFat"),
                    saturatedFat: intOrNil("saturatedFat"),
                    transFat: intOrNil("transFat"),
                    animalProtein: intOrNil("animalProtein"),
                    plantProtein: intOrNil("plantProtein"),
                    proteinSupplements: intOrNil("proteinSupplements"),
                    vitaminA: intOrNil("vitaminA"),
                    vitaminB: intOrNil("vitaminB"),
                    vitaminC: intOrNil("vitaminC"),
                    vitaminD: intOrNil("vitaminD"),
                    vitaminE: intOrNil("vitaminE"),
                    vitaminK: intOrNil("vitaminK"),
                    calcium: intOrNil("calcium"),
                    iron: intOrNil("iron"),
                    potassium: intOrNil("potassium"),
                    zinc: intOrNil("zinc"),
                    magnesium: intOrNil("magnesium")
                )
            }
            // Prefer DB result; fall back to bundled JSON if nil
            return entry ?? LocalBarcodeDB.lookup(code: code)
        } catch {
            // On any DB error, fall back to JSON
            return LocalBarcodeDB.lookup(code: code)
        }
        #else
        // If DuckDB is not available in this target, use the bundled JSON only.
        return LocalBarcodeDB.lookup(code: code)
        #endif
    }
}
