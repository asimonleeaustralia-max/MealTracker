//
//  Meal.swift
//  MealTracker
//
//  Created by Simon Lee on 17/11/2025.
//

import Foundation
import CoreData

@objc(Meal)
public class Meal: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var calories: Double
    @NSManaged public var carbohydrates: Double
    @NSManaged public var protein: Double
    @NSManaged public var sodium: Double
    @NSManaged public var fat: Double
    @NSManaged public var date: Date

    // Optional coordinates (Double in code; optional in model is fine, 0.0 used when unset)
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double

    // Alcohol (grams) and accuracy flag
    @NSManaged public var alcohol: Double
    @NSManaged public var alcoholIsGuess: Bool

    // Stimulant: Nicotine (milligrams) and accuracy flag
    @NSManaged public var nicotine: Double
    @NSManaged public var nicotineIsGuess: Bool

    // Stimulant: Theobromine (milligrams) and accuracy flag [ADDED]
    @NSManaged public var theobromine: Double
    @NSManaged public var theobromineIsGuess: Bool

    // Stimulant: Caffeine (milligrams) and accuracy flag [ADDED]
    @NSManaged public var caffeine: Double
    @NSManaged public var caffeineIsGuess: Bool

    // Stimulant: Taurine (milligrams) and accuracy flag [ADDED]
    @NSManaged public var taurine: Double
    @NSManaged public var taurineIsGuess: Bool

    // Existing attributes
    @NSManaged public var starch: Double
    @NSManaged public var sugars: Double
    @NSManaged public var fibre: Double

    // New fat breakdown attributes
    @NSManaged public var monounsaturatedFat: Double
    @NSManaged public var polyunsaturatedFat: Double
    @NSManaged public var saturatedFat: Double
    @NSManaged public var transFat: Double
    // Added: Omega-3 (grams)
    @NSManaged public var omega3: Double
    // Added: Omega-6 (grams)
    @NSManaged public var omega6: Double

    // New protein breakdown attributes
    @NSManaged public var animalProtein: Double
    @NSManaged public var plantProtein: Double
    @NSManaged public var proteinSupplements: Double

    // Vitamins (stored in milligrams as base unit)
    @NSManaged public var vitaminA: Double
    @NSManaged public var vitaminB: Double
    @NSManaged public var vitaminC: Double
    @NSManaged public var vitaminD: Double
    @NSManaged public var vitaminE: Double
    @NSManaged public var vitaminK: Double

    // Minerals (stored in milligrams as base unit)
    @NSManaged public var calcium: Double
    @NSManaged public var iron: Double
    @NSManaged public var potassium: Double
    @NSManaged public var zinc: Double
    @NSManaged public var magnesium: Double

    // Accuracy flags
    @NSManaged public var caloriesIsGuess: Bool
    @NSManaged public var carbohydratesIsGuess: Bool
    @NSManaged public var proteinIsGuess: Bool
    @NSManaged public var sodiumIsGuess: Bool
    @NSManaged public var fatIsGuess: Bool
    @NSManaged public var starchIsGuess: Bool
    @NSManaged public var sugarsIsGuess: Bool
    @NSManaged public var fibreIsGuess: Bool
    @NSManaged public var monounsaturatedFatIsGuess: Bool
    @NSManaged public var polyunsaturatedFatIsGuess: Bool
    @NSManaged public var saturatedFatIsGuess: Bool
    @NSManaged public var transFatIsGuess: Bool
    // Added: Omega-3 accuracy flag
    @NSManaged public var omega3IsGuess: Bool
    // Added: Omega-6 accuracy flag
    @NSManaged public var omega6IsGuess: Bool

    // New protein breakdown accuracy flags
    @NSManaged public var animalProteinIsGuess: Bool
    @NSManaged public var plantProteinIsGuess: Bool
    @NSManaged public var proteinSupplementsIsGuess: Bool

    // Vitamins accuracy flags
    @NSManaged public var vitaminAIsGuess: Bool
    @NSManaged public var vitaminBIsGuess: Bool
    @NSManaged public var vitaminCIsGuess: Bool
    @NSManaged public var vitaminDIsGuess: Bool
    @NSManaged public var vitaminEIsGuess: Bool
    @NSManaged public var vitaminKIsGuess: Bool

    // Minerals accuracy flags
    @NSManaged public var calciumIsGuess: Bool
    @NSManaged public var ironIsGuess: Bool
    @NSManaged public var potassiumIsGuess: Bool
    @NSManaged public var zincIsGuess: Bool
    @NSManaged public var magnesiumIsGuess: Bool

    // Optional: last sync GUID assigned by cloud after successful sync (nil when never synced)
    @NSManaged public var lastSyncGUID: String?

    // Ensure defaults for brand new inserts so `id` is never nil in the store
    public override func awakeFromInsert() {
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

    // Auto-generate a reasonable title based on time-of-day and weekday.
    // Windows:
    // - Breakfast: 05:00–10:59
    // - Lunch:     11:00–14:59
    // - Dinner:    18:00–21:59
    // - Snack:     all other times (shows "at HH:mm Weekday")
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
            default: return "overnight" // 01:00–04:59
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

    // Set the last sync GUID after a successful cloud sync
    func markSynced(with guid: String, in context: NSManagedObjectContext) {
        lastSyncGUID = guid
        try? context.save()
    }

    // Clear the sync marker (e.g., if local changes need re-upload)
    func clearSyncMarker(in context: NSManagedObjectContext) {
        lastSyncGUID = nil
        try? context.save()
    }
}
