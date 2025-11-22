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
    @AppStorage("sodiumUnit") private var sodiumUnit: SodiumUnit = .milligrams
    @AppStorage("showVitamins") private var showVitamins: Bool = false
    @AppStorage("vitaminsUnit") private var vitaminsUnit: VitaminsUnit = .milligrams
    @AppStorage("showMinerals") private var showMinerals: Bool = false

    // Hidden title/date inputs removed from UI; we still keep local state for default title logic
    @State private var mealDescription: String = "" // not shown in UI
    // Numeric inputs
    @State private var calories: String = ""
    @State private var carbohydrates: String = ""
    @State private var protein: String = ""
    @State private var sodium: String = ""          // renamed from salt for UI
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
    // New protein breakdown fields
    @State private var animalProtein: String = ""
    @State private var plantProtein: String = ""
    @State private var proteinSupplements: String = ""
    // Vitamins (UI text values; storage is mg, conversion applied)
    @State private var vitaminA: String = ""
    @State private var vitaminB: String = ""
    @State private var vitaminC: String = ""
    @State private var vitaminD: String = ""
    @State private var vitaminE: String = ""
    @State private var vitaminK: String = ""
    // Minerals (UI text values; storage is mg, conversion applied)
    @State private var calcium: String = ""
    @State private var iron: String = ""
    @State private var potassium: String = ""
    @State private var zinc: String = ""
    @State private var magnesium: String = ""

    // Accuracy flags: default Guess = true
    @State private var caloriesIsGuess = true
    @State private var carbohydratesIsGuess = true
    @State private var proteinIsGuess = true
    @State private var sodiumIsGuess = true
    @State private var fatIsGuess = true
    @State private var starchIsGuess = true
    @State private var sugarsIsGuess = true
    @State private var fibreIsGuess = true
    @State private var monounsaturatedFatIsGuess = true
    @State private var polyunsaturatedFatIsGuess = true
    @State private var saturatedFatIsGuess = true
    @State private var transFatIsGuess = true
    // Protein breakdown flags
    @State private var animalProteinIsGuess = true
    @State private var plantProteinIsGuess = true
    @State private var proteinSupplementsIsGuess = true
    // Vitamins guess flags
    @State private var vitaminAIsGuess = true
    @State private var vitaminBIsGuess = true
    @State private var vitaminCIsGuess = true
    @State private var vitaminDIsGuess = true
    @State private var vitaminEIsGuess = true
    @State private var vitaminKIsGuess = true
    // Minerals guess flags
    @State private var calciumIsGuess = true
    @State private var ironIsGuess = true
    @State private var potassiumIsGuess = true
    @State private var zincIsGuess = true
    @State private var magnesiumIsGuess = true

    // We won’t show date picker; date will be set on save
    @State private var date: Date = Date()

    // Location manager
    @StateObject private var locationManager = LocationManager()

    // Settings presentation
    @State private var showingSettings = false

    // Expand/collapse state (per session, compatible with older iOS)
    @State private var expandedCarbs = false
    @State private var expandedProtein = false
    @State private var expandedFat = false
    @State private var expandedVitamins = false
    @State private var expandedMinerals = false

    var meal: Meal?

    init(meal: Meal? = nil) {
        self.meal = meal
    }

    var isEditing: Bool { meal != nil }

    var body: some View {
        let l = LocalizationManager(languageCode: appLanguageCode)

        Form {
            // Energy
            Section(header: LocalizedText("energy", manager: l)) {
                MetricField(
                    titleKey: caloriesTitleWithUnit(manager: l),
                    text: numericBinding($calories),
                    isGuess: $caloriesIsGuess,
                    keyboard: .decimalPad,
                    manager: l,
                    unitSuffix: energyUnit.displaySuffix(manager: l),
                    isPrelocalizedTitle: true,
                    isError: { value in
                        let kcal = (energyUnit == .calories) ? value : value / 4.184
                        return kcal > 3000.0
                    }
                )
            }

            // Carbohydrates
            Section(header: LocalizedText("carbohydrates", manager: l)) {
                MetricField(titleKey: "carbohydrates", text: numericBinding($carbohydrates), isGuess: $carbohydratesIsGuess, manager: l, unitSuffix: "g")

                ToggleDetailsButton(isExpanded: $expandedCarbs, titleCollapsed: l.localized("show_details"), titleExpanded: l.localized("hide_details"))

                if expandedCarbs {
                    CarbsSubFields(manager: l,
                                   sugarsText: numericBinding($sugars), sugarsIsGuess: $sugarsIsGuess,
                                   starchText: numericBinding($starch), starchIsGuess: $starchIsGuess,
                                   fibreText: numericBinding($fibre), fibreIsGuess: $fibreIsGuess)
                }
            }

            // Protein
            Section(header: LocalizedText("protein", manager: l)) {
                MetricField(titleKey: "protein", text: numericBinding($protein), isGuess: $proteinIsGuess, manager: l, unitSuffix: "g")

                ToggleDetailsButton(isExpanded: $expandedProtein, titleCollapsed: l.localized("show_details"), titleExpanded: l.localized("hide_details"))

                if expandedProtein {
                    ProteinSubFields(manager: l,
                                     animalText: numericBinding($animalProtein), animalIsGuess: $animalProteinIsGuess,
                                     plantText: numericBinding($plantProtein), plantIsGuess: $plantProteinIsGuess,
                                     supplementsText: numericBinding($proteinSupplements), supplementsIsGuess: $proteinSupplementsIsGuess)
                }
            }

            // Sodium
            Section(header: LocalizedText("sodium", manager: l)) {
                MetricField(titleKey: "Sodium",
                            text: numericBinding($sodium),
                            isGuess: $sodiumIsGuess,
                            manager: l,
                            unitSuffix: sodiumUnit.displaySuffix,
                            isPrelocalizedTitle: true)
            }

            // Fat
            Section(header: LocalizedText("fat", manager: l)) {
                MetricField(titleKey: "fat", text: numericBinding($fat), isGuess: $fatIsGuess, manager: l, unitSuffix: "g")

                ToggleDetailsButton(isExpanded: $expandedFat, titleCollapsed: l.localized("show_details"), titleExpanded: l.localized("hide_details"))

                if expandedFat {
                    FatSubFields(manager: l,
                                 monoText: numericBinding($monounsaturatedFat), monoIsGuess: $monounsaturatedFatIsGuess,
                                 polyText: numericBinding($polyunsaturatedFat), polyIsGuess: $polyunsaturatedFatIsGuess,
                                 satText: numericBinding($saturatedFat), satIsGuess: $saturatedFatIsGuess,
                                 transText: numericBinding($transFat), transIsGuess: $transFatIsGuess)
                }
            }

            if showVitamins {
                Section(header: LocalizedText("vitamins", manager: l)) {
                    // No "total" for vitamins, just collapse the whole block
                    ToggleDetailsButton(isExpanded: $expandedVitamins, titleCollapsed: l.localized("show_vitamins"), titleExpanded: l.localized("hide_vitamins"))

                    if expandedVitamins {
                        VitaminsGroupView(
                            manager: l,
                            unitSuffix: vitaminsUnit.displaySuffix,
                            aText: numericBinding($vitaminA), aIsGuess: $vitaminAIsGuess,
                            bText: numericBinding($vitaminB), bIsGuess: $vitaminBIsGuess,
                            cText: numericBinding($vitaminC), cIsGuess: $vitaminCIsGuess,
                            dText: numericBinding($vitaminD), dIsGuess: $vitaminDIsGuess,
                            eText: numericBinding($vitaminE), eIsGuess: $vitaminEIsGuess,
                            kText: numericBinding($vitaminK), kIsGuess: $vitaminKIsGuess
                        )
                    }
                }
            }

            if showMinerals {
                Section(header: LocalizedText("minerals", manager: l)) {
                    ToggleDetailsButton(isExpanded: $expandedMinerals, titleCollapsed: l.localized("show_minerals"), titleExpanded: l.localized("hide_minerals"))

                    if expandedMinerals {
                        MineralsGroupView(
                            manager: l,
                            unitSuffix: vitaminsUnit.displaySuffix, // reuse vitamins unit toggle (mg/µg)
                            calciumText: numericBinding($calcium), calciumIsGuess: $calciumIsGuess,
                            ironText: numericBinding($iron), ironIsGuess: $ironIsGuess,
                            potassiumText: numericBinding($potassium), potassiumIsGuess: $potassiumIsGuess,
                            zincText: numericBinding($zinc), zincIsGuess: $zincIsGuess,
                            magnesiumText: numericBinding($magnesium), magnesiumIsGuess: $magnesiumIsGuess
                        )
                    }
                }
            }
        }
        .toolbar {
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
                mealDescription = meal.mealDescription
                calories = meal.calories.cleanString
                carbohydrates = meal.carbohydrates.cleanString
                protein = meal.protein.cleanString
                sodium = meal.salt.cleanString
                fat = meal.fat.cleanString
                starch = meal.starch.cleanString
                sugars = meal.sugars.cleanString
                fibre = meal.fibre.cleanString
                monounsaturatedFat = meal.monounsaturatedFat.cleanString
                polyunsaturatedFat = meal.polyunsaturatedFat.cleanString
                saturatedFat = meal.saturatedFat.cleanString
                transFat = meal.transFat.cleanString
                animalProtein = meal.animalProtein.cleanString
                plantProtein = meal.plantProtein.cleanString
                proteinSupplements = meal.proteinSupplements.cleanString

                // Vitamins
                vitaminA = vitaminsUnit.fromStorageMG(meal.vitaminA).cleanString
                vitaminB = vitaminsUnit.fromStorageMG(meal.vitaminB).cleanString
                vitaminC = vitaminsUnit.fromStorageMG(meal.vitaminC).cleanString
                vitaminD = vitaminsUnit.fromStorageMG(meal.vitaminD).cleanString
                vitaminE = vitaminsUnit.fromStorageMG(meal.vitaminE).cleanString
                vitaminK = vitaminsUnit.fromStorageMG(meal.vitaminK).cleanString

                // Minerals
                calcium = vitaminsUnit.fromStorageMG(meal.calcium).cleanString
                iron = vitaminsUnit.fromStorageMG(meal.iron).cleanString
                potassium = vitaminsUnit.fromStorageMG(meal.potassium).cleanString
                zinc = vitaminsUnit.fromStorageMG(meal.zinc).cleanString
                magnesium = vitaminsUnit.fromStorageMG(meal.magnesium).cleanString

                date = meal.date

                caloriesIsGuess = meal.caloriesIsGuess
                carbohydratesIsGuess = meal.carbohydratesIsGuess
                proteinIsGuess = meal.proteinIsGuess
                sodiumIsGuess = meal.saltIsGuess
                fatIsGuess = meal.fatIsGuess
                starchIsGuess = meal.starchIsGuess
                sugarsIsGuess = meal.sugarsIsGuess
                fibreIsGuess = meal.fibreIsGuess
                monounsaturatedFatIsGuess = meal.monounsaturatedFatIsGuess
                polyunsaturatedFatIsGuess = meal.polyunsaturatedFatIsGuess
                saturatedFatIsGuess = meal.saturatedFatIsGuess
                transFatIsGuess = meal.transFatIsGuess

                animalProteinIsGuess = meal.animalProteinIsGuess
                plantProteinIsGuess = meal.plantProteinIsGuess
                proteinSupplementsIsGuess = meal.proteinSupplementsIsGuess

                vitaminAIsGuess = meal.vitaminAIsGuess
                vitaminBIsGuess = meal.vitaminBIsGuess
                vitaminCIsGuess = meal.vitaminCIsGuess
                vitaminDIsGuess = meal.vitaminDIsGuess
                vitaminEIsGuess = meal.vitaminEIsGuess
                vitaminKIsGuess = meal.vitaminKIsGuess

                calciumIsGuess = meal.calciumIsGuess
                ironIsGuess = meal.ironIsGuess
                potassiumIsGuess = meal.potassiumIsGuess
                zincIsGuess = meal.zincIsGuess
                magnesiumIsGuess = meal.magnesiumIsGuess
            }

            locationManager.requestAuthorization()
            locationManager.startUpdating()
        }
    }

    private var isValid: Bool {
        guard Double(calories) != nil else { return false }
        let allNumericStrings = [
            calories, carbohydrates, protein, sodium, fat,
            starch, sugars, fibre, monounsaturatedFat, polyunsaturatedFat, saturatedFat, transFat,
            animalProtein, plantProtein, proteinSupplements,
            vitaminA, vitaminB, vitaminC, vitaminD, vitaminE, vitaminK,
            calcium, iron, potassium, zinc, magnesium
        ]
        return allNumericStrings.allSatisfy { s in
            guard let v = Double(s) else { return s.isEmpty }
            return v >= 0
        }
    }

    private func doubleOrZero(_ text: String) -> Double {
        max(0, Double(text) ?? 0)
    }

    private func defaultTitle(using date: Date) -> String {
        if !mealDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return mealDescription
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Meal on \(formatter.string(from: date))"
    }

    private func save() {
        guard let cal = Double(calories) else { return }

        let carbs = doubleOrZero(carbohydrates)
        let prot = doubleOrZero(protein)
        let sod = doubleOrZero(sodium)
        let f = doubleOrZero(fat)
        let sta = doubleOrZero(starch)
        let sug = doubleOrZero(sugars)
        let fib = doubleOrZero(fibre)
        let mono = doubleOrZero(monounsaturatedFat)
        let poly = doubleOrZero(polyunsaturatedFat)
        let sat = doubleOrZero(saturatedFat)
        let trans = doubleOrZero(transFat)
        let animal = doubleOrZero(animalProtein)
        let plant = doubleOrZero(plantProtein)
        let supps = doubleOrZero(proteinSupplements)
        // Vitamins: convert UI -> storage (mg)
        let vA = vitaminsUnit.toStorageMG(doubleOrZero(vitaminA))
        let vB = vitaminsUnit.toStorageMG(doubleOrZero(vitaminB))
        let vC = vitaminsUnit.toStorageMG(doubleOrZero(vitaminC))
        let vD = vitaminsUnit.toStorageMG(doubleOrZero(vitaminD))
        let vE = vitaminsUnit.toStorageMG(doubleOrZero(vitaminE))
        let vK = vitaminsUnit.toStorageMG(doubleOrZero(vitaminK))
        // Minerals: convert UI -> storage (mg) using same unit toggle
        let mCa = vitaminsUnit.toStorageMG(doubleOrZero(calcium))
        let mFe = vitaminsUnit.toStorageMG(doubleOrZero(iron))
        let mK = vitaminsUnit.toStorageMG(doubleOrZero(potassium))
        let mZn = vitaminsUnit.toStorageMG(doubleOrZero(zinc))
        let mMg = vitaminsUnit.toStorageMG(doubleOrZero(magnesium))

        let now = Date()

        if let meal = meal {
            meal.mealDescription = defaultTitle(using: meal.date)
            meal.calories = cal
            meal.carbohydrates = carbs
            meal.protein = prot
            meal.salt = sod
            meal.fat = f
            meal.starch = sta
            meal.sugars = sug
            meal.fibre = fib
            meal.monounsaturatedFat = mono
            meal.polyunsaturatedFat = poly
            meal.saturatedFat = sat
            meal.transFat = trans

            meal.animalProtein = animal
            meal.plantProtein = plant
            meal.proteinSupplements = supps

            // Vitamins
            meal.vitaminA = vA
            meal.vitaminB = vB
            meal.vitaminC = vC
            meal.vitaminD = vD
            meal.vitaminE = vE
            meal.vitaminK = vK

            // Minerals
            meal.calcium = mCa
            meal.iron = mFe
            meal.potassium = mK
            meal.zinc = mZn
            meal.magnesium = mMg

            meal.caloriesIsGuess = caloriesIsGuess
            meal.carbohydratesIsGuess = carbohydratesIsGuess
            meal.proteinIsGuess = proteinIsGuess
            meal.saltIsGuess = sodiumIsGuess
            meal.fatIsGuess = fatIsGuess
            meal.starchIsGuess = starchIsGuess
            meal.sugarsIsGuess = sugarsIsGuess
            meal.fibreIsGuess = fibreIsGuess
            meal.monounsaturatedFatIsGuess = monounsaturatedFatIsGuess
            meal.polyunsaturatedFatIsGuess = polyunsaturatedFatIsGuess
            meal.saturatedFatIsGuess = saturatedFatIsGuess
            meal.transFatIsGuess = transFatIsGuess

            meal.animalProteinIsGuess = animalProteinIsGuess
            meal.plantProteinIsGuess = plantProteinIsGuess
            meal.proteinSupplementsIsGuess = proteinSupplementsIsGuess

            // Vitamins flags
            meal.vitaminAIsGuess = vitaminAIsGuess
            meal.vitaminBIsGuess = vitaminBIsGuess
            meal.vitaminCIsGuess = vitaminCIsGuess
            meal.vitaminDIsGuess = vitaminDIsGuess
            meal.vitaminEIsGuess = vitaminEIsGuess
            meal.vitaminKIsGuess = vitaminKIsGuess

            // Minerals flags
            meal.calciumIsGuess = calciumIsGuess
            meal.ironIsGuess = ironIsGuess
            meal.potassiumIsGuess = potassiumIsGuess
            meal.zincIsGuess = zincIsGuess
            meal.magnesiumIsGuess = magnesiumIsGuess

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
            newMeal.salt = sod
            newMeal.fat = f
            newMeal.starch = sta
            newMeal.sugars = sug
            newMeal.fibre = fib
            newMeal.monounsaturatedFat = mono
            newMeal.polyunsaturatedFat = poly
            newMeal.saturatedFat = sat
            newMeal.transFat = trans

            newMeal.animalProtein = animal
            newMeal.plantProtein = plant
            newMeal.proteinSupplements = supps

            // Vitamins
            newMeal.vitaminA = vA
            newMeal.vitaminB = vB
            newMeal.vitaminC = vC
            newMeal.vitaminD = vD
            newMeal.vitaminE = vE
            newMeal.vitaminK = vK

            // Minerals
            newMeal.calcium = mCa
            newMeal.iron = mFe
            newMeal.potassium = mK
            newMeal.zinc = mZn
            newMeal.magnesium = mMg

            newMeal.caloriesIsGuess = caloriesIsGuess
            newMeal.carbohydratesIsGuess = carbohydratesIsGuess
            newMeal.proteinIsGuess = proteinIsGuess
            newMeal.saltIsGuess = sodiumIsGuess
            newMeal.fatIsGuess = fatIsGuess
            newMeal.starchIsGuess = starchIsGuess
            newMeal.sugarsIsGuess = sugarsIsGuess
            newMeal.fibreIsGuess = fibreIsGuess
            newMeal.monounsaturatedFatIsGuess = monounsaturatedFatIsGuess
            newMeal.polyunsaturatedFatIsGuess = polyunsaturatedFatIsGuess
            newMeal.saturatedFatIsGuess = saturatedFatIsGuess
            newMeal.transFatIsGuess = transFatIsGuess

            newMeal.animalProteinIsGuess = animalProteinIsGuess
            newMeal.plantProteinIsGuess = plantProteinIsGuess
            newMeal.proteinSupplementsIsGuess = proteinSupplementsIsGuess

            newMeal.vitaminAIsGuess = vitaminAIsGuess
            newMeal.vitaminBIsGuess = vitaminBIsGuess
            newMeal.vitaminCIsGuess = vitaminCIsGuess
            newMeal.vitaminDIsGuess = vitaminDIsGuess
            newMeal.vitaminEIsGuess = vitaminEIsGuess
            newMeal.vitaminKIsGuess = vitaminKIsGuess

            newMeal.calciumIsGuess = calciumIsGuess
            newMeal.ironIsGuess = ironIsGuess
            newMeal.potassiumIsGuess = potassiumIsGuess
            newMeal.zincIsGuess = zincIsGuess
            newMeal.magnesiumIsGuess = magnesiumIsGuess

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
        let localeSep = Locale.current.decimalSeparator ?? "."
        var digits = ""
        var sawSeparator = false

        for ch in input {
            if ch.isNumber {
                digits.append(ch)
            } else if ch == "." || ch == "," {
                if !sawSeparator {
                    sawSeparator = true
                    digits.append("|")
                }
            } else {
                // ignore everything else (including '-')
            }
        }

        if let sepIndex = digits.firstIndex(of: "|") {
            var integer = String(digits[..<sepIndex]).filter(\.isNumber)
            let fractional = String(digits[digits.index(after: sepIndex)...]).filter(\.isNumber)
            if integer.isEmpty { integer = "0" }
            return integer + localeSep + fractional
        } else {
            if digits.count > 1, digits.allSatisfy({ $0 == "0" }) {
                return "0"
            }
            return digits
        }
    }

    private func caloriesTitleWithUnit(manager: LocalizationManager) -> String {
        let base = manager.localized("calories")
        let unit = energyUnit.displaySuffix(manager: manager)
        return "\(base) (\(unit))"
    }
}

