//
//  MealFormView+Logic.swift
//  MealTracker
//
//  Created by Simon Lee on 17/11/2025.
//

import SwiftUI
import CoreData
import CoreLocation
import UIKit
import AVFoundation

extension MealFormView {

    // MARK: - Lifecycle wiring

    func onAppearSetup(l: LocalizationManager) {
        // Mark this home screen visible
        isHomeVisible = true

        // Build gallery items from Core Data or dev fallback
        reloadGalleryItems()

        if let meal = meal {
            // Initialize editable title from existing meal
            mealDescription = meal.title

            calories = Int(meal.calories).description
            carbohydrates = Int(meal.carbohydrates).description
            protein = Int(meal.protein).description
            sodium = Int(meal.sodium).description
            fat = Int(meal.fat).description
            alcohol = Int(meal.alcohol).description
            nicotine = Int(meal.nicotine).description
            theobromine = Int(meal.theobromine).description
            caffeine = Int(meal.caffeine).description
            taurine = Int(meal.taurine).description
            starch = Int(meal.starch).description
            sugars = Int(meal.sugars).description
            fibre = Int(meal.fibre).description
            monounsaturatedFat = Int(meal.monounsaturatedFat).description
            polyunsaturatedFat = Int(meal.polyunsaturatedFat).description
            saturatedFat = Int(meal.saturatedFat).description
            transFat = Int(meal.transFat).description
            omega3 = Int(meal.omega3).description
            omega6 = Int(meal.omega6).description
            animalProtein = Int(meal.animalProtein).description
            plantProtein = Int(meal.plantProtein).description
            proteinSupplements = Int(meal.proteinSupplements).description

            vitaminA = Int(vitaminsUnit.fromStorageMG(meal.vitaminA)).description
            vitaminB = Int(vitaminsUnit.fromStorageMG(meal.vitaminB)).description
            vitaminC = Int(vitaminsUnit.fromStorageMG(meal.vitaminC)).description
            vitaminD = Int(vitaminsUnit.fromStorageMG(meal.vitaminD)).description
            vitaminE = Int(vitaminsUnit.fromStorageMG(meal.vitaminE)).description
            vitaminK = Int(vitaminsUnit.fromStorageMG(meal.vitaminK)).description

            calcium = Int(vitaminsUnit.fromStorageMG(meal.calcium)).description
            iron = Int(vitaminsUnit.fromStorageMG(meal.iron)).description
            potassium = Int(vitaminsUnit.fromStorageMG(meal.potassium)).description
            zinc = Int(vitaminsUnit.fromStorageMG(meal.zinc)).description
            magnesium = Int(vitaminsUnit.fromStorageMG(meal.magnesium)).description

            date = meal.date

            caloriesIsGuess = meal.caloriesIsGuess
            carbohydratesIsGuess = meal.carbohydratesIsGuess
            proteinIsGuess = meal.proteinIsGuess
            sodiumIsGuess = meal.sodiumIsGuess
            fatIsGuess = meal.fatIsGuess
            alcoholIsGuess = meal.alcoholIsGuess
            nicotineIsGuess = meal.nicotineIsGuess
            theobromineIsGuess = meal.theobromineIsGuess
            caffeineIsGuess = meal.caffeineIsGuess
            taurineIsGuess = meal.taurineIsGuess
            starchIsGuess = meal.starchIsGuess
            sugarsIsGuess = meal.sugarsIsGuess
            fibreIsGuess = meal.fibreIsGuess
            monounsaturatedFatIsGuess = meal.monounsaturatedFatIsGuess
            polyunsaturatedFatIsGuess = meal.polyunsaturatedFatIsGuess
            saturatedFatIsGuess = meal.saturatedFatIsGuess
            transFatIsGuess = meal.transFatIsGuess
            omega3IsGuess = meal.omega3IsGuess
            omega6IsGuess = meal.omega6IsGuess

            animalProteinIsGuess = meal.animalProteinIsGuess
            plantProteinIsGuess = meal.plantProteinIsGuess
            proteinSupplementsIsGuess = meal.proteinSupplementsIsGuess

            vitaminAIsGuess = meal.vitaminAIsGuess
            vitaminBIsGuess = meal.vitaminBIsGuess
            vitaminCIsGuess = meal.vitaminCIsGuess
            vitaminDIsGuess = meal.vitaminDIsGuess
            vitaminEIsGuess = meal.vitaminEIsGuess
            vitaminKIsGuess = meal.vitaminKIsGuess

            calciumIsGuess = meal.calciumIsGuess
            ironIsGuess = meal.ironIsGuess
            potassiumIsGuess = meal.potassiumIsGuess
            zincIsGuess = meal.zincIsGuess
            magnesiumIsGuess = meal.magnesiumIsGuess

            sugarsTouched = !sugars.isEmpty
            starchTouched = !starch.isEmpty
            fibreTouched = !fibre.isEmpty
            monoTouched = !monounsaturatedFat.isEmpty
            polyTouched = !polyunsaturatedFat.isEmpty
            satTouched = !saturatedFat.isEmpty
            transTouched = !transFat.isEmpty
            omega3Touched = !omega3.isEmpty
            omega6Touched = !omega6.isEmpty
            animalTouched = !animalProtein.isEmpty
            plantTouched = !plantProtein.isEmpty
            supplementsTouched = !proteinSupplements.isEmpty

            func zeroToEmpty(_ s: String) -> String { s == "0" ? "" : s }

            carbohydrates = zeroToEmpty(carbohydrates)
            protein = zeroToEmpty(protein)
            sodium = zeroToEmpty(sodium)
            fat = zeroToEmpty(fat)
            alcohol = zeroToEmpty(alcohol)
            nicotine = zeroToEmpty(nicotine)
            theobromine = zeroToEmpty(theobromine)
            caffeine = zeroToEmpty(caffeine)
            taurine = zeroToEmpty(taurine)

            starch = zeroToEmpty(starch)
            sugars = zeroToEmpty(sugars)
            fibre = zeroToEmpty(fibre)

            monounsaturatedFat = zeroToEmpty(monounsaturatedFat)
            polyunsaturatedFat = zeroToEmpty(polyunsaturatedFat)
            saturatedFat = zeroToEmpty(saturatedFat)
            transFat = zeroToEmpty(transFat)
            omega3 = zeroToEmpty(omega3)
            omega6 = zeroToEmpty(omega6)

            animalProtein = zeroToEmpty(animalProtein)
            plantProtein = zeroToEmpty(plantProtein)
            proteinSupplements = zeroToEmpty(proteinSupplements)

            vitaminA = zeroToEmpty(vitaminA)
            vitaminB = zeroToEmpty(vitaminB)
            vitaminC = zeroToEmpty(vitaminC)
            vitaminD = zeroToEmpty(vitaminD)
            vitaminE = zeroToEmpty(vitaminE)
            vitaminK = zeroToEmpty(vitaminK)

            calcium = zeroToEmpty(calcium)
            iron = zeroToEmpty(iron)
            potassium = zeroToEmpty(potassium)
            zinc = zeroToEmpty(zinc)
            magnesium = zeroToEmpty(magnesium)

        } else {
            mealDescription = Meal.autoTitle(for: date)
        }

        locationManager.requestAuthorization()
        locationManager.startUpdating()

        recomputeConsistency(resetPrevMismatch: true)

        if scenePhase == .active {
            scheduleAutoOpenCameraIfNeeded()
        }
    }

