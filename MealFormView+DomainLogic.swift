//
//  MealFormView+DomainLogic.swift
//  MealTracker
//
//  Extracted wizard/analysis/validation/saving/consistency/autofill/utilities from MealFormView+Logic.swift
//

import SwiftUI
import CoreData
import CoreLocation
import UIKit
import AVFoundation

extension MealFormView {

    // Snapshot of wizard-editable fields and flags for undo
    struct WizardSnapshot {
        let calories: String
        let carbohydrates: String
        let protein: String
        let sodium: String
        let fat: String

        let alcohol: String
        let nicotine: String
        let theobromine: String
        let caffeine: String
        let taurine: String

        let starch: String
        let sugars: String
        let fibre: String

        let monounsaturatedFat: String
        let polyunsaturatedFat: String
        let saturatedFat: String
        let transFat: String
        let omega3: String
        let omega6: String

        let animalProtein: String
        let plantProtein: String
        let proteinSupplements: String

        let vitaminA: String
        let vitaminB: String
        let vitaminC: String
        let vitaminD: String
        let vitaminE: String
        let vitaminK: String

        let calcium: String
        let iron: String
        let potassium: String
        let zinc: String
        let magnesium: String

        // Guess flags
        let caloriesIsGuess: Bool
        let carbohydratesIsGuess: Bool
        let proteinIsGuess: Bool
        let sodiumIsGuess: Bool
        let fatIsGuess: Bool

        let alcoholIsGuess: Bool
        let nicotineIsGuess: Bool
        let theobromineIsGuess: Bool
        let caffeineIsGuess: Bool
        let taurineIsGuess: Bool

        let starchIsGuess: Bool
        let sugarsIsGuess: Bool
        let fibreIsGuess: Bool

        let monounsaturatedFatIsGuess: Bool
        let polyunsaturatedFatIsGuess: Bool
        let saturatedFatIsGuess: Bool
        let transFatIsGuess: Bool
        let omega3IsGuess: Bool
        let omega6IsGuess: Bool

        let animalProteinIsGuess: Bool
        let plantProteinIsGuess: Bool
        let proteinSupplementsIsGuess: Bool

        let vitaminAIsGuess: Bool
        let vitaminBIsGuess: Bool
        let vitaminCIsGuess: Bool
        let vitaminDIsGuess: Bool
        let vitaminEIsGuess: Bool
        let vitaminKIsGuess: Bool

        let calciumIsGuess: Bool
        let ironIsGuess: Bool
        let potassiumIsGuess: Bool
        let zincIsGuess: Bool
        let magnesiumIsGuess: Bool
    }

    private func captureSnapshotForWizard() -> WizardSnapshot {
        WizardSnapshot(
            calories: calories,
            carbohydrates: carbohydrates,
            protein: protein,
            sodium: sodium,
            fat: fat,
            alcohol: alcohol,
            nicotine: nicotine,
            theobromine: theobromine,
            caffeine: caffeine,
            taurine: taurine,
            starch: starch,
            sugars: sugars,
            fibre: fibre,
            monounsaturatedFat: monounsaturatedFat,
            polyunsaturatedFat: polyunsaturatedFat,
            saturatedFat: saturatedFat,
            transFat: transFat,
            omega3: omega3,
            omega6: omega6,
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
            magnesium: magnesium,
            caloriesIsGuess: caloriesIsGuess,
            carbohydratesIsGuess: carbohydratesIsGuess,
            proteinIsGuess: proteinIsGuess,
            sodiumIsGuess: sodiumIsGuess,
            fatIsGuess: fatIsGuess,
            alcoholIsGuess: alcoholIsGuess,
            nicotineIsGuess: nicotineIsGuess,
            theobromineIsGuess: theobromineIsGuess,
            caffeineIsGuess: caffeineIsGuess,
            taurineIsGuess: taurineIsGuess,
            starchIsGuess: starchIsGuess,
            sugarsIsGuess: sugarsIsGuess,
            fibreIsGuess: fibreIsGuess,
            monounsaturatedFatIsGuess: monounsaturatedFatIsGuess,
            polyunsaturatedFatIsGuess: polyunsaturatedFatIsGuess,
            saturatedFatIsGuess: saturatedFatIsGuess,
            transFatIsGuess: transFatIsGuess,
            omega3IsGuess: omega3IsGuess,
            omega6IsGuess: omega6IsGuess,
            animalProteinIsGuess: animalProteinIsGuess,
            plantProteinIsGuess: plantProteinIsGuess,
            proteinSupplementsIsGuess: proteinSupplementsIsGuess,
            vitaminAIsGuess: vitaminAIsGuess,
            vitaminBIsGuess: vitaminBIsGuess,
            vitaminCIsGuess: vitaminCIsGuess,
            vitaminDIsGuess: vitaminDIsGuess,
            vitaminEIsGuess: vitaminEIsGuess,
            vitaminKIsGuess: vitaminKIsGuess,
            calciumIsGuess: calciumIsGuess,
            ironIsGuess: ironIsGuess,
            potassiumIsGuess: potassiumIsGuess,
            zincIsGuess: zincIsGuess,
            magnesiumIsGuess: magnesiumIsGuess
        )
    }

