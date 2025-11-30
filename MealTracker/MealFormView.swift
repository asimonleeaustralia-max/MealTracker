//
//  MealFormView.swift
//  MealTracker
//
//  Created by Simon Lee on 17/11/2025.
//

import SwiftUI
import CoreData
import CoreLocation
import UIKit

struct MealFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject var session: SessionManager

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
    // Numeric inputs (now integers only)
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

    // Touched flags to avoid overwriting manual edits
    @State private var sugarsTouched = false
    @State private var starchTouched = false
    @State private var fibreTouched = false

    @State private var monoTouched = false
    @State private var polyTouched = false
    @State private var satTouched = false
    @State private var transTouched = false

    @State private var animalTouched = false
    @State private var plantTouched = false
    @State private var supplementsTouched = false

    // Track last auto-sum for totals so we can keep updating while user types
    @State private var carbsLastAutoSum: Int?
    @State private var proteinLastAutoSum: Int?
    @State private var fatLastAutoSum: Int?

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

    // Group consistency states
    @State private var carbsMismatch = false
    @State private var proteinMismatch = false
    @State private var fatMismatch = false

    @State private var carbsBlink = false
    @State private var proteinBlink = false
    @State private var fatBlink = false

    // New: short red blink when subfields have values but top-level is empty at time of edit
    @State private var carbsRedBlink = false
    @State private var proteinRedBlink = false
    @State private var fatRedBlink = false

    // Helper number states (brief “(sum)” display)
    @State private var carbsHelperText: String = ""
    @State private var proteinHelperText: String = ""
    @State private var fatHelperText: String = ""

    @State private var carbsHelperVisible: Bool = false
    @State private var proteinHelperVisible: Bool = false
    @State private var fatHelperVisible: Bool = false

    // Track previous mismatch to detect corrections
    @State private var prevCarbsMismatch = false
    @State private var prevProteinMismatch = false
    @State private var prevFatMismatch = false

    // Focus handling to delay validation until leaving a field
    fileprivate enum FocusedField: Hashable {
        case calories
        case carbsTotal
        case proteinTotal
        case fatTotal
        case sodium
    }
    @FocusState private var focused: FocusedField?
    @State private var lastFocused: FocusedField?

    // MARK: - Gallery state
    private let maxPhotos = 2
    @State private var galleryItems: [GalleryItem] = [] // ordered, display-ready
    @State private var selectedIndex: Int = 0

    // Bundle resources for dev fallback (cupcake + fish & chips)
    // IMG_0204.jpg.webp -> resource name "IMG_0204.jpg", ext "webp"
    private let devImage1Name = "IMG_0204.jpg"
    private let devImage1Ext = "webp"
    // Screenshot 2025-11-24 at 6.30.52 pm.png
    private let devImage2Name = "Screenshot 2025-11-24 at 6.30.52 pm"
    private let devImage2Ext = "png"

    // Expanded header height toggle (kept from previous UI)
    @State private var isImageExpanded: Bool = false

    // MARK: - Analyze button state
    @State private var isAnalyzing: Bool = false
    @State private var analyzeError: String?

    // Force-enable Save after wand finishes
    @State private var forceEnableSave: Bool = false

    // MARK: - Limit alert state
    @State private var showingLimitAlert: Bool = false
    @State private var limitErrorMessage: String?

    // MARK: - Delete confirmation state
    @State private var showingDeleteConfirm: Bool = false

    var meal: Meal?

    init(meal: Meal? = nil) {
        self.meal = meal
    }

    var isEditing: Bool { meal != nil }

    var body: some View {
        let l = LocalizationManager(languageCode: appLanguageCode)

        // Heights for header image
        let fullHeight = UIScreen.main.bounds.height * 0.45
        let collapsedHeight = fullHeight * 0.5

        VStack(spacing: 0) {
            // Main gallery + thumbnails
            GalleryHeader(
                items: galleryItems,
                selectedIndex: $selectedIndex,
                isExpanded: $isImageExpanded,
                fullHeight: fullHeight,
                collapsedHeight: collapsedHeight,
                isBusy: $isAnalyzing.wrappedValue,
                onAnalyzeTap: {
                    Task { await analyzePhoto() }
                }
            )

            Form {
                // Energy (no header)
                Section {
                    MetricField(
                        titleKey: "calories",
                        text: numericBindingInt($calories),
                        isGuess: $caloriesIsGuess,
                        keyboard: .numberPad,
                        manager: l,
                        unitSuffix: energyUnit.displaySuffix(manager: l),
                        isPrelocalizedTitle: false,
                        validator: { value in
                            let kcal = (energyUnit == .calories) ? value : Int(Double(value) / 4.184)
                            if kcal <= 0 { return .stupid }
                            return ValidationThresholds.calories.severity(for: kcal)
                        },
                        focusedField: $focused,
                        thisField: .calories,
                        onSubmit: { handleFocusLeaveIfNeeded(leaving: .calories) }
                    )
                    .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                }
                .padding(.vertical, 2)

                // Carbohydrates (no header)
                Section {
                    MetricField(
                        titleKey: "carbohydrates",
                        text: numericBindingInt($carbohydrates),
                        isGuess: $carbohydratesIsGuess,
                        keyboard: .numberPad,
                        manager: l,
                        unitSuffix: "g",
                        validator: { ValidationThresholds.grams.severity(for: $0) },
                        leadingAccessory: {
                            AnyView(
                                CompactChevronToggle(isExpanded: $expandedCarbs,
                                                     labelCollapsed: l.localized("show_details"),
                                                     labelExpanded: l.localized("hide_details"))
                            )
                        },
                        trailingAccessory: {
                            if carbsHelperVisible, !carbohydrates.isEmpty {
                                return AnyView(
                                    Text("(\(carbsHelperText))")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .transition(.opacity)
                                )
                            } else {
                                return AnyView(EmptyView())
                            }
                        },
                        highlight: carbsMismatch ? .error
                            : (carbsRedBlink ? .error
                               : (carbsBlink ? .successBlink(active: true) : .none)),
                        focusedField: $focused,
                        thisField: .carbsTotal,
                        onSubmit: { handleFocusLeaveIfNeeded(leaving: .carbsTotal) }
                    )
                    .onChange(of: carbohydrates, perform: { _ in
                        recomputeConsistency()
                        if let last = carbsLastAutoSum, Int(carbohydrates) != last {
                            carbsLastAutoSum = nil
                        }
                    })
                    .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))

                    if expandedCarbs {
                        CarbsSubFields(manager: l,
                                       sugarsText: numericBindingInt($sugars), sugarsIsGuess: $sugarsIsGuess,
                                       starchText: numericBindingInt($starch), starchIsGuess: $starchIsGuess,
                                       fibreText: numericBindingInt($fibre), fibreIsGuess: $fibreIsGuess)
                            .onAppear { handleTopFromCarbSubs() }
                            .onChange(of: sugars, perform: { _ in
                                sugarsTouched = true
                                handleTopFromCarbSubs()
                                handleHelperForCarbs()
                                recomputeConsistencyAndBlinkIfFixed()
                            })
                            .onChange(of: starch, perform: { _ in
                                starchTouched = true
                                handleTopFromCarbSubs()
                                handleHelperForCarbs()
                                recomputeConsistencyAndBlinkIfFixed()
                            })
                            .onChange(of: fibre, perform: { _ in
                                fibreTouched = true
                                handleTopFromCarbSubs()
                                handleHelperForCarbs()
                                recomputeConsistencyAndBlinkIfFixed()
                            })
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    }
                }
                .padding(.vertical, 2)
                .onChange(of: expandedCarbs, perform: { expanded in
                    if expanded { handleTopFromCarbSubs() }
                })

                // Protein (no header)
                Section {
                    MetricField(
                        titleKey: "protein",
                        text: numericBindingInt($protein),
                        isGuess: $proteinIsGuess,
                        keyboard: .numberPad,
                        manager: l,
                        unitSuffix: "g",
                        validator: { ValidationThresholds.grams.severity(for: $0) },
                        leadingAccessory: {
                            AnyView(
                                CompactChevronToggle(isExpanded: $expandedProtein,
                                                     labelCollapsed: l.localized("show_details"),
                                                     labelExpanded: l.localized("hide_details"))
                            )
                        },
                        trailingAccessory: {
                            if proteinHelperVisible, !protein.isEmpty {
                                return AnyView(
                                    Text("(\(proteinHelperText))")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .transition(.opacity)
                                )
                            } else {
                                return AnyView(EmptyView())
                            }
                        },
                        highlight: proteinMismatch ? .error
                            : (proteinRedBlink ? .error
                               : (proteinBlink ? .successBlink(active: true) : .none)),
                        focusedField: $focused,
                        thisField: .proteinTotal,
                        onSubmit: { handleFocusLeaveIfNeeded(leaving: .proteinTotal) }
                    )
                    .onChange(of: protein, perform: { _ in
                        recomputeConsistency()
                        if let last = proteinLastAutoSum, Int(protein) != last {
                            proteinLastAutoSum = nil
                        }
                    })
                    .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))

                    if expandedProtein {
                        ProteinSubFields(manager: l,
                                         animalText: numericBindingInt($animalProtein), animalIsGuess: $animalProteinIsGuess,
                                         plantText: numericBindingInt($plantProtein), plantIsGuess: $plantProteinIsGuess,
                                         supplementsText: numericBindingInt($proteinSupplements), supplementsIsGuess: $proteinSupplementsIsGuess)
                            .onAppear { handleTopFromProteinSubs() }
                            .onChange(of: animalProtein, perform: { _ in
                                animalTouched = true
                                handleTopFromProteinSubs()
                                handleHelperForProtein()
                                recomputeConsistencyAndBlinkIfFixed()
                            })
                            .onChange(of: plantProtein, perform: { _ in
                                plantTouched = true
                                handleTopFromProteinSubs()
                                handleHelperForProtein()
                                recomputeConsistencyAndBlinkIfFixed()
                            })
                            .onChange(of: proteinSupplements, perform: { _ in
                                supplementsTouched = true
                                handleTopFromProteinSubs()
                                handleHelperForProtein()
                                recomputeConsistencyAndBlinkIfFixed()
                            })
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    }
                }
                .padding(.vertical, 2)
                .onChange(of: expandedProtein, perform: { expanded in
                    if expanded { handleTopFromProteinSubs() }
                })

                // Fat (no header) — moved above Sodium
                Section {
                    MetricField(
                        titleKey: "fat",
                        text: numericBindingInt($fat),
                        isGuess: $fatIsGuess,
                        keyboard: .numberPad,
                        manager: l,
                        unitSuffix: "g",
                        validator: { ValidationThresholds.grams.severity(for: $0) },
                        leadingAccessory: {
                            AnyView(
                                CompactChevronToggle(isExpanded: $expandedFat,
                                                     labelCollapsed: l.localized("show_details"),
                                                     labelExpanded: l.localized("hide_details"))
                            )
                        },
                        trailingAccessory: {
                            if fatHelperVisible, !fat.isEmpty {
                                return AnyView(
                                    Text("(\(fatHelperText))")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .transition(.opacity)
                                )
                            } else {
                                return AnyView(EmptyView())
                            }
                        },
                        highlight: fatMismatch ? .error
                            : (fatRedBlink ? .error
                               : (fatBlink ? .successBlink(active: true) : .none)),
                        focusedField: $focused,
                        thisField: .fatTotal,
                        onSubmit: { handleFocusLeaveIfNeeded(leaving: .fatTotal) }
                    )
                    .onChange(of: fat, perform: { _ in
                        recomputeConsistency()
                        if let last = fatLastAutoSum, Int(fat) != last {
                            fatLastAutoSum = nil
                        }
                    })
                    .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))

                    if expandedFat {
                        FatSubFields(manager: l,
                                     monoText: numericBindingInt($monounsaturatedFat), monoIsGuess: $monounsaturatedFatIsGuess,
                                     polyText: numericBindingInt($polyunsaturatedFat), polyIsGuess: $polyunsaturatedFatIsGuess,
                                     satText: numericBindingInt($saturatedFat), satIsGuess: $saturatedFatIsGuess,
                                     transText: numericBindingInt($transFat), transIsGuess: $transFatIsGuess)
                            .onAppear { handleTopFromFatSubs() }
                            .onChange(of: monounsaturatedFat, perform: { _ in
                                monoTouched = true
                                handleTopFromFatSubs()
                                handleHelperForFat()
                                recomputeConsistencyAndBlinkIfFixed()
                            })
                            .onChange(of: polyunsaturatedFat, perform: { _ in
                                polyTouched = true
                                handleTopFromFatSubs()
                                handleHelperForFat()
                                recomputeConsistencyAndBlinkIfFixed()
                            })
                            .onChange(of: saturatedFat, perform: { _ in
                                satTouched = true
                                handleTopFromFatSubs()
                                handleHelperForFat()
                                recomputeConsistencyAndBlinkIfFixed()
                            })
                            .onChange(of: transFat, perform: { _ in
                                transTouched = true
                                handleTopFromFatSubs()
                                handleHelperForFat()
                                recomputeConsistencyAndBlinkIfFixed()
                            })
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    }
                }
                .padding(.vertical, 2)
                .onChange(of: expandedFat, perform: { expanded in
                    if expanded { handleTopFromFatSubs() }
                })

                // Sodium (no header) — moved below Fat
                Section {
                    MetricField(titleKey: "Sodium",
                                text: numericBindingInt($sodium),
                                isGuess: $sodiumIsGuess,
                                keyboard: .numberPad,
                                manager: l,
                                unitSuffix: sodiumUnit.displaySuffix,
                                isPrelocalizedTitle: true,
                                validator: {
                                    switch sodiumUnit {
                                    case .milligrams:
                                        return ValidationThresholds.sodiumMg.severity(for: $0)
                                    case .grams:
                                        return ValidationThresholds.sodiumG.severity(for: $0)
                                    }
                                },
                                focusedField: $focused,
                                thisField: .sodium,
                                onSubmit: { handleFocusLeaveIfNeeded(leaving: .sodium) })
                    .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                }
                .padding(.vertical, 2)

                if showVitamins {
                    // Vitamins (no header)
                    Section {
                        ToggleDetailsButton(isExpanded: $expandedVitamins, titleCollapsed: l.localized("show_vitamins"), titleExpanded: l.localized("hide_vitamins"))

                        if expandedVitamins {
                            VitaminsGroupView(
                                manager: l,
                                unitSuffix: vitaminsUnit.displaySuffix,
                                aText: numericBindingInt($vitaminA), aIsGuess: $vitaminAIsGuess,
                                bText: numericBindingInt($vitaminB), bIsGuess: $vitaminBIsGuess,
                                cText: numericBindingInt($vitaminC), cIsGuess: $vitaminCIsGuess,
                                dText: numericBindingInt($vitaminD), dIsGuess: $vitaminDIsGuess,
                                eText: numericBindingInt($vitaminE), eIsGuess: $vitaminEIsGuess,
                                kText: numericBindingInt($vitaminK), kIsGuess: $vitaminKIsGuess
                            )
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        }
                    }
                    .padding(.vertical, 2)
                }

                if showMinerals {
                    // Minerals (no header)
                    Section {
                        ToggleDetailsButton(isExpanded: $expandedMinerals, titleCollapsed: l.localized("show_minerals"), titleExpanded: l.localized("hide_minerals"))

                        if expandedMinerals {
                            MineralsGroupView(
                                manager: l,
                                unitSuffix: vitaminsUnit.displaySuffix, // reuse vitamins unit toggle (mg/µg)
                                calciumText: numericBindingInt($calcium), calciumIsGuess: $calciumIsGuess,
                                ironText: numericBindingInt($iron), ironIsGuess: $ironIsGuess,
                                potassiumText: numericBindingInt($potassium), potassiumIsGuess: $potassiumIsGuess,
                                zincText: numericBindingInt($zinc), zincIsGuess: $zincIsGuess,
                                magnesiumText: numericBindingInt($magnesium), magnesiumIsGuess: $magnesiumIsGuess
                            )
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .modifier(CompactSectionSpacing())
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(l.localized("save")) {
                    save()
                }
                .disabled(!isValid && !forceEnableSave)
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
            // New: open gallery of saved meals
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    MealsGalleryView()
                } label: {
                    Image(systemName: "photo.on.rectangle")
                }
                .accessibilityLabel("Open Meal Gallery")
            }
            // New: Delete button when editing (avoid iOS 16-only buildIf in ToolbarContent)
            ToolbarItem(placement: .bottomBar) {
                if isEditing {
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label(l.localized("delete"), systemImage: "trash")
                    }
                    .accessibilityIdentifier("deleteMealButton")
                } else {
                    EmptyView()
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(session) // Ensure SessionManager is available in SettingsView
        }
        .alert(isPresented: $showingLimitAlert) {
            Alert(
                title: Text("Limit Reached"),
                message: Text(limitErrorMessage ?? "You have reached your limit."),
                dismissButton: .default(Text("OK"))
            )
        }
        // Delete confirmation
        .confirmationDialog(
            LocalizationManager(languageCode: appLanguageCode).localized("confirm_delete_title"),
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                deleteMeal()
            } label: {
                Text(LocalizationManager(languageCode: appLanguageCode).localized("delete"))
            }
            Button(LocalizationManager(languageCode: appLanguageCode).localized("cancel"), role: .cancel) { }
        } message: {
            Text(LocalizationManager(languageCode: appLanguageCode).localized("confirm_delete_message"))
        }
        .onChange(of: focused, perform: { newFocus in
            if let leaving = lastFocused, leaving != newFocus {
                handleFocusLeaveIfNeeded(leaving: leaving)
            }
            lastFocused = newFocus
        })
        .onAppear {
            // Build gallery items from Core Data or dev fallback
            reloadGalleryItems()

            if let meal = meal {
                mealDescription = meal.mealDescription
                calories = Int(meal.calories).description
                carbohydrates = Int(meal.carbohydrates).description
                protein = Int(meal.protein).description
                sodium = Int(meal.sodium).description
                fat = Int(meal.fat).description
                starch = Int(meal.starch).description
                sugars = Int(meal.sugars).description
                fibre = Int(meal.fibre).description
                monounsaturatedFat = Int(meal.monounsaturatedFat).description
                polyunsaturatedFat = Int(meal.polyunsaturatedFat).description
                saturatedFat = Int(meal.saturatedFat).description
                transFat = Int(meal.transFat).description
                animalProtein = Int(meal.animalProtein).description
                plantProtein = Int(meal.plantProtein).description
                proteinSupplements = Int(meal.proteinSupplements).description

                vitaminA = Int(vitaminsUnit.fromStorageMG(meal.vitaminA)).description
                vitaminB = Int(vitaminsUnit.fromStorageMG(meal.vitaminB)).description
                vitaminC = Int(vitaminsUnit.fromStorageMG(meal.vitaminC)).description
                vitaminD = Int(vitaminsUnit.fromStorageMG(meal.vitaminD)).description
                vitaminE = Int(vitaminsUnit.fromStorageMG(meal.vitaminE)).description
                vitaminK = Int(vitaminsUnit.fromStorageMG(meal.vitaminK)).description

                calcium = Int(vitaminsUnit.fromStorageMG(meal.calcium)).description
                iron = Int(vitaminsUnit.fromStorageMG(meal.iron)).description
                potassium = Int(vitaminsUnit.fromStorageMG(meal.potassium)).description
                zinc = Int(vitaminsUnit.fromStorageMG(meal.zinc)).description
                magnesium = Int(vitaminsUnit.fromStorageMG(meal.magnesium)).description

                date = meal.date

                caloriesIsGuess = meal.caloriesIsGuess
                carbohydratesIsGuess = meal.carbohydratesIsGuess
                proteinIsGuess = meal.proteinIsGuess
                sodiumIsGuess = meal.sodiumIsGuess
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

                sugarsTouched = !sugars.isEmpty
                starchTouched = !starch.isEmpty
                fibreTouched = !fibre.isEmpty
                monoTouched = !monounsaturatedFat.isEmpty
                polyTouched = !polyunsaturatedFat.isEmpty
                satTouched = !saturatedFat.isEmpty
                transTouched = !transFat.isEmpty
                animalTouched = !animalProtein.isEmpty
                plantTouched = !plantProtein.isEmpty
                supplementsTouched = !proteinSupplements.isEmpty
            }

            locationManager.requestAuthorization()
            locationManager.startUpdating()

            recomputeConsistency(resetPrevMismatch: true)
        }
    }

    // MARK: - Deletion

    private func deleteMeal() {
        guard let meal = meal else { return }

        // Remove photos and their files first
        if let set = meal.value(forKey: "photos") as? Set<MealPhoto>, !set.isEmpty {
            for photo in set {
                PhotoService.removePhoto(photo, in: context)
            }
        }

        // Delete the meal itself
        context.delete(meal)

        do {
            try context.save()
            dismiss()
        } catch {
            print("Failed to delete meal: \(error)")
        }
    }

    // MARK: - Gallery composition

    private func reloadGalleryItems() {
        var items: [GalleryItem] = []

        if let meal = meal {
            // Use inverse relationship instead of a fetch with predicate
            if let set = meal.value(forKey: "photos") as? Set<MealPhoto>, !set.isEmpty {
                let sorted = set.sorted { (a, b) in
                    let da = a.createdAt ?? .distantFuture
                    let db = b.createdAt ?? .distantFuture
                    return da < db
                }
                for p in sorted.prefix(maxPhotos) {
                    if let url = PhotoService.urlForUpload(p) ?? PhotoService.urlForOriginal(p) {
                        items.append(.persistent(photo: p, url: url))
                    }
                }
            }
        }

        if items.isEmpty {
            // Dev fallback: load exactly two bundle images (cupcake + fish & chips)
            var devPairs: [(name: String, ext: String)] = [
                (devImage1Name, devImage1Ext),
                (devImage2Name, devImage2Ext)
            ]
            // Attempt a second chance for the PNG with regular space instead of narrow space, if needed
            if Bundle.main.url(forResource: devImage2Name, withExtension: devImage2Ext) == nil {
                let altName = devImage2Name.replacingOccurrences(of: "\u{202F}", with: " ")
                devPairs[1].name = altName
            }

            for (idx, pair) in devPairs.enumerated() {
                if let url = Bundle.main.url(forResource: pair.name, withExtension: pair.ext),
                   let data = try? Data(contentsOf: url),
                   let ui = UIImage(data: data) {
                    items.append(.inMemory(id: UUID(), image: ui, data: data, devIndex: idx))
                }
            }
        }

        self.galleryItems = items
        self.selectedIndex = min(self.selectedIndex, max(0, items.count - 1))
    }

    // MARK: - Analyze button logic

    private func applyIfEmpty(_ source: inout String, with value: Int?, markGuess: inout Bool) {
        guard let v = value, source.isEmpty else { return }
        source = String(max(0, v))
        markGuess = true
    }

    private func analyzePhoto() async {
        // If already analyzing, ignore further taps
        if await MainActor.run(resultType: Bool.self, body: { isAnalyzing }) { return }

        // Use the currently selected gallery image data if available; otherwise bail.
        let imageData: Data? = {
            guard selectedIndex < galleryItems.count else { return nil }
            switch galleryItems[selectedIndex] {
            case .persistent(_, let url):
                return try? Data(contentsOf: url)
            case .inMemory(_, _, let data, _):
                return data
            }
        }()

        guard let data = imageData else { return }

        await MainActor.run { isAnalyzing = true }
        defer { Task { await MainActor.run { isAnalyzing = false } } }

        do {
            if let result = try await PhotoNutritionGuesser.guess(from: data, languageCode: appLanguageCode) {
                // Apply only to empty fields; set guess flags
                await MainActor.run {
                    // Calories (convert guessed kcal to current UI unit)
                    if calories.isEmpty, let kcal = result.calories {
                        let uiVal: Int
                        switch energyUnit {
                        case .calories:
                            uiVal = kcal
                        case .kilojoules:
                            uiVal = Int((Double(kcal) * 4.184).rounded())
                        }
                        calories = String(max(0, uiVal))
                        caloriesIsGuess = true
                    }

                    applyIfEmpty(&carbohydrates, with: result.carbohydrates, markGuess: &carbohydratesIsGuess)
                    applyIfEmpty(&protein, with: result.protein, markGuess: &proteinIsGuess)
                    // Sodium stored as mg in UI; convert to UI unit if needed
                    if sodium.isEmpty, let mg = result.sodiumMg {
                        let uiVal: Int
                        switch sodiumUnit {
                        case .milligrams:
                            uiVal = mg
                        case .grams:
                            uiVal = Int(Double(mg) / 1000.0)
                        }
                        sodium = String(max(0, uiVal))
                        sodiumIsGuess = true
                    }
                    applyIfEmpty(&fat, with: result.fat, markGuess: &fatIsGuess)

                    applyIfEmpty(&sugars, with: result.sugars, markGuess: &sugarsIsGuess)
                    sugarsTouched = sugarsTouched || !sugars.isEmpty
                    applyIfEmpty(&starch, with: result.starch, markGuess: &starchIsGuess)
                    starchTouched = starchTouched || !starch.isEmpty
                    applyIfEmpty(&fibre, with: result.fibre, markGuess: &fibreIsGuess)
                    fibreTouched = fibreTouched || !fibre.isEmpty

                    applyIfEmpty(&monounsaturatedFat, with: result.monounsaturatedFat, markGuess: &monounsaturatedFatIsGuess)
                    monoTouched = monoTouched || !monounsaturatedFat.isEmpty
                    applyIfEmpty(&polyunsaturatedFat, with: result.polyunsaturatedFat, markGuess: &polyunsaturatedFatIsGuess)
                    polyTouched = polyTouched || !polyunsaturatedFat.isEmpty
                    applyIfEmpty(&saturatedFat, with: result.saturatedFat, markGuess: &saturatedFatIsGuess)
                    satTouched = satTouched || !saturatedFat.isEmpty
                    applyIfEmpty(&transFat, with: result.transFat, markGuess: &transFatIsGuess)
                    transTouched = transTouched || !transFat.isEmpty

                    applyIfEmpty(&animalProtein, with: result.animalProtein, markGuess: &animalProteinIsGuess)
                    animalTouched = animalTouched || !animalProtein.isEmpty
                    applyIfEmpty(&plantProtein, with: result.plantProtein, markGuess: &plantProteinIsGuess)
                    plantTouched = plantTouched || !plantProtein.isEmpty
                    applyIfEmpty(&proteinSupplements, with: result.proteinSupplements, markGuess: &proteinSupplementsIsGuess)
                    supplementsTouched = supplementsTouched || !proteinSupplements.isEmpty

                    // Vitamins/minerals (UI uses vitaminsUnit; storage is mg)
                    func applyVitaminMineral(_ field: inout String, _ guessFlag: inout Bool, mg: Int?) {
                        guard field.isEmpty, let mg else { return }
                        let uiVal: Int
                        switch vitaminsUnit {
                        case .milligrams: uiVal = mg
                        case .micrograms: uiVal = Int(Double(mg) * 1000.0)
                        }
                        field = String(max(0, uiVal))
                        guessFlag = true
                    }
                    applyVitaminMineral(&vitaminA, &vitaminAIsGuess, mg: result.vitaminA)
                    applyVitaminMineral(&vitaminB, &vitaminBIsGuess, mg: result.vitaminB)
                    applyVitaminMineral(&vitaminC, &vitaminCIsGuess, mg: result.vitaminC)
                    applyVitaminMineral(&vitaminD, &vitaminDIsGuess, mg: result.vitaminD)
                    applyVitaminMineral(&vitaminE, &vitaminEIsGuess, mg: result.vitaminE)
                    applyVitaminMineral(&vitaminK, &vitaminKIsGuess, mg: result.vitaminK)

                    applyVitaminMineral(&calcium, &calciumIsGuess, mg: result.calcium)
                    applyVitaminMineral(&iron, &ironIsGuess, mg: result.iron)
                    applyVitaminMineral(&potassium, &potassiumIsGuess, mg: result.potassium)
                    applyVitaminMineral(&zinc, &zincIsGuess, mg: result.zinc)
                    applyVitaminMineral(&magnesium, &magnesiumIsGuess, mg: result.magnesium)

                    // If totals present but subfields empty, use your existing autofill helpers
                    if !(carbohydrates.isEmpty), sugars.isEmpty || starch.isEmpty || fibre.isEmpty {
                        autofillCarbSubfieldsIfNeeded()
                    }
                    if !(protein.isEmpty), animalProtein.isEmpty || plantProtein.isEmpty || proteinSupplements.isEmpty {
                        autofillProteinSubfieldsIfNeeded()
                    }
                    if !(fat.isEmpty), monounsaturatedFat.isEmpty || polyunsaturatedFat.isEmpty || saturatedFat.isEmpty || transFat.isEmpty {
                        autofillFatSubfieldsIfNeeded()
                    }

                    recomputeConsistencyAndBlinkIfFixed()

                    // IMPORTANT: force-enable Save now that the wand finished applying values
                    forceEnableSave = true
                }
            }
        } catch {
            await MainActor.run { analyzeError = "Analysis failed: \(error)" }
        }
    }

    private var isValid: Bool {
        guard let cal = Int(calories), cal > 0 else { return false }
        let allNumericStrings = [
            calories, carbohydrates, protein, sodium, fat,
            starch, sugars, fibre, monounsaturatedFat, polyunsaturatedFat, saturatedFat, transFat,
            animalProtein, plantProtein, proteinSupplements,
            vitaminA, vitaminB, vitaminC, vitaminD, vitaminE, vitaminK,
            calcium, iron, potassium, zinc, magnesium
        ]
        return allNumericStrings.dropFirst().allSatisfy { s in
            guard !s.isEmpty else { return true }
            return Int(s).map { $0 > 0 } ?? false
        }
    }

    private func intOrZero(_ text: String) -> Int {
        max(0, Int(text) ?? 0)
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

    // MARK: - Saving

    private func save() {
        // Enforce daily meal cap for new meals only (not editing)
        if meal == nil {
            let tier = Entitlements.tier(for: session)
            let maxPerDay = Entitlements.maxMealsPerDay(for: tier)
            if maxPerDay < 9000 {
                let todaysCount = Entitlements.mealsRecordedToday(in: context)
                if todaysCount >= maxPerDay {
                    limitErrorMessage = "Free tier allows up to \(maxPerDay) meals per day."
                    showingLimitAlert = true
                    return
                }
            }
        }

        guard let calInt = Int(calories), calInt > 0 else { return }

        // Create or update Meal
        let object: Meal = meal ?? Meal(context: context)
        if meal == nil {
            object.id = UUID()
            object.date = Date()
        }

        // Title/description
        let title = defaultTitle(using: object.date)
        object.mealDescription = title

        // Energy: store in kcal in model; if UI is kJ, convert to kcal
        let kcal: Double = {
            if energyUnit == .calories {
                return Double(intOrZero(calories))
            } else {
                // kJ -> kcal
                return (Double(intOrZero(calories)) / 4.184).rounded()
            }
        }()
        object.calories = max(0, kcal)

        // Macros (grams)
        object.carbohydrates = Double(intOrZero(carbohydrates))
        object.protein = Double(intOrZero(protein))
        object.fat = Double(intOrZero(fat))

        // Sodium UI -> store as mg in Meal.sodium
        let sodiumMg: Double = {
            let val = Double(intOrZero(sodium))
            switch sodiumUnit {
            case .milligrams: return val
            case .grams: return val * 1000.0
            }
        }()
        object.sodium = max(0, sodiumMg)

        // Carbs subs (grams)
        object.starch = Double(intOrZero(starch))
        object.sugars = Double(intOrZero(sugars))
        object.fibre = Double(intOrZero(fibre))

        // Fat subs (grams)
        object.monounsaturatedFat = Double(intOrZero(monounsaturatedFat))
        object.polyunsaturatedFat = Double(intOrZero(polyunsaturatedFat))
        object.saturatedFat = Double(intOrZero(saturatedFat))
        object.transFat = Double(intOrZero(transFat))

        // Protein subs (grams)
        object.animalProtein = Double(intOrZero(animalProtein))
        object.plantProtein = Double(intOrZero(plantProtein))
        object.proteinSupplements = Double(intOrZero(proteinSupplements))

        // Vitamins & Minerals: UI unit -> mg storage
        func uiToMG(_ text: String) -> Double {
            let v = Double(intOrZero(text))
            switch vitaminsUnit {
            case .milligrams: return v
            case .micrograms: return v / 1000.0
            }
        }
        object.vitaminA = uiToMG(vitaminA)
        object.vitaminB = uiToMG(vitaminB)
        object.vitaminC = uiToMG(vitaminC)
        object.vitaminD = uiToMG(vitaminD)
        object.vitaminE = uiToMG(vitaminE)
        object.vitaminK = uiToMG(vitaminK)

        object.calcium = uiToMG(calcium)
        object.iron = uiToMG(iron)
        object.potassium = uiToMG(potassium)
        object.zinc = uiToMG(zinc)
        object.magnesium = uiToMG(magnesium)

        // Accuracy flags
        object.caloriesIsGuess = caloriesIsGuess
        object.carbohydratesIsGuess = carbohydratesIsGuess
        object.proteinIsGuess = proteinIsGuess
        object.sodiumIsGuess = sodiumIsGuess
        object.fatIsGuess = fatIsGuess
        object.starchIsGuess = starchIsGuess
        object.sugarsIsGuess = sugarsIsGuess
        object.fibreIsGuess = fibreIsGuess
        object.monounsaturatedFatIsGuess = monounsaturatedFatIsGuess
        object.polyunsaturatedFatIsGuess = polyunsaturatedFatIsGuess
        object.saturatedFatIsGuess = saturatedFatIsGuess
        object.transFatIsGuess = transFatIsGuess

        object.animalProteinIsGuess = animalProteinIsGuess
        object.plantProteinIsGuess = plantProteinIsGuess
        object.proteinSupplementsIsGuess = proteinSupplementsIsGuess

        object.vitaminAIsGuess = vitaminAIsGuess
        object.vitaminBIsGuess = vitaminBIsGuess
        object.vitaminCIsGuess = vitaminCIsGuess
        object.vitaminDIsGuess = vitaminDIsGuess
        object.vitaminEIsGuess = vitaminEIsGuess
        object.vitaminKIsGuess = vitaminKIsGuess

        object.calciumIsGuess = calciumIsGuess
        object.ironIsGuess = ironIsGuess
        object.potassiumIsGuess = potassiumIsGuess
        object.zincIsGuess = zincIsGuess
        object.magnesiumIsGuess = magnesiumIsGuess

        // Persist
        do {
            try context.save()

            // Refresh header gallery (if editing) and dismiss
            reloadGalleryItems()
            dismiss()
        } catch {
            print("Failed to save meal: \(error)")
        }
    }

    private func numericBindingInt(_ source: Binding<String>) -> Binding<String> {
        Binding(
            get: { source.wrappedValue },
            set: { newValue in
                source.wrappedValue = sanitizeIntegerInput(newValue)
            }
        )
    }

    private func sanitizeIntegerInput(_ input: String) -> String {
        let digitsOnly = input.compactMap { $0.isNumber ? $0 : nil }
        var s = String(digitsOnly)
        if s.isEmpty { return "" }
        while s.first == "0" && s.count > 1 { s.removeFirst() }
        if s == "0" { return "" }
        return s
    }

    private func recomputeConsistency(resetPrevMismatch: Bool = false) {
        let carbsTotal: Int = Int(carbohydrates) ?? 0
        let sugarsVal: Int = Int(sugars) ?? 0
        let starchVal: Int = Int(starch) ?? 0
        let fibreVal: Int = Int(fibre) ?? 0
        let carbsSubSum: Int = sugarsVal + starchVal + fibreVal
        let carbsHasAnySub: Bool = !(sugars.isEmpty && starch.isEmpty && fibre.isEmpty)
        let carbsHasTotal: Bool = !carbohydrates.isEmpty
        carbsMismatch = carbsHasTotal && carbsHasAnySub && (carbsSubSum != carbsTotal)

        let proteinTotal: Int = Int(protein) ?? 0
        let animalVal: Int = Int(animalProtein) ?? 0
        let plantVal: Int = Int(plantProtein) ?? 0
        let suppsVal: Int = Int(proteinSupplements) ?? 0
        let proteinSubSum: Int = animalVal + plantVal + suppsVal
        let proteinHasAnySub: Bool = !(animalProtein.isEmpty && plantProtein.isEmpty && proteinSupplements.isEmpty)
        let proteinHasTotal: Bool = !protein.isEmpty
        proteinMismatch = proteinHasTotal && proteinHasAnySub && (proteinSubSum != proteinTotal)

        let fatTotal: Int = Int(fat) ?? 0
        let monoVal: Int = Int(monounsaturatedFat) ?? 0
        let polyVal: Int = Int(polyunsaturatedFat) ?? 0
        let satVal: Int = Int(saturatedFat) ?? 0
        let transVal: Int = Int(Int(transFat) ?? 0)
        let fatSubSum: Int = monoVal + polyVal + satVal + transVal
        let fatHasAnySub: Bool = !(monounsaturatedFat.isEmpty && polyunsaturatedFat.isEmpty && saturatedFat.isEmpty && transFat.isEmpty)
        let fatHasTotal: Bool = !fat.isEmpty
        fatMismatch = fatHasTotal && fatHasAnySub && (fatSubSum != fatTotal)

        if resetPrevMismatch {
            prevCarbsMismatch = carbsMismatch
            prevProteinMismatch = proteinMismatch
            prevFatMismatch = fatMismatch
        }
    }

    private func recomputeConsistencyAndBlinkIfFixed() {
        let oldCarbsMismatch = carbsMismatch
        let oldProteinMismatch = proteinMismatch
        let oldFatMismatch = fatMismatch

        recomputeConsistency()

        if oldCarbsMismatch && !carbsMismatch { flashGreenTwice(for: .carbs) }
        if oldProteinMismatch && !proteinMismatch { flashGreenTwice(for: .protein) }
        if oldFatMismatch && !fatMismatch { flashGreenTwice(for: .fat) }

        prevCarbsMismatch = carbsMismatch
        prevProteinMismatch = proteinMismatch
        prevFatMismatch = fatMismatch
    }

    private enum GroupKind { case carbs, protein, fat }

    private func flashGreenTwice(for group: GroupKind) {
        Task { @MainActor in
            func setBlink(_ active: Bool) {
                switch group {
                case .carbs: carbsBlink = active
                case .protein: proteinBlink = active
                case .fat: fatBlink = active
                }
            }
            for i in 0..<4 {
                setBlink(i % 2 == 0)
                try? await Task.sleep(nanoseconds: 180_000_000)
            }
            setBlink(false)
        }
    }

    private func flashRedOnce(for group: GroupKind) {
        Task { @MainActor in
            func setRed(_ active: Bool) {
                switch group {
                case .carbs: carbsRedBlink = active
                case .protein: proteinRedBlink = active
                case .fat: fatRedBlink = active
                }
            }
            setRed(true)
            try? await Task.sleep(nanoseconds: 220_000_000)
            setRed(false)
        }
    }

    private func showHelper(for group: GroupKind, sum: Int) {
        Task { @MainActor in
            let text = String(sum)
            switch group {
            case .carbs:
                carbsHelperText = text
                carbsHelperVisible = true
            case .protein:
                proteinHelperText = text
                proteinHelperVisible = true
            case .fat:
                fatHelperText = text
                fatHelperVisible = true
            }
            try? await Task.sleep(nanoseconds: 900_000_000)
            switch group {
            case .carbs: carbsHelperVisible = false
            case .protein: proteinHelperVisible = false
            case .fat: fatHelperVisible = false
            }
        }
    }

    private func autofillCarbSubfieldsIfNeeded() {
        guard let total = Int(carbohydrates), total >= 0 else { return }
        if sugarsTouched && starchTouched && fibreTouched { return }
        let ratios: [Double] = [0.30, 0.60, 0.10]
        let parts = distributeInt(total, ratios: ratios)
        if !sugarsTouched { sugars = parts[0].description; sugarsIsGuess = true }
        if !starchTouched { starch = parts[1].description; starchIsGuess = true }
        if !fibreTouched { fibre = parts[2].description; fibreIsGuess = true }
    }

    private func autofillFatSubfieldsIfNeeded() {
        guard let total = Int(fat), total >= 0 else { return }
        if monoTouched && polyTouched && satTouched && transTouched { return }
        let ratios: [Double] = [0.40, 0.30, 0.25, 0.05]
        let parts = distributeInt(total, ratios: ratios)
        if !monoTouched { monounsaturatedFat = parts[0].description; monounsaturatedFatIsGuess = true }
        if !polyTouched { polyunsaturatedFat = parts[1].description; polyunsaturatedFatIsGuess = true }
        if !satTouched { saturatedFat = parts[2].description; saturatedFatIsGuess = true }
        if !transTouched { transFat = parts[3].description; transFatIsGuess = true }
    }

    private func autofillProteinSubfieldsIfNeeded() {
        guard let total = Int(protein), total >= 0 else { return }
        if animalTouched && plantTouched && supplementsTouched { return }
        let ratios: [Double] = [0.50, 0.40, 0.10]
        let parts = distributeInt(total, ratios: ratios)
        if !animalTouched { animalProtein = parts[0].description; animalProteinIsGuess = true }
        if !plantTouched { plantProtein = parts[1].description; plantProteinIsGuess = true }
        if !supplementsTouched { proteinSupplements = parts[2].description; proteinSupplementsIsGuess = true }
    }

    private func handleTopFromCarbSubs() {
        let hasAnySub = !(sugars.isEmpty && starch.isEmpty && fibre.isEmpty)
        guard hasAnySub else { return }
        let sum = (Int(sugars) ?? 0) + (Int(starch) ?? 0) + (Int(fibre) ?? 0)

        let currentTop = Int(carbohydrates)
        let canAutoUpdate = (currentTop == nil) || (currentTop == carbsLastAutoSum)

        if canAutoUpdate {
            let wasEmpty = carbohydrates.isEmpty
            carbohydrates = String(sum)
            carbohydratesIsGuess = true
            carbsLastAutoSum = sum

            if wasEmpty {
                flashRedOnce(for: .carbs)
                showHelper(for: .carbs, sum: sum)
            }
        }
    }

    private func handleTopFromProteinSubs() {
        let hasAnySub = !(animalProtein.isEmpty && plantProtein.isEmpty && proteinSupplements.isEmpty)
        guard hasAnySub else { return }
        let sum = (Int(animalProtein) ?? 0) + (Int(plantProtein) ?? 0) + (Int(proteinSupplements) ?? 0)

        let currentTop = Int(protein)
        let canAutoUpdate = (currentTop == nil) || (currentTop == proteinLastAutoSum)

        if canAutoUpdate {
            let wasEmpty = protein.isEmpty
            protein = String(sum)
            proteinIsGuess = true
            proteinLastAutoSum = sum

            if wasEmpty {
                flashRedOnce(for: .protein)
                showHelper(for: .protein, sum: sum)
            }
        }
    }

    private func handleTopFromFatSubs() {
        let hasAnySub = !(monounsaturatedFat.isEmpty && polyunsaturatedFat.isEmpty && saturatedFat.isEmpty && transFat.isEmpty)
        guard hasAnySub else { return }
        let mono = Int(monounsaturatedFat) ?? 0
        let poly = Int(polyunsaturatedFat) ?? 0
        let sat = Int(saturatedFat) ?? 0
        let trans = Int(transFat) ?? 0
        let sum = mono + poly + sat + trans

        let currentTop = Int(fat)
        let canAutoUpdate = (currentTop == nil) || (currentTop == fatLastAutoSum)

        if canAutoUpdate {
            let wasEmpty = fat.isEmpty
            fat = String(sum)
            fatIsGuess = true
            fatLastAutoSum = sum

            if wasEmpty {
                flashRedOnce(for: .fat)
                showHelper(for: .fat, sum: sum)
            }
        }
    }

    private func handleHelperForCarbs() {
        let total = Int(carbohydrates) ?? 0
        let sum = (Int(sugars) ?? 0) + (Int(starch) ?? 0) + (Int(fibre) ?? 0)
        let hasAnySub = !(sugars.isEmpty && starch.isEmpty && fibre.isEmpty)
        let hasTotal = !carbohydrates.isEmpty
        if hasAnySub && hasTotal && sum != total {
            showHelper(for: .carbs, sum: sum)
            flashRedOnce(for: .carbs)
        }
    }

    private func handleHelperForProtein() {
        let total = Int(protein) ?? 0
        let sum = (Int(animalProtein) ?? 0) + (Int(plantProtein) ?? 0) + (Int(proteinSupplements) ?? 0)
        let hasAnySub = !(animalProtein.isEmpty && plantProtein.isEmpty && proteinSupplements.isEmpty)
        let hasTotal = !protein.isEmpty
        if hasAnySub && hasTotal && sum != total {
            showHelper(for: .protein, sum: sum)
            flashRedOnce(for: .protein)
        }
    }

    private func handleHelperForFat() {
        let total = Int(fat) ?? 0
        let mono = Int(monounsaturatedFat) ?? 0
        let poly = Int(polyunsaturatedFat) ?? 0
        let sat = Int(saturatedFat) ?? 0
        let trans = Int(transFat) ?? 0
        let sum = mono + poly + sat + trans
        let hasAnySub = !(monounsaturatedFat.isEmpty && polyunsaturatedFat.isEmpty && saturatedFat.isEmpty && transFat.isEmpty)
        let hasTotal = !fat.isEmpty
        if hasAnySub && hasTotal && sum != total {
            showHelper(for: .fat, sum: sum)
            flashRedOnce(for: .fat)
        }
    }

    private func handleFocusLeaveIfNeeded(leaving field: FocusedField) {
        switch field {
        case .carbsTotal:
            recomputeConsistencyAndBlinkIfFixed()
            handleHelperOnTopChangeForCarbs()
        case .proteinTotal:
            recomputeConsistencyAndBlinkIfFixed()
            handleHelperOnTopChangeForProtein()
        case .fatTotal:
            recomputeConsistencyAndBlinkIfFixed()
            handleHelperOnTopChangeForFat()
        default:
            break
        }
    }

    private func handleHelperOnTopChangeForCarbs() {
        let total = Int(carbohydrates) ?? 0
        let sum = (Int(sugars) ?? 0) + (Int(starch) ?? 0) + (Int(fibre) ?? 0)
        let hasAnySub = !(sugars.isEmpty && starch.isEmpty && fibre.isEmpty)
        let hasTotal = !carbohydrates.isEmpty
        if hasAnySub && hasTotal && sum != total {
            showHelper(for: .carbs, sum: sum)
            flashRedOnce(for: .carbs)
        }
    }

    private func handleHelperOnTopChangeForProtein() {
        let total = Int(protein) ?? 0
        let sum = (Int(animalProtein) ?? 0) + (Int(plantProtein) ?? 0) + (Int(proteinSupplements) ?? 0)
        let hasAnySub = !(animalProtein.isEmpty && plantProtein.isEmpty && proteinSupplements.isEmpty)
        let hasTotal = !protein.isEmpty
        if hasAnySub && hasTotal && sum != total {
            showHelper(for: .protein, sum: sum)
            flashRedOnce(for: .protein)
        }
    }

    private func handleHelperOnTopChangeForFat() {
        let total = Int(fat) ?? 0
        let mono = Int(monounsaturatedFat) ?? 0
        let poly = Int(polyunsaturatedFat) ?? 0
        let sat = Int(saturatedFat) ?? 0
        let trans = Int(transFat) ?? 0
        let sum = mono + poly + sat + trans
        let hasAnySub = !(monounsaturatedFat.isEmpty && polyunsaturatedFat.isEmpty && saturatedFat.isEmpty && transFat.isEmpty)
        let hasTotal = !fat.isEmpty
        if hasAnySub && hasTotal && sum != total {
            showHelper(for: .fat, sum: sum)
            flashRedOnce(for: .fat)
        }
    }

    private func distributeInt(_ total: Int, ratios: [Double]) -> [Int] {
        guard total >= 0, !ratios.isEmpty else { return Array(repeating: 0, count: max(1, ratios.count)) }
        let normalized = ratios.map { max(0.0, $0) }
        let sum = normalized.reduce(0, +)
        if sum == 0 { return Array(repeating: 0, count: ratios.count) }

        var parts = [Int]()
        var accumulated = 0
        for i in 0..<(ratios.count - 1) {
            let value = Int(floor(Double(total) * (normalized[i] / sum)))
            parts.append(value)
            accumulated += value
        }
        parts.append(max(0, total - accumulated))
        return parts
    }
}