    // MARK: - Camera handling

    func ensureMealForPhoto() -> Meal {
        if let m = meal {
            return m
        }
        let new = Meal(context: context)
        new.id = UUID()
        new.date = Date()
        new.title = Meal.autoTitle(for: new.date)
        try? context.save()
        self.meal = new
        return new
    }

    func handleCapturedPhoto(data: Data, suggestedExt: String?) async {
        let targetMeal = ensureMealForPhoto()
        let location = await MainActor.run { locationManager.lastLocation }
        do {
            let newPhoto = try await MainActor.run { () throws -> MealPhoto in
                try PhotoService.addPhoto(
                    from: data,
                    suggestedUTTypeExtension: suggestedExt,
                    to: targetMeal,
                    in: context,
                    session: session,
                    location: location
                )
            }

            await MainActor.run {
                if let url = PhotoService.urlForUpload(newPhoto) ?? PhotoService.urlForOriginal(newPhoto) {
                    _ = warmUpFileRead(url: url, retries: 2, delay: 0.08)
                }
                reloadGalleryItems()
                selectedIndex = max(0, galleryItems.count - 1)
            }
        } catch PhotoServiceError.freeTierPhotoLimitReached(let max) {
            await MainActor.run {
                limitErrorMessage = "Free tier allows up to \(max) photos per meal."
                showingLimitAlert = true
            }
        } catch {
            await MainActor.run {
                limitErrorMessage = "Failed to add photo: \(error.localizedDescription)"
                showingLimitAlert = true
            }
        }
    }

