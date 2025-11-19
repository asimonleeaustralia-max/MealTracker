//
//  MealFormView.swift
//  MealTracker
//
//  Created by Simon Lee on 17/11/2025.
//

import SwiftUI
import CoreData
import CoreLocation

struct MealFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context

    // App settings
    @AppStorage("energyUnit") private var energyUnit: EnergyUnit = .calories
    @AppStorage("measurementSystem") private var measurementSystem: MeasurementSystem = .metric
    @AppStorage("appLanguageCode") private var appLanguageCode: String = LocalizationManager.defaultLanguageCode

    // Hidden title/date inputs removed from UI; we still keep local state for default title logic
    @State private var mealDescription: String = "" // not shown in UI
    // Numeric inputs
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

    // Accuracy flags (default Accurate = false for "isGuess")
    @State private var caloriesIsGuess = false
    @State private var carbohydratesIsGuess = false
    @State private var proteinIsGuess = false
    @State private var saltIsGuess = false
    @State private var fatIsGuess = false
    @State private var starchIsGuess = false
    @State private var sugarsIsGuess = false
    @State private var fibreIsGuess = false
    @State private var monounsaturatedFatIsGuess = false
    @State private var polyunsaturatedFatIsGuess = false
    @State private var saturatedFatIsGuess = false
    @State private var transFatIsGuess = false

    // We won’t show date picker; date will be set on save
    @State private var date: Date = Date()

    // Location manager (no visible UI; we’ll request permission and keep last location)
    @StateObject private var locationManager = LocationManager()

    // Settings presentation
    @State private var showingSettings = false

    var meal: Meal?

    init(meal: Meal? = nil) {
        self.meal = meal
    }

    var isEditing: Bool { meal != nil }

    var body: some View {
        let l = LocalizationManager(languageCode: appLanguageCode)

        Form {
            Section(header: LocalizedText("nutrition", manager: l)) {
                MetricField(titleKey: "calories", text: numericBinding($calories), isGuess: $caloriesIsGuess, keyboard: .decimalPad, manager: l, unitSuffix: energyUnit.displaySuffix(manager: l))
                MetricField(titleKey: "carbohydrates", text: numericBinding($carbohydrates), isGuess: $carbohydratesIsGuess, manager: l)
                MetricField(titleKey: "protein", text: numericBinding($protein), isGuess: $proteinIsGuess, manager: l)
                MetricField(titleKey: "fat", text: numericBinding($fat), isGuess: $fatIsGuess, manager: l)
                MetricField(titleKey: "salt", text: numericBinding($salt), isGuess: $saltIsGuess, manager: l)

                // Added fields for new attributes
                MetricField(titleKey: "starch", text: numericBinding($starch), isGuess: $starchIsGuess, manager: l)
                MetricField(titleKey: "sugars", text: numericBinding($sugars), isGuess: $sugarsIsGuess, manager: l)
                MetricField(titleKey: "fibre", text: numericBinding($fibre), isGuess: $fibreIsGuess, manager: l)

                // Fat breakdown
                MetricField(titleKey: "monounsaturated_fat", text: numericBinding($monounsaturatedFat), isGuess: $monounsaturatedFatIsGuess, manager: l)
                MetricField(titleKey: "polyunsaturated_fat", text: numericBinding($polyunsaturatedFat), isGuess: $polyunsaturatedFatIsGuess, manager: l)
                MetricField(titleKey: "saturated_fat", text: numericBinding($saturatedFat), isGuess: $saturatedFatIsGuess, manager: l)
                MetricField(titleKey: "trans_fat", text: numericBinding($transFat), isGuess: $transFatIsGuess, manager: l)
            }
        }
        // No navigationTitle to keep the first page clean
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(l.localized("cancel")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(l.localized("save")) {
                    save()
                }
                .disabled(!isValid)
                .accessibilityIdentifier("saveMealButton")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(l.localized("settings"))
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onAppear {
            if let meal = meal {
                // Populate existing values
                mealDescription = meal.mealDescription
                calories = meal.calories.cleanString
                carbohydrates = meal.carbohydrates.cleanString
                protein = meal.protein.cleanString
                salt = meal.salt.cleanString
                fat = meal.fat.cleanString
                starch = meal.starch.cleanString
                sugars = meal.sugars.cleanString
                fibre = meal.fibre.cleanString
                monounsaturatedFat = meal.monounsaturatedFat.cleanString
                polyunsaturatedFat = meal.polyunsaturatedFat.cleanString
                saturatedFat = meal.saturatedFat.cleanString
                transFat = meal.transFat.cleanString
                date = meal.date

                // Load guess flags
                caloriesIsGuess = meal.caloriesIsGuess
                carbohydratesIsGuess = meal.carbohydratesIsGuess
                proteinIsGuess = meal.proteinIsGuess
                saltIsGuess = meal.saltIsGuess
                fatIsGuess = meal.fatIsGuess
                starchIsGuess = meal.starchIsGuess
                sugarsIsGuess = meal.sugarsIsGuess
                fibreIsGuess = meal.fibreIsGuess
                monounsaturatedFatIsGuess = meal.monounsaturatedFatIsGuess
                polyunsaturatedFatIsGuess = meal.polyunsaturatedFatIsGuess
                saturatedFatIsGuess = meal.saturatedFatIsGuess
                transFatIsGuess = meal.transFatIsGuess
            }

            // Start location so we have a fix at save time (no UI shown)
            locationManager.requestAuthorization()
            locationManager.startUpdating()
        }
    }

    // Only calories are required
    private var isValid: Bool {
        Double(calories) != nil
    }

    private func doubleOrZero(_ text: String) -> Double {
        Double(text) ?? 0
    }

    // Default title used when user didn’t enter one; editable later in history screen
    private func defaultTitle(using date: Date) -> String {
        if !mealDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return mealDescription
        }
        // Use English fallback for default title; you can also localize this literal if desired
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Meal on \(formatter.string(from: date))"
    }

    private func save() {
        guard let cal = Double(calories) else { return }

        let carbs = doubleOrZero(carbohydrates)
        let prot = doubleOrZero(protein)
        let s = doubleOrZero(salt)
        let f = doubleOrZero(fat)
        let sta = doubleOrZero(starch)
        let sug = doubleOrZero(sugars)
        let fib = doubleOrZero(fibre)
        let mono = doubleOrZero(monounsaturatedFat)
        let poly = doubleOrZero(polyunsaturatedFat)
        let sat = doubleOrZero(saturatedFat)
        let trans = doubleOrZero(transFat)

        // Capture now for default title and date
        let now = Date()

        if let meal = meal {
            meal.mealDescription = defaultTitle(using: meal.date)
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

            // Persist guess flags
            meal.caloriesIsGuess = caloriesIsGuess
            meal.carbohydratesIsGuess = carbohydratesIsGuess
            meal.proteinIsGuess = proteinIsGuess
            meal.saltIsGuess = saltIsGuess
            meal.fatIsGuess = fatIsGuess
            meal.starchIsGuess = starchIsGuess
            meal.sugarsIsGuess = sugarsIsGuess
            meal.fibreIsGuess = fibreIsGuess
            meal.monounsaturatedFatIsGuess = monounsaturatedFatIsGuess
            meal.polyunsaturatedFatIsGuess = polyunsaturatedFatIsGuess
            meal.saturatedFatIsGuess = saturatedFatIsGuess
            meal.transFatIsGuess = transFatIsGuess

            if let loc = locationManager.lastLocation {
                meal.setValue(loc.coordinate.latitude, forKey: "latitude")
                meal.setValue(loc.coordinate.longitude, forKey: "longitude")
            }
        } else {
            let newMeal = Meal(context: context)
            newMeal.id = UUID()
            newMeal.date = now
            newMeal.mealDescription = defaultTitle(using: now)

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

            newMeal.caloriesIsGuess = caloriesIsGuess
            newMeal.carbohydratesIsGuess = carbohydratesIsGuess
            newMeal.proteinIsGuess = proteinIsGuess
            newMeal.saltIsGuess = saltIsGuess
            newMeal.fatIsGuess = fatIsGuess
            newMeal.starchIsGuess = starchIsGuess
            newMeal.sugarsIsGuess = sugarsIsGuess
            newMeal.fibreIsGuess = fibreIsGuess
            newMeal.monounsaturatedFatIsGuess = monounsaturatedFatIsGuess
            newMeal.polyunsaturatedFatIsGuess = polyunsaturatedFatIsGuess
            newMeal.saturatedFatIsGuess = saturatedFatIsGuess
            newMeal.transFatIsGuess = transFatIsGuess

            if let loc = locationManager.lastLocation {
                newMeal.setValue(loc.coordinate.latitude, forKey: "latitude")
                newMeal.setValue(loc.coordinate.longitude, forKey: "longitude")
            }
        }

        do {
            try context.save()
            dismiss()
        } catch {
            print("Failed to save meal: \(error)")
        }
    }

    private func numericBinding(_ source: Binding<String>) -> Binding<String> {
        Binding(
            get: { source.wrappedValue },
            set: { newValue in
                source.wrappedValue = sanitizeNumericInput(newValue)
            }
        )
    }

    private func sanitizeNumericInput(_ input: String) -> String {
        let decimalSeparator = Locale.current.decimalSeparator ?? "."
        var result = ""
        var hasDecimal = false

        for ch in input {
            if ch.isNumber {
                result.append(ch)
            } else if String(ch) == decimalSeparator {
                if !hasDecimal {
                    if result.isEmpty { result = "0" }
                    result.append(decimalSeparator)
                    hasDecimal = true
                }
            } else {
                continue
            }
        }

        if !hasDecimal {
            if result.count > 1, result.allSatisfy({ $0 == "0" }) {
                result = "0"
            }
        }
        return result
    }
}