// Simple toggle button to expand/collapse details (compatible with older iOS)
private struct ToggleDetailsButton: View {
    @Binding var isExpanded: Bool
    let titleCollapsed: String
    let titleExpanded: String

    var body: some View {
        HStack {
            Spacer()
            Button(action: { isExpanded.toggle() }) {
                HStack(spacing: 6) {
                    Text(isExpanded ? titleExpanded : titleCollapsed)
                        .font(.footnote)
                        .foregroundColor(.accentColor)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.footnote)
                        .foregroundColor(.accentColor)
                        .imageScale(.small)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? titleExpanded : titleCollapsed)
        }
    }
}

// Subfields only (used when expanded)
private struct CarbsSubFields: View {
    let manager: LocalizationManager
    @Binding var sugarsText: String
    @Binding var sugarsIsGuess: Bool
    @Binding var starchText: String
    @Binding var starchIsGuess: Bool
    @Binding var fibreText: String
    @Binding var fibreIsGuess: Bool

    var body: some View {
        VStack(spacing: 0) {
            MetricField(titleKey: "sugars", text: $sugarsText, isGuess: $sugarsIsGuess, manager: manager, unitSuffix: "g")
            MetricField(titleKey: "starch", text: $starchText, isGuess: $starchIsGuess, manager: manager, unitSuffix: "g")
            MetricField(titleKey: "fibre", text: $fibreText, isGuess: $fibreIsGuess, manager: manager, unitSuffix: "g")
        }
    }
}

