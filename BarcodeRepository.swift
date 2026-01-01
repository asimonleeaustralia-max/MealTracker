//
//  BarcodeRepository.swift
//  MealTracker
//
//  DuckDB-backed repository for barcode -> nutrition lookups.
//  Emits structured barcode log events around normalization, local lookup, and upsert.
//

import Foundation
import CoreData

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
                guard rs.next() else { return nil }

                func intOrNil(_ name: String) -> Int? { rs.get(name) as Int? }
                func doubleOrNil(_ name: String) -> Double? { rs.get(name) as Double? }
                func stringOrNil(_ name: String) -> String? { rs.get(name) as String? }

                let codeVal = stringOrNil("code") ?? code

                return LocalBarcodeDB.Entry(
                    code: codeVal,
                    calories: intOrNil("calories"),
                    carbohydrates: doubleOrNil("carbohydrates"),
                    protein: doubleOrNil("protein"),
                    fat: doubleOrNil("fat"),
                    sodiumMg: intOrNil("sodiumMg"),
                    sugars: doubleOrNil("sugars"),
                    starch: doubleOrNil("starch"),
                    fibre: doubleOrNil("fibre"),
                    monounsaturatedFat: doubleOrNil("monounsaturatedFat"),
                    polyunsaturatedFat: doubleOrNil("polyunsaturatedFat"),
                    saturatedFat: doubleOrNil("saturatedFat"),
                    transFat: doubleOrNil("transFat"),
                    animalProtein: doubleOrNil("animalProtein"),
                    plantProtein: doubleOrNil("plantProtein"),
                    proteinSupplements: doubleOrNil("proteinSupplements"),
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

    // Upsert a barcode entry into DuckDB using INSERT ... ON CONFLICT DO UPDATE.
    func upsert(entry e: LocalBarcodeDB.Entry) async throws {
        #if DEBUG
        await BarcodeLogStore.shared.appendEvent(
            .init(stage: .upsertAttempt,
                  codeRaw: e.code,
                  codeNormalized: e.code,
                  entry: e)
        )
        #endif

        #if canImport(DuckDB)
        do {
            try await DuckDBManager.shared.withConnection { conn in
                let sql = """
                INSERT INTO barcodes (
                    code,
                    calories, carbohydrates, protein, fat, sodiumMg,
                    sugars, starch, fibre,
                    monounsaturatedFat, polyunsaturatedFat, saturatedFat, transFat,
                    animalProtein, plantProtein, proteinSupplements,
                    vitaminA, vitaminB, vitaminC, vitaminD, vitaminE, vitaminK,
                    calcium, iron, potassium, zinc, magnesium
                ) VALUES (
                    ?, ?, ?, ?, ?, ?,
                    ?, ?, ?,
                    ?, ?, ?, ?,
                    ?, ?, ?,
                    ?, ?, ?, ?, ?, ?,
                    ?, ?, ?, ?, ?
                )
                ON CONFLICT(code) DO UPDATE SET
                    calories = excluded.calories,
                    carbohydrates = excluded.carbohydrates,
                    protein = excluded.protein,
                    fat = excluded.fat,
                    sodiumMg = excluded.sodiumMg,
                    sugars = excluded.sugars,
                    starch = excluded.starch,
                    fibre = excluded.fibre,
                    monounsaturatedFat = excluded.monounsaturatedFat,
                    polyunsaturatedFat = excluded.polyunsaturatedFat,
                    saturatedFat = excluded.saturatedFat,
                    transFat = excluded.transFat,
                    animalProtein = excluded.animalProtein,
                    plantProtein = excluded.plantProtein,
                    proteinSupplements = excluded.proteinSupplements,
                    vitaminA = excluded.vitaminA,
                    vitaminB = excluded.vitaminB,
                    vitaminC = excluded.vitaminC,
                    vitaminD = excluded.vitaminD,
                    vitaminE = excluded.vitaminE,
                    vitaminK = excluded.vitaminK,
                    calcium = excluded.calcium,
                    iron = excluded.iron,
                    potassium = excluded.potassium,
                    zinc = excluded.zinc,
                    magnesium = excluded.magnesium;
                """
                _ = try conn.query(
                    sql,
                    e.code,
                    e.calories, e.carbohydrates, e.protein, e.fat, e.sodiumMg,
                    e.sugars, e.starch, e.fibre,
                    e.monounsaturatedFat, e.polyunsaturatedFat, e.saturatedFat, e.transFat,
                    e.animalProtein, e.plantProtein, e.proteinSupplements,
                    e.vitaminA, e.vitaminB, e.vitaminC, e.vitaminD, e.vitaminE, e.vitaminK,
                    e.calcium, e.iron, e.potassium, e.zinc, e.magnesium
                )
            }
            #if DEBUG
            await BarcodeLogStore.shared.appendEvent(
                .init(stage: .upsertSuccess, codeRaw: e.code, codeNormalized: e.code, entry: e)
            )
            #endif
        } catch {
            #if DEBUG
            await BarcodeLogStore.shared.appendEvent(
                .init(stage: .upsertFailure, codeRaw: e.code, codeNormalized: e.code, entry: e, error: error.localizedDescription)
            )
            #endif
            throw error
        }
        #else
        // No-op on targets without DuckDB
        return
        #endif
    }

    // High-level: handle a scanned barcode -> local DB -> OFF -> save to DB and apply to meal.
    // Added optional debug logger to surface API progress/errors to the wizard.
    func handleScannedBarcode(_ rawCode: String,
                              for meal: Meal,
                              in context: NSManagedObjectContext,
                              sodiumUnit: SodiumUnit,
                              vitaminsUnit: VitaminsUnit,
                              logger: ((String) -> Void)? = nil) async {
        let code = normalize(rawCode)

        #if DEBUG
        await BarcodeLogStore.shared.appendEvent(
            .init(stage: .normalizeCode, codeRaw: rawCode, codeNormalized: code)
        )
        #endif

        // 1) Local lookup
        if let local = await lookup(code: code) {
            let msg = "Local barcode DB hit for \(code)"
            logger?(msg)
            #if DEBUG
            await BarcodeLogStore.shared.appendEvent(
                .init(stage: .localLookupHit, codeRaw: rawCode, codeNormalized: code, entry: local)
            )
            #endif
            await MainActor.run {
                applyEntryToMealForm(entry: local, meal: meal, context: context, sodiumUnit: sodiumUnit, vitaminsUnit: vitaminsUnit)
            }
        } else {
            let msg = "Local barcode DB miss for \(code)"
            logger?(msg)
            #if DEBUG
            await BarcodeLogStore.shared.appendEvent(
                .init(stage: .localLookupMiss, codeRaw: rawCode, codeNormalized: code)
            )
            #endif
        }

        // 2) Open Food Facts
        do {
            let startMsg = "OFF: fetching product \(code)…"
            logger?(startMsg)

            let product = try await OpenFoodFactsClient.fetchProduct(by: code, logger: { s in
                logger?(s)
            })

            let foundMsg = "OFF: product found for \(code)"
            logger?(foundMsg)

            if let offEntry = OpenFoodFactsClient.mapToEntry(from: product) {
                let mapMsg = "OFF: mapped nutriments -> upserting and applying"
                logger?(mapMsg)
                // Upsert into DuckDB
                try? await upsert(entry: offEntry)
                // Apply to meal (fill empty-only)
                await MainActor.run {
                    applyEntryToMealForm(entry: offEntry, meal: meal, context: context, sodiumUnit: sodiumUnit, vitaminsUnit: vitaminsUnit)
                }
            } else {
                let noMapMsg = "OFF: mapping returned no usable nutriments"
                logger?(noMapMsg)
                #if DEBUG
                await BarcodeLogStore.shared.appendEvent(
                    .init(stage: .offMapStart, codeRaw: rawCode, codeNormalized: code, error: "No usable nutriments")
                )
                #endif
            }
        } catch {
            let errMsg = "OFF: error for \(code): \(error.localizedDescription)"
            logger?(errMsg)
            #if DEBUG
            await BarcodeLogStore.shared.appendEvent(
                .init(stage: .offDecodeError, codeRaw: rawCode, codeNormalized: code, error: errMsg)
            )
            #endif
        }
    }

    // Fill empty fields only, mark as accurate (guess=false), respect UI units for sodium/vitamins.
    @MainActor
    private func applyEntryToMealForm(entry: LocalBarcodeDB.Entry,
                                      meal: Meal,
                                      context: NSManagedObjectContext,
                                      sodiumUnit: SodiumUnit,
                                      vitaminsUnit: VitaminsUnit) {
        func fillDoubleIfZero(_ current: Double, with v: Double?) -> Double {
            guard current <= 0, let v else { return current }
            return max(0.0, v)
        }

        if meal.calories <= 0, let kcal = entry.calories {
            meal.calories = Double(max(0, kcal))
            meal.caloriesIsGuess = false
        }

        meal.carbohydrates = fillDoubleIfZero(meal.carbohydrates, with: entry.carbohydrates)
        if entry.carbohydrates != nil { meal.carbohydratesIsGuess = meal.carbohydratesIsGuess && meal.carbohydrates > 0 ? false : meal.carbohydratesIsGuess }

        meal.protein = fillDoubleIfZero(meal.protein, with: entry.protein)
        if entry.protein != nil { meal.proteinIsGuess = meal.proteinIsGuess && meal.protein > 0 ? false : meal.proteinIsGuess }

        meal.fat = fillDoubleIfZero(meal.fat, with: entry.fat)
        if entry.fat != nil { meal.fatIsGuess = meal.fatIsGuess && meal.fat > 0 ? false : meal.fatIsGuess }

        if meal.sodium <= 0, let mg = entry.sodiumMg {
            meal.sodium = Double(max(0, mg))
            meal.sodiumIsGuess = false
        }

        meal.sugars = fillDoubleIfZero(meal.sugars, with: entry.sugars)
        if entry.sugars != nil { meal.sugarsIsGuess = meal.sugarsIsGuess && meal.sugars > 0 ? false : meal.sugarsIsGuess }

        meal.starch = fillDoubleIfZero(meal.starch, with: entry.starch)
        if entry.starch != nil { meal.starchIsGuess = meal.starchIsGuess && meal.starch > 0 ? false : meal.starchIsGuess }

        meal.fibre = fillDoubleIfZero(meal.fibre, with: entry.fibre)
        if entry.fibre != nil { meal.fibreIsGuess = meal.fibreIsGuess && meal.fibre > 0 ? false : meal.fibreIsGuess }

        meal.monounsaturatedFat = fillDoubleIfZero(meal.monounsaturatedFat, with: entry.monounsaturatedFat)
        if entry.monounsaturatedFat != nil { meal.monounsaturatedFatIsGuess = meal.monounsaturatedFatIsGuess && meal.monounsaturatedFat > 0 ? false : meal.monounsaturatedFatIsGuess }

        meal.polyunsaturatedFat = fillDoubleIfZero(meal.polyunsaturatedFat, with: entry.polyunsaturatedFat)
        if entry.polyunsaturatedFat != nil { meal.polyunsaturatedFatIsGuess = meal.polyunsaturatedFatIsGuess && meal.polyunsaturatedFat > 0 ? false : meal.polyunsaturatedFatIsGuess }

        meal.saturatedFat = fillDoubleIfZero(meal.saturatedFat, with: entry.saturatedFat)
        if entry.saturatedFat != nil { meal.saturatedFatIsGuess = meal.saturatedFatIsGuess && meal.saturatedFat > 0 ? false : meal.saturatedFatIsGuess }

        meal.transFat = fillDoubleIfZero(meal.transFat, with: entry.transFat)
        if entry.transFat != nil { meal.transFatIsGuess = meal.transFatIsGuess && meal.transFat > 0 ? false : meal.transFatIsGuess }

        meal.animalProtein = fillDoubleIfZero(meal.animalProtein, with: entry.animalProtein)
        if entry.animalProtein != nil { meal.animalProteinIsGuess = meal.animalProteinIsGuess && meal.animalProtein > 0 ? false : meal.animalProteinIsGuess }

        meal.plantProtein = fillDoubleIfZero(meal.plantProtein, with: entry.plantProtein)
        if entry.plantProtein != nil { meal.plantProteinIsGuess = meal.plantProteinIsGuess && meal.plantProtein > 0 ? false : meal.plantProteinIsGuess }

        meal.proteinSupplements = fillDoubleIfZero(meal.proteinSupplements, with: entry.proteinSupplements)
        if entry.proteinSupplements != nil { meal.proteinSupplementsIsGuess = meal.proteinSupplementsIsGuess && meal.proteinSupplements > 0 ? false : meal.proteinSupplementsIsGuess }

        func fillVitaminMineral(_ current: Double, with mg: Int?) -> Double {
            guard current <= 0, let mg else { return current }
            return Double(max(0, mg))
        }

        meal.vitaminA = fillVitaminMineral(meal.vitaminA, with: entry.vitaminA)
        if entry.vitaminA != nil { meal.vitaminAIsGuess = meal.vitaminAIsGuess && meal.vitaminA > 0 ? false : meal.vitaminAIsGuess }

        meal.vitaminB = fillVitaminMineral(meal.vitaminB, with: entry.vitaminB)
        if entry.vitaminB != nil { meal.vitaminBIsGuess = meal.vitaminBIsGuess && meal.vitaminB > 0 ? false : meal.vitaminBIsGuess }

        meal.vitaminC = fillVitaminMineral(meal.vitaminC, with: entry.vitaminC)
        if entry.vitaminC != nil { meal.vitaminCIsGuess = meal.vitaminCIsGuess && meal.vitaminC > 0 ? false : meal.vitaminCIsGuess }

        meal.vitaminD = fillVitaminMineral(meal.vitaminD, with: entry.vitaminD)
        if entry.vitaminD != nil { meal.vitaminDIsGuess = meal.vitaminDIsGuess && meal.vitaminD > 0 ? false : meal.vitaminDIsGuess }

        meal.vitaminE = fillVitaminMineral(meal.vitaminE, with: entry.vitaminE)
        if entry.vitaminE != nil { meal.vitaminEIsGuess = meal.vitaminEIsGuess && meal.vitaminE > 0 ? false : meal.vitaminEIsGuess }

        meal.vitaminK = fillVitaminMineral(meal.vitaminK, with: entry.vitaminK)
        if entry.vitaminK != nil { meal.vitaminKIsGuess = meal.vitaminKIsGuess && meal.vitaminK > 0 ? false : meal.vitaminKIsGuess }

        meal.calcium = fillVitaminMineral(meal.calcium, with: entry.calcium)
        if entry.calcium != nil { meal.calciumIsGuess = meal.calciumIsGuess && meal.calcium > 0 ? false : meal.calciumIsGuess }

        meal.iron = fillVitaminMineral(meal.iron, with: entry.iron)
        if entry.iron != nil { meal.ironIsGuess = meal.ironIsGuess && meal.iron > 0 ? false : meal.ironIsGuess }

        meal.potassium = fillVitaminMineral(meal.potassium, with: entry.potassium)
        if entry.potassium != nil { meal.potassiumIsGuess = meal.potassiumIsGuess && meal.potassium > 0 ? false : meal.potassiumIsGuess }

        meal.zinc = fillVitaminMineral(meal.zinc, with: entry.zinc)
        if entry.zinc != nil { meal.zincIsGuess = meal.zincIsGuess && meal.zinc > 0 ? false : meal.zincIsGuess }

        meal.magnesium = fillVitaminMineral(meal.magnesium, with: entry.magnesium)
        if entry.magnesium != nil { meal.magnesiumIsGuess = meal.magnesiumIsGuess && meal.magnesium > 0 ? false : meal.magnesiumIsGuess }

        try? context.save()
    }
}

