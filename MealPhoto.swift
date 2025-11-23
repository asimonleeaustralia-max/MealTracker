//
//  MealPhoto.swift
//  MealTracker
//
//  Created by Simon Lee on 17/11/2025.
//

import Foundation
import CoreData

@objc(MealPhoto)
public class MealPhoto: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var createdAt: Date?
    @NSManaged public var width: Int32
    @NSManaged public var height: Int32
    @NSManaged public var fileNameOriginal: String?
    @NSManaged public var fileNameUpload: String?
    @NSManaged public var byteSizeOriginal: Int64
    @NSManaged public var byteSizeUpload: Int64
    @NSManaged public var sha256: String?
    @NSManaged public var meal: Meal?
}