// MARK: - Gallery models and views

private enum GalleryItem: Identifiable, Equatable {
    case persistent(photo: MealPhoto, url: URL)
    case inMemory(id: UUID, image: UIImage, data: Data, devIndex: Int)

    var id: String {
        switch self {
        case .persistent(let p, _):
            return p.objectID.uriRepresentation().absoluteString
        case .inMemory(let id, _, _, let idx):
            return id.uuidString + "_\(idx)"
        }
    }

    var thumbnailImage: UIImage? {
        switch self {
        case .persistent(_, let url):
            if let data = try? Data(contentsOf: url) {
                return UIImage(data: data)
            }
            return nil
        case .inMemory(_, let img, _, _):
            return img
        }
    }
}

private struct GalleryHeader: View {
    let items: [GalleryItem]
    @Binding var selectedIndex: Int
    @Binding var isExpanded: Bool
    let fullHeight: CGFloat
    let collapsedHeight: CGFloat
    let isBusy: Bool
    let onAnalyzeTap: () -> Void

    // Thumbnail sizing and spacing (10% smaller than 64; tighter spacing)
    private let thumbSize: CGFloat = 58
    private let thumbSpacing: CGFloat = 6
    private let horizontalPadding: CGFloat = 8
    private let bottomPadding: CGFloat = 2

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                if items.isEmpty {
                    HeaderImageView(image: nil)
                        .frame(maxWidth: .infinity)
                        .frame(height: isExpanded ? fullHeight : collapsedHeight)
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                isExpanded.toggle()
                            }
                        }
                } else {
                    // Main swipeable pager
                    TabView(selection: $selectedIndex) {
                        ForEach(items.indices, id: \.self) { idx in
                            let image = items[idx].thumbnailImage
                            HeaderImageView(image: image)
                                .tag(idx)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .frame(maxWidth: .infinity)
                    .frame(height: isExpanded ? fullHeight : collapsedHeight)
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            isExpanded.toggle()
                        }
                    }
                }

                if !items.isEmpty {
                    AnalyzeButton(isBusy: isBusy) { onAnalyzeTap() }
                        .padding(12)
                }
            }

            // Thumbnail strip
            if !items.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: thumbSpacing) {
                        ForEach(items.indices, id: \.self) { idx in
                            let img = items[idx].thumbnailImage
                            ZStack {
                                if let ui = img {
                                    Image(uiImage: ui)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: thumbSize, height: thumbSize)
                                        .clipped()
                                        .cornerRadius(6)
                                } else {
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.1))
                                        .frame(width: thumbSize, height: thumbSize)
                                        .cornerRadius(6)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundStyle(.secondary)
                                        )
                                }
                                // Selection ring
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(selectedIndex == idx ? Color.accentColor : Color.clear, lineWidth: 2)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedIndex = idx
                                }
                            }
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, bottomPadding)
                }
            }
        }
    }
}

