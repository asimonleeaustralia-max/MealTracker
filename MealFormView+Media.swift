//
//  MealFormView+Media.swift
//  MealTracker
//
//  Extracted camera/gallery/lifecycle/deletion logic from MealFormView+Logic.swift
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
}

