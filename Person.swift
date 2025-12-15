//
//  Person.swift
//  MealTracker
//
//  Manual Core Data class for the Person entity.
//  Matches attributes shown in the data model: id (UUID), name (String),
//  isDefault (Bool), isRemoved (Bool), and a to-many relationship `meal` to Meal.
//

import Foundation
import CoreData

@objc(Person)
public class Person: NSManagedObject, Identifiable {

    // MARK: - Attributes

    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var isDefault: Bool
    @NSManaged public var isRemoved: Bool

    // MARK: - Relationships

    // The model shows a relationship named "meal" to the Meal entity, with no inverse.
    // Implemented here as to-many. If your model is to-one, change this to:
    // @NSManaged public var meal: Meal?
    @NSManaged public var meal: Set<Meal>

    // MARK: - Lifecycle

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        // Ensure a UUID is assigned on creation
        if value(forKey: "id") == nil {
            setPrimitiveValue(UUID(), forKey: "id")
        }
        // Provide a sensible default name for brand-new rows
        if value(forKey: "name") == nil {
            let defaultName = NSLocalizedString("default_person_name_me", comment: "Default person name for device owner")
            setPrimitiveValue(defaultName == "default_person_name_me" ? "Me" : defaultName, forKey: "name")
        }
        // Default flags
        if value(forKey: "isDefault") == nil {
            setPrimitiveValue(false, forKey: "isDefault")
        }
        if value(forKey: "isRemoved") == nil {
            setPrimitiveValue(false, forKey: "isRemoved")
        }
    }
}

// MARK: - Fetch helpers

extension Person {
    // Fetch all persons, default-first then by name
    static func fetchAllRequest() -> NSFetchRequest<Person> {
        let request = NSFetchRequest<Person>(entityName: "Person")
        request.sortDescriptors = [
            NSSortDescriptor(key: "isDefault", ascending: false),
            NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedStandardCompare(_:)))
        ]
        request.includesSubentities = false
        return request
    }

    // Fetch the single default person (if any)
    static func fetchDefaultRequest() -> NSFetchRequest<Person> {
        let request = NSFetchRequest<Person>(entityName: "Person")
        request.predicate = NSPredicate(format: "isDefault == YES")
        request.fetchLimit = 1
        request.includesSubentities = false
        return request
    }
}

// MARK: - Generated accessors for to-many `meal` relationship

extension Person {
    @objc(addMealObject:)
    @NSManaged public func addToMeal(_ value: Meal)

    @objc(removeMealObject:)
    @NSManaged public func removeFromMeal(_ value: Meal)

    @objc(addMeal:)
    @NSManaged public func addToMeal(_ values: Set<Meal>)

    @objc(removeMeal:)
    @NSManaged public func removeFromMeal(_ values: Set<Meal>)
}