enum EnergyUnit: String, CaseIterable, Codable {
    case calories
    case kilojoules

    func displaySuffix(manager: LocalizationManager) -> String {
        switch self {
        case .calories: return manager.localized("kcal_suffix") // e.g., "kcal"
        case .kilojoules: return manager.localized("kj_suffix") // e.g., "kJ"
        }
    }
}

enum MeasurementSystem: String, CaseIterable, Codable {
    case metric
    case imperial
}

private struct MetricField: View {
    let titleKey: String
    @Binding var text: String
    @Binding var isGuess: Bool
    var keyboard: UIKeyboardType = .decimalPad
    let manager: LocalizationManager
    var unitSuffix: String? = nil

    private var tintColor: Color {
        isGuess ? .orange : .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                LocalizedText(titleKey, manager: manager)
                Spacer()
                TextField("", text: $text)
                    .keyboardType(keyboard)
                    .multilineTextAlignment(.trailing)
                    .submitLabel(.done)
                    .frame(maxWidth: 140)
                if let suffix = unitSuffix {
                    Text(suffix).foregroundStyle(.secondary)
                }
            }

            Picker("", selection: $isGuess) {
                Text(manager.localized("accurate")).tag(false)
                Text(manager.localized("guess")).tag(true)
            }
            .pickerStyle(.segmented)
            .tint(tintColor)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(manager.localized(titleKey))
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
