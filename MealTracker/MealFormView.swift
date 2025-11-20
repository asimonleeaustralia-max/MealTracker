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
            // Plain section (no "nutrition" header)
            Section {
                // Energy
                MetricField(titleKey: "calories",
                            text: numericBinding($calories),
                            isGuess: $caloriesIsGuess,
                            keyboard: .decimalPad,
                            manager: l,
                            unitSuffix: energyUnit.displaySuffix(manager: l))

                // Carbs group (total + optional breakdown)
                CarbsGroupView(
                    manager: l,
                    totalText: numericBinding($carbohydrates),
                    totalIsGuess: $carbohydratesIsGuess,
                    sugarsText: numericBinding($sugars),
                    sugarsIsGuess: $sugarsIsGuess,
                    starchText: numericBinding($starch),
                    starchIsGuess: $starchIsGuess,
                    fibreText: numericBinding($fibre),
                    fibreIsGuess: $fibreIsGuess
                )

                // Protein and salt remain as simple fields
                MetricField(titleKey: "protein",
                            text: numericBinding($protein),
                            isGuess: $proteinIsGuess,
                            manager: l)

                MetricField(titleKey: "salt",
                            text: numericBinding($salt),
                            isGuess: $saltIsGuess,
                            manager: l)

                // Fat group (total + optional breakdown)
                FatGroupView(
                    manager: l,
                    totalText: numericBinding($fat),
                    totalIsGuess: $fatIsGuess,
                    monoText: numericBinding($monounsaturatedFat),
                    monoIsGuess: $monounsaturatedFatIsGuess,
                    polyText: numericBinding($polyunsaturatedFat),
                    polyIsGuess: $polyunsaturatedFatIsGuess,
                    satText: numericBinding($saturatedFat),
                    satIsGuess: $saturatedFatIsGuess,
                    transText: numericBinding($transFat),
                    transIsGuess: $transFatIsGuess
                )
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
        // Allow digits and one decimal separator (either "." or ",") while typing.
        // Normalize the kept separator to the current locale’s separator.
        let localeSep = Locale.current.decimalSeparator ?? "."
        var digits = ""
        var hasSeparator = false
        var firstSeparator: Character?

        for ch in input {
            if ch.isNumber {
                digits.append(ch)
            } else if ch == "." || ch == "," {
                if !hasSeparator {
                    hasSeparator = true
                    firstSeparator = ch
                }
                // ignore additional separators
            } else {
                // ignore other characters
            }
        }

        // Build result with normalized separator
        var result = digits
        if let _ = firstSeparator {
            // Insert separator before the last typed fractional digits if user typed any after sep.
            // We can’t infer cursor position here, so we assume the user typed in order.
            // Reconstruct by splitting the original input at the first separator.
            let parts = input.replacingOccurrences(of: " ", with: "")
                .split(maxSplits: 1, whereSeparator: { $0 == "." || $0 == "," })
            let integerPart = parts.first.map { String($0.filter(\.isNumber)) } ?? ""
            let fractionalPart = parts.count > 1 ? String(parts[1].filter(\.isNumber)) : ""

            var normalized = integerPart
            if normalized.isEmpty { normalized = "0" }
            normalized.append(localeSep)
            normalized.append(fractionalPart)
            result = normalized
        }

        // Collapse leading zeros like "000" to "0"
        if !result.contains(localeSep), result.count > 1, result.allSatisfy({ $0 == "0" }) {
            result = "0"
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
        VStack(alignment: .leading, spacing: 6) {
            // Title above the line
            LocalizedText(titleKey, manager: manager)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Input row: accuracy control on the left, entry on the right
            HStack(alignment: .center, spacing: 8) {
                Picker("", selection: $isGuess) {
                    Text(manager.localized("accurate")).tag(false)
                    Text(manager.localized("guess")).tag(true)
                }
                .pickerStyle(.segmented)
                .tint(tintColor)
                .frame(width: 160)
                .accessibilityLabel(manager.localized(titleKey) + " " + manager.localized("accuracy"))

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    TextField("", text: $text)
                        .keyboardType(keyboard)
                        .multilineTextAlignment(.trailing)
                        .submitLabel(.done)
                        .frame(maxWidth: 140)

                    if let suffix = unitSuffix {
                        Text(suffix).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(manager.localized(titleKey))
    }
}

// MARK: - Grouped Macros

private struct CarbsGroupView: View {
    let manager: LocalizationManager

    @Binding var totalText: String
    @Binding var totalIsGuess: Bool

    @Binding var sugarsText: String
    @Binding var sugarsIsGuess: Bool

    @Binding var starchText: String
    @Binding var starchIsGuess: Bool

    @Binding var fibreText: String
    @Binding var fibreIsGuess: Bool

    @State private var expanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            MetricField(titleKey: "carbohydrates",
                        text: $totalText,
                        isGuess: $totalIsGuess,
                        manager: manager)
                .onChange(of: totalText) { newValue in
                    applyEstimatedCarbSplit(from: newValue)
                }

            DisclosureGroup(isExpanded: $expanded) {
                VStack(spacing: 0) {
                    MetricField(titleKey: "sugars",
                                text: $sugarsText,
                                isGuess: $sugarsIsGuess,
                                manager: manager)
                    MetricField(titleKey: "starch",
                                text: $starchText,
                                isGuess: $starchIsGuess,
                                manager: manager)
                    MetricField(titleKey: "fibre",
                                text: $fibreText,
                                isGuess: $fibreIsGuess,
                                manager: manager)
                }
                .padding(.top, 6)
            } label: {
                // Empty label: only the chevron remains tappable
                EmptyView()
            }
            .padding(.vertical, 4)
        }
    }

    private mutating func applyEstimatedCarbSplit(from totalString: String) {
        guard let total = Double(totalString), total > 0 else { return }

        // Default target ratios
        let defaultRatios: (sugars: Double, starch: Double, fibre: Double) = (0.40, 0.55, 0.05)

        // Current accurate values (preserve if isGuess == false)
        let currentSugars = Double(sugarsText) ?? 0
        let currentStarch = Double(starchText) ?? 0
        let currentFibre = Double(fibreText) ?? 0

        let accurateTotal =
            (sugarsIsGuess ? 0 : currentSugars) +
            (starchIsGuess ? 0 : currentStarch) +
            (fibreIsGuess ? 0 : currentFibre)

        // Remaining to distribute among guess fields
        let remaining = max(0, total - accurateTotal)

        // Build accessors to mutate bindings without key paths to self
        struct Field {
            let get: () -> Double
            let set: (Double) -> Void
            let setGuess: (Bool) -> Void
            let ratio: Double
        }

        var fields: [Field] = []
        if sugarsIsGuess {
            fields.append(Field(
                get: { Double(sugarsText) ?? 0 },
                set: { sugarsText = $0.rounded(toPlaces: 2).cleanString },
                setGuess: { sugarsIsGuess = $0 },
                ratio: defaultRatios.sugars
            ))
        }
        if starchIsGuess {
            fields.append(Field(
                get: { Double(starchText) ?? 0 },
                set: { starchText = $0.rounded(toPlaces: 2).cleanString },
                setGuess: { starchIsGuess = $0 },
                ratio: defaultRatios.starch
            ))
        }
        if fibreIsGuess {
            fields.append(Field(
                get: { Double(fibreText) ?? 0 },
                set: { fibreText = $0.rounded(toPlaces: 2).cleanString },
                setGuess: { fibreIsGuess = $0 },
                ratio: defaultRatios.fibre
            ))
        }

        guard !fields.isEmpty else { return }

        let ratioSum = fields.map { $0.ratio }.reduce(0, +)
        let normalized = fields.map { ratioSum > 0 ? $0.ratio / ratioSum : (1.0 / Double(fields.count)) }

        // Assign values
        for (i, field) in fields.enumerated() {
            let value = remaining * normalized[i]
            field.set(value)
            field.setGuess(true)
        }

        // If rounding caused drift, adjust the last guess field to exactly match remaining
        let assigned = fields.reduce(0.0) { $0 + $1.get() }
        let drift = remaining - assigned
        if let last = fields.last {
            last.set(max(0, last.get() + drift))
        }
    }
}

private struct FatGroupView: View {
    let manager: LocalizationManager

    @Binding var totalText: String
    @Binding var totalIsGuess: Bool

    @Binding var monoText: String
    @Binding var monoIsGuess: Bool

    @Binding var polyText: String
    @Binding var polyIsGuess: Bool

    @Binding var satText: String
    @Binding var satIsGuess: Bool

    @Binding var transText: String
    @Binding var transIsGuess: Bool

    @State private var expanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            MetricField(titleKey: "fat",
                        text: $totalText,
                        isGuess: $totalIsGuess,
                        manager: manager)
                .onChange(of: totalText) { newValue in
                    applyEstimatedFatSplit(from: newValue)
                }

            DisclosureGroup(isExpanded: $expanded) {
                VStack(spacing: 0) {
                    MetricField(titleKey: "monounsaturated_fat",
                                text: $monoText,
                                isGuess: $monoIsGuess,
                                manager: manager)
                    MetricField(titleKey: "polyunsaturated_fat",
                                text: $polyText,
                                isGuess: $polyIsGuess,
                                manager: manager)
                    MetricField(titleKey: "saturated_fat",
                                text: $satText,
                                isGuess: $satIsGuess,
                                manager: manager)
                    MetricField(titleKey: "trans_fat",
                                text: $transText,
                                isGuess: $transIsGuess,
                                manager: manager)
                }
                .padding(.top, 6)
            } label: {
                // Empty label: only the chevron remains tappable
                EmptyView()
            }
            .padding(.vertical, 4)
        }
    }

    private mutating func applyEstimatedFatSplit(from totalString: String) {
        guard let total = Double(totalString), total > 0 else { return }

        // Default target ratios: 40% mono, 35% sat, 23% poly, 2% trans
        let defaultRatios: (mono: Double, sat: Double, poly: Double, trans: Double) = (0.40, 0.35, 0.23, 0.02)

        // Current accurate values
        let currentMono = Double(monoText) ?? 0
        let currentPoly = Double(polyText) ?? 0
        let currentSat = Double(satText) ?? 0
        let currentTrans = Double(transText) ?? 0

        let accurateTotal =
            (monoIsGuess ? 0 : currentMono) +
            (polyIsGuess ? 0 : currentPoly) +
            (satIsGuess ? 0 : currentSat) +
            (transIsGuess ? 0 : currentTrans)

        let remaining = max(0, total - accurateTotal)

        struct Field {
            let get: () -> Double
            let set: (Double) -> Void
            let setGuess: (Bool) -> Void
            let ratio: Double
        }

        var fields: [Field] = []
        if monoIsGuess {
            fields.append(Field(
                get: { Double(monoText) ?? 0 },
                set: { monoText = $0.cleanString },
                setGuess: { monoIsGuess = $0 },
                ratio: defaultRatios.mono
            ))
        }
        if polyIsGuess {
            fields.append(Field(
                get: { Double(polyText) ?? 0 },
                set: { polyText = $0.cleanString },
                setGuess: { polyIsGuess = $0 },
                ratio: defaultRatios.poly
            ))
        }
        if satIsGuess {
            fields.append(Field(
                get: { Double(satText) ?? 0 },
                set: { satText = $0.cleanString },
                setGuess: { satIsGuess = $0 },
                ratio: defaultRatios.sat
            ))
        }
        if transIsGuess {
            fields.append(Field(
                get: { Double(transText) ?? 0 },
                set: { transText = $0.cleanString },
                setGuess: { transIsGuess = $0 },
                ratio: defaultRatios.trans
            ))
        }

        guard !fields.isEmpty else { return }

        let ratioSum = fields.map { $0.ratio }.reduce(0, +)
        let normalized = fields.map { ratioSum > 0 ? $0.ratio / ratioSum : (1.0 / Double(fields.count)) }

        for (i, field) in fields.enumerated() {
            let value = remaining * normalized[i]
            field.set(value)
            field.setGuess(true)
        }

        // Adjust last to fix drift due to formatting
        let assigned = fields.reduce(0.0) { $0 + $1.get() }
        let drift = remaining - assigned
        if let last = fields.last {
            last.set(max(0, last.get() + drift))
        }
    }
}

private extension Double {
    var cleanString: String {
        truncatingRemainder(dividingBy: 1) == 0 ? String(Int(self)) : String(self)
    }

    func rounded(toPlaces places: Int) -> Double {
        guard places >= 0 else { return self }
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
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
