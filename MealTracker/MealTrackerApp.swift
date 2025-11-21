//
//  MealTrackerApp.swift
//  MealTracker
//
//  Created by Simon Lee on 17/11/2025.
//

import SwiftUI
import CoreData

@main
struct MealTrackerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            NavigationView {
                MealFormView()
            }
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}