private struct ProteinSubFields: View {
    let manager: LocalizationManager
    @Binding var animalText: String
    @Binding var animalIsGuess: Bool
    @Binding var plantText: String
    @Binding var plantIsGuess: Bool
    @Binding var supplementsText: String
    @Binding var supplementsIsGuess: Bool

    var body: some View {
        VStack(spacing: 0) {
            MetricField(titleKey: "animal_protein", text: $animalText, isGuess: $animalIsGuess, manager: manager, unitSuffix: "g")
            MetricField(titleKey: "plant_protein", text: $plantText, isGuess: $plantIsGuess, manager: manager, unitSuffix: "g")
            MetricField(titleKey: "protein_supplements", text: $supplementsText, isGuess: $supplementsIsGuess, manager: manager, unitSuffix: "g")
        }
    }
}

private struct FatSubFields: View {
    let manager: LocalizationManager
    @Binding var monoText: String
    @Binding var monoIsGuess: Bool
    @Binding var polyText: String
    @Binding var polyIsGuess: Bool
    @Binding var satText: String
    @Binding var satIsGuess: Bool
    @Binding var transText: String
    @Binding var transIsGuess: Bool

    var body: some View {
        VStack(spacing: 0) {
            MetricField(titleKey: "monounsaturated_fat", text: $monoText, isGuess: $monoIsGuess, manager: manager, unitSuffix: "g")
            MetricField(titleKey: "polyunsaturated_fat", text: $polyText, isGuess: $polyIsGuess, manager: manager, unitSuffix: "g")
            MetricField(titleKey: "saturated_fat", text: $satText, isGuess: $satIsGuess, manager: manager, unitSuffix: "g")
            MetricField(titleKey: "trans_fat", text: $transText, isGuess: $transIsGuess, manager: manager, unitSuffix: "g")
        }
    }
}

