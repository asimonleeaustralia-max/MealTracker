// NewMealIntent.swift
import AppIntents
import SwiftUI

@available(iOS 16.0, *)
struct NewMealIntent: AppIntent {
    static var title: LocalizedStringResource = "intent_new_meal_title" // Localize later
    static var description = IntentDescription("intent_new_meal_description") // Localize later

    // Display in Shortcuts app
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // Signal the app to present a fresh MealFormView.
        UserDefaults.standard.set("newMeal", forKey: "launchAction")
        return .result()
    }
}
