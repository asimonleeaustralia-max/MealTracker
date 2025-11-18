//
//  MealFormView.swift
//  MealTracker
//
//  Created by Simon Lee on 17/11/2025.
//

import SwiftUI
import CoreData

struct MealFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context

    @State private var mealDescription: String = ""
    @State private var calories: String = ""
    @State private var carbohydrates: String = ""
    @State private var protein: String = ""
    @State private var salt: String = ""
    @State private var fat: String = ""
    // Added missing nutrient fields
    @State private var starch: String = ""
    @State private var sugars: String = ""
    @State private var fibre: String = ""
    // New fat breakdown fields
    @State private var monounsaturatedFat: String = ""
    @State private var polyunsaturatedFat: String = ""
    @State private var saturatedFat: String = ""
    @State private var transFat: String = ""

    @State private var date: Date = Date()

    var meal: Meal?

    init(meal: Meal? = nil) {
        self.meal = meal
    }

    var isEditing: Bool { meal != nil }

    var body: some View {
        Form {
            Section(header: Text(NSLocalizedString("meal_details", comment: "Meal details"))) {
                TextField(NSLocalizedString("meal_description", comment: "Meal Description"), text: $mealDescription)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)

                DatePicker(NSLocalizedString("meal_date", comment: "Meal Date"), selection: $date, displayedComponents: [.date, .hourAndMinute])
            }

            Section(header: Text(NSLocalizedString("nutrition", comment: "Nutrition"))) {
                NumericField(titleKey: "calories", text: $calories, keyboard: .numberPad)
                NumericField(titleKey: "carbohydrates", text: $carbohydrates)
                NumericField(titleKey: "protein", text: $protein)
                NumericField(titleKey: "fat", text: $fat)
                NumericField(titleKey: "salt", text: $salt)
                // Added fields for new attributes
                NumericField(titleKey: "starch", text: $starch)
                NumericField(titleKey: "sugars", text: $sugars)
                NumericField(titleKey: "fibre", text: $fibre)

                // Fat breakdown
                NumericField(titleKey: "monounsaturated_fat", text: $monounsaturatedFat)
                NumericField(titleKey: "polyunsaturated_fat", text: $polyunsaturatedFat)
                NumericField(titleKey: "saturated_fat", text: $saturatedFat)
                NumericField(titleKey: "trans_fat", text: $transFat)
            }
        }
        .navigationTitle(isEditing ? NSLocalizedString("edit_meal", comment: "Edit Meal") : NSLocalizedString("add_meal", comment: "Add Meal"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(NSLocalizedString("cancel", comment: "Cancel")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(NSLocalizedString("save", comment: "Save")) {
                    save()
                }
                .disabled(!isValid)
                .accessibilityIdentifier("saveMealButton")
            }
        }
        .onAppear {
            if let meal = meal {
                mealDescription = meal.mealDescription
                calories = meal.calories.cleanString
                carbohydrates = meal.carbohydrates.cleanString
                protein = meal.protein.cleanString
                salt = meal.salt.cleanString
                fat = meal.fat.cleanString
                // Populate new fields on edit
                starch = meal.starch.cleanString
                sugars = meal.sugars.cleanString
                fibre = meal.fibre.cleanString
                monounsaturatedFat = meal.monounsaturatedFat.cleanString
                polyunsaturatedFat = meal.polyunsaturatedFat.cleanString
                saturatedFat = meal.saturatedFat.cleanString
                transFat = meal.transFat.cleanString
                date = meal.date
            } else {
                date = Date()
            }
        }
    }

    private var isValid: Bool {
        !mealDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Double(calories) != nil &&
        Double(carbohydrates) != nil &&
        Double(protein) != nil &&
        Double(salt) != nil &&
        Double(fat) != nil &&
        Double(starch) != nil &&
        Double(sugars) != nil &&
        Double(fibre) != nil &&
        Double(monounsaturatedFat) != nil &&
        Double(polyunsaturatedFat) != nil &&
        Double(saturatedFat) != nil &&
        Double(transFat) != nil
    }

    private func save() {
        guard let cal = Double(calories),
              let carbs = Double(carbohydrates),
              let prot = Double(protein),
              let s = Double(salt),
              let f = Double(fat),
              let sta = Double(starch),
              let sug = Double(sugars),
              let fib = Double(fibre),
              let mono = Double(monounsaturatedFat),
              let poly = Double(polyunsaturatedFat),
              let sat = Double(saturatedFat),
              let trans = Double(transFat)
        else { return }

        if let meal = meal {
            meal.mealDescription = mealDescription
            meal.calories = cal
            meal.carbohydrates = carbs
            meal.protein = prot
            meal.salt = s
            meal.fat = f
            meal.starch = sta
            meal.sugars = sug
            meal.fibre = fib
            meal.monounsaturatedFat = mono
            meal.polyunsaturatedFat = poly
            meal.saturatedFat = sat
            meal.transFat = trans
            meal.date = date
        } else {
            let newMeal = Meal(context: context)
            newMeal.id = UUID()
            newMeal.mealDescription = mealDescription
            newMeal.calories = cal
            newMeal.carbohydrates = carbs
            newMeal.protein = prot
            newMeal.salt = s
            newMeal.fat = f
            newMeal.starch = sta
            newMeal.sugars = sug
            newMeal.fibre = fib
            newMeal.monounsaturatedFat = mono
            newMeal.polyunsaturatedFat = poly
            newMeal.saturatedFat = sat
            newMeal.transFat = trans
            newMeal.date = date
        }

        do {
            try context.save()
            dismiss()
        } catch {
            print("Failed to save meal: \(error)")
        }
    }
}

private struct NumericField: View {
    let titleKey: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .decimalPad

    var body: some View {
        TextField(NSLocalizedString(titleKey, comment: titleKey), text: $text)
            .keyboardType(keyboard)
            .multilineTextAlignment(.trailing)
            .submitLabel(.done)
    }
}

private extension Double {
    var cleanString: String {
        truncatingRemainder(dividingBy: 1) == 0 ? String(Int(self)) : String(self)
    }
}

#Preview {
    let controller = PersistenceController(inMemory: true)
    let context = controller.container.viewContext

    if #available(iOS 16.0, *) {
        return NavigationStack {
            MealFormView()
                .environment(\.managedObjectContext, context)
        }
    } else {
        return NavigationView {
            MealFormView()
                .environment(\.managedObjectContext, context)
        }
    }
}
