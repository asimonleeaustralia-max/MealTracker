//
//  MealTrackerApp.swift
//  MealTracker
//
//  Created by Simon Lee on 17/11/2025.
//

import SwiftUI
import CoreData
import UIKit
import BackgroundTasks
import UserNotifications

@main
struct MealTrackerApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var session = SessionManager()
    @Environment(\.scenePhase) private var scenePhase

    // Install AppDelegate to receive background URLSession events
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // New: user-configurable setting to open to a new meal on launch
    @AppStorage("openToNewMealOnLaunch") private var openToNewMealOnLaunch: Bool = false
    // New: transient launch action flag used by AppIntent routing
    @AppStorage("launchAction") private var launchAction: String?

    // Presentation control
    @State private var presentNewMealSheet: Bool = false

    // MARK: - Background Task identifiers
    private let mealsSeedingTaskIdentifier = "com.mealtracker.mealsseeding"

    init() {
        // Register default settings (does not overwrite user-changed values)
        UserDefaults.standard.register(defaults: [
            "aiFeaturesEnabled": true
        ])

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

        // Register background processing task for Meals Seeder
        BGTaskScheduler.shared.register(forTaskWithIdentifier: mealsSeedingTaskIdentifier, using: nil) { task in
            // Ensure correct task type
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            // Kick off the seeding manager to run in background
            Task {
                await MealsSeedingManager.shared.handleBackgroundTask(processingTask)
            }
        }

        // Ask for user notification permission once (to notify on completion/failure)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
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
                                // Always open entry screen immediately on launch
                                presentNewMealSheet = true

                                // Still respect AppIntent flag if present
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
                                    // Give BGTaskScheduler a chance to run queued work
                                    scheduleMealsSeedingIfQueued()
                                }
                            }
                    }
                } else {
                    NavigationView {
                        MealsRootView()
                            .sheet(isPresented: $presentNewMealSheet) {
                                // FIX: wrap MealFormView in a NavigationView on iOS 15 as well
                                NavigationView {
                                    MealFormView()
                                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                                        .environmentObject(session)
                                }
                                .accessibilityIdentifier("newMealSheet")
                            }
                            .onAppear {
                                // Always open entry screen immediately on launch
                                presentNewMealSheet = true

                                // Still respect AppIntent flag if present
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
                                    scheduleMealsSeedingIfQueued()
                                }
                            }
                    }
                }
            }
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
            .environmentObject(session)
        }
    }

    // MARK: - BGTask scheduling entry points

    // Called when user taps "Start Bulk Download" in Settings; the manager will call this.
    static func scheduleMealsSeedingTask() {
        let request = BGProcessingTaskRequest(identifier: "com.mealtracker.mealsseeding")
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        // Let the system run it soon
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            #if DEBUG
            print("BGTaskScheduler submit failed: \(error)")
            #endif
        }
    }

    // When app goes to background, if a seeding run is queued or running, re-submit to keep the system aware.
    private func scheduleMealsSeedingIfQueued() {
        Task {
            let shouldSchedule = await MealsSeedingManager.shared.shouldEnsureScheduled()
            if shouldSchedule {
                Self.scheduleMealsSeedingTask()
            }
        }
    }
}

// A simple root to keep the main stack clean.
// Updated: show the MealsGalleryView so after saving (and dismissing the sheet) we land on the gallery.
private struct MealsRootView: View {
    var body: some View {
        MealsGalleryView()
    }
}