// Minerals group view
private struct MineralsGroupView: View {
    let manager: LocalizationManager
    let unitSuffix: String

    @Binding var calciumText: String
    @Binding var calciumIsGuess: Bool
    @Binding var ironText: String
    @Binding var ironIsGuess: Bool
    @Binding var potassiumText: String
    @Binding var potassiumIsGuess: Bool
    @Binding var zincText: String
    @Binding var zincIsGuess: Bool
    @Binding var magnesiumText: String
    @Binding var magnesiumIsGuess: Bool

    var body: some View {
        VStack(spacing: 0) {
            MetricField(titleKey: "calcium", text: $calciumText, isGuess: $calciumIsGuess, manager: manager, unitSuffix: unitSuffix)
            MetricField(titleKey: "iron", text: $ironText, isGuess: $ironIsGuess, manager: manager, unitSuffix: unitSuffix)
            MetricField(titleKey: "potassium", text: $potassiumText, isGuess: $potassiumIsGuess, manager: manager, unitSuffix: unitSuffix)
            MetricField(titleKey: "zinc", text: $zincText, isGuess: $zincIsGuess, manager: manager, unitSuffix: unitSuffix)
            MetricField(titleKey: "magnesium", text: $magnesiumText, isGuess: $magnesiumIsGuess, manager: manager, unitSuffix: unitSuffix)
        }
    }
}