    private func restoreSnapshotForWizard(_ s: WizardSnapshot) {
        calories = s.calories
        carbohydrates = s.carbohydrates
        protein = s.protein
        sodium = s.sodium
        fat = s.fat

        alcohol = s.alcohol
        nicotine = s.nicotine
        theobromine = s.theobromine
        caffeine = s.caffeine
        taurine = s.taurine

        starch = s.starch
        sugars = s.sugars
        fibre = s.fibre

        monounsaturatedFat = s.monounsaturatedFat
        polyunsaturatedFat = s.polyunsaturatedFat
        saturatedFat = s.saturatedFat
        transFat = s.transFat
        omega3 = s.omega3
        omega6 = s.omega6

        animalProtein = s.animalProtein
        plantProtein = s.plantProtein
        proteinSupplements = s.proteinSupplements

        vitaminA = s.vitaminA
        vitaminB = s.vitaminB
        vitaminC = s.vitaminC
        vitaminD = s.vitaminD
        vitaminE = s.vitaminE
        vitaminK = s.vitaminK

        calcium = s.calcium
        iron = s.iron
        potassium = s.potassium
        zinc = s.zinc
        magnesium = s.magnesium

        caloriesIsGuess = s.caloriesIsGuess
        carbohydratesIsGuess = s.carbohydratesIsGuess
        proteinIsGuess = s.proteinIsGuess
        sodiumIsGuess = s.sodiumIsGuess
        fatIsGuess = s.fatIsGuess

        alcoholIsGuess = s.alcoholIsGuess
        nicotineIsGuess = s.nicotineIsGuess
        theobromineIsGuess = s.theobromineIsGuess
        caffeineIsGuess = s.caffeineIsGuess
        taurineIsGuess = s.taurineIsGuess

        starchIsGuess = s.starchIsGuess
        sugarsIsGuess = s.sugarsIsGuess
        fibreIsGuess = s.fibreIsGuess

        monounsaturatedFatIsGuess = s.monounsaturatedFatIsGuess
        polyunsaturatedFatIsGuess = s.polyunsaturatedFatIsGuess
        saturatedFatIsGuess = s.saturatedFatIsGuess
        transFatIsGuess = s.transFatIsGuess
        omega3IsGuess = s.omega3IsGuess
        omega6IsGuess = s.omega6IsGuess

        animalProteinIsGuess = s.animalProteinIsGuess
        plantProteinIsGuess = s.plantProteinIsGuess
        proteinSupplementsIsGuess = s.proteinSupplementsIsGuess

        vitaminAIsGuess = s.vitaminAIsGuess
        vitaminBIsGuess = s.vitaminBIsGuess
        vitaminCIsGuess = s.vitaminCIsGuess
        vitaminDIsGuess = s.vitaminDIsGuess
        vitaminEIsGuess = s.vitaminEIsGuess
        vitaminKIsGuess = s.vitaminKIsGuess

        calciumIsGuess = s.calciumIsGuess
        ironIsGuess = s.ironIsGuess
        potassiumIsGuess = s.potassiumIsGuess
        zincIsGuess = s.zincIsGuess
        magnesiumIsGuess = s.magnesiumIsGuess

        // Recompute consistency after restore
        recomputeConsistency(resetPrevMismatch: true)
    }

    func undoWizard() {
        guard let snap = wizardUndoSnapshot else { return }
        restoreSnapshotForWizard(snap)
        wizardUndoSnapshot = nil
        wizardCanUndo = false
        analyzeError = nil
        forceEnableSave = false
    }

    // MARK: - Analyze button logic

    func applyIfEmpty(_ source: inout String, with value: Int?, markGuess: inout Bool) {
        guard let v = value, source.isEmpty else { return }
        source = String(max(0, v))
        markGuess = true
    }

    // Wrap analyzePhoto() to manage snapshot and undo state
    func analyzePhotoWithSnapshot() async {
        // If undo is active, ignore to avoid stacking
        guard !wizardCanUndo else { return }
        // Make sure we have a photo selected
        guard selectedIndex < galleryItems.count else { return }

        // Capture snapshot before we mutate any field
        await MainActor.run {
            wizardUndoSnapshot = captureSnapshotForWizard()
        }

        // Run analysis
        await analyzePhoto()

        // If there was an error or nothing changed, do not enable undo
        let enableUndo: Bool = await MainActor.run {
            // Heuristic: enable if at least one field differs from snapshot
            guard let snap = wizardUndoSnapshot else { return false }
            let changed =
                calories != snap.calories ||
                carbohydrates != snap.carbohydrates ||
                protein != snap.protein ||
                sodium != snap.sodium ||
                fat != snap.fat ||
                sugars != snap.sugars ||
                starch != snap.starch ||
                fibre != snap.fibre ||
                monounsaturatedFat != snap.monounsaturatedFat ||
                polyunsaturatedFat != snap.polyunsaturatedFat ||
                saturatedFat != snap.saturatedFat ||
                transFat != snap.transFat ||
                vitaminA != snap.vitaminA ||
                vitaminB != snap.vitaminB ||
                vitaminC != snap.vitaminC ||
                vitaminD != snap.vitaminD ||
                vitaminE != snap.vitaminE ||
                vitaminK != snap.vitaminK ||
                calcium != snap.calcium ||
                iron != snap.iron ||
                potassium != snap.potassium ||
                zinc != snap.zinc ||
                magnesium != snap.magnesium
            return changed && analyzeError == nil
        }

        await MainActor.run {
            wizardCanUndo = enableUndo
            if !enableUndo {
                // Drop snapshot if nothing to undo
                wizardUndoSnapshot = nil
            }
        }
    }

