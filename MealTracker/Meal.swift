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
    @NSManaged public var mealDescription: String
    @NSManaged public var calories: Double
    @NSManaged public var carbohydrates: Double
    @NSManaged public var protein: Double
    @NSManaged public var sodium: Double
    @NSManaged public var fat: Double
    @NSManaged public var date: Date

    // Existing attributes
    @NSManaged public var starch: Double
    @NSManaged public var sugars: Double
    @NSManaged public var fibre: Double

    // New fat breakdown attributes
    @NSManaged public var monounsaturatedFat: Double
    @NSManaged public var polyunsaturatedFat: Double
    @NSManaged public var saturatedFat: Double
    @NSManaged public var transFat: Double

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

    // Ensure defaults for brand new inserts so `id` is never nil in the store
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        // Use primitive setters to avoid unnecessary KVO/bridging
        if value(forKey: "id") == nil {
            setPrimitiveValue(UUID(), forKey: "id")
        }
        if value(forKey: "date") == nil {
            setPrimitiveValue(Date(), forKey: "date")
        }
    }
}

extension Meal {
    static func fetchAllMealsRequest() -> NSFetchRequest<Meal> {
        let request = NSFetchRequest<Meal>(entityName: "Meal")
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        return request
    }
}