private struct HeaderImageView: View {
    let image: UIImage?

    var body: some View {
        Group {
            if let ui = image {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .background(Color.black.opacity(0.05))
                    .accessibilityLabel("Meal photo")
            } else {
                ZStack {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.08))
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("No photo")
            }
        }
        .contentShape(Rectangle())
    }
}

private struct AnalyzeButton: View {
    let isBusy: Bool
    let action: () -> Void

    @State private var rotation: Angle = .degrees(0)

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 44, height: 44)

                if isBusy {
                    // Show a spinning SF Symbol wand while busy
                    Image(systemName: "wand.and.stars")
                        .foregroundColor(.white)
                        .imageScale(.medium)
                        .rotationEffect(rotation)
                        .animation(isBusy ? .linear(duration: 1.0).repeatForever(autoreverses: false) : .default, value: rotation)
                        .onAppear { rotation = .degrees(360) }
                        .onChange(of: isBusy) { busy in
                            if busy { rotation = .degrees(360) } else { rotation = .degrees(0) }
                        }
                } else {
                    Image(systemName: "wand.and.stars")
                        .foregroundColor(.white)
                        .imageScale(.medium)
                        .rotationEffect(.degrees(0))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isBusy ? "Analyzing Photo" : "Analyze Photo")
    }
}