enum EnergyUnit: String, CaseIterable, Codable {
    case calories
    case kilojoules

    func displaySuffix(manager: LocalizationManager) -> String {
        switch self {
        case .calories:
            return "kcal"
        case .kilojoules:
            return "kJ"
        }
    }
}

enum MeasurementSystem: String, CaseIterable, Codable {
    case metric
    case imperial
}

enum SodiumUnit: String, CaseIterable, Codable {
    case milligrams
    case grams

    var displaySuffix: String {
        switch self {
        case .milligrams: return "mg"
        case .grams: return "g"
        }
    }
}

enum VitaminsUnit: String, CaseIterable, Codable {
    case milligrams
    case micrograms

    var displaySuffix: String {
        switch self {
        case .milligrams: return "mg"
        case .micrograms: return "µg"
        }
    }

    func toStorageMG(_ valueInUI: Double) -> Double {
        switch self {
        case .milligrams: return valueInUI
        case .micrograms: return valueInUI / 1000.0
        }
    }

    func fromStorageMG(_ valueInMG: Double) -> Double {
        switch self {
        case .milligrams: return valueInMG
        case .micrograms: return valueInMG * 1000.0
        }
    }
}

private struct MetricField: View {
    let titleKey: String
    @Binding var text: String
    @Binding var isGuess: Bool
    var keyboard: UIKeyboardType = .decimalPad
    let manager: LocalizationManager
    var unitSuffix: String? = nil
    var isPrelocalizedTitle: Bool = false
    var isError: ((Double) -> Bool)? = nil

