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
    @NSManaged public var salt: Double
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
}

extension Meal {
    static func fetchAllMealsRequest() -> NSFetchRequest<Meal> {
        let request = NSFetchRequest<Meal>(entityName: "Meal")
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        return request
    }
}

