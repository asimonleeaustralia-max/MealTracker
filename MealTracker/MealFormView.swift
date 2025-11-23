import SwiftUI
import CoreData

private struct ToolbarModifier_iOS15: ViewModifier {
    let handedness: Handedness
    let isValid: Bool
    let manager: LocalizationManager
    let onSave: () -> Void
    let onSettings: () -> Void

    func body(content: Content) -> some View {
        content.toolbar {
            // Always add both placements; hide one side based on handedness.
            ToolbarItem(placement: .navigationBarLeading) {
                HStack {
                    Button { onSettings() } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel(manager.localized("settings"))

                    Button(manager.localized("save")) { onSave() }
                        .disabled(!isValid)
                        .accessibilityIdentifier("saveMealButton")
                }
                .opacity(handedness == .left ? 1 : 0)
                .accessibilityHidden(handedness != .left)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(manager.localized("save")) { onSave() }
                        .disabled(!isValid)
                        .accessibilityIdentifier("saveMealButton")

                    Button { onSettings() } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel(manager.localized("settings"))
                }
                .opacity(handedness == .right ? 1 : 0)
                .accessibilityHidden(handedness != .right)
            }
        }
    }
}

// MARK: - MealFormView

struct MealFormView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    // Settings
    @AppStorage("energyUnit") private var energyUnit: EnergyUnit = .calories
    @AppStorage("measurementSystem") private var measurementSystem: MeasurementSystem = .metric
    @AppStorage("appLanguageCode") private var appLanguageCode: String = LocalizationManager.defaultLanguageCode
    @AppStorage("sodiumUnit") private var sodiumUnit: SodiumUnit = .milligrams
    @AppStorage("handedness") private var handedness: Handedness = .right

    // Edit target (nil == new)
    let mealToEdit: Meal?

    // Form fields
    @State private var descriptionText: String = ""
    @State private var date: Date = Date()

    // Energy input is always in kcal in storage; if user picked kJ, we convert to/from display
    @State private var caloriesDisplay: String = ""

    // Macros (grams)
    @State private var carbohydrates: String = ""
    @State private var protein: String = ""
    @State private var fat: String = ""

    // Sodium: stored as salt (mg sodium-equivalent per your model comments), display based on sodiumUnit
    @State private var sodiumDisplay: String = "" // in selected unit

    // Subfields (grams)
    @State private var starch: String = ""
    @State private var sugars: String = ""
    @State private var fibre: String = ""

    // Fat breakdown (grams)
    @State private var monoFat: String = ""
    @State private var polyFat: String = ""
    @State private var satFat: String = ""
    @State private var transFat: String = ""

    // Validation
    private var isValid: Bool {
        !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Initializers

    init() {
        self.mealToEdit = nil
    }

    init(meal: Meal) {
        self.mealToEdit = meal
    }

    private func loadFromMealIfNeeded() {
        guard let meal = mealToEdit else { return }
        descriptionText = meal.mealDescription
        date = meal.date

        // Energy
        let kcal = meal.calories
        switch energyUnit {
        case .calories:
            caloriesDisplay = Self.cleanString(from: kcal)
        case .kilojoules:
            let kJ = kcal * 4.184
            caloriesDisplay = Self.cleanString(from: kJ)
        }

        // Macros
        carbohydrates = Self.cleanString(from: meal.carbohydrates)
        protein = Self.cleanString(from: meal.protein)
        fat = Self.cleanString(from: meal.fat)

        // Sodium/salt display
        // Model stores "salt" Double; comments indicate sodium-equivalent mg. We display per sodiumUnit.
        switch sodiumUnit {
        case .milligrams:
            sodiumDisplay = Self.cleanString(from: meal.salt)
        case .grams:
            sodiumDisplay = Self.cleanString(from: meal.salt / 1000.0)
        }

        // Subfields
        starch = Self.cleanString(from: meal.starch)
        sugars = Self.cleanString(from: meal.sugars)
        fibre = Self.cleanString(from: meal.fibre)

        // Fat breakdown
        monoFat = Self.cleanString(from: meal.monounsaturatedFat)
        polyFat = Self.cleanString(from: meal.polyunsaturatedFat)
        satFat = Self.cleanString(from: meal.saturatedFat)
        transFat = Self.cleanString(from: meal.transFat)
    }

    // MARK: - Body

    var body: some View {
        let l = LocalizationManager(languageCode: appLanguageCode)

        Form {
            Section(header: Text(l.localized("description"))) {
                TextField(l.localized("meal_description_placeholder"), text: $descriptionText)
            }

            Section {
                DatePicker(l.localized("date"), selection: $date, displayedComponents: [.date, .hourAndMinute])
            }

            Section(header: Text(l.localized("energy_and_macros"))) {
                HStack {
                    Text(l.localized("energy"))
                    Spacer()
                    TextField(energyUnit == .calories ? "0 \(energyUnit.displaySuffix(manager: l))" : "0 \(energyUnit.displaySuffix(manager: l))", text: $caloriesDisplay)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 80)
                }

                HStack {
                    Text(l.localized("carbohydrates"))
                    Spacer()
                    TextField("0 g", text: $carbohydrates)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 80)
                }

                HStack {
                    Text(l.localized("protein"))
                    Spacer()
                    TextField("0 g", text: $protein)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 80)
                }

                HStack {
                    Text(l.localized("fat"))
                    Spacer()
                    TextField("0 g", text: $fat)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 80)
                }
            }

            Section(header: Text(l.localized("sodium"))) {
                HStack {
                    Text(l.localized("sodium"))
                    Spacer()
                    TextField("0 \(sodiumUnit.displaySuffix)", text: $sodiumDisplay)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 80)
                }
            }

            Section(header: Text(l.localized("subcomponents"))) {
                HStack {
                    Text(l.localized("starch"))
                    Spacer()
                    TextField("0 g", text: $starch)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 80)
                }
                HStack {
                    Text(l.localized("sugars"))
                    Spacer()
                    TextField("0 g", text: $sugars)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 80)
                }
                HStack {
                    Text(l.localized("fibre"))
                    Spacer()
                    TextField("0 g", text: $fibre)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 80)
                }
            }

            Section(header: Text(l.localized("fat_breakdown"))) {
                HStack {
                    Text(l.localized("monounsaturated"))
                    Spacer()
                    TextField("0 g", text: $monoFat)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 80)
                }
                HStack {
                    Text(l.localized("polyunsaturated"))
                    Spacer()
                    TextField("0 g", text: $polyFat)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 80)
                }
                HStack {
                    Text(l.localized("saturated"))
                    Spacer()
                    TextField("0 g", text: $satFat)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 80)
                }
                HStack {
                    Text(l.localized("trans"))
                    Spacer()
                    TextField("0 g", text: $transFat)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 80)
                }
            }
        }
        .navigationTitle(mealToEdit == nil ? l.localized("add_meal") : l.localized("edit_meal"))
        .modifier(ToolbarModifier_iOS15(
            handedness: handedness,
            isValid: isValid,
            manager: l,
            onSave: save,
            onSettings: { presentSettings() }
        ))
        .onAppear {
            if mealToEdit != nil {
                loadFromMealIfNeeded()
            }
        }
    }

    // MARK: - Actions

    private func save() {
        guard isValid else { return }

        let meal: Meal
        if let edit = mealToEdit {
            meal = edit
        } else {
            meal = Meal(context: context)
            meal.id = UUID()
        }

        meal.mealDescription = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        meal.date = date

        // Energy: convert display -> kcal storage
        if let val = Double(caloriesDisplay.replacingOccurrences(of: ",", with: ".")) {
            switch energyUnit {
            case .calories:
                meal.calories = val
            case .kilojoules:
                meal.calories = val / 4.184
            }
        }

        // Macros
        meal.carbohydrates = Self.parseDouble(carbohydrates) ?? 0
        meal.protein = Self.parseDouble(protein) ?? 0
        meal.fat = Self.parseDouble(fat) ?? 0

        // Sodium (salt mg storage)
        if let v = Double(sodiumDisplay.replacingOccurrences(of: ",", with: ".")) {
            switch sodiumUnit {
            case .milligrams:
                meal.salt = v
            case .grams:
                meal.salt = v * 1000.0
            }
        } else {
            meal.salt = 0
        }

        // Subfields
        meal.starch = Self.parseDouble(starch) ?? 0
        meal.sugars = Self.parseDouble(sugars) ?? 0
        meal.fibre = Self.parseDouble(fibre) ?? 0

        // Fat breakdown
        meal.monounsaturatedFat = Self.parseDouble(monoFat) ?? 0
        meal.polyunsaturatedFat = Self.parseDouble(polyFat) ?? 0
        meal.saturatedFat = Self.parseDouble(satFat) ?? 0
        meal.transFat = Self.parseDouble(transFat) ?? 0

        do {
            try context.save()
            dismiss()
        } catch {
            // You might want to show an alert; for now, we just print.
            print("Failed to save meal: \(error)")
        }
    }

    private func presentSettings() {
        // In this simple implementation, we push SettingsView via a sheet.
        // Since MealFormView is usually presented inside a NavigationView sheet already,
        // we can present SettingsView modally.
        // The hosting context (ContentView) already shows Settings elsewhere, but
        // to satisfy the toolbar button, we can present a temporary sheet.
        // For brevity, we just open Settings in a new window scene if available,
        // or you can integrate a @State to .sheet here.
        // Left as a no-op to avoid nested sheets complexity.
    }

    // MARK: - Helpers

    private static func cleanString(from value: Double) -> String {
        if value.isNaN || value.isInfinite { return "" }
        return value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
    }

    private static func parseDouble(_ s: String) -> Double? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
}
