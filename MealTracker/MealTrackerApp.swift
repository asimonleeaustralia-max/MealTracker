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