    func analyzePhoto() async {
        if await MainActor.run(resultType: Bool.self, body: { isAnalyzing }) { return }

        let imageData: Data? = {
            guard selectedIndex < galleryItems.count else { return nil }
            switch galleryItems[selectedIndex] {
            case .persistent(_, let url, _):
                return try? Data(contentsOf: url)
            case .inMemory(_, _, let data, _, _):
                return data
            }
        }()

        guard let data = imageData else { return }

        await MainActor.run { isAnalyzing = true }
        defer { Task { await MainActor.run { isAnalyzing = false } } }

        // Helper to set the guesser tag and persist immediately
        @MainActor
        func tagMealGuesser(_ tag: String) {
            let m = ensureMealForPhoto()
            m.photoGuesserType = tag
            try? context.save()
        }

        do {
            // First: try barcode path with DB -> OFF, then return early if anything applied
            if let image = UIImage(data: data) {
                let variants = [image] + [PhotoNutritionGuesser.rotationVariants(of: image)].flatMap { $0 }
                for img in variants {
                    if let code = await PhotoNutritionGuesser.detectFirstBarcode(in: img) {
                        let targetMeal = ensureMealForPhoto()
                        await BarcodeRepository.shared.handleScannedBarcode(
                            code,
                            for: targetMeal,
                            in: context,
                            sodiumUnit: sodiumUnit,
                            vitaminsUnit: vitaminsUnit
                        )
                        // Record method used
                        await MainActor.run {
                            targetMeal.photoGuesserType = "barcode"
                            try? context.save()
                        }
                        // We applied authoritative values; refresh the form fields from Core Data object to show them
                        await MainActor.run {
                            // Reload visible text fields for any newly populated values (fill empty-only)
                            // Only update fields that remain empty in UI to avoid clobbering user edits-in-progress.
                            if calories.isEmpty { calories = Int(targetMeal.calories).description }
                            if carbohydrates.isEmpty { carbohydrates = targetMeal.carbohydrates.cleanString }
                            if protein.isEmpty { protein = targetMeal.protein.cleanString }
                            if fat.isEmpty { fat = targetMeal.fat.cleanString }

                            if sodium.isEmpty {
                                switch sodiumUnit {
                                case .milligrams: sodium = Int(targetMeal.sodium).description
                                case .grams: sodium = (targetMeal.sodium / 1000.0).cleanString
                                }
                            }

                            func fillVM(_ field: inout String, from mg: Double) {
                                guard field.isEmpty else { return }
                                switch vitaminsUnit {
                                case .milligrams: field = Int(mg).description
                                case .micrograms: field = Int((mg * 1000.0).rounded()).description
                                }
                            }
                            fillVM(&vitaminA, from: targetMeal.vitaminA)
                            fillVM(&vitaminB, from: targetMeal.vitaminB)
                            fillVM(&vitaminC, from: targetMeal.vitaminC)
                            fillVM(&vitaminD, from: targetMeal.vitaminD)
                            fillVM(&vitaminE, from: targetMeal.vitaminE)
                            fillVM(&vitaminK, from: targetMeal.vitaminK)

                            fillVM(&calcium, from: targetMeal.calcium)
                            fillVM(&iron, from: targetMeal.iron)
                            fillVM(&potassium, from: targetMeal.potassium)
                            fillVM(&zinc, from: targetMeal.zinc)
                            fillVM(&magnesium, from: targetMeal.magnesium)

                            if sugars.isEmpty { sugars = targetMeal.sugars.cleanString }
                            if starch.isEmpty { starch = targetMeal.starch.cleanString }
                            if fibre.isEmpty { fibre = targetMeal.fibre.cleanString }

                            if monounsaturatedFat.isEmpty { monounsaturatedFat = targetMeal.monounsaturatedFat.cleanString }
                            if polyunsaturatedFat.isEmpty { polyunsaturatedFat = targetMeal.polyunsaturatedFat.cleanString }
                            if saturatedFat.isEmpty { saturatedFat = targetMeal.saturatedFat.cleanString }
                            if transFat.isEmpty { transFat = targetMeal.transFat.cleanString }
                        }

                        // After applying authoritative data, stop further analysis.
                        return
                    }
                }
            }

            // If no barcode path succeeded, fall back to the original pipeline
            if let result = try await PhotoNutritionGuesser.guess(from: data, languageCode: appLanguageCode) {
                await MainActor.run {
                    if calories.isEmpty, let kcal = result.calories {
                        let uiVal: Int
                        switch energyUnit {
                        case .calories:
                            uiVal = kcal
                        case .kilojoules:
                            uiVal = Int((Double(kcal) * 4.184).rounded())
                        }
                        calories = String(max(0, uiVal))
                        caloriesIsGuess = true
                    }

                    // grams-based fields can be Ints from guesser; keep as strings
                    func setGIfEmpty(_ field: inout String, _ guessFlag: inout Bool, from v: Int?) {
                        guard field.isEmpty, let v else { return }
                        field = String(v)
                        guessFlag = true
                    }
                    setGIfEmpty(&carbohydrates, &carbohydratesIsGuess, from: result.carbohydrates)
                    setGIfEmpty(&protein, &proteinIsGuess, from: result.protein)
                    setGIfEmpty(&fat, &fatIsGuess, from: result.fat)

                    if sodium.isEmpty, let mg = result.sodiumMg {
                        let uiVal: Int
                        switch sodiumUnit {
                        case .milligrams:
                            uiVal = mg
                        case .grams:
                            uiVal = Int((Double(mg) / 1000.0).rounded())
                        }
                        sodium = String(max(0, uiVal))
                        sodiumIsGuess = true
                    }

                    setGIfEmpty(&sugars, &sugarsIsGuess, from: result.sugars)
                    sugarsTouched = sugarsTouched || !sugars.isEmpty
                    setGIfEmpty(&starch, &starchIsGuess, from: result.starch)
                    starchTouched = starchTouched || !starch.isEmpty
                    setGIfEmpty(&fibre, &fibreIsGuess, from: result.fibre)
                    fibreTouched = fibreTouched || !fibre.isEmpty

                    setGIfEmpty(&monounsaturatedFat, &monounsaturatedFatIsGuess, from: result.monounsaturatedFat)
                    monoTouched = monoTouched || !monounsaturatedFat.isEmpty
                    setGIfEmpty(&polyunsaturatedFat, &polyunsaturatedFatIsGuess, from: result.polyunsaturatedFat)
                    polyTouched = polyTouched || !polyunsaturatedFat.isEmpty
                    setGIfEmpty(&saturatedFat, &saturatedFatIsGuess, from: result.saturatedFat)
                    satTouched = satTouched || !saturatedFat.isEmpty
                    setGIfEmpty(&transFat, &transFatIsGuess, from: result.transFat)
                    transTouched = transTouched || !transFat.isEmpty

                    setGIfEmpty(&animalProtein, &animalProteinIsGuess, from: result.animalProtein)
                    animalTouched = animalTouched || !animalProtein.isEmpty
                    setGIfEmpty(&plantProtein, &plantProteinIsGuess, from: result.plantProtein)
                    plantTouched = plantTouched || !plantProtein.isEmpty
                    setGIfEmpty(&proteinSupplements, &proteinSupplementsIsGuess, from: result.proteinSupplements)
                    supplementsTouched = supplementsTouched || !proteinSupplements.isEmpty

                    func applyVitaminMineral(_ field: inout String, _ guessFlag: inout Bool, mg: Int?) {
                        guard field.isEmpty, let mg else { return }
                        let uiVal: Int
                        switch vitaminsUnit {
                        case .milligrams: uiVal = mg
                        case .micrograms: uiVal = Int(Double(mg) * 1000.0)
                        }
                        field = String(max(0, uiVal))
                        guessFlag = true
                    }
                    applyVitaminMineral(&vitaminA, &vitaminAIsGuess, mg: result.vitaminA)
                    applyVitaminMineral(&vitaminB, &vitaminBIsGuess, mg: result.vitaminB)
                    applyVitaminMineral(&vitaminC, &vitaminCIsGuess, mg: result.vitaminC)
                    applyVitaminMineral(&vitaminD, &vitaminDIsGuess, mg: result.vitaminD)
                    applyVitaminMineral(&vitaminE, &vitaminEIsGuess, mg: result.vitaminE)
                    applyVitaminMineral(&vitaminK, &vitaminKIsGuess, mg: result.vitaminK)

                    applyVitaminMineral(&calcium, &calciumIsGuess, mg: result.calcium)
                    applyVitaminMineral(&iron, &ironIsGuess, mg: result.iron)
                    applyVitaminMineral(&potassium, &potassiumIsGuess, mg: result.potassium)
                    applyVitaminMineral(&zinc, &zincIsGuess, mg: result.zinc)
                    applyVitaminMineral(&magnesium, &magnesiumIsGuess, mg: result.magnesium)

                    if !(carbohydrates.isEmpty), sugars.isEmpty || starch.isEmpty || fibre.isEmpty {
                        autofillCarbSubfieldsIfNeeded()
                    }
                    if !(protein.isEmpty), animalProtein.isEmpty || plantProtein.isEmpty || proteinSupplements.isEmpty {
                        autofillProteinSubfieldsIfNeeded()
                    }
                    if !(fat.isEmpty), monounsaturatedFat.isEmpty || polyunsaturatedFat.isEmpty || saturatedFat.isEmpty || transFat.isEmpty {
                        autofillFatSubfieldsIfNeeded()
                    }

                    recomputeConsistencyAndBlinkIfFixed()
                    forceEnableSave = true
                }

                // Decide which tag to record
                await MainActor.run {
                    let m = ensureMealForPhoto()
                    let lookedLikeOCR =
                        result.sodiumMg != nil ||
                        result.vitaminA != nil || result.vitaminB != nil || result.vitaminC != nil ||
                        result.vitaminD != nil || result.vitaminE != nil || result.vitaminK != nil ||
                        result.calcium != nil || result.iron != nil || result.potassium != nil ||
                        result.zinc != nil || result.magnesium != nil
                    if lookedLikeOCR {
                        m.photoGuesserType = "ocr"
                    } else {
                        let macrosPresent = (result.carbohydrates != nil) || (result.protein != nil) || (result.fat != nil) || (result.calories != nil)
                        m.photoGuesserType = macrosPresent ? "featureprint" : "visual"
                    }
                    try? context.save()
                }

                return
            }

            // If PhotoNutritionGuesser.guess returned nil, nothing was detected. Do not set a tag.
        } catch {
            await MainActor.run { analyzeError = "Analysis failed: \(error)" }
        }
    }

