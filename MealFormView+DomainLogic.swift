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
import Vision
import CryptoKit

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
        // Clear transient barcode display on undo
        lastDetectedBarcode = nil
        // Keep the last wizardProgress as-is; user initiated an undo.
    }

    // MARK: - Analyze button logic

    func applyIfEmpty(_ source: inout String, with value: Int?, markGuess: inout Bool) {
        guard let v = value, source.isEmpty else { return }
        source = String(max(0, v))
        markGuess = true
    }

    // Overload for Double? (grams), preserving decimals with cleanString
    func applyIfEmpty(_ source: inout String, with value: Double?, markGuess: inout Bool) {
        guard let v = value, source.isEmpty else { return }
        source = max(0.0, v).cleanString
        markGuess = true
    }

    // Wrapper: SHA-256 of normalized OCR text -> hex string (for synthetic keys)
    private func sha256Hex(of text: String) -> String {
        let data = Data(text.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    // Wrap analyzePhoto() to manage snapshot and undo state
    func analyzePhotoWithSnapshot() async {
        #if DEBUG
        await LabelDiagnosticsStore.shared.appendEvent(.init(stage: .analyzeStart))
        #endif

        await MainActor.run {
            isAnalyzing = true
            analyzeError = nil
            wizardProgress = "Detecting barcode…"
            forceEnableSave = false
        }

        // Obtain image to analyze
        let image: UIImage? = {
            guard selectedIndex < galleryItems.count else { return nil }
            switch galleryItems[selectedIndex] {
            case .persistent(_, let url, _):
                if let data = try? Data(contentsOf: url) { return UIImage(data: data) }
                return nil
            case .inMemory(_, let img, _, _, _):
                return img
            }
        }()

        guard let baseImage = image else {
            #if DEBUG
            await LabelDiagnosticsStore.shared.appendEvent(.init(stage: .analyzeError, message: "No image"))
            #endif
            await MainActor.run {
                analyzeError = "No image"
                wizardProgress = nil
                isAnalyzing = false
            }
            return
        }

        #if DEBUG
        await LabelDiagnosticsStore.shared.appendEvent(.init(stage: .imagePrepared))
        #endif

        // 1) Try barcode on rotations; if found, apply via repository (local DB + OFF)
        var appliedFromBarcode = false
        var detectedCode: String?
        var sawUnreadableBarcode = false
        do {
            let variants = PhotoNutritionGuesser.rotationVariants(of: baseImage)
            let degrees = [0, 90, 180, 270]
            for (idx, img) in variants.enumerated() {
                #if DEBUG
                await LabelDiagnosticsStore.shared.appendEvent(.init(stage: .rotationAttempt, rotationDegrees: (idx < degrees.count ? degrees[idx] : 0)))
                #endif
                // First, quick decode attempt
                if let code = await PhotoNutritionGuesser.detectFirstBarcode(in: img) {
                    detectedCode = code
                    #if DEBUG
                    await LabelDiagnosticsStore.shared.appendEvent(.init(stage: .barcodeDecoded, code: code))
                    #endif
                    await MainActor.run {
                        lastDetectedBarcode = code
                        wizardProgress = "Barcode: \(code)"
                    }
                    if let meal = self.meal {
                        // Apply to Core Data meal via repository, which also hits OFF
                        await BarcodeRepository.shared.handleScannedBarcode(
                            code,
                            for: meal,
                            in: context,
                            sodiumUnit: sodiumUnit,
                            vitaminsUnit: vitaminsUnit,
                            logger: { msg in
                                #if DEBUG
                                self.appendWizardLog(msg)
                                #endif
                                Task { @MainActor in
                                    self.wizardProgress = msg
                                }
                            }
                        )
                        // Reflect updated Core Data values into the form if fields are empty
                        await MainActor.run {
                            // Calories
                            if calories.isEmpty, meal.calories > 0 {
                                calories = Int(meal.calories).description
                                caloriesIsGuess = false
                            }
                            // Grams
                            if carbohydrates.isEmpty, meal.carbohydrates > 0 { carbohydrates = meal.carbohydrates.cleanString; carbohydratesIsGuess = false }
                            if protein.isEmpty, meal.protein > 0 { protein = meal.protein.cleanString; proteinIsGuess = false }
                            if fat.isEmpty, meal.fat > 0 { fat = meal.fat.cleanString; fatIsGuess = false }

                            // Sodium (UI unit)
                            if sodium.isEmpty, meal.sodium > 0 {
                                if sodiumUnit == .milligrams {
                                    sodium = Int(meal.sodium).description
                                } else {
                                    sodium = (meal.sodium / 1000.0).cleanString
                                }
                                sodiumIsGuess = false
                            }

                            // Sub-macros
                            if sugars.isEmpty, meal.sugars > 0 { sugars = meal.sugars.cleanString; sugarsIsGuess = false }
                            if starch.isEmpty, meal.starch > 0 { starch = meal.starch.cleanString; starchIsGuess = false }
                            if fibre.isEmpty, meal.fibre > 0 { fibre = meal.fibre.cleanString; fibreIsGuess = false }

                            // Fat breakdown
                            if monounsaturatedFat.isEmpty, meal.monounsaturatedFat > 0 { monounsaturatedFat = meal.monounsaturatedFat.cleanString; monounsaturatedFatIsGuess = false }
                            if polyunsaturatedFat.isEmpty, meal.polyunsaturatedFat > 0 { polyunsaturatedFat = meal.polyunsaturatedFat.cleanString; polyunsaturatedFatIsGuess = false }
                            if saturatedFat.isEmpty, meal.saturatedFat > 0 { saturatedFat = meal.saturatedFat.cleanString; saturatedFatIsGuess = false }
                            if transFat.isEmpty, meal.transFat > 0 { transFat = meal.transFat.cleanString; transFatIsGuess = false }

                            // Vitamins/minerals in UI units
                            func toUIVitamin(_ mg: Double) -> String {
                                // Use the same logic as mgToUIText in Media file
                                switch vitaminsUnit {
                                case .milligrams:
                                    let nf = NumberFormatter()
                                    nf.locale = Locale.current
                                    nf.minimumFractionDigits = 0
                                    nf.maximumFractionDigits = 3
                                    nf.minimumIntegerDigits = 1
                                    return nf.string(from: NSNumber(value: mg)) ?? mg.cleanString
                                case .micrograms:
                                    return Int((mg * 1000.0).rounded()).description
                                }
                            }
                            if vitaminA.isEmpty, meal.vitaminA > 0 { vitaminA = toUIVitamin(meal.vitaminA); vitaminAIsGuess = false }
                            if vitaminB.isEmpty, meal.vitaminB > 0 { vitaminB = toUIVitamin(meal.vitaminB); vitaminBIsGuess = false }
                            if vitaminC.isEmpty, meal.vitaminC > 0 { vitaminC = toUIVitamin(meal.vitaminC); vitaminCIsGuess = false }
                            if vitaminD.isEmpty, meal.vitaminD > 0 { vitaminD = toUIVitamin(meal.vitaminD); vitaminDIsGuess = false }
                            if vitaminE.isEmpty, meal.vitaminE > 0 { vitaminE = toUIVitamin(meal.vitaminE); vitaminEIsGuess = false }
                            if vitaminK.isEmpty, meal.vitaminK > 0 { vitaminK = toUIVitamin(meal.vitaminK); vitaminKIsGuess = false }

                            // Minerals: keep Int for mg-based ones; potassium is Double mg -> preserve decimals
                            if calcium.isEmpty, meal.calcium > 0 { calcium = toUIVitamin(meal.calcium); calciumIsGuess = false }
                            if iron.isEmpty, meal.iron > 0 { iron = toUIVitamin(meal.iron); ironIsGuess = false }
                            if potassium.isEmpty, meal.potassium > 0 { potassium = toUIVitamin(meal.potassium); potassiumIsGuess = false }
                            if zinc.isEmpty, meal.zinc > 0 { zinc = toUIVitamin(meal.zinc); zincIsGuess = false }
                            if magnesium.isEmpty, meal.magnesium > 0 { magnesium = toUIVitamin(meal.magnesium); magnesiumIsGuess = false }

                            recomputeConsistency(resetPrevMismatch: false)
                            forceEnableSave = true
                        }
                        #if DEBUG
                        await LabelDiagnosticsStore.shared.appendEvent(.init(stage: .applyToForm, fieldsFilled: []))
                        #endif
                        appliedFromBarcode = true
                    }
                    break
                } else {
                    // No decoded payload; check if barcode-like regions are present but unreadable
                    let presence = await PhotoNutritionGuesser.probeBarcodePresence(in: img)
                    if case .presentButUnreadable = presence {
                        sawUnreadableBarcode = true
                        #if DEBUG
                        await LabelDiagnosticsStore.shared.appendEvent(.init(stage: .barcodeUnreadable))
                        #endif
                    } else if case .none = presence {
                        #if DEBUG
                        await LabelDiagnosticsStore.shared.appendEvent(.init(stage: .barcodeNone))
                        #endif
                    }
                }
            }
        }

        // If we saw an unreadable barcode on any rotation but never decoded one, inform the user now.
        if !appliedFromBarcode && sawUnreadableBarcode {
            await MainActor.run {
                // Short, actionable hint shown in the existing status overlay
                wizardProgress = "Barcode not readable. Fill the frame, steady the camera, and try better lighting."
            }
        }

        // 2) OCR if nothing applied yet, or to complement missing fields
        await MainActor.run { wizardProgress = appliedFromBarcode ? wizardProgress : "Reading label…" }

        // For diagnostics, try both OCR passes explicitly to capture timing/length
        if let text = await recognizeTextForWizard(in: baseImage, languageCode: appLanguageCode) {
            #if DEBUG
            // Include both the length and the full recognized text in the event so it shows in LabelDiagnosticsView.
            await LabelDiagnosticsStore.shared.appendEvent(.init(stage: .ocrFinished, textLength: text.count, message: text))
            #endif

            let parsed = PhotoNutritionGuesser.parseNutrition(from: text)
            #if DEBUG
            await LabelDiagnosticsStore.shared.appendEvent(.init(stage: .parseResult, parsedFieldCount: parsed.parsedFieldCount))
            #endif

            // NEW: Upsert parsed OCR text into DuckDB (barcodes table)
            Task.detached {
                // Build a deterministic key: prefer detected barcode, else OCR hash
                let key: String = {
                    if let code = detectedCode, !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return code.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "")
                    } else {
                        // Normalize the OCR text a little for stability before hashing
                        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        let hash = self.sha256Hex(of: normalized)
                        return "ocr:\(hash)"
                    }
                }()

                #if DEBUG
                await LabelDiagnosticsStore.shared.appendEvent(.init(stage: .ocrUpsertAttempt, upsertKey: key))
                #endif

                // Map GuessResult -> LocalBarcodeDB.Entry
                let entry = LocalBarcodeDB.Entry(
                    code: key,
                    calories: parsed.calories,
                    carbohydrates: parsed.carbohydrates,
                    protein: parsed.protein,
                    fat: parsed.fat,
                    sodiumMg: parsed.sodiumMg,
                    sugars: parsed.sugars,
                    starch: parsed.starch,
                    fibre: parsed.fibre,
                    monounsaturatedFat: parsed.monounsaturatedFat,
                    polyunsaturatedFat: parsed.polyunsaturatedFat,
                    saturatedFat: parsed.saturatedFat,
                    transFat: parsed.transFat,
                    animalProtein: parsed.animalProtein,
                    plantProtein: parsed.plantProtein,
                    proteinSupplements: parsed.proteinSupplements,
                    vitaminA: parsed.vitaminA,
                    vitaminB: parsed.vitaminB,
                    vitaminC: parsed.vitaminC,
                    vitaminD: parsed.vitaminD,
                    vitaminE: parsed.vitaminE,
                    vitaminK: parsed.vitaminK,
                    calcium: parsed.calcium,
                    iron: parsed.iron,
                    potassium: parsed.potassium,
                    zinc: parsed.zinc,
                    magnesium: parsed.magnesium
                )

                do {
                    try await BarcodeRepository.shared.upsert(entry: entry)
                    #if DEBUG
                    await LabelDiagnosticsStore.shared.appendEvent(.init(stage: .ocrUpsertSuccess, upsertKey: key))
                    #endif
                    await MainActor.run {
                        #if DEBUG
                        self.appendWizardLog("OCR upserted to DuckDB with key \(key)")
                        #endif
                        if self.wizardProgress == nil || self.wizardProgress?.isEmpty == true {
                            self.wizardProgress = "Saved OCR to DB"
                        }
                    }
                } catch {
                    #if DEBUG
                    await LabelDiagnosticsStore.shared.appendEvent(.init(stage: .ocrUpsertFailure, upsertKey: key, message: error.localizedDescription))
                    #endif
                    await MainActor.run {
                        #if DEBUG
                        self.appendWizardLog("OCR upsert failed: \(error.localizedDescription)")
                        #endif
                        // Don’t surface as fatal; continue filling the form.
                    }
                }
            }

            // Apply empty-only fields from parsed result
            await MainActor.run {
                var filled: [String] = []

                // calories (kcal)
                let beforeCalories = calories
                applyIfEmpty(&calories, with: parsed.calories, markGuess: &caloriesIsGuess)
                if calories != beforeCalories { filled.append("calories") }

                // grams
                let bCarb = carbohydrates
                applyIfEmpty(&carbohydrates, with: parsed.carbohydrates, markGuess: &carbohydratesIsGuess)
                if carbohydrates != bCarb { filled.append("carbohydrates") }

                let bProt = protein
                applyIfEmpty(&protein, with: parsed.protein, markGuess: &proteinIsGuess)
                if protein != bProt { filled.append("protein") }

                let bFat = fat
                applyIfEmpty(&fat, with: parsed.fat, markGuess: &fatIsGuess)
                if fat != bFat { filled.append("fat") }

                // sodium UI: parsed.sodiumMg is mg
                let bSodium = sodium
                if sodium.isEmpty, let mg = parsed.sodiumMg {
                    if sodiumUnit == .milligrams {
                        sodium = String(max(0, mg))
                    } else {
                        // convert mg -> g (rounded to preserve decimals)
                        sodium = (Double(mg) / 1000.0).cleanString
                    }
                    sodiumIsGuess = true
                }
                if sodium != bSodium { filled.append("sodium") }

                // sub-macros (grams)
                let bSug = sugars
                applyIfEmpty(&sugars, with: parsed.sugars, markGuess: &sugarsIsGuess)
                if sugars != bSug { filled.append("sugars") }

                let bSta = starch
                applyIfEmpty(&starch, with: parsed.starch, markGuess: &starchIsGuess)
                if starch != bSta { filled.append("starch") }

                let bFib = fibre
                applyIfEmpty(&fibre, with: parsed.fibre, markGuess: &fibreIsGuess)
                if fibre != bFib { filled.append("fibre") }

                // fat breakdown (grams)
                let bMono = monounsaturatedFat
                applyIfEmpty(&monounsaturatedFat, with: parsed.monounsaturatedFat, markGuess: &monounsaturatedFatIsGuess)
                if monounsaturatedFat != bMono { filled.append("monounsaturatedFat") }

                let bPoly = polyunsaturatedFat
                applyIfEmpty(&polyunsaturatedFat, with: parsed.polyunsaturatedFat, markGuess: &polyunsaturatedFatIsGuess)
                if polyunsaturatedFat != bPoly { filled.append("polyunsaturatedFat") }

                let bSat = saturatedFat
                applyIfEmpty(&saturatedFat, with: parsed.saturatedFat, markGuess: &saturatedFatIsGuess)
                if saturatedFat != bSat { filled.append("saturatedFat") }

                let bTrans = transFat
                applyIfEmpty(&transFat, with: parsed.transFat, markGuess: &transFatIsGuess)
                if transFat != bTrans { filled.append("transFat") }

                // protein breakdown (grams)
                let bAni = animalProtein
                applyIfEmpty(&animalProtein, with: parsed.animalProtein, markGuess: &animalProteinIsGuess)
                if animalProtein != bAni { filled.append("animalProtein") }

                let bPlant = plantProtein
                applyIfEmpty(&plantProtein, with: parsed.plantProtein, markGuess: &plantProteinIsGuess)
                if plantProtein != bPlant { filled.append("plantProtein") }

                let bSupp = proteinSupplements
                applyIfEmpty(&proteinSupplements, with: parsed.proteinSupplements, markGuess: &proteinSupplementsIsGuess)
                if proteinSupplements != bSupp { filled.append("proteinSupplements") }

                func setVitaminUI(_ target: inout String, _ valueMg: Double?, _ flag: inout Bool, name: String) {
                    let before = target
                    guard target.isEmpty, let mg = valueMg else { return }
                    switch vitaminsUnit {
                    case .milligrams:
                        let nf = NumberFormatter()
                        nf.locale = Locale.current
                        nf.minimumFractionDigits = 0
                        nf.maximumFractionDigits = 3
                        nf.minimumIntegerDigits = 1
                        target = nf.string(from: NSNumber(value: mg)) ?? mg.cleanString
                    case .micrograms:
                        target = String(max(0, Int((mg * 1000.0).rounded())))
                    }
                    flag = true
                    if target != before { filled.append(name) }
                }
                setVitaminUI(&vitaminA, parsed.vitaminA, &vitaminAIsGuess, name: "vitaminA")
                setVitaminUI(&vitaminB, parsed.vitaminB, &vitaminBIsGuess, name: "vitaminB")
                setVitaminUI(&vitaminC, parsed.vitaminC, &vitaminCIsGuess, name: "vitaminC")
                setVitaminUI(&vitaminD, parsed.vitaminD, &vitaminDIsGuess, name: "vitaminD")
                setVitaminUI(&vitaminE, parsed.vitaminE, &vitaminEIsGuess, name: "vitaminE")
                setVitaminUI(&vitaminK, parsed.vitaminK, &vitaminKIsGuess, name: "vitaminK")

                func setMineralUIInt(_ target: inout String, _ valueMg: Int?, _ flag: inout Bool, name: String) {
                    let before = target
                    guard target.isEmpty, let mg = valueMg else { return }
                    switch vitaminsUnit {
                    case .milligrams:
                        target = String(max(0, mg))
                    case .micrograms:
                        target = String(max(0, mg * 1000))
                    }
                    flag = true
                    if target != before { filled.append(name) }
                }
                func setMineralUIDouble(_ target: inout String, _ valueMg: Double?, _ flag: inout Bool, name: String) {
                    let before = target
                    guard target.isEmpty, let mg = valueMg else { return }
                    switch vitaminsUnit {
                    case .milligrams:
                        let nf = NumberFormatter()
                        nf.locale = Locale.current
                        nf.minimumFractionDigits = 0
                        nf.maximumFractionDigits = 3
                        nf.minimumIntegerDigits = 1
                        target = nf.string(from: NSNumber(value: mg)) ?? mg.cleanString
                    case .micrograms:
                        target = String(max(0, Int((mg * 1000.0).rounded())))
                    }
                    flag = true
                    if target != before { filled.append(name) }
                }

                setMineralUIInt(&calcium, parsed.calcium, &calciumIsGuess, name: "calcium")
                setMineralUIInt(&iron, parsed.iron, &ironIsGuess, name: "iron")
                setMineralUIDouble(&potassium, parsed.potassium, &potassiumIsGuess, name: "potassium")
                setMineralUIInt(&zinc, parsed.zinc, &zincIsGuess, name: "zinc")
                setMineralUIInt(&magnesium, parsed.magnesium, &magnesiumIsGuess, name: "magnesium")

                recomputeConsistency(resetPrevMismatch: false)

                #if DEBUG
                Task { await LabelDiagnosticsStore.shared.appendEvent(.init(stage: .applyToForm, fieldsFilled: filled)) }
                #endif
            }
        }

        await MainActor.run {
            if appliedFromBarcode {
                wizardProgress = "Applied from barcode"
            } else if sawUnreadableBarcode {
                if wizardProgress == nil || wizardProgress?.isEmpty == true {
                    wizardProgress = "Barcode not readable."
                }
            } else {
                wizardProgress = "Analysis complete"
            }
            isAnalyzing = false
            forceEnableSave = true
        }

        #if DEBUG
        await LabelDiagnosticsStore.shared.appendEvent(.init(stage: .analyzeComplete))
        #endif
    }

    // MARK: - Consistency and helper text

    // Recompute mismatch flags and helper texts for macro groups.
    // If resetPrevMismatch is true, prevCarbsMismatch/prevProteinMismatch/prevFatMismatch are reset to current mismatch states.
    func recomputeConsistency(resetPrevMismatch: Bool) {
        func parseDouble(_ s: String) -> Double {
            Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        }

        // Carbs
        let carbsTop = parseDouble(carbohydrates)
        let carbsSum = parseDouble(sugars) + parseDouble(starch) + parseDouble(fibre)
        carbsMismatch = (carbsTop > 0 || carbsSum > 0) && abs(carbsTop - carbsSum) > 0.01
        carbsHelperText = carbsSum > 0 ? carbsSum.cleanString : ""
        carbsHelperVisible = carbsSum > 0

        // Protein
        let proteinTop = parseDouble(protein)
        let proteinSum = parseDouble(animalProtein) + parseDouble(plantProtein) + parseDouble(proteinSupplements)
        proteinMismatch = (proteinTop > 0 || proteinSum > 0) && abs(proteinTop - proteinSum) > 0.01
        proteinHelperText = proteinSum > 0 ? proteinSum.cleanString : ""
        proteinHelperVisible = proteinSum > 0

        // Fat
        let fatTop = parseDouble(fat)
        let fatSum = parseDouble(monounsaturatedFat) + parseDouble(polyunsaturatedFat) + parseDouble(saturatedFat) + parseDouble(transFat)
        fatMismatch = (fatTop > 0 || fatSum > 0) && abs(fatTop - fatSum) > 0.01
        fatHelperText = fatSum > 0 ? fatSum.cleanString : ""
        fatHelperVisible = fatSum > 0

        if resetPrevMismatch {
            prevCarbsMismatch = carbsMismatch
            prevProteinMismatch = proteinMismatch
            prevFatMismatch = fatMismatch
        }
    }

    // Blink green underline once when a mismatch transitions from true -> false
    func recomputeConsistencyAndBlinkIfFixed() {
        let oldCarbs = carbsMismatch
        let oldProtein = proteinMismatch
        let oldFat = fatMismatch

        recomputeConsistency(resetPrevMismatch: false)

        if oldCarbs && !carbsMismatch {
            carbsBlink = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { carbsBlink = false }
        }
        if oldProtein && !proteinMismatch {
            proteinBlink = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { proteinBlink = false }
        }
        if oldFat && !fatMismatch {
            fatBlink = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { fatBlink = false }
        }

        // Track previous for other logic if needed
        prevCarbsMismatch = carbsMismatch
        prevProteinMismatch = proteinMismatch
        prevFatMismatch = fatMismatch
    }

    // MARK: - OCR wrapper used by wizard

    // Wrapper that uses PhotoNutritionGuesser’s OCR dual-pass with preprocessing and rotations.
    func recognizeTextForWizard(in image: UIImage, languageCode: String?) async -> String? {
        // Reuse PhotoNutritionGuesser OCR pipeline to keep preprocessing and language hints consistent.
        // Build rotation variants and pick the longest recognized text among them.
        let variants = PhotoNutritionGuesser.rotationVariants(of: image)
        var best: String?
        for img in variants {
            let ocrReady = img // PhotoNutritionGuesser.recognizeTextDualPass does its own preprocessing
            if let text = await withUnsafeContinuation({ (cont: UnsafeContinuation<String?, Never>) in
                Task {
                    let t = await PhotoNutritionGuesser.recognizeTextDualPass(in: ocrReady, languageCode: languageCode)
                    cont.resume(returning: t)
                }
            }) {
                if let current = best {
                    if text.count > current.count { best = text }
                } else {
                    best = text
                }
            }
        }
        return best
    }

    // MARK: - UI interaction helpers for macro groups (missing symbols fix)

    private func parseDouble(_ s: String) -> Double {
        Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0.0
    }

    // Called when any carb subfield changes
    func handleTopFromCarbSubs() {
        let sum = parseDouble(sugars) + parseDouble(starch) + parseDouble(fibre)
        carbsHelperText = sum > 0 ? sum.cleanString : ""
        carbsHelperVisible = sum > 0

        // If top is empty or matches the last auto-sum we set, keep auto-updating it.
        let top = parseDouble(carbohydrates)
        if carbohydrates.isEmpty || (carbsLastAutoSum != nil && top == Double(carbsLastAutoSum!)) {
            carbohydrates = sum.cleanString
            carbsLastAutoSum = Int(round(sum))
        }

        // Red blink if subfields have values but top is empty at edit time
        carbsRedBlink = (sum > 0 && carbohydrates.isEmpty)

        recomputeConsistencyAndBlinkIfFixed()
    }

    // Called when user submits/changes the top carbs field (to reconcile helper)
    func handleHelperOnTopChangeForCarbs() {
        let sum = parseDouble(sugars) + parseDouble(starch) + parseDouble(fibre)
        let top = parseDouble(carbohydrates)

        // Hide helper if reconciled; otherwise keep it to guide user
        carbsHelperVisible = sum > 0 && abs(sum - top) > 0.01
        carbsHelperText = sum > 0 ? sum.cleanString : ""

        // If user entered a manual top different from auto-sum, stop auto-updating
        carbsLastAutoSum = nil

        // Clear red blink if user filled the top
        if !carbohydrates.isEmpty { carbsRedBlink = false }

        recomputeConsistencyAndBlinkIfFixed()
    }

    // Protein subfields change
    func handleTopFromProteinSubs() {
        let sum = parseDouble(animalProtein) + parseDouble(plantProtein) + parseDouble(proteinSupplements)
        proteinHelperText = sum > 0 ? sum.cleanString : ""
        proteinHelperVisible = sum > 0

        let top = parseDouble(protein)
        if protein.isEmpty || (proteinLastAutoSum != nil && top == Double(proteinLastAutoSum!)) {
            protein = sum.cleanString
            proteinLastAutoSum = Int(round(sum))
        }

        proteinRedBlink = (sum > 0 && protein.isEmpty)

        recomputeConsistencyAndBlinkIfFixed()
    }

    func handleHelperOnTopChangeForProtein() {
        let sum = parseDouble(animalProtein) + parseDouble(plantProtein) + parseDouble(proteinSupplements)
        let top = parseDouble(protein)

        proteinHelperVisible = sum > 0 && abs(sum - top) > 0.01
        proteinHelperText = sum > 0 ? sum.cleanString : ""

        proteinLastAutoSum = nil

        if !protein.isEmpty { proteinRedBlink = false }

        recomputeConsistencyAndBlinkIfFixed()
    }

    // Fat subfields change
    func handleTopFromFatSubs() {
        let sum = parseDouble(monounsaturatedFat) + parseDouble(polyunsaturatedFat) + parseDouble(saturatedFat) + parseDouble(transFat)
        fatHelperText = sum > 0 ? sum.cleanString : ""
        fatHelperVisible = sum > 0

        let top = parseDouble(fat)
        if fat.isEmpty || (fatLastAutoSum != nil && top == Double(fatLastAutoSum!)) {
            fat = sum.cleanString
            fatLastAutoSum = Int(round(sum))
        }

        fatRedBlink = (sum > 0 && fat.isEmpty)

        recomputeConsistencyAndBlinkIfFixed()
    }

    func handleHelperOnTopChangeForFat() {
        let sum = parseDouble(monounsaturatedFat) + parseDouble(polyunsaturatedFat) + parseDouble(saturatedFat) + parseDouble(transFat)
        let top = parseDouble(fat)

        fatHelperVisible = sum > 0 && abs(sum - top) > 0.01
        fatHelperText = sum > 0 ? sum.cleanString : ""

        fatLastAutoSum = nil

        if !fat.isEmpty { fatRedBlink = false }

        recomputeConsistencyAndBlinkIfFixed()
    }

    // Called when leaving a focused field to finalize helper/red-blink states
    func handleFocusLeaveIfNeeded(leaving: FocusedField) {
        switch leaving {
        case .carbsTotal:
            handleHelperOnTopChangeForCarbs()
        case .proteinTotal:
            handleHelperOnTopChangeForProtein()
        case .fatTotal:
            handleHelperOnTopChangeForFat()
        default:
            break
        }
    }

    // ... rest of the file remains unchanged ...
}