// MARK: - Existing supporting views and helpers (unchanged below)

private struct CompactChevronToggle: View {
    @Binding var isExpanded: Bool
    let labelCollapsed: String
    let labelExpanded: String

    var body: some View {
        Button(action: { isExpanded.toggle() }) {
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption)
                .imageScale(.small)
                .foregroundColor(.accentColor)
                .frame(width: 20, height: 20, alignment: .center)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? labelExpanded : labelCollapsed)
    }
}

private enum ValidationSeverity {
    case none
    case unusual
    case stupid
}

private struct ValidationThresholds {
    static let calories = ValidationThresholds(unusual: 3000, stupid: 10000)
    static let grams = ValidationThresholds(unusual: 300, stupid: 2000)
    static let sodiumMg = ValidationThresholds(unusual: 5000, stupid: 20000)
    static let sodiumG = ValidationThresholds(unusual: 5, stupid: 20)
    static let vitaminMineralMg = ValidationThresholds(unusual: 500, stupid: 2000)
    static let mineralMg = ValidationThresholds(unusual: 1000, stupid: 5000)

    let unusual: Int
    let stupid: Int

    func severity(for value: Int) -> ValidationSeverity {
        if value >= stupid { return .stupid }
        if value >= unusual { return .unusual }
        return .none
    }
}

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
                    Image(systemName: (isExpanded ? "chevron.up" : "chevron.down"))
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