    // MARK: - Validation

    var isValid: Bool {
        guard let cal = Int(calories), cal > 0 else { return false }
        // Grams fields should accept Double; mg/µg remain Int.
        // calories handled above.
        // sodium: if grams -> Double; if mg -> Int (but UI restricts to Int anyway).
        func isEmptyOrPositiveDouble(_ s: String) -> Bool {
            guard !s.isEmpty else { return true }
            let v = Double(s.replacingOccurrences(of: ",", with: ".")) ?? -1
            return v > 0
        }
        func isEmptyOrPositiveInt(_ s: String) -> Bool {
            guard !s.isEmpty else { return true }
            return (Int(s) ?? -1) > 0
        }

        // grams-based
        let gramsFields = [carbohydrates, protein, fat, sugars, starch, fibre, monounsaturatedFat, polyunsaturatedFat, saturatedFat, transFat, omega3, omega6, alcohol, animalProtein, plantProtein, proteinSupplements]
        guard gramsFields.allSatisfy(isEmptyOrPositiveDouble) else { return false }

        // sodium depends on unit
        if sodiumUnit == .grams {
            guard isEmptyOrPositiveDouble(sodium) else { return false }
        } else {
            guard isEmptyOrPositiveInt(sodium) else { return false }
        }

        // mg-based stimulants
        let mgFields = [nicotine, theobromine, caffeine, taurine, vitaminA, vitaminB, vitaminC, vitaminD, vitaminE, vitaminK, calcium, iron, potassium, zinc, magnesium]
        guard mgFields.allSatisfy(isEmptyOrPositiveInt) else { return false }

        return true
    }

    func intOrZero(_ text: String) -> Int {
        max(0, Int(text) ?? 0)
    }

    func doubleOrZero(_ text: String) -> Double {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        return max(0, Double(normalized) ?? 0)
    }

    func defaultTitle(using date: Date) -> String {
        if !mealDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return mealDescription
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Meal on \(formatter.string(from: date))"
    }

    // MARK: - Saving

    func save() {
        if meal == nil {
            let tier = Entitlements.tier(for: session)
            let maxPerDay = Entitlements.maxMealsPerDay(for: tier)
            if maxPerDay < 9000 {
                let todaysCount = Entitlements.mealsRecordedToday(in: context)
                if todaysCount >= maxPerDay {
                    limitErrorMessage = "Free tier allows up to \(maxPerDay) meals per day."
                    showingLimitAlert = true
                    return
                }
            }
        }

        guard let calInt = Int(calories), calInt > 0 else { return }

        let object: Meal = meal ?? Meal(context: context)
        if meal == nil {
            object.id = UUID()
            object.date = Date()
        }

        let trimmedTitle = mealDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            object.title = Meal.autoTitle(for: object.date)
        } else {
            object.title = trimmedTitle
        }

