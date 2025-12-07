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
    @StateObject private var session = SessionManager()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // One-time migration: assign UUIDs to any Meal rows missing an id
        let context = persistenceController.container.viewContext
        context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "Meal")
            request.predicate = NSPredicate(format: "id == nil")
            if let rows = try? context.fetch(request), !rows.isEmpty {
                for obj in rows {
                    // Use KVC to avoid reading a non-optional Swift property
                    obj.setValue(UUID(), forKey: "id")
                    if obj.value(forKey: "date") == nil {
                        obj.setValue(Date(), forKey: "date")
                    }
                }
                if context.hasChanges {
                    try? context.save()
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if #available(iOS 16.0, *) {
                    NavigationStack {
                        MealFormView()
                    }
                } else {
                    NavigationView {
                        MealFormView()
                    }
                }
            }
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
            .environmentObject(session)
            .onChange(of: scenePhase) { phase in
                if phase == .background {
                    let context = persistenceController.container.viewContext
                    if context.hasChanges {
                        try? context.save()
                    }
                }
            }
        }
    }
}