private enum FieldHighlight {
    case none
    case error
    case successBlink(active: Bool)
}

private struct MetricField: View {
    let titleKey: String
    @Binding var text: String
    @Binding var isGuess: Bool
    var keyboard: UIKeyboardType = .numberPad
    let manager: LocalizationManager
    var unitSuffix: String? = nil
    var isPrelocalizedTitle: Bool = false
    var validator: ((Int) -> ValidationSeverity)? = nil

    // Type-erased accessory closures
    var leadingAccessory: (() -> AnyView)? = nil
    var trailingAccessory: (() -> AnyView)? = nil

    var highlight: FieldHighlight = .none

    var focusedField: FocusState<MealFormView.FocusedField?>.Binding? = nil
    var thisField: MealFormView.FocusedField? = nil
    var onSubmit: (() -> Void)? = nil

    // New: handedness preference
    @AppStorage("handedness") private var handedness: Handedness = .right

    init(
        titleKey: String,
        text: Binding<String>,
        isGuess: Binding<Bool>,
        keyboard: UIKeyboardType = .numberPad,
        manager: LocalizationManager,
        unitSuffix: String? = nil,
        isPrelocalizedTitle: Bool = false,
        validator: ((Int) -> ValidationSeverity)? = nil,
        leadingAccessory: (() -> AnyView)? = nil,
        trailingAccessory: (() -> AnyView)? = nil,
        highlight: FieldHighlight = .none,
        focusedField: FocusState<MealFormView.FocusedField?>.Binding? = nil,
        thisField: MealFormView.FocusedField? = nil,
        onSubmit: (() -> Void)? = nil
    ) {
        self.titleKey = titleKey
        self._text = text
        self._isGuess = isGuess
        self.keyboard = keyboard
        self.manager = manager
        self.unitSuffix = unitSuffix
        self.isPrelocalizedTitle = isPrelocalizedTitle
        self.validator = validator
        self.leadingAccessory = leadingAccessory
        self.trailingAccessory = trailingAccessory
        self.highlight = highlight
        self.focusedField = focusedField
        self.thisField = thisField
        self.onSubmit = onSubmit
    }