        let kcal: Double = {
            if energyUnit == .calories {
                return Double(intOrZero(calories))
            } else {
                return (Double(intOrZero(calories)) / 4.184).rounded()
            }
        }()
        object.calories = max(0, kcal)

        // Grams fields as Double
        object.carbohydrates = doubleOrZero(carbohydrates)
        object.protein = doubleOrZero(protein)
        object.fat = doubleOrZero(fat)
        object.alcohol = doubleOrZero(alcohol)

        // mg stimulants
        object.nicotine = Double(intOrZero(nicotine))
        object.theobromine = Double(intOrZero(theobromine))
        object.caffeine = Double(intOrZero(caffeine))
        object.taurine = Double(intOrZero(taurine))

        let sodiumMg: Double = {
            if sodiumUnit == .milligrams {
                return Double(intOrZero(sodium))
            } else {
                return doubleOrZero(sodium) * 1000.0
            }
        }()
        object.sodium = max(0, sodiumMg)

        object.starch = doubleOrZero(starch)
        object.sugars = doubleOrZero(sugars)
        object.fibre = doubleOrZero(fibre)

        object.monounsaturatedFat = doubleOrZero(monounsaturatedFat)
        object.polyunsaturatedFat = doubleOrZero(polyunsaturatedFat)
        object.saturatedFat = doubleOrZero(saturatedFat)
        object.transFat = doubleOrZero(transFat)
        object.omega3 = doubleOrZero(omega3)
        object.omega6 = doubleOrZero(omega6)

        object.animalProtein = doubleOrZero(animalProtein)
        object.plantProtein = doubleOrZero(plantProtein)
        object.proteinSupplements = doubleOrZero(proteinSupplements)

        func uiToMG(_ text: String) -> Double {
            let v = Double(intOrZero(text))
            switch vitaminsUnit {
                case .milligrams: return v
                case .micrograms: return v / 1000.0
            }
        }
        object.vitaminA = uiToMG(vitaminA)
        object.vitaminB = uiToMG(vitaminB)
        object.vitaminC = uiToMG(vitaminC)
        object.vitaminD = uiToMG(vitaminD)
        object.vitaminE = uiToMG(vitaminE)
        object.vitaminK = uiToMG(vitaminK)

        object.calcium = uiToMG(calcium)
        object.iron = uiToMG(iron)
        object.potassium = uiToMG(potassium)
        object.zinc = uiToMG(zinc)
        object.magnesium = uiToMG(magnesium)

        object.caloriesIsGuess = caloriesIsGuess
        object.carbohydratesIsGuess = carbohydratesIsGuess
        object.proteinIsGuess = proteinIsGuess
        object.sodiumIsGuess = sodiumIsGuess
        object.fatIsGuess = fatIsGuess
        object.alcoholIsGuess = alcoholIsGuess
        object.nicotineIsGuess = nicotineIsGuess
        object.theobromineIsGuess = theobromineIsGuess
        object.caffeineIsGuess = caffeineIsGuess
        object.taurineIsGuess = taurineIsGuess
        object.starchIsGuess = starchIsGuess
        object.sugarsIsGuess = sugarsIsGuess
        object.fibreIsGuess = fibreIsGuess
        object.monounsaturatedFatIsGuess = monounsaturatedFatIsGuess
        object.polyunsaturatedFatIsGuess = polyunsaturatedFatIsGuess
        object.saturatedFatIsGuess = saturatedFatIsGuess
        object.transFatIsGuess = transFatIsGuess
        object.omega3IsGuess = omega3IsGuess
        object.omega6IsGuess = omega6IsGuess

        object.animalProteinIsGuess = animalProteinIsGuess
        object.plantProteinIsGuess = plantProteinIsGuess
        object.proteinSupplementsIsGuess = proteinSupplementsIsGuess

        object.vitaminAIsGuess = vitaminAIsGuess
        object.vitaminBIsGuess = vitaminBIsGuess
        object.vitaminCIsGuess = vitaminCIsGuess
        object.vitaminDIsGuess = vitaminDIsGuess
        object.vitaminEIsGuess = vitaminEIsGuess
        object.vitaminKIsGuess = vitaminKIsGuess

        object.calciumIsGuess = calciumIsGuess
        object.ironIsGuess = ironIsGuess
        object.potassiumIsGuess = potassiumIsGuess
        object.zincIsGuess = zincIsGuess
        object.magnesiumIsGuess = magnesiumIsGuess