    func warmUpFileRead(url: URL, retries: Int, delay: TimeInterval) -> Bool {
        if (try? Data(contentsOf: url)) != nil { return true }
        var remaining = retries
        while remaining > 0 {
            remaining -= 1
            RunLoop.current.run(until: Date().addingTimeInterval(delay))
            if (try? Data(contentsOf: url)) != nil { return true }
        }
        return false
    }

    func scheduleAutoOpenCameraIfNeeded() {
        guard !didAutoOpenThisActivation else { return }
        guard isHomeVisible else { return }
        guard !explicitEditMode else { return }
        guard !showingCamera && !showingPhotoPicker && !showingSettings else { return }
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }

        didAutoOpenThisActivation = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            await presentCameraAfterPermission()
        }
    }

    @MainActor
    func presentCameraAfterPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            let granted = await requestCameraAccess()
            if granted {
                showingCamera = true
            } else {
                cameraPermissionMessage = "Camera access is required to take meal photos. You can enable it in Settings."
                showingCameraPermissionAlert = true
            }
        case .denied, .restricted:
            cameraPermissionMessage = "Camera access is disabled. Please enable it in Settings > Privacy > Camera."
            showingCameraPermissionAlert = true
        @unknown default:
            break
        }
    }

    func requestCameraAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - Deletion

    func deleteMeal() {
        guard let meal = meal else { return }

        if let set = meal.value(forKey: "photos") as? Set<MealPhoto>, !set.isEmpty {
            for photo in set {
                PhotoService.removePhoto(photo, in: context)
            }
        }

        context.delete(meal)

        do {
            try context.save()
            dismiss()
        } catch {
            print("Failed to delete meal: \(error)")
        }
    }

    // MARK: - Gallery composition

    func reloadGalleryItems() {
        var items: [GalleryItem] = []

        if let meal = meal {
            if let set = meal.value(forKey: "photos") as? Set<MealPhoto>, !set.isEmpty {
                let sorted = set.sorted { (a, b) in
                    let da = a.createdAt ?? .distantFuture
                    let db = b.createdAt ?? .distantFuture
                    return da < db
                }
                for p in sorted.prefix(maxPhotos) {
                    if let url = PhotoService.urlForUpload(p) ?? PhotoService.urlForOriginal(p) {
                        let version = fileVersionToken(for: url)
                        items.append(.persistent(photo: p, url: url, version: version))
                    }
                }
            }
        }

        self.galleryItems = items
        self.selectedIndex = min(self.selectedIndex, max(0, items.count - 1))
    }

    func fileVersionToken(for url: URL) -> String {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey]
        if let vals = try? url.resourceValues(forKeys: keys) {
            let ts = vals.contentModificationDate?.timeIntervalSince1970 ?? 0
            let size = (vals.fileSize ?? 0)
            return "\(ts)-\(size)"
        }
        return UUID().uuidString
    }

    // MARK: - Analyze button logic

    func applyIfEmpty(_ source: inout String, with value: Int?, markGuess: inout Bool) {
        guard let v = value, source.isEmpty else { return }
        source = String(max(0, v))
        markGuess = true
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
                        // We applied authoritative values; refresh the form fields from Core Data object to show them
                        await MainActor.run {
                            // Reload visible text fields for any newly populated values (fill empty-only)
                            // Only update fields that remain empty in UI to avoid clobbering user edits-in-progress.
                            if calories.isEmpty { calories = Int(targetMeal.calories).description }
                            if carbohydrates.isEmpty { carbohydrates = Int(targetMeal.carbohydrates).description }
                            if protein.isEmpty { protein = Int(targetMeal.protein).description }
                            if fat.isEmpty { fat = Int(targetMeal.fat).description }

                            if sodium.isEmpty {
                                switch sodiumUnit {
                                case .milligrams: sodium = Int(targetMeal.sodium).description
                                case .grams: sodium = Int((targetMeal.sodium / 1000.0).rounded()).description
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

                            if sugars.isEmpty { sugars = Int(targetMeal.sugars).description }
                            if starch.isEmpty { starch = Int(targetMeal.starch).description }
                            if fibre.isEmpty { fibre = Int(targetMeal.fibre).description }

                            if monounsaturatedFat.isEmpty { monounsaturatedFat = Int(targetMeal.monounsaturatedFat).description }
                            if polyunsaturatedFat.isEmpty { polyunsaturatedFat = Int(targetMeal.polyunsaturatedFat).description }
                            if saturatedFat.isEmpty { saturatedFat = Int(targetMeal.saturatedFat).description }
                            if transFat.isEmpty { transFat = Int(targetMeal.transFat).description }
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

                    applyIfEmpty(&carbohydrates, with: result.carbohydrates, markGuess: &carbohydratesIsGuess)
                    applyIfEmpty(&protein, with: result.protein, markGuess: &proteinIsGuess)
                    if sodium.isEmpty, let mg = result.sodiumMg {
                        let uiVal: Int
                        switch sodiumUnit {
                        case .milligrams:
                            uiVal = mg
                        case .grams:
                            uiVal = Int(Double(mg) / 1000.0)
                        }
                        sodium = String(max(0, uiVal))
                        sodiumIsGuess = true
                    }
                    applyIfEmpty(&fat, with: result.fat, markGuess: &fatIsGuess)

                    applyIfEmpty(&sugars, with: result.sugars, markGuess: &sugarsIsGuess)
                    sugarsTouched = sugarsTouched || !sugars.isEmpty
                    applyIfEmpty(&starch, with: result.starch, markGuess: &starchIsGuess)
                    starchTouched = starchTouched || !starch.isEmpty
                    applyIfEmpty(&fibre, with: result.fibre, markGuess: &fibreIsGuess)
                    fibreTouched = fibreTouched || !fibre.isEmpty

                    applyIfEmpty(&monounsaturatedFat, with: result.monounsaturatedFat, markGuess: &monounsaturatedFatIsGuess)
                    monoTouched = monoTouched || !monounsaturatedFat.isEmpty
                    applyIfEmpty(&polyunsaturatedFat, with: result.polyunsaturatedFat, markGuess: &polyunsaturatedFatIsGuess)
                    polyTouched = polyTouched || !polyunsaturatedFat.isEmpty
                    applyIfEmpty(&saturatedFat, with: result.saturatedFat, markGuess: &saturatedFatIsGuess)
                    satTouched = satTouched || !saturatedFat.isEmpty
                    applyIfEmpty(&transFat, with: result.transFat, markGuess: &transFatIsGuess)
                    transTouched = transTouched || !transFat.isEmpty

                    applyIfEmpty(&animalProtein, with: result.animalProtein, markGuess: &animalProteinIsGuess)
                    animalTouched = animalTouched || !animalProtein.isEmpty
                    applyIfEmpty(&plantProtein, with: result.plantProtein, markGuess: &plantProteinIsGuess)
                    plantTouched = plantTouched || !plantProtein.isEmpty
                    applyIfEmpty(&proteinSupplements, with: result.proteinSupplements, markGuess: &proteinSupplementsIsGuess)
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
            }
        } catch {
            await MainActor.run { analyzeError = "Analysis failed: \(error)" }
        }
    }

    // MARK: - Validation

    var isValid: Bool {
        guard let cal = Int(calories), cal > 0 else { return false }
        let allNumericStrings = [
            calories, carbohydrates, protein, sodium, fat, alcohol, nicotine, theobromine, caffeine, taurine,
            starch, sugars, fibre, monounsaturatedFat, polyunsaturatedFat, saturatedFat, transFat, omega3, omega6,
            animalProtein, plantProtein, proteinSupplements,
            vitaminA, vitaminB, vitaminC, vitaminD, vitaminE, vitaminK,
            calcium, iron, potassium, zinc, magnesium
        ]
        return allNumericStrings.dropFirst().allSatisfy { s in
            guard !s.isEmpty else { return true }
            return Int(s).map { $0 > 0 } ?? false
        }
    }

    func intOrZero(_ text: String) -> Int {
        max(0, Int(text) ?? 0)
    }

    func doubleOrZero(_ text: String) -> Double {
        max(0, Double(text) ?? 0)
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

        object.carbohydrates = Double(intOrZero(carbohydrates))
        object.protein = Double(intOrZero(protein))
        object.fat = Double(intOrZero(fat))
        object.alcohol = Double(intOrZero(alcohol))
        object.nicotine = Double(intOrZero(nicotine))
        object.theobromine = Double(intOrZero(theobromine))
        object.caffeine = Double(intOrZero(caffeine))
        object.taurine = Double(intOrZero(taurine))

        let sodiumMg: Double = {
            let val = Double(intOrZero(sodium))
            switch sodiumUnit {
            case .milligrams: return val
            case .grams: return val * 1000.0
            }
        }()
        object.sodium = max(0, sodiumMg)

        object.starch = Double(intOrZero(starch))
        object.sugars = Double(intOrZero(sugars))
        object.fibre = Double(intOrZero(fibre))

        object.monounsaturatedFat = Double(intOrZero(monounsaturatedFat))
        object.polyunsaturatedFat = Double(intOrZero(polyunsaturatedFat))
        object.saturatedFat = Double(intOrZero(saturatedFat))
        object.transFat = Double(intOrZero(transFat))
        object.omega3 = Double(intOrZero(omega3))
        object.omega6 = Double(intOrZero(omega6))

        object.animalProtein = Double(intOrZero(animalProtein))
        object.plantProtein = Double(intOrZero(plantProtein))
        object.proteinSupplements = Double(intOrZero(proteinSupplements))

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

    func sanitizeIntegerInput(_ input: String) -> String {
        let digitsOnly = input.compactMap { $0.isNumber ? $0 : nil }
        var s = String(digitsOnly)
        if s.isEmpty { return "" }
        while s.first == "0" && s.count > 1 { s.removeFirst() }
        if s == "0" { return "" }
        return s
    }

    // MARK: - Consistency

    func recomputeConsistency(resetPrevMismatch: Bool = false) {
        let carbsTotal: Int = Int(carbohydrates) ?? 0
        let sugarsVal: Int = Int(sugars) ?? 0
        let starchVal: Int = Int(starch) ?? 0
        let fibreVal: Int = Int(fibre) ?? 0
        let carbsSubSum: Int = sugarsVal + starchVal + fibreVal
        let carbsHasAnySub: Bool = !(sugars.isEmpty && starch.isEmpty && fibre.isEmpty)
        let carbsHasTotal: Bool = !carbohydrates.isEmpty
        carbsMismatch = carbsHasTotal && carbsHasAnySub && (carbsSubSum != carbsTotal)

        let proteinTotal: Int = Int(protein) ?? 0
        let animalVal: Int = Int(animalProtein) ?? 0
        let plantVal: Int = Int(plantProtein) ?? 0
        let suppsVal: Int = Int(proteinSupplements) ?? 0
        let proteinSubSum: Int = animalVal + plantVal + suppsVal
        let proteinHasAnySub: Bool = !(animalProtein.isEmpty && plantProtein.isEmpty && proteinSupplements.isEmpty)
        let proteinHasTotal: Bool = !protein.isEmpty
        proteinMismatch = proteinHasTotal && proteinHasAnySub && (proteinSubSum != proteinTotal)

        let fatTotal: Int = Int(fat) ?? 0
        let monoVal: Int = Int(monounsaturatedFat) ?? 0
        let polyVal: Int = Int(polyunsaturatedFat) ?? 0
        let satVal: Int = Int(saturatedFat) ?? 0
        let transVal: Int = Int(Int(transFat) ?? 0)
        let fatSubSum: Int = monoVal + polyVal + satVal + transVal
        let fatHasAnySub: Bool = !(monounsaturatedFat.isEmpty && polyunsaturatedFat.isEmpty && saturatedFat.isEmpty && transFat.isEmpty)
        let fatHasTotal: Bool = !fat.isEmpty
        fatMismatch = fatHasTotal && fatHasAnySub && (fatSubSum != fatTotal)

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

    func showHelper(for group: GroupKind, sum: Int) {
        Task { @MainActor in
            let text = String(sum)
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
        guard let total = Int(carbohydrates), total >= 0 else { return }
        if sugarsTouched && starchTouched && fibreTouched { return }
        let ratios: [Double] = [0.30, 0.60, 0.10]
        let parts = distributeInt(total, ratios: ratios)
        if !sugarsTouched { sugars = parts[0].description; sugarsIsGuess = true }
        if !starchTouched { starch = parts[1].description; starchIsGuess = true }
        if !fibreTouched { fibre = parts[2].description; fibreIsGuess = true }
    }

    func autofillFatSubfieldsIfNeeded() {
        guard let total = Int(fat), total >= 0 else { return }
        if monoTouched && polyTouched && satTouched && transTouched { return }
        let ratios: [Double] = [0.40, 0.30, 0.25, 0.05]
        let parts = distributeInt(total, ratios: ratios)
        if !monoTouched { monounsaturatedFat = parts[0].description; monounsaturatedFatIsGuess = true }
        if !polyTouched { polyunsaturatedFat = parts[1].description; polyunsaturatedFatIsGuess = true }
        if !satTouched { saturatedFat = parts[2].description; saturatedFatIsGuess = true }
        if !transTouched { transFat = parts[3].description; transFatIsGuess = true }
    }

    func autofillProteinSubfieldsIfNeeded() {
        guard let total = Int(protein), total >= 0 else { return }
        if animalTouched && plantTouched && supplementsTouched { return }
        let ratios: [Double] = [0.50, 0.40, 0.10]
        let parts = distributeInt(total, ratios: ratios)
        if !animalTouched { animalProtein = parts[0].description; animalProteinIsGuess = true }
        if !plantTouched { plantProtein = parts[1].description; plantProteinIsGuess = true }
        if !supplementsTouched { proteinSupplements = parts[2].description; proteinSupplementsIsGuess = true }
    }

    // MARK: - Top-level updates from subfields

    func handleTopFromCarbSubs() {
        let hasAnySub = !(sugars.isEmpty && starch.isEmpty && fibre.isEmpty)
        guard hasAnySub else { return }
        let sum = (Int(sugars) ?? 0) + (Int(starch) ?? 0) + (Int(fibre) ?? 0)

        let currentTop = Int(carbohydrates)
        let canAutoUpdate = (currentTop == nil) || (currentTop == carbsLastAutoSum)

        if canAutoUpdate {
            let wasEmpty = carbohydrates.isEmpty
            carbohydrates = String(sum)
            carbohydratesIsGuess = true
            carbsLastAutoSum = sum

            if wasEmpty {
                flashRedOnce(for: .carbs)
                showHelper(for: .carbs, sum: sum)
            }
        }
    }

    func handleTopFromProteinSubs() {
        let hasAnySub = !(animalProtein.isEmpty && plantProtein.isEmpty && proteinSupplements.isEmpty)
        guard hasAnySub else { return }
        let sum = (Int(animalProtein) ?? 0) + (Int(plantProtein) ?? 0) + (Int(proteinSupplements) ?? 0)

        let currentTop = Int(protein)
        let canAutoUpdate = (currentTop == nil) || (currentTop == proteinLastAutoSum)

        if canAutoUpdate {
            let wasEmpty = protein.isEmpty
            protein = String(sum)
            proteinIsGuess = true
            proteinLastAutoSum = sum

            if wasEmpty {
                flashRedOnce(for: .protein)
                showHelper(for: .protein, sum: sum)
            }
        }
    }

    func handleTopFromFatSubs() {
        let hasAnySub = !(monounsaturatedFat.isEmpty && polyunsaturatedFat.isEmpty && saturatedFat.isEmpty && transFat.isEmpty)
        guard hasAnySub else { return }
        let mono = Int(monounsaturatedFat) ?? 0
        let poly = Int(polyunsaturatedFat) ?? 0
        let sat = Int(saturatedFat) ?? 0
        let trans = Int(transFat) ?? 0
        let sum = mono + poly + sat + trans

        let currentTop = Int(fat)
        let canAutoUpdate = (currentTop == nil) || (currentTop == fatLastAutoSum)

        if canAutoUpdate {
            let wasEmpty = fat.isEmpty
            fat = String(sum)
            fatIsGuess = true
            fatLastAutoSum = sum

            if wasEmpty {
                flashRedOnce(for: .fat)
                showHelper(for: .fat, sum: sum)
            }
        }
    }

    // MARK: - Helper prompts

    func handleHelperForCarbs() {
        let total = Int(carbohydrates) ?? 0
        let sum = (Int(sugars) ?? 0) + (Int(starch) ?? 0) + (Int(fibre) ?? 0)
        let hasAnySub = !(sugars.isEmpty && starch.isEmpty && fibre.isEmpty)
        let hasTotal = !carbohydrates.isEmpty
        if hasAnySub && hasTotal && sum != total {
            showHelper(for: .carbs, sum: sum)
            flashRedOnce(for: .carbs)
        }
    }

    func handleHelperForProtein() {
        let total = Int(protein) ?? 0
        let sum = (Int(animalProtein) ?? 0) + (Int(plantProtein) ?? 0) + (Int(proteinSupplements) ?? 0)
        let hasAnySub = !(animalProtein.isEmpty && plantProtein.isEmpty && proteinSupplements.isEmpty)
        let hasTotal = !protein.isEmpty
        if hasAnySub && hasTotal && sum != total {
            showHelper(for: .protein, sum: sum)
            flashRedOnce(for: .protein)
        }
    }

    func handleHelperForFat() {
        let total = Int(fat) ?? 0
        let mono = Int(monounsaturatedFat) ?? 0
        let poly = Int(polyunsaturatedFat) ?? 0
        let sat = Int(saturatedFat) ?? 0
        let trans = Int(Int(transFat) ?? 0)
        let sum = mono + poly + sat + trans
        let hasAnySub = !(monounsaturatedFat.isEmpty && polyunsaturatedFat.isEmpty && saturatedFat.isEmpty && transFat.isEmpty)
        let hasTotal = !fat.isEmpty
        if hasAnySub && hasTotal && sum != total {
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
        let total = Int(carbohydrates) ?? 0
        let sum = (Int(sugars) ?? 0) + (Int(starch) ?? 0) + (Int(fibre) ?? 0)
        let hasAnySub = !(sugars.isEmpty && starch.isEmpty && fibre.isEmpty)
        let hasTotal = !carbohydrates.isEmpty
        if hasAnySub && hasTotal && sum != total {
            showHelper(for: .carbs, sum: sum)
            flashRedOnce(for: .carbs)
        }
    }

    func handleHelperOnTopChangeForProtein() {
        let total = Int(protein) ?? 0
        let sum = (Int(animalProtein) ?? 0) + (Int(plantProtein) ?? 0) + (Int(proteinSupplements) ?? 0)
        let hasAnySub = !(animalProtein.isEmpty && plantProtein.isEmpty && proteinSupplements.isEmpty)
        let hasTotal = !protein.isEmpty
        if hasAnySub && hasTotal && sum != total {
            showHelper(for: .protein, sum: sum)
            flashRedOnce(for: .protein)
        }
    }

    func handleHelperOnTopChangeForFat() {
        let total = Int(fat) ?? 0
        let mono = Int(monounsaturatedFat) ?? 0
        let poly = Int(polyunsaturatedFat) ?? 0
        let sat = Int(saturatedFat) ?? 0
        let trans = Int(transFat) ?? 0
        let sum = mono + poly + sat + trans
        let hasAnySub = !(monounsaturatedFat.isEmpty && polyunsaturatedFat.isEmpty && saturatedFat.isEmpty && transFat.isEmpty)
        let hasTotal = !fat.isEmpty
        if hasAnySub && hasTotal && sum != total {
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
}

