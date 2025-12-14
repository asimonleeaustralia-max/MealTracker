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

    // New: user-configurable setting to open to a new meal on launch
    @AppStorage("openToNewMealOnLaunch") private var openToNewMealOnLaunch: Bool = false
    // New: transient launch action flag used by AppIntent routing
    @AppStorage("launchAction") private var launchAction: String?

    // Presentation control
    @State private var presentNewMealSheet: Bool = false

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
                        MealsRootView()
                            .sheet(isPresented: $presentNewMealSheet) {
                                // Always present a fresh new-meal form
                                NavigationView {
                                    MealFormView()
                                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                                        .environmentObject(session)
                                }
                                .accessibilityIdentifier("newMealSheet")
                            }
                            .onAppear {
                                // Handle cold start: respect user setting
                                if openToNewMealOnLaunch {
                                    presentNewMealSheet = true
                                }
                                // Handle pending AppIntent flag (e.g., tapped from Shortcuts)
                                if launchAction == "newMeal" {
                                    presentNewMealSheet = true
                                    launchAction = nil
                                }
                            }
                            .onChange(of: scenePhase) { phase in
                                if phase == .active {
                                    // Handle coming to foreground via intent
                                    if launchAction == "newMeal" {
                                        presentNewMealSheet = true
                                        launchAction = nil
                                    }
                                } else if phase == .background {
                                    let context = persistenceController.container.viewContext
                                    if context.hasChanges {
                                        try? context.save()
                                    }
                                }
                            }
                    }
                } else {
                    NavigationView {
                        MealsRootView()
                            .sheet(isPresented: $presentNewMealSheet) {
                                MealFormView()
                                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                                    .environmentObject(session)
                            }
                            .onAppear {
                                if openToNewMealOnLaunch {
                                    presentNewMealSheet = true
                                }
                                if launchAction == "newMeal" {
                                    presentNewMealSheet = true
                                    launchAction = nil
                                }
                            }
                            .onChange(of: scenePhase) { phase in
                                if phase == .active {
                                    if launchAction == "newMeal" {
                                        presentNewMealSheet = true
                                        launchAction = nil
                                    }
                                } else if phase == .background {
                                    let context = persistenceController.container.viewContext
                                    if context.hasChanges {
                                        try? context.save()
                                    }
                                }
                            }
                    }
                }
            }
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
            .environmentObject(session)
        }
    }
}

// A simple root to keep the main stack clean.
// Updated: use a neutral root (ContentView) so MealFormView is only shown via the sheet.
private struct MealsRootView: View {
    var body: some View {
        ContentView()
    }
}