    private var tintColor: Color {
        isGuess ? .orange : .green
    }

    private var displayTitle: String {
        if isPrelocalizedTitle {
            return titleKey
        } else {
            let localized = manager.localized(titleKey)
            let spaced = localized.replacingOccurrences(of: "_", with: " ")
            let words = spaced.split(separator: " ")
            let titled = words.map { word -> String in
                var s = String(word)
                if let first = s.first {
                    let firstUpper = String(first).uppercased()
                    s.replaceSubrange(s.startIndex...s.startIndex, with: firstUpper)
                }
                return s
            }.joined(separator: " ")
            return titled
        }
    }

    private var parsedValue: Double? {
        Double(text)
    }

    private var hasError: Bool {
        guard let v = parsedValue else { return false }
        if v < 0 { return true }
        if let validator = isError {
            return validator(v)
        }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(displayTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Picker("", selection: $isGuess) {
                    Text(manager.localized("accurate")).tag(false)
                    Text(manager.localized("guess")).tag(true)
                }
                .font(.caption)
                .pickerStyle(.segmented)
                .tint(tintColor)
                .frame(maxWidth: 180)
                .accessibilityLabel(displayTitle + " " + manager.localized("accuracy"))
            }

            HStack(spacing: 8) {
                TextField("", text: $text)
                    .keyboardType(keyboard)
                    .multilineTextAlignment(.leading)
                    .submitLabel(.done)
                    .foregroundColor(hasError ? .red : .primary)

                if let suffix = unitSuffix {
                    Text(suffix)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(hasError ? Color.red : Color.secondary.opacity(0.15), lineWidth: hasError ? 2 : 1)
            )
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(displayTitle)
    }
}

private struct VitaminsGroupView: View {
    let manager: LocalizationManager
    let unitSuffix: String

