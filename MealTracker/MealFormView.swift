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
import AVFoundation

struct MealFormView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) var context
    @EnvironmentObject var session: SessionManager
    @Environment(\.scenePhase) var scenePhase

    // App settings
    @AppStorage("energyUnit") var energyUnit: EnergyUnit = .calories
    @AppStorage("appLanguageCode") var appLanguageCode: String = LocalizationManager.defaultLanguageCode
    @AppStorage("sodiumUnit") var sodiumUnit: SodiumUnit = .milligrams
    @AppStorage("showVitamins") var showVitamins: Bool = false
    @AppStorage("vitaminsUnit") var vitaminsUnit: VitaminsUnit = .milligrams
    @AppStorage("showMinerals") var showMinerals: Bool = false
    // New: stimulants group visibility (key matches SettingsView)
    @AppStorage("showSimulants") var showSimulants: Bool = false

    // Fetch active people (non-soft-deleted)
    @FetchRequest(fetchRequest: Person.fetchAllRequest())
    private var people: FetchedResults<Person>

    // Selected person for this meal (Pro only)
    @State private var selectedPerson: Person?

    // Person picker presentation
    @State private var showingPersonPicker: Bool = false

    // Hidden title/date inputs removed from UI; we still keep local state for default title logic
    @State var mealDescription: String = "" // not shown in UI for new meals
    // Numeric inputs (now integers only)
    @State var calories: String = ""
    @State var carbohydrates: String = ""
    @State var protein: String = ""
    @State var sodium: String = ""          // renamed from salt for UI
    @State var fat: String = ""
    // Alcohol (grams)
    @State var alcohol: String = ""
    // Nicotine (milligrams)
    @State var nicotine: String = ""
    // Theobromine (milligrams)
    @State var theobromine: String = ""
    // Caffeine (milligrams) [NEW]
    @State var caffeine: String = ""
    // Taurine (milligrams) [NEW]
    @State var taurine: String = ""

    // Added missing nutrient fields
    @State var starch: String = ""
    @State var sugars: String = ""
    @State var fibre: String = ""
    // New fat breakdown fields
    @State var monounsaturatedFat: String = ""
    @State var polyunsaturatedFat: String = ""
    @State var saturatedFat: String = ""
    @State var transFat: String = ""
    // New: Omega-3 (grams)
    @State var omega3: String = ""
    // New: Omega-6 (grams)
    @State var omega6: String = ""

    // New protein breakdown fields
    @State var animalProtein: String = ""
    @State var plantProtein: String = ""
    @State var proteinSupplements: String = ""
    // Vitamins (UI text values; storage is mg, conversion applied)
    @State var vitaminA: String = ""
    @State var vitaminB: String = ""
    @State var vitaminC: String = ""
    @State var vitaminD: String = ""
    @State var vitaminE: String = ""
    @State var vitaminK: String = ""
    // Minerals (UI text values; storage is mg, conversion applied)
    @State var calcium: String = ""
    @State var iron: String = ""
    @State var potassium: String = ""
    @State var zinc: String = ""
    @State var magnesium: String = ""

    // Accuracy flags: default Guess = true
    @State var caloriesIsGuess = true
    @State var carbohydratesIsGuess = true
    @State var proteinIsGuess = true
    @State var sodiumIsGuess = true
    @State var fatIsGuess = true
    @State var alcoholIsGuess = true
    @State var nicotineIsGuess = true
    @State var theobromineIsGuess = true
    // Caffeine accuracy flag [NEW]
    @State var caffeineIsGuess = true
    // Taurine accuracy flag [NEW]
    @State var taurineIsGuess = true
    @State var starchIsGuess = true
    @State var sugarsIsGuess = true
    @State var fibreIsGuess = true
    @State var monounsaturatedFatIsGuess = true
    @State var polyunsaturatedFatIsGuess = true
    @State var saturatedFatIsGuess = true
    @State var transFatIsGuess = true
    // New: Omega-3 accuracy flag
    @State var omega3IsGuess = true
    // New: Omega-6 accuracy flag
    @State var omega6IsGuess = true

    // Protein breakdown flags
    @State var animalProteinIsGuess = true
    @State var plantProteinIsGuess = true
    @State var proteinSupplementsIsGuess = true
    // Vitamins guess flags
    @State var vitaminAIsGuess = true
    @State var vitaminBIsGuess = true
    @State var vitaminCIsGuess = true
    @State var vitaminDIsGuess = true
    @State var vitaminEIsGuess = true
    @State var vitaminKIsGuess = true
    // Minerals guess flags
    @State var calciumIsGuess = true
    @State var ironIsGuess = true
    @State var potassiumIsGuess = true
    @State var zincIsGuess = true
    @State var magnesiumIsGuess = true

    // Touched flags to avoid overwriting manual edits
    @State var sugarsTouched = false
    @State var starchTouched = false
    @State var fibreTouched = false

    @State var monoTouched = false
    @State var polyTouched = false
    @State var satTouched = false
    @State var transTouched = false
    @State var omega3Touched = false
    @State var omega6Touched = false

    @State var animalTouched = false
    @State var plantTouched = false
    @State var supplementsTouched = false

    // Track last auto-sum for totals so we can keep updating while user types
    @State var carbsLastAutoSum: Int?
    @State var proteinLastAutoSum: Int?
    @State var fatLastAutoSum: Int?

    // We won’t show date picker; date will be set on save
    @State var date: Date = Date()

    // Location manager
    @StateObject var locationManager = LocationManager()

    // Settings presentation
    @State var showingSettings = false

    // Expand/collapse state (per session, compatible with older iOS)
    @State var expandedCarbs = false
    @State var expandedProtein = false
    @State var expandedFat = false
    @State var expandedVitamins = false
    @State var expandedMinerals = false
    // New: Stimulants expansion
    @State var expandedStimulants = false

    // Group consistency states
    @State var carbsMismatch = false
    @State var proteinMismatch = false
    @State var fatMismatch = false

    @State var carbsBlink = false
    @State var proteinBlink = false
    @State var fatBlink = false

    // New: short red blink when subfields have values but top-level is empty at time of edit
    @State var carbsRedBlink = false
    @State var proteinRedBlink = false
    @State var fatRedBlink = false

    // Helper number states (brief “(sum)” display)
    @State var carbsHelperText: String = ""
    @State var proteinHelperText: String = ""
    @State var fatHelperText: String = ""

    @State var carbsHelperVisible: Bool = false
    @State var proteinHelperVisible: Bool = false
    @State var fatHelperVisible: Bool = false

    // Track previous mismatch to detect corrections
    @State var prevCarbsMismatch = false
    @State var prevProteinMismatch = false
    @State var prevFatMismatch = false

    // Focus handling to delay validation until leaving a field
    enum FocusedField: Hashable {
        case calories
        case carbsTotal
        case proteinTotal
        case fatTotal
        case sodium
    }
    @FocusState var focused: FocusedField?
    @State var lastFocused: FocusedField?

    // MARK: - Gallery state
    let maxPhotos = 2
    @State var galleryItems: [GalleryItem] = [] // ordered, display-ready
    @State var selectedIndex: Int = 0

    // Expanded header height toggle (kept from previous UI)
    @State var isImageExpanded: Bool = false

    // MARK: - Analyze button state
    @State var isAnalyzing: Bool = false
    @State var analyzeError: String?

    // Force-enable Save after wand finishes
    @State var forceEnableSave: Bool = false

    // MARK: - Limit alert state
    @State var showingLimitAlert: Bool = false
    @State var limitErrorMessage: String?

    // MARK: - Delete confirmation state
    @State var showingDeleteConfirm: Bool = false

    // MARK: - Camera state
    @State var showingCamera: Bool = false
    @State var cameraErrorMessage: String?

    // Auto-open gating and permission alert
    @State var didAutoOpenThisActivation: Bool = false
    @State var showingCameraPermissionAlert: Bool = false
    @State var cameraPermissionMessage: String?

    // Track if this home screen is currently visible (not pushed away)
    @State var isHomeVisible: Bool = false

    // MARK: - Photo library state
    @State var showingPhotoPicker: Bool = false

    @State var meal: Meal?

    // New: distinguish explicit edit mode (opened from gallery) from auto-created meals for photos
    let explicitEditMode: Bool

    init(meal: Meal? = nil) {
        self._meal = State(initialValue: meal)
        // If the caller provided a meal, we’re explicitly editing.
        self.explicitEditMode = (meal != nil)
    }

    // Keep this for other logic if needed, but UI visibility will use explicitEditMode
    var isEditing: Bool { meal != nil }

    var body: some View {
        // Keep local constants lightly typed to help the solver
        let l: LocalizationManager = LocalizationManager(languageCode: appLanguageCode)
        let fullHeight: CGFloat = UIScreen.main.bounds.height * 0.45
        let collapsedHeight: CGFloat = fullHeight * 0.5

        return mainContent(l: l, fullHeight: fullHeight, collapsedHeight: collapsedHeight)
    }

    // Split the large body into a smaller builder
    @ViewBuilder
    func mainContent(l: LocalizationManager, fullHeight: CGFloat, collapsedHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            GalleryHeader(
                items: galleryItems,
                selectedIndex: $selectedIndex,
                isExpanded: $isImageExpanded,
                fullHeight: fullHeight,
                collapsedHeight: collapsedHeight,
                isBusy: $isAnalyzing.wrappedValue,
                onAnalyzeTap: {
                    Task { await analyzePhoto() }
                },
                onCameraTap: {
                    showingCamera = true
                },
                onPhotosTap: {
                    showingPhotoPicker = true
                },
                trailingAccessoryButton: personSelectorAccessoryIfEligible()
            )

            formContent(l: l)
                .modifier(CompactSectionSpacing())
        }
        .toolbar { toolbarContent(l: l) }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(session)
        }
        .sheet(isPresented: $showingCamera) {
            CameraCaptureView { result in
                showingCamera = false
                switch result {
                case .success(let payload):
                    Task { await handleCapturedPhoto(data: payload.data, suggestedExt: payload.suggestedExt) }
                case .failure(let error):
                    cameraErrorMessage = error.localizedDescription
                    limitErrorMessage = cameraErrorMessage
                    showingLimitAlert = cameraErrorMessage != nil
                case .none:
                    break
                }
            }
        }
        .sheet(isPresented: $showingPhotoPicker) {
            PhotoLibraryPickerView { result in
                showingPhotoPicker = false
                switch result {
                case .success(let payload):
                    Task { await handleCapturedPhoto(data: payload.data, suggestedExt: payload.suggestedExt) }
                case .failure(let error):
                    limitErrorMessage = error.localizedDescription
                    showingLimitAlert = true
                case .none:
                    break
                }
            }
        }
        .alert(isPresented: $showingLimitAlert) {
            Alert(
                title: Text("Limit Reached"),
                message: Text(limitErrorMessage ?? "You have reached your limit."),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert("Camera Access Needed", isPresented: $showingCameraPermissionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text(cameraPermissionMessage ?? "Please enable camera access in Settings to take meal photos.")
        }
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
        .onAppear { onAppearSetup(l: l); initializeSelectedPersonIfNeeded() }
        .onDisappear { isHomeVisible = false }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                scheduleAutoOpenCameraIfNeeded()
            case .inactive, .background:
                didAutoOpenThisActivation = false
            default:
                break
            }
        }
        // Person picker sheet
        .actionSheet(isPresented: $showingPersonPicker) {
            ActionSheet(
                title: Text("Select Person"),
                buttons: personActionSheetButtons()
            )
        }
    }

    // Build the trailing accessory button if user is eligible to assign person
    private func personSelectorAccessoryIfEligible() -> AnyView? {
        let tier = Entitlements.tier(for: session)
        guard session.isLoggedIn && tier == .paid && !people.isEmpty && !galleryItems.isEmpty else {
            return nil
        }
        let title = "Select Person"
        return AnyView(
            PersonPickerButton(title: title) {
                showingPersonPicker = true
            }
        )
    }

    // ActionSheet buttons for person selection
    private func personActionSheetButtons() -> [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = people.map { person in
            .default(Text(person.name)) {
                selectedPerson = person
                // If a meal already exists, attach it immediately for consistency
                if let m = meal {
                    attach(meal: m, to: person)
                }
            }
        }
        buttons.append(.cancel())
        return buttons
    }

    // Attach meal to exactly one person (remove from others)
    private func attach(meal: Meal, to person: Person) {
        // Remove from any other active person's set
        for p in people {
            if p != person, p.meal.contains(meal) {
                p.removeFromMeal(meal)
            }
        }
        // Add to chosen person's set if not present
        if !person.meal.contains(meal) {
            person.addToMeal(meal)
        }
        try? context.save()
    }

    // Initialize selectedPerson from existing meal or default person
    private func initializeSelectedPersonIfNeeded() {
        guard selectedPerson == nil else { return }
        // If editing, find the person who already owns this meal
        if let m = meal {
            if let owner = people.first(where: { $0.meal.contains(m) }) {
                selectedPerson = owner
                return
            }
        }
        // Otherwise use default person if any
        if let def = people.first(where: { $0.isDefault }) ?? people.first {
            selectedPerson = def
        }
    }

    @ToolbarContentBuilder
    func toolbarContent(l: LocalizationManager) -> some ToolbarContent {
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
        ToolbarItem(placement: .topBarLeading) {
            NavigationLink {
                MealsGalleryView()
            } label: {
                Image(systemName: "photo.on.rectangle")
            }
            .accessibilityLabel("Open Meal Gallery")
        }
        ToolbarItem(placement: .bottomBar) {
            if explicitEditMode {
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

    func formContent(l: LocalizationManager) -> some View {
        Form {
            titleSection(l: l)
            caloriesSection(l: l)
            carbsSection(l: l)
            proteinSection(l: l)
            fatSection(l: l)
            sodiumSection(l: l)
            if showVitamins { vitaminsSection(l: l) }
            if showMinerals { mineralsSection(l: l) }
            // Move stimulants to the bottom, below minerals
            if showSimulants { stimulantsSection(l: l) }
        }
    }

    @ViewBuilder
    func titleSection(l: LocalizationManager) -> some View {
        if explicitEditMode {
            Section {
                TextField("Meal title", text: $mealDescription, prompt: Text("Enter a title"))
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
            }
            .padding(.vertical, 2)
        }
    }

    func caloriesSection(l: LocalizationManager) -> some View {
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
    }

    func carbsSection(l: LocalizationManager) -> some View {
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
    }

    func proteinSection(l: LocalizationManager) -> some View {
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
    }

    func fatSection(l: LocalizationManager) -> some View {
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
                             transText: numericBindingInt($transFat), transIsGuess: $transFatIsGuess,
                             omega3Text: numericBindingInt($omega3), omega3IsGuess: $omega3IsGuess,
                             omega6Text: numericBindingInt($omega6), omega6IsGuess: $omega6IsGuess)
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
                .onChange(of: omega3, perform: { _ in
                    omega3Touched = true
                    // Not included in total consistency for now
                })
                .onChange(of: omega6, perform: { _ in
                    omega6Touched = true
                    // Not included in total consistency for now
                })
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }
        }
        .padding(.vertical, 2)
        .onChange(of: expandedFat, perform: { expanded in
            if expanded { handleTopFromFatSubs() }
        })
    }

    func sodiumSection(l: LocalizationManager) -> some View {
        Section {
            MetricField(titleKey: "sodium",
                        text: numericBindingInt($sodium),
                        isGuess: $sodiumIsGuess,
                        keyboard: .numberPad,
                        manager: l,
                        unitSuffix: sodiumUnit.displaySuffix,
                        isPrelocalizedTitle: false,
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
    }

    // New: Stimulants group (Alcohol + Nicotine + Theobromine + Caffeine + Taurine)
    func stimulantsSection(l: LocalizationManager) -> some View {
        Section {
            ToggleDetailsButton(
                isExpanded: $expandedStimulants,
                titleCollapsed: l.localized("show_stimulants"),
                titleExpanded: l.localized("hide_stimulants")
            )

            if expandedStimulants {
                VStack(spacing: 0) {
                    MetricField(
                        titleKey: "alcohol",
                        text: numericBindingInt($alcohol),
                        isGuess: $alcoholIsGuess,
                        keyboard: .numberPad,
                        manager: l,
                        unitSuffix: "g",
                        isPrelocalizedTitle: false,
                        validator: { ValidationThresholds.grams.severity(for: $0) }
                    )
                    MetricField(
                        titleKey: "nicotine",
                        text: numericBindingInt($nicotine),
                        isGuess: $nicotineIsGuess,
                        keyboard: .numberPad,
                        manager: l,
                        unitSuffix: "mg",
                        isPrelocalizedTitle: false,
                        validator: { ValidationThresholds.vitaminMineralMg.severity(for: $0) }
                    )
                    MetricField(
                        titleKey: "theobromine",
                        text: numericBindingInt($theobromine),
                        isGuess: $theobromineIsGuess,
                        keyboard: .numberPad,
                        manager: l,
                        unitSuffix: "mg",
                        isPrelocalizedTitle: false,
                        validator: { ValidationThresholds.vitaminMineralMg.severity(for: $0) }
                    )
                    // Caffeine (mg)
                    MetricField(
                        titleKey: "caffeine",
                        text: numericBindingInt($caffeine),
                        isGuess: $caffeineIsGuess,
                        keyboard: .numberPad,
                        manager: l,
                        unitSuffix: "mg",
                        isPrelocalizedTitle: false,
                        validator: { ValidationThresholds.vitaminMineralMg.severity(for: $0) }
                    )
                    // Taurine (mg) [NEW]
                    MetricField(
                        titleKey: "taurine",
                        text: numericBindingInt($taurine),
                        isGuess: $taurineIsGuess,
                        keyboard: .numberPad,
                        manager: l,
                        unitSuffix: "mg",
                        isPrelocalizedTitle: false,
                        validator: { ValidationThresholds.vitaminMineralMg.severity(for: $0) }
                    )
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }
        }
        .padding(.vertical, 2)
    }

    func vitaminsSection(l: LocalizationManager) -> some View {
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

    func mineralsSection(l: LocalizationManager) -> some View {
        Section {
            ToggleDetailsButton(isExpanded: $expandedMinerals, titleCollapsed: l.localized("show_minerals"), titleExpanded: l.localized("hide_minerals"))

            if expandedMinerals {
                MineralsGroupView(
                    manager: l,
                    unitSuffix: vitaminsUnit.displaySuffix,
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
}