    private var tintColor: Color { isGuess ? .orange : .green }

    private var displayTitle: String {
        if isPrelocalizedTitle { return titleKey }
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

    private var parsedValue: Int? { Int(text) }

    private var severity: ValidationSeverity {
        guard let v = parsedValue, let validator else { return .none }
        if v < 0 { return .stupid }
        return validator(v)
    }

    private var underlineColor: Color {
        switch highlight {
        case .error: return .red
        case .successBlink(let active): return active ? .green : defaultUnderlineColor
        case .none: return defaultUnderlineColor
        }
    }

    private var defaultUnderlineColor: Color {
        switch severity {
        case .none: return .clear
        case .unusual: return .orange
        case .stupid: return .red
        }
    }

    private var underlineHeight: CGFloat {
        switch highlight {
        case .error: return 2
        case .successBlink(let active): return active ? 2 : defaultUnderlineHeight
        case .none: return defaultUnderlineHeight
        }
    }

    private var defaultUnderlineHeight: CGFloat {
        switch severity {
        case .none: return 1
        case .unusual: return 2
        case .stupid: return 2
        }
    }

    private func requestFocus() {
        if let focusedField, let thisField {
            focusedField.wrappedValue = thisField
        }
    }

    @ViewBuilder
    private func headerRow() -> some View {
        if handedness == .left {
            HStack(alignment: .firstTextBaseline) {
                // Segmented first for left-handed users
                Picker("", selection: $isGuess) {
                    Text(manager.localized("accurate")).tag(false)
                    Text(manager.localized("guess")).tag(true)
                }
                .font(.caption)
                .pickerStyle(.segmented)
                .tint(tintColor)
                .frame(maxWidth: 180)
                .accessibilityLabel(displayTitle + " " + manager.localized("accuracy"))
                .simultaneousGesture(TapGesture().onEnded { requestFocus() })

                Spacer(minLength: 8)

                Text(displayTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
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
                .simultaneousGesture(TapGesture().onEnded { requestFocus() })
            }
        }
    }

    @ViewBuilder
    private func inputRow() -> some View {
        if handedness == .left {
            // Mirror: put trailing accessory and unit closer to left, then text field
        HStack(spacing: 6) {
                if let trailing = trailingAccessory {
                    trailing()
                }

                if let suffix = unitSuffix {
                    Text(suffix)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TextField("", text: $text)
                    .keyboardType(keyboard)
                    .multilineTextAlignment(.leading)
                    .submitLabel(.done)
                    .onSubmit { onSubmit?() }
                    .applyFocus(focusedField: focusedField, thisField: thisField)

                if let accessory = leadingAccessory {
                    accessory()
                }
            }
        } else {
            HStack(spacing: 6) {
                if let accessory = leadingAccessory {
                    accessory()
                }

                TextField("", text: $text)
                    .keyboardType(keyboard)
                    .multilineTextAlignment(.leading)
                    .submitLabel(.done)
                    .onSubmit { onSubmit?() }
                    .applyFocus(focusedField: focusedField, thisField: thisField)

                if let suffix = unitSuffix {
                    Text(suffix)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let trailing = trailingAccessory {
                    trailing()
                }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            headerRow()

            VStack(spacing: 2) {
                inputRow()
                    .contentShape(Rectangle())
                    .onTapGesture { requestFocus() }

                Rectangle()
                    .fill(underlineColor)
                    .frame(height: underlineHeight)
                    .animation(.easeInOut(duration: 0.18), value: underlineColor)
                    .animation(.easeInOut(duration: 0.18), value: underlineHeight)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { requestFocus() }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(displayTitle)
    }
}

private extension View {
    @ViewBuilder
    func applyFocus(focusedField: FocusState<MealFormView.FocusedField?>.Binding?, thisField: MealFormView.FocusedField?) -> some View {
        if let focusedField, let thisField {
            self.focused(focusedField, equals: thisField)
        } else {
            self
        }
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
            MetricField(titleKey: "vitamin_a", text: $aText, isGuess: $aIsGuess, keyboard: .numberPad, manager: manager, unitSuffix: unitSuffix, validator: { ValidationThresholds.vitaminMineralMg.severityForVitaminsUI($0, unit: .milligrams) })
            MetricField(titleKey: "vitamin_b", text: $bText, isGuess: $bIsGuess, keyboard: .numberPad, manager: manager, unitSuffix: unitSuffix, validator: { ValidationThresholds.vitaminMineralMg.severityForVitaminsUI($0, unit: .milligrams) })
            MetricField(titleKey: "vitamin_c", text: $cText, isGuess: $cIsGuess, keyboard: .numberPad, manager: manager, unitSuffix: unitSuffix, validator: { ValidationThresholds.vitaminMineralMg.severityForVitaminsUI($0, unit: .milligrams) })
            MetricField(titleKey: "vitamin_d", text: $dText, isGuess: $dIsGuess, keyboard: .numberPad, manager: manager, unitSuffix: unitSuffix, validator: { ValidationThresholds.vitaminMineralMg.severityForVitaminsUI($0, unit: .milligrams) })
            MetricField(titleKey: "vitamin_e", text: $eText, isGuess: $eIsGuess, keyboard: .numberPad, manager: manager, unitSuffix: unitSuffix, validator: { ValidationThresholds.vitaminMineralMg.severityForVitaminsUI($0, unit: .milligrams) })
            MetricField(titleKey: "vitamin_k", text: $kText, isGuess: $kIsGuess, keyboard: .numberPad, manager: manager, unitSuffix: unitSuffix, validator: { ValidationThresholds.vitaminMineralMg.severityForVitaminsUI($0, unit: .milligrams) })
        }
    }
}

private extension ValidationThresholds {
    func severityForVitaminsUI(_ uiValue: Int, unit: VitaminsUnit) -> ValidationSeverity {
        let mg: Int
        switch unit {
        case .milligrams: mg = uiValue
        case .micrograms: mg = Int(Double(uiValue) / 1000.0)
        }
        return severity(for: mg)
    }
}

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
            MetricField(titleKey: "sugars", text: $sugarsText, isGuess: $sugarsIsGuess, keyboard: .numberPad, manager: manager, unitSuffix: "g", validator: { ValidationThresholds.grams.severity(for: $0) })
            MetricField(titleKey: "starch", text: $starchText, isGuess: $starchIsGuess, keyboard: .numberPad, manager: manager, unitSuffix: "g", validator: { ValidationThresholds.grams.severity(for: $0) })
            MetricField(titleKey: "fibre", text: $fibreText, isGuess: $fibreIsGuess, keyboard: .numberPad, manager: manager, unitSuffix: "g", validator: { ValidationThresholds.grams.severity(for: $0) })
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
            MetricField(titleKey: "animal_protein", text: $animalText, isGuess: $animalIsGuess, keyboard: .numberPad, manager: manager, unitSuffix: "g", validator: { ValidationThresholds.grams.severity(for: $0) })
            MetricField(titleKey: "plant_protein", text: $plantText, isGuess: $plantIsGuess, keyboard: .numberPad, manager: manager, unitSuffix: "g", validator: { ValidationThresholds.grams.severity(for: $0) })
            MetricField(titleKey: "protein_supplements", text: $supplementsText, isGuess: $supplementsIsGuess, keyboard: .numberPad, manager: manager, unitSuffix: "g", validator: { ValidationThresholds.grams.severity(for: $0) })
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
            MetricField(titleKey: "monounsaturated_fat", text: $monoText, isGuess: $monoIsGuess, keyboard: .numberPad, manager: manager, unitSuffix: "g", validator: { ValidationThresholds.grams.severity(for: $0) })
            MetricField(titleKey: "polyunsaturated_fat", text: $polyText, isGuess: $polyIsGuess, keyboard: .numberPad, manager: manager, unitSuffix: "g", validator: { ValidationThresholds.grams.severity(for: $0) })
            MetricField(titleKey: "saturated_fat", text: $satText, isGuess: $satIsGuess, keyboard: .numberPad, manager: manager, unitSuffix: "g", validator: { ValidationThresholds.grams.severity(for: $0) })
            MetricField(titleKey: "trans_fat", text: $transText, isGuess: $transIsGuess, keyboard: .numberPad, manager: manager, unitSuffix: "g", validator: { ValidationThresholds.grams.severity(for: $0) })
        }
    }
}

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
            MetricField(
                titleKey: "calcium",
                text: $calciumText,
                isGuess: $calciumIsGuess,
                keyboard: .numberPad,
                manager: manager,
                unitSuffix: unitSuffix,
                validator: { ValidationThresholds.mineralMg.severityForVitaminsUI($0, unit: .milligrams) }
            )
            MetricField(
                titleKey: "iron",
                text: $ironText,
                isGuess: $ironIsGuess,
                keyboard: .numberPad,
                manager: manager,
                unitSuffix: unitSuffix,
                validator: { ValidationThresholds.mineralMg.severityForVitaminsUI($0, unit: .milligrams) }
            )
            MetricField(
                titleKey: "potassium",
                text: $potassiumText,
                isGuess: $potassiumIsGuess,
                keyboard: .numberPad,
                manager: manager,
                unitSuffix: unitSuffix,
                validator: { ValidationThresholds.mineralMg.severityForVitaminsUI($0, unit: .milligrams) }
            )
            MetricField(
                titleKey: "zinc",
                text: $zincText,
                isGuess: $zincIsGuess,
                keyboard: .numberPad,
                manager: manager,
                unitSuffix: unitSuffix,
                validator: { ValidationThresholds.mineralMg.severityForVitaminsUI($0, unit: .milligrams) }
            )
            MetricField(
                titleKey: "magnesium",
                text: $magnesiumText,
                isGuess: $magnesiumIsGuess,
                keyboard: .numberPad,
                manager: manager,
                unitSuffix: unitSuffix,
                validator: { ValidationThresholds.mineralMg.severityForVitaminsUI($0, unit: .milligrams) }
            )
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

private struct CompactSectionSpacing: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .listSectionSpacing(.compact)
        } else {
            content
        }
    }
}

#Preview {
    let controller = PersistenceController(inMemory: true)
    let context = controller.container.viewContext

    if #available(iOS 16.0, *) {
        return NavigationStack {
            MealFormView()
                .environment(\.managedObjectContext, context)
                .environmentObject(SessionManager())
        }
    } else {
        return NavigationView {
            MealFormView()
                .environment(\.managedObjectContext, context)
                .environmentObject(SessionManager())
        }
    }
}