    @Binding var aText: String
    @Binding var aIsGuess: Bool
    @Binding var bText: String
    @Binding var bIsGuess: Bool
    @Binding var cText: String
    @Binding var cIsGuess: Bool
    @Binding var dText: String
    @Binding var dIsGuess: Bool
    @Binding var eText: String
    @Binding var eIsGuess: Bool
    @Binding var kText: String
    @Binding var kIsGuess: Bool

    var body: some View {
        VStack(spacing: 0) {
            MetricField(titleKey: "vitamin_a", text: $aText, isGuess: $aIsGuess, manager: manager, unitSuffix: unitSuffix)
            MetricField(titleKey: "vitamin_b", text: $bText, isGuess: $bIsGuess, manager: manager, unitSuffix: unitSuffix)
            MetricField(titleKey: "vitamin_c", text: $cText, isGuess: $cIsGuess, manager: manager, unitSuffix: unitSuffix)
            MetricField(titleKey: "vitamin_d", text: $dText, isGuess: $dIsGuess, manager: manager, unitSuffix: unitSuffix)
            MetricField(titleKey: "vitamin_e", text: $eText, isGuess: $eIsGuess, manager: manager, unitSuffix: unitSuffix)
            MetricField(titleKey: "vitamin_k", text: $kText, isGuess: $kIsGuess, manager: manager, unitSuffix: unitSuffix)
        }
    }
}

// Split out subfields views used when expanded
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