        do {
            try context.save()
            reloadGalleryItems()
            dismiss()
        } catch {
            print("Failed to save meal: \(error)")
        }
    }

    // MARK: - Input sanitation

    func numericBindingInt(_ source: Binding<String>) -> Binding<String> {
        Binding(
            get: { source.wrappedValue },
            set: { newValue in
                source.wrappedValue = sanitizeIntegerInput(newValue)
            }
        )
    }

    // New: decimal sanitizer for grams
    func numericBindingDecimal(_ source: Binding<String>) -> Binding<String> {
        Binding(
            get: { source.wrappedValue },
            set: { newValue in
                source.wrappedValue = sanitizeDecimalInput(newValue)
            }
        )
    }

    func sanitizeIntegerInput(_ input: String) -> String {
        let digitsOnly = input.compactMap { $0.isNumber ? $0 : nil }
        var s = String(digitsOnly)
        if s.isEmpty { return "" }
        while s.first == "0" && s.count > 1 { s.removeFirst() }
        if s == "0" { return "" }
        return s
    }

    func sanitizeDecimalInput(_ input: String) -> String {
        // Allow digits and a single decimal separator (dot or comma, normalize to dot)
        var result = ""
        var hasSeparator = false
        for ch in input {
            if ch.isNumber {
                result.append(ch)
            } else if ch == "." || ch == "," {
                if !hasSeparator {
                    hasSeparator = true
                    result.append(".")
                }
            }
        }
        // Trim leading zeros unless immediately followed by decimal
        if result.hasPrefix("0") && result.count > 1 && !result.hasPrefix("0.") {
            while result.first == "0" && result.count > 1 && !result.hasPrefix("0.") {
                result.removeFirst()
            }
        }
        // Disallow a lone "0"
        if result == "0" { return "" }
        return result
    }

    // MARK: - Consistency

    func recomputeConsistency(resetPrevMismatch: Bool = false) {
        let carbsTotal: Double = Double(carbohydrates.replacingOccurrences(of: ",", with: ".")) ?? 0
        let sugarsVal: Double = Double(sugars.replacingOccurrences(of: ",", with: ".")) ?? 0
        let starchVal: Double = Double(starch.replacingOccurrences(of: ",", with: ".")) ?? 0
        let fibreVal: Double = Double(fibre.replacingOccurrences(of: ",", with: ".")) ?? 0
        let carbsSubSum: Double = sugarsVal + starchVal + fibreVal
        let carbsHasAnySub: Bool = !(sugars.isEmpty && starch.isEmpty && fibre.isEmpty)
        let carbsHasTotal: Bool = !carbohydrates.isEmpty
        carbsMismatch = carbsHasTotal && carbsHasAnySub && (abs(carbsSubSum - carbsTotal) > 0.0001)

        let proteinTotal: Double = Double(protein.replacingOccurrences(of: ",", with: ".")) ?? 0
        let animalVal: Double = Double(animalProtein.replacingOccurrences(of: ",", with: ".")) ?? 0
        let plantVal: Double = Double(plantProtein.replacingOccurrences(of: ",", with: ".")) ?? 0
        let suppsVal: Double = Double(proteinSupplements.replacingOccurrences(of: ",", with: ".")) ?? 0
        let proteinSubSum: Double = animalVal + plantVal + suppsVal
        let proteinHasAnySub: Bool = !(animalProtein.isEmpty && plantProtein.isEmpty && proteinSupplements.isEmpty)
        let proteinHasTotal: Bool = !protein.isEmpty
        proteinMismatch = proteinHasTotal && proteinHasAnySub && (abs(proteinSubSum - proteinTotal) > 0.0001)

        let fatTotal: Double = Double(fat.replacingOccurrences(of: ",", with: ".")) ?? 0
        let monoVal: Double = Double(monounsaturatedFat.replacingOccurrences(of: ",", with: ".")) ?? 0
        let polyVal: Double = Double(polyunsaturatedFat.replacingOccurrences(of: ",", with: ".")) ?? 0
        let satVal: Double = Double(saturatedFat.replacingOccurrences(of: ",", with: ".")) ?? 0
        let transVal: Double = Double(transFat.replacingOccurrences(of: ",", with: ".")) ?? 0
        let fatSubSum: Double = monoVal + polyVal + satVal + transVal
        let fatHasAnySub: Bool = !(monounsaturatedFat.isEmpty && polyunsaturatedFat.isEmpty && saturatedFat.isEmpty && transFat.isEmpty)
        let fatHasTotal: Bool = !fat.isEmpty
        fatMismatch = fatHasTotal && fatHasAnySub && (abs(fatSubSum - fatTotal) > 0.0001)

        if resetPrevMismatch {
            prevCarbsMismatch = carbsMismatch
            prevProteinMismatch = proteinMismatch
            prevFatMismatch = fatMismatch
        }
    }

    func recomputeConsistencyAndBlinkIfFixed() {
        let oldCarbsMismatch = carbsMismatch
        let oldProteinMismatch = proteinMismatch
        let oldFatMismatch = fatMismatch

        recomputeConsistency()

        if oldCarbsMismatch && !carbsMismatch { flashGreenTwice(for: .carbs) }
        if oldProteinMismatch && !proteinMismatch { flashGreenTwice(for: .protein) }
        if oldFatMismatch && !fatMismatch { flashGreenTwice(for: .fat) }

        prevCarbsMismatch = carbsMismatch
        prevProteinMismatch = proteinMismatch
        prevFatMismatch = fatMismatch
    }

    enum GroupKind { case carbs, protein, fat }

    func flashGreenTwice(for group: GroupKind) {
        Task { @MainActor in
            func setBlink(_ active: Bool) {
                switch group {
                case .carbs: carbsBlink = active
                case .protein: proteinBlink = active
                case .fat: fatBlink = active
                }
            }
            for i in 0..<4 {
                setBlink(i % 2 == 0)
                try? await Task.sleep(nanoseconds: 180_000_000)
            }
            setBlink(false)
        }
    }

    func flashRedOnce(for group: GroupKind) {
        Task { @MainActor in
            func setRed(_ active: Bool) {
                switch group {
                case .carbs: carbsRedBlink = active
                case .protein: proteinRedBlink = active
                case .fat: fatRedBlink = active
                }
            }
            setRed(true)
            try? await Task.sleep(nanoseconds: 220_000_000)
            setRed(false)
        }
    }

    func showHelper(for group: GroupKind, sum: Double) {
        Task { @MainActor in
            let text = sum.cleanString
            switch group {
            case .carbs:
                carbsHelperText = text
                carbsHelperVisible = true
            case .protein:
                proteinHelperText = text
                proteinHelperVisible = true
            case .fat:
                fatHelperText = text
                fatHelperVisible = true
            }
            try? await Task.sleep(nanoseconds: 900_000_000)
            switch group {
            case .carbs: carbsHelperVisible = false
            case .protein: proteinHelperVisible = false
            case .fat: fatHelperVisible = false
            }
        }
    }

    // MARK: - Autofill

    func autofillCarbSubfieldsIfNeeded() {
        guard let total = Double(carbohydrates.replacingOccurrences(of: ",", with: ".")), total >= 0 else { return }
        if sugarsTouched && starchTouched && fibreTouched { return }
        let ratios: [Double] = [0.30, 0.60, 0.10]
        let parts = distributeDouble(total, ratios: ratios)
        if !sugarsTouched { sugars = parts[0].cleanString; sugarsIsGuess = true }
        if !starchTouched { starch = parts[1].cleanString; starchIsGuess = true }
        if !fibreTouched { fibre = parts[2].cleanString; fibreIsGuess = true }
    }

    func autofillFatSubfieldsIfNeeded() {
        guard let total = Double(fat.replacingOccurrences(of: ",", with: ".")), total >= 0 else { return }
        if monoTouched && polyTouched && satTouched && transTouched { return }
        let ratios: [Double] = [0.40, 0.30, 0.25, 0.05]
        let parts = distributeDouble(total, ratios: ratios)
        if !monoTouched { monounsaturatedFat = parts[0].cleanString; monounsaturatedFatIsGuess = true }
        if !polyTouched { polyunsaturatedFat = parts[1].cleanString; polyunsaturatedFatIsGuess = true }
        if !satTouched { saturatedFat = parts[2].cleanString; saturatedFatIsGuess = true }
        if !transTouched { transFat = parts[3].cleanString; transFatIsGuess = true }
    }

    func autofillProteinSubfieldsIfNeeded() {
        guard let total = Double(protein.replacingOccurrences(of: ",", with: ".")), total >= 0 else { return }
        if animalTouched && plantTouched && supplementsTouched { return }
        let ratios: [Double] = [0.50, 0.40, 0.10]
        let parts = distributeDouble(total, ratios: ratios)
        if !animalTouched { animalProtein = parts[0].cleanString; animalProteinIsGuess = true }
        if !plantTouched { plantProtein = parts[1].cleanString; plantProteinIsGuess = true }
        if !supplementsTouched { proteinSupplements = parts[2].cleanString; proteinSupplementsIsGuess = true }
    }

    // MARK: - Top-level updates from subfields

    func handleTopFromCarbSubs() {
        let hasAnySub = !(sugars.isEmpty && starch.isEmpty && fibre.isEmpty)
        guard hasAnySub else { return }
        let sugarsVal = Double(sugars.replacingOccurrences(of: ",", with: ".")) ?? 0
        let starchVal = Double(starch.replacingOccurrences(of: ",", with: ".")) ?? 0
        let fibreVal = Double(fibre.replacingOccurrences(of: ",", with: ".")) ?? 0
        let sum = sugarsVal + starchVal + fibreVal

        let currentTop = Double(carbohydrates.replacingOccurrences(of: ",", with: "."))
        let canAutoUpdate = (currentTop == nil) || (currentTop == Double(carbsLastAutoSum ?? -1))

        if canAutoUpdate {
            let wasEmpty = carbohydrates.isEmpty
            carbohydrates = sum.cleanString
            carbohydratesIsGuess = true
            carbsLastAutoSum = Int(sum.rounded())

            if wasEmpty {
                flashRedOnce(for: .carbs)
                showHelper(for: .carbs, sum: sum)
            }
        }
    }

    func handleTopFromProteinSubs() {
        let hasAnySub = !(animalProtein.isEmpty && plantProtein.isEmpty && proteinSupplements.isEmpty)
        guard hasAnySub else { return }
        let animalVal = Double(animalProtein.replacingOccurrences(of: ",", with: ".")) ?? 0
        let plantVal = Double(plantProtein.replacingOccurrences(of: ",", with: ".")) ?? 0
        let suppsVal = Double(proteinSupplements.replacingOccurrences(of: ",", with: ".")) ?? 0
        let sum = animalVal + plantVal + suppsVal

        let currentTop = Double(protein.replacingOccurrences(of: ",", with: "."))
        let canAutoUpdate = (currentTop == nil) || (currentTop == Double(proteinLastAutoSum ?? -1))

        if canAutoUpdate {
            let wasEmpty = protein.isEmpty
            protein = sum.cleanString
            proteinIsGuess = true
            proteinLastAutoSum = Int(sum.rounded())

            if wasEmpty {
                flashRedOnce(for: .protein)
                showHelper(for: .protein, sum: sum)
            }
        }
    }

    func handleTopFromFatSubs() {
        let hasAnySub = !(monounsaturatedFat.isEmpty && polyunsaturatedFat.isEmpty && saturatedFat.isEmpty && transFat.isEmpty)
        guard hasAnySub else { return }

        let monoVal = Double(monounsaturatedFat.replacingOccurrences(of: ",", with: ".")) ?? 0
        let polyVal = Double(polyunsaturatedFat.replacingOccurrences(of: ",", with: ".")) ?? 0
        let satVal = Double(saturatedFat.replacingOccurrences(of: ",", with: ".")) ?? 0
        let transVal = Double(transFat.replacingOccurrences(of: ",", with: ".")) ?? 0
        let sum = monoVal + polyVal + satVal + transVal

        let currentTop = Double(fat.replacingOccurrences(of: ",", with: "."))
        let canAutoUpdate = (currentTop == nil) || (currentTop == Double(fatLastAutoSum ?? -1))

        if canAutoUpdate {
            let wasEmpty = fat.isEmpty
            fat = sum.cleanString
            fatIsGuess = true
            fatLastAutoSum = Int(sum.rounded())

            if wasEmpty {
                flashRedOnce(for: .fat)
                showHelper(for: .fat, sum: sum)
            }
        }
    }

    // MARK: - Helper prompts

    func handleHelperForCarbs() {
        let total = Double(carbohydrates.replacingOccurrences(of: ",", with: ".")) ?? 0
        let sugarsVal = Double(sugars.replacingOccurrences(of: ",", with: ".")) ?? 0
        let starchVal = Double(starch.replacingOccurrences(of: ",", with: ".")) ?? 0
        let fibreVal = Double(fibre.replacingOccurrences(of: ",", with: ".")) ?? 0
        let sum = sugarsVal + starchVal + fibreVal
        let hasAnySub = !(sugars.isEmpty && starch.isEmpty && fibre.isEmpty)
        let hasTotal = !carbohydrates.isEmpty
        if hasAnySub && hasTotal && abs(sum - total) > 0.0001 {
            showHelper(for: .carbs, sum: sum)
            flashRedOnce(for: .carbs)
        }
    }

    func handleHelperForProtein() {
        let total = Double(protein.replacingOccurrences(of: ",", with: ".")) ?? 0
        let animalVal = Double(animalProtein.replacingOccurrences(of: ",", with: ".")) ?? 0
        let plantVal = Double(plantProtein.replacingOccurrences(of: ",", with: ".")) ?? 0
        let suppsVal = Double(proteinSupplements.replacingOccurrences(of: ",", with: ".")) ?? 0
        let sum = animalVal + plantVal + suppsVal
        let hasAnySub = !(animalProtein.isEmpty && plantProtein.isEmpty && proteinSupplements.isEmpty)
        let hasTotal = !protein.isEmpty
        if hasAnySub && hasTotal && abs(sum - total) > 0.0001 {
            showHelper(for: .protein, sum: sum)
            flashRedOnce(for: .protein)
        }
    }

    func handleHelperForFat() {
        let total = Double(fat.replacingOccurrences(of: ",", with: ".")) ?? 0
        let monoVal = Double(monounsaturatedFat.replacingOccurrences(of: ",", with: ".")) ?? 0
        let polyVal = Double(polyunsaturatedFat.replacingOccurrences(of: ",", with: ".")) ?? 0
        let satVal = Double(saturatedFat.replacingOccurrences(of: ",", with: ".")) ?? 0
        let transVal = Double(transFat.replacingOccurrences(of: ",", with: ".")) ?? 0
        let sum = monoVal + polyVal + satVal + transVal
        let hasAnySub = !(monounsaturatedFat.isEmpty && polyunsaturatedFat.isEmpty && saturatedFat.isEmpty && transFat.isEmpty)
        let hasTotal = !fat.isEmpty
        if hasAnySub && hasTotal && abs(sum - total) > 0.0001 {
            showHelper(for: .fat, sum: sum)
            flashRedOnce(for: .fat)
        }
    }

    func handleFocusLeaveIfNeeded(leaving field: FocusedField) {
        switch field {
        case .carbsTotal:
            recomputeConsistencyAndBlinkIfFixed()
            handleHelperOnTopChangeForCarbs()
        case .proteinTotal:
            recomputeConsistencyAndBlinkIfFixed()
            handleHelperOnTopChangeForProtein()
        case .fatTotal:
            recomputeConsistencyAndBlinkIfFixed()
            handleHelperOnTopChangeForFat()
        case .sodium:
            break
        case .calories:
            break
        }
    }

    func handleHelperOnTopChangeForCarbs() {
        let total = Double(carbohydrates.replacingOccurrences(of: ",", with: ".")) ?? 0
        let sugarsVal = Double(sugars.replacingOccurrences(of: ",", with: ".")) ?? 0
        let starchVal = Double(starch.replacingOccurrences(of: ",", with: ".")) ?? 0
        let fibreVal = Double(fibre.replacingOccurrences(of: ",", with: ".")) ?? 0
        let sum = sugarsVal + starchVal + fibreVal
        let hasAnySub = !(sugars.isEmpty && starch.isEmpty && fibre.isEmpty)
        let hasTotal = !carbohydrates.isEmpty
        if hasAnySub && hasTotal && abs(sum - total) > 0.0001 {
            showHelper(for: .carbs, sum: sum)
            flashRedOnce(for: .carbs)
        }
    }

    func handleHelperOnTopChangeForProtein() {
        let total = Double(protein.replacingOccurrences(of: ",", with: ".")) ?? 0
        let animalVal = Double(animalProtein.replacingOccurrences(of: ",", with: ".")) ?? 0
        let plantVal = Double(plantProtein.replacingOccurrences(of: ",", with: ".")) ?? 0
        let suppsVal = Double(proteinSupplements.replacingOccurrences(of: ",", with: ".")) ?? 0
        let sum = animalVal + plantVal + suppsVal
        let hasAnySub = !(animalProtein.isEmpty && plantProtein.isEmpty && proteinSupplements.isEmpty)
        let hasTotal = !protein.isEmpty
        if hasAnySub && hasTotal && abs(sum - total) > 0.0001 {
            showHelper(for: .protein, sum: sum)
            flashRedOnce(for: .protein)
        }
    }

    func handleHelperOnTopChangeForFat() {
        let total = Double(fat.replacingOccurrences(of: ",", with: ".")) ?? 0
        let monoVal = Double(monounsaturatedFat.replacingOccurrences(of: ",", with: ".")) ?? 0
        let polyVal = Double(polyunsaturatedFat.replacingOccurrences(of: ",", with: ".")) ?? 0
        let satVal = Double(saturatedFat.replacingOccurrences(of: ",", with: ".")) ?? 0
        let transVal = Double(transFat.replacingOccurrences(of: ",", with: ".")) ?? 0
        let sum = monoVal + polyVal + satVal + transVal
        let hasAnySub = !(monounsaturatedFat.isEmpty && polyunsaturatedFat.isEmpty && saturatedFat.isEmpty && transFat.isEmpty)
        let hasTotal = !fat.isEmpty
        if hasAnySub && hasTotal && abs(sum - total) > 0.0001 {
            showHelper(for: .fat, sum: sum)
            flashRedOnce(for: .fat)
        }
    }

    // MARK: - Utilities

    func distributeInt(_ total: Int, ratios: [Double]) -> [Int] {
        guard total >= 0, !ratios.isEmpty else { return Array(repeating: 0, count: max(1, ratios.count)) }
        let normalized = ratios.map { max(0.0, $0) }
        let sum = normalized.reduce(0, +)
        if sum == 0 { return Array(repeating: 0, count: ratios.count) }

        var parts = [Int]()
        var accumulated = 0
        for i in 0..<(ratios.count - 1) {
            let value = Int(floor(Double(total) * (normalized[i] / sum)))
            parts.append(value)
            accumulated += value
        }
        parts.append(max(0, total - accumulated))
        return parts
    }

    // New: Double distribution preserving decimals
    func distributeDouble(_ total: Double, ratios: [Double]) -> [Double] {
        guard total >= 0, !ratios.isEmpty else { return Array(repeating: 0, count: max(1, ratios.count)) }
        let normalized = ratios.map { max(0.0, $0) }
        let sum = normalized.reduce(0, +)
        if sum == 0 { return Array(repeating: 0, count: ratios.count) }

        var parts = [Double]()
        var accumulated = 0.0
        for i in 0..<(ratios.count - 1) {
            let value = (total * (normalized[i] / sum))
            parts.append(value)
            accumulated += value
        }
        parts.append(max(0, total - accumulated))
        return parts
    }
}
