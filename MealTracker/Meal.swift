//
//  Meal.swift
//  MealTracker
//
//  Created by Simon Lee on 17/11/2025.
//

import Foundation
import CoreData

@objc(Meal)
class Meal: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var calories: Double
    @NSManaged var carbohydrates: Double
    @NSManaged var protein: Double
    @NSManaged var sodium: Double
    @NSManaged var fat: Double
    @NSManaged var date: Date

    // Optional coordinates (Double in code; optional in model is fine, 0.0 used when unset)
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double

    // Alcohol (grams) and accuracy flag
    @NSManaged var alcohol: Double
    @NSManaged var alcoholIsGuess: Bool

    // Stimulant: Nicotine (milligrams) and accuracy flag
    @NSManaged var nicotine: Double
    @NSManaged var nicotineIsGuess: Bool

    // Stimulant: Theobromine (milligrams) and accuracy flag
    @NSManaged var theobromine: Double
    @NSManaged var theobromineIsGuess: Bool

    // Stimulant: Caffeine (milligrams) and accuracy flag
    @NSManaged var caffeine: Double
    @NSManaged var caffeineIsGuess: Bool

    // Stimulant: Taurine (milligrams) and accuracy flag
    @NSManaged var taurine: Double
    @NSManaged var taurineIsGuess: Bool

    // Existing attributes
    @NSManaged var starch: Double
    @NSManaged var sugars: Double
    @NSManaged var fibre: Double

    // New fat breakdown attributes
    @NSManaged var monounsaturatedFat: Double
    @NSManaged var polyunsaturatedFat: Double
    @NSManaged var saturatedFat: Double
    @NSManaged var transFat: Double
    // Added: Omega-3 (grams)
    @NSManaged var omega3: Double
    // Added: Omega-6 (grams)
    @NSManaged var omega6: Double

    // New protein breakdown attributes
    @NSManaged var animalProtein: Double
    @NSManaged var plantProtein: Double
    @NSManaged var proteinSupplements: Double

    // Vitamins (stored in milligrams as base unit)
    @NSManaged var vitaminA: Double
    @NSManaged var vitaminB: Double
    @NSManaged var vitaminC: Double
    @NSManaged var vitaminD: Double
    @NSManaged var vitaminE: Double
    @NSManaged var vitaminK: Double

    // Minerals (stored in milligrams as base unit)
    @NSManaged var calcium: Double
    @NSManaged var iron: Double
    @NSManaged var potassium: Double
    @NSManaged var zinc: Double
    @NSManaged var magnesium: Double

    // Accuracy flags
    @NSManaged var caloriesIsGuess: Bool
    @NSManaged var carbohydratesIsGuess: Bool
    @NSManaged var proteinIsGuess: Bool
    @NSManaged var sodiumIsGuess: Bool
    @NSManaged var fatIsGuess: Bool
    @NSManaged var starchIsGuess: Bool
    @NSManaged var sugarsIsGuess: Bool
    @NSManaged var fibreIsGuess: Bool
    @NSManaged var monounsaturatedFatIsGuess: Bool
    @NSManaged var polyunsaturatedFatIsGuess: Bool
    @NSManaged var saturatedFatIsGuess: Bool
    @NSManaged var transFatIsGuess: Bool
    // Added: Omega-3 accuracy flag
    @NSManaged var omega3IsGuess: Bool
    // Added: Omega-6 accuracy flag
    @NSManaged var omega6IsGuess: Bool

    // New protein breakdown accuracy flags
    @NSManaged var animalProteinIsGuess: Bool
    @NSManaged var plantProteinIsGuess: Bool
    @NSManaged var proteinSupplementsIsGuess: Bool

    // Vitamins accuracy flags
    @NSManaged var vitaminAIsGuess: Bool
    @NSManaged var vitaminBIsGuess: Bool
    @NSManaged var vitaminCIsGuess: Bool
    @NSManaged var vitaminDIsGuess: Bool
    @NSManaged var vitaminEIsGuess: Bool
    @NSManaged var vitaminKIsGuess: Bool

    // Minerals accuracy flags
    @NSManaged var calciumIsGuess: Bool
    @NSManaged var ironIsGuess: Bool
    @NSManaged var potassiumIsGuess: Bool
    @NSManaged var zincIsGuess: Bool
    @NSManaged var magnesiumIsGuess: Bool

    // Optional: last sync GUID assigned by cloud after successful sync (nil when never synced)
    @NSManaged var lastSyncGUID: String?

    // Ensure defaults for brand new inserts so `id` is never nil in the store
    override func awakeFromInsert() {
        super.awakeFromInsert()
        if value(forKey: "id") == nil {
            setPrimitiveValue(UUID(), forKey: "id")
        }
        if value(forKey: "date") == nil {
            setPrimitiveValue(Date(), forKey: "date")
        }
        // Title is required in the model; default to empty string on brand-new rows
        if value(forKey: "title") == nil {
            setPrimitiveValue("", forKey: "title")
        }
        // Do not set lastSyncGUID here — it should remain nil until a successful sync.
    }
}

extension Meal {
    static func fetchAllMealsRequest() -> NSFetchRequest<Meal> {
        let request = NSFetchRequest<Meal>(entityName: "Meal")
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        // Prefetch photos to reduce faulting during UI updates/removals
        request.relationshipKeyPathsForPrefetching = ["photos"]
        return request
    }

    static func autoTitle(for date: Date, locale: Locale = .current) -> String {
        var cal = Calendar.current
        cal.locale = locale

        let comps = cal.dateComponents([.hour, .minute, .weekday], from: date)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0

        let inBreakfast = (hour >= 5 && hour < 11)
        let inLunch = (hour >= 11 && hour < 15)
        let inDinner = (hour >= 18 && hour < 22)

        let weekdayName: String = {
            let df = DateFormatter()
            df.locale = locale
            df.setLocalizedDateFormatFromTemplate("EEEE")
            return df.string(from: date)
        }()

        let timeString: String = {
            let tf = DateFormatter()
            tf.locale = locale
            tf.timeStyle = .short
            tf.dateStyle = .none
            return tf.string(from: date)
        }()

        func dayPart() -> String {
            switch (hour, minute) {
            case (5..<8, _): return "early morning"
            case (8..<11, _): return "morning"
            case (11..<14, _): return "midday"
            case (14..<18, _): return "afternoon"
            case (18..<22, _): return "evening"
            case (22..<24, _), (0..<1, _): return "late night"
            default: return "overnight"
            }
        }

        if inBreakfast {
            return "Breakfast \(weekdayName) \(dayPart())"
        } else if inLunch {
            return "Lunch \(weekdayName) \(dayPart())"
        } else if inDinner {
            return "Dinner \(weekdayName) \(dayPart())"
        } else {
            return "Snack at \(timeString) \(weekdayName)"
        }
    }

    // MARK: - Sync helpers

    func markSynced(with guid: String, in context: NSManagedObjectContext) {
        lastSyncGUID = guid
        try? context.save()
    }

    func clearSyncMarker(in context: NSManagedObjectContext) {
        lastSyncGUID = nil
        try? context.save()
    }
}