    var body: some View {
        VStack(spacing: 0) {
            MetricField(titleKey: "carbohydrates", text: $totalText, isGuess: $totalIsGuess, manager: manager, unitSuffix: "g")
            MetricField(titleKey: "sugars", text: $sugarsText, isGuess: $sugarsIsGuess, manager: manager, unitSuffix: "g")
            MetricField(titleKey: "starch", text: $starchText, isGuess: $starchIsGuess, manager: manager, unitSuffix: "g")
            MetricField(titleKey: "fibre", text: $fibreText, isGuess: $fibreIsGuess, manager: manager, unitSuffix: "g")
        }
    }
}

private struct ProteinGroupView: View {
    let manager: LocalizationManager

    @Binding var descriptionText: String
    @Binding var totalText: String
    @Binding var totalIsGuess: Bool
    @Binding var animalText: String
    @Binding var animalIsGuess: Bool
    @Binding var plantText: String
    @Binding var plantIsGuess: Bool
    @Binding var supplementsText: String
    @Binding var supplementsIsGuess: Bool

    var body: some View {
        VStack(spacing: 0) {
            MetricField(titleKey: "protein", text: $totalText, isGuess: $totalIsGuess, manager: manager, unitSuffix: "g")
            MetricField(titleKey: "animal_protein", text: $animalText, isGuess: $animalIsGuess, manager: manager, unitSuffix: "g")
            MetricField(titleKey: "plant_protein", text: $plantText, isGuess: $plantIsGuess, manager: manager, unitSuffix: "g")
            MetricField(titleKey: "protein_supplements", text: $supplementsText, isGuess: $supplementsIsGuess, manager: manager, unitSuffix: "g")
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

    var body: some View {
        VStack(spacing: 0) {
            MetricField(titleKey: "fat", text: $totalText, isGuess: $totalIsGuess, manager: manager, unitSuffix: "g")
            MetricField(titleKey: "monounsaturated_fat", text: $monoText, isGuess: $monoIsGuess, manager: manager, unitSuffix: "g")
            MetricField(titleKey: "polyunsaturated_fat", text: $polyText, isGuess: $polyIsGuess, manager: manager, unitSuffix: "g")
            MetricField(titleKey: "saturated_fat", text: $satText, isGuess: $satIsGuess, manager: manager, unitSuffix: "g")
            MetricField(titleKey: "trans_fat", text: $transText, isGuess: $transIsGuess, manager: manager, unitSuffix: "g")
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
