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
    // New: AI features master toggle (matches SettingsView)
    @AppStorage("aiFeaturesEnabled") var aiFeaturesEnabled: Bool = false

    // Fetch active people (non-soft-deleted)
    @FetchRequest(fetchRequest: Person.fetchAllRequest())
    private var people: FetchedResults<Person>

    // Selected person for this meal (Pro only)
    @State private var selectedPerson: Person?

    // Person picker presentation
    @State private var showingPersonPicker: Bool = false

    // Hidden title/date inputs removed from UI; we still keep local state for default title logic
    @State var mealDescription: String = "" // not shown in UI for new meals
    // Numeric inputs (grams now allow decimals)
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

    // New: live progress/status line for the wizard overlay
    @State var wizardProgress: String?

    // New: transient barcode display
    @State var lastDetectedBarcode: String?

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

    // MARK: - Wizard undo state
    @State var wizardUndoSnapshot: WizardSnapshot?
    @State var wizardCanUndo: Bool = false

    // MARK: - DEBUG-only wizard log buffer
    #if DEBUG
    @State private var wizardDebugLog: [String] = []
    func appendWizardLog(_ message: String) {
        let ts = Date()
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss.SSS"
        let line = "[\(df.string(from: ts))] \(message)"
        wizardDebugLog.append(line)
        // Keep log bounded
        if wizardDebugLog.count > 200 {
            wizardDebugLog.removeFirst(wizardDebugLog.count - 200)
        }
    }
    #endif

    init(meal: Meal? = nil) {
        self._meal = State(initialValue: meal)
        // If the caller provided a meal, we’re explicitly editing.
        self.explicitEditMode = (meal != nil)
    }

    // Keep this for other logic if needed, but UI visibility will use explicitEditMode
    var isEditing: Bool { meal != nil }

    // MARK: - Wizard status (short, top-left)
    private var wizardStatusText: String {
        guard aiFeaturesEnabled, !galleryItems.isEmpty else { return "" }
        if isAnalyzing {
            if let progress = wizardProgress, !progress.isEmpty {
                return progress
            }
            return "Analyzing…"
        }
        if let err = analyzeError, !err.isEmpty { return err }
        // Prefer showing the last detected barcode when available
        if let code = lastDetectedBarcode, !code.isEmpty {
            return "Barcode: \(code)"
        }
        if wizardCanUndo {
            if let tag = meal?.photoGuesserType, !tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Applied: \(tag)"
            }
            return "Applied"
        }
        if let progress = wizardProgress, !progress.isEmpty {
            return progress
        }
        return ""
    }

    private var wizardStatusIsError: Bool {
        return aiFeaturesEnabled && (analyzeError != nil)
    }

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
                    Task { await analyzePhotoWithSnapshot() }
                },
                onCameraTap: {
                    showingCamera = true
                },
                onPhotosTap: {
                    showingPhotoPicker = true
                },
                // New: pass undo state/handler
                isUndoAvailable: wizardCanUndo,
                onUndoTap: {
                    undoWizard()
                },
                trailingAccessoryButton: personSelectorAccessoryIfEligible(),
                // Gate wizard visibility
                aiEnabled: aiFeaturesEnabled,
                // New: short status text overlay (top-left)
                statusText: wizardStatusText,
                statusIsError: wizardStatusIsError
            )

            formContent(l: l)
                .modifier(CompactSectionSpacing())

            // DEBUG-only wizard progress + API log
            #if DEBUG
            if aiFeaturesEnabled, !galleryItems.isEmpty {
                Section {
                    if let progress = wizardProgress, !progress.isEmpty {
                        Text("Wizard: \(progress)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let err = analyzeError, !err.isEmpty {
                        Text("Wizard Error: \(err)")
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !wizardDebugLog.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Wizard Debug Log")
                                .font(.caption)
                                .fontWeight(.semibold)
                            ForEach(Array(wizardDebugLog.suffix(50)).indices, id: \.self) { idx in
                                Text(wizardDebugLog[idx])
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            #endif
        }
        // Attach toolbars directly here, avoiding conditional logic inside the builder.
        // Apply two separate toolbar modifiers guarded by availability.
        .modifier(ToolbarShim(l: l, isEditing: isEditing, isValid: isValid, forceEnableSave: forceEnableSave, showingSettings: $showingSettings, showingDeleteConfirm: $showingDeleteConfirm, dismiss: dismiss, save: save))
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

    // MARK: - Missing helpers implemented below

    @ViewBuilder
    private func formContent(l: LocalizationManager) -> some View {
        Form {
            // Calories
            Section {
                MetricField(
                    titleKey: "calories",
                    text: numericBindingInt($calories),
                    isGuess: $caloriesIsGuess,
                    keyboard: .numberPad,
                    manager: l,
                    unitSuffix: (energyUnit == .calories ? l.localized("kcal_suffix") : l.localized("kj_suffix")),
                    validator: { ValidationThresholds.calories.severity(for: $0) },
                    focusedField: $focused,
                    thisField: .calories,
                    onSubmit: { focused = nil }
                )
            }

            // Carbohydrates
            Section {
                VStack(spacing: 0) {
                    MetricField(
                        titleKey: "carbohydrates",
                        text: numericBindingDecimal($carbohydrates),
                        isGuess: $carbohydratesIsGuess,
                        keyboard: .decimalPad,
                        manager: l,
                        unitSuffix: "g",
                        doubleValidator: { ValidationThresholds.grams.severityDouble($0) },
                        leadingAccessory: {
                            AnyView(
                                Group {
                                    if carbsHelperVisible {
                                        Text("(\(carbsHelperText))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            )
                        },
                        highlight: carbsMismatch ? (carbsBlink ? .successBlink(active: true) : .error) : (carbsRedBlink ? .error : .none),
                        focusedField: $focused,
                        thisField: .carbsTotal,
                        onSubmit: {
                            focused = nil
                            handleHelperOnTopChangeForCarbs()
                        }
                    )

                    ToggleDetailsButton(
                        isExpanded: $expandedCarbs,
                        titleCollapsed: l.localized("show_details"),
                        titleExpanded: l.localized("hide_details")
                    )

                    if expandedCarbs {
                        CarbsSubFields(
                            manager: l,
                            sugarsText: $sugars, sugarsIsGuess: $sugarsIsGuess,
                            starchText: $starch, starchIsGuess: $starchIsGuess,
                            fibreText: $fibre, fibreIsGuess: $fibreIsGuess
                        )
                        .onChange(of: sugars) { _ in sugarsTouched = true; handleTopFromCarbSubs(); recomputeConsistencyAndBlinkIfFixed() }
                        .onChange(of: starch) { _ in starchTouched = true; handleTopFromCarbSubs(); recomputeConsistencyAndBlinkIfFixed() }
                        .onChange(of: fibre) { _ in fibreTouched = true; handleTopFromCarbSubs(); recomputeConsistencyAndBlinkIfFixed() }
                    }
                }
            }

            // Protein
            Section {
                VStack(spacing: 0) {
                    MetricField(
                        titleKey: "protein",
                        text: numericBindingDecimal($protein),
                        isGuess: $proteinIsGuess,
                        keyboard: .decimalPad,
                        manager: l,
                        unitSuffix: "g",
                        doubleValidator: { ValidationThresholds.grams.severityDouble($0) },
                        leadingAccessory: {
                            AnyView(
                                Group {
                                    if proteinHelperVisible {
                                        Text("(\(proteinHelperText))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            )
                        },
                        highlight: proteinMismatch ? (proteinBlink ? .successBlink(active: true) : .error) : (proteinRedBlink ? .error : .none),
                        focusedField: $focused,
                        thisField: .proteinTotal,
                        onSubmit: {
                            focused = nil
                            handleHelperOnTopChangeForProtein()
                        }
                    )

                    ToggleDetailsButton(
                        isExpanded: $expandedProtein,
                        titleCollapsed: l.localized("show_details"),
                        titleExpanded: l.localized("hide_details")
                    )

                    if expandedProtein {
                        ProteinSubFields(
                            manager: l,
                            animalText: $animalProtein, animalIsGuess: $animalProteinIsGuess,
                            plantText: $plantProtein, plantIsGuess: $plantProteinIsGuess,
                            supplementsText: $proteinSupplements, supplementsIsGuess: $proteinSupplementsIsGuess
                        )
                        .onChange(of: animalProtein) { _ in animalTouched = true; handleTopFromProteinSubs(); recomputeConsistencyAndBlinkIfFixed() }
                        .onChange(of: plantProtein) { _ in plantTouched = true; handleTopFromProteinSubs(); recomputeConsistencyAndBlinkIfFixed() }
                        .onChange(of: proteinSupplements) { _ in supplementsTouched = true; handleTopFromProteinSubs(); recomputeConsistencyAndBlinkIfFixed() }
                    }
                }
            }

            // Fat
            Section {
                VStack(spacing: 0) {
                    MetricField(
                        titleKey: "fat",
                        text: numericBindingDecimal($fat),
                        isGuess: $fatIsGuess,
                        keyboard: .decimalPad,
                        manager: l,
                        unitSuffix: "g",
                        doubleValidator: { ValidationThresholds.grams.severityDouble($0) },
                        leadingAccessory: {
                            AnyView(
                                Group {
                                    if fatHelperVisible {
                                        Text("(\(fatHelperText))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            )
                        },
                        highlight: fatMismatch ? (fatBlink ? .successBlink(active: true) : .error) : (fatRedBlink ? .error : .none),
                        focusedField: $focused,
                        thisField: .fatTotal,
                        onSubmit: {
                            focused = nil
                            handleHelperOnTopChangeForFat()
                        }
                    )

                    ToggleDetailsButton(
                        isExpanded: $expandedFat,
                        titleCollapsed: l.localized("show_details"),
                        titleExpanded: l.localized("hide_details")
                    )

                    if expandedFat {
                        FatSubFields(
                            manager: l,
                            monoText: $monounsaturatedFat, monoIsGuess: $monounsaturatedFatIsGuess,
                            polyText: $polyunsaturatedFat, polyIsGuess: $polyunsaturatedFatIsGuess,
                            satText: $saturatedFat, satIsGuess: $saturatedFatIsGuess,
                            transText: $transFat, transIsGuess: $transFatIsGuess,
                            omega3Text: $omega3, omega3IsGuess: $omega3IsGuess,
                            omega6Text: $omega6, omega6IsGuess: $omega6IsGuess
                        )
                        .onChange(of: monounsaturatedFat) { _ in monoTouched = true; handleTopFromFatSubs(); recomputeConsistencyAndBlinkIfFixed() }
                        .onChange(of: polyunsaturatedFat) { _ in polyTouched = true; handleTopFromFatSubs(); recomputeConsistencyAndBlinkIfFixed() }
                        .onChange(of: saturatedFat) { _ in satTouched = true; handleTopFromFatSubs(); recomputeConsistencyAndBlinkIfFixed() }
                        .onChange(of: transFat) { _ in transTouched = true; handleTopFromFatSubs(); recomputeConsistencyAndBlinkIfFixed() }
                        .onChange(of: omega3) { _ in omega3Touched = true }
                        .onChange(of: omega6) { _ in omega6Touched = true }
                    }
                }
            }

            // Sodium
            Section {
                if sodiumUnit == .milligrams {
                    MetricField(
                        titleKey: "sodium",
                        text: numericBindingInt($sodium),
                        isGuess: $sodiumIsGuess,
                        keyboard: .numberPad,
                        manager: l,
                        unitSuffix: "mg",
                        validator: { ValidationThresholds.sodiumMg.severity(for: $0) },
                        focusedField: $focused,
                        thisField: .sodium,
                        onSubmit: { focused = nil }
                    )
                } else {
                    MetricField(
                        titleKey: "sodium",
                        text: numericBindingDecimal($sodium),
                        isGuess: $sodiumIsGuess,
                        keyboard: .decimalPad,
                        manager: l,
                        unitSuffix: "g",
                        doubleValidator: { ValidationThresholds.sodiumG.severityDouble($0) },
                        focusedField: $focused,
                        thisField: .sodium,
                        onSubmit: { focused = nil }
                    )
                }
            }

            // Stimulants group (optional)
            if showSimulants {
                Section(header: Text("Stimulants")) {
                    MetricField(titleKey: "alcohol", text: numericBindingDecimal($alcohol), isGuess: $alcoholIsGuess, keyboard: .decimalPad, manager: l, unitSuffix: "g", doubleValidator: { ValidationThresholds.grams.severityDouble($0) })
                    MetricField(titleKey: "nicotine", text: numericBindingInt($nicotine), isGuess: $nicotineIsGuess, keyboard: .numberPad, manager: l, unitSuffix: "mg", validator: { ValidationThresholds.vitaminMineralMg.severity(for: $0) })
                    MetricField(titleKey: "theobromine", text: numericBindingInt($theobromine), isGuess: $theobromineIsGuess, keyboard: .numberPad, manager: l, unitSuffix: "mg", validator: { ValidationThresholds.vitaminMineralMg.severity(for: $0) })
                    MetricField(titleKey: "caffeine", text: numericBindingInt($caffeine), isGuess: $caffeineIsGuess, keyboard: .numberPad, manager: l, unitSuffix: "mg", validator: { ValidationThresholds.vitaminMineralMg.severity(for: $0) })
                    MetricField(titleKey: "taurine", text: numericBindingInt($taurine), isGuess: $taurineIsGuess, keyboard: .numberPad, manager: l, unitSuffix: "mg", validator: { ValidationThresholds.vitaminMineralMg.severity(for: $0) })
                }
            }

            // Vitamins (optional)
            if showVitamins {
                Section(header: Text(l.localized("vitamins_section_title"))) {
                    VitaminsGroupView(
                        manager: l,
                        unitSuffix: vitaminsUnit.displaySuffix,
                        aText: $vitaminA, aIsGuess: $vitaminAIsGuess,
                        bText: $vitaminB, bIsGuess: $vitaminBIsGuess,
                        cText: $vitaminC, cIsGuess: $vitaminCIsGuess,
                        dText: $vitaminD, dIsGuess: $vitaminDIsGuess,
                        eText: $vitaminE, eIsGuess: $vitaminEIsGuess,
                        kText: $vitaminK, kIsGuess: $vitaminKIsGuess
                    )
                }
            }

            // Minerals (optional)
            if showMinerals {
                Section(header: Text(l.localized("minerals_section_title"))) {
                    MineralsGroupView(
                        manager: l,
                        unitSuffix: vitaminsUnit.displaySuffix,
                        calciumText: $calcium, calciumIsGuess: $calciumIsGuess,
                        ironText: $iron, ironIsGuess: $ironIsGuess,
                        potassiumText: $potassium, potassiumIsGuess: $potassiumIsGuess,
                        zincText: $zinc, zincIsGuess: $zincIsGuess,
                        magnesiumText: $magnesium, magnesiumIsGuess: $magnesiumIsGuess
                    )
                }
            }

            // Analysis error feedback
            if let analyzeError, aiFeaturesEnabled {
                Section {
                    Text(analyzeError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .onChange(of: carbohydrates) { _ in recomputeConsistencyAndBlinkIfFixed() }
        .onChange(of: protein) { _ in recomputeConsistencyAndBlinkIfFixed() }
        .onChange(of: fat) { _ in recomputeConsistencyAndBlinkIfFixed() }
    }

    private func personActionSheetButtons() -> [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = []
        // Only allow selection in eligible conditions
        let tier = Entitlements.tier(for: session)
        guard session.isLoggedIn && tier == .paid && !people.isEmpty else {
            buttons.append(.cancel())
            return buttons
        }
        for person in people {
            buttons.append(.default(Text(person.name)) {
                selectedPerson = person
            })
        }
        buttons.append(.cancel())
        return buttons
    }

    private func initializeSelectedPersonIfNeeded() {
        // Auto-select default person for Pro users when photos exist (to match accessory gating)
        let tier = Entitlements.tier(for: session)
        guard session.isLoggedIn && tier == .paid else { return }
        if selectedPerson == nil {
            if let def = people.first(where: { $0.isDefault }) {
                selectedPerson = def
            } else {
                selectedPerson = people.first
            }
        }
    }

    // MARK: - Save

    private func save() {
        // Only allow save if valid or forced by wizard
        guard isValid || forceEnableSave else { return }

        let m: Meal = meal ?? Meal(context: context)

        // If new, setup basic fields
        if meal == nil {
            m.id = UUID()
            m.date = Date()
            let locale = Locale(identifier: appLanguageCode)
            m.title = mealDescription.isEmpty ? Meal.autoTitle(for: m.date, locale: locale) : mealDescription
        } else {
            // Update title if user changed description
            if !mealDescription.isEmpty {
                m.title = mealDescription
            } else if m.title.isEmpty {
                let locale = Locale(identifier: appLanguageCode)
                m.title = Meal.autoTitle(for: m.date, locale: locale)
            }
        }

        // Helper parsers
        func d(_ s: String) -> Double { Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0 }
        func i(_ s: String) -> Double { Double(Int(s) ?? 0) }

        // Calories (stored as kcal)
        m.calories = Double(Int(calories) ?? 0)

        // Grams-based doubles
        m.carbohydrates = d(carbohydrates)
        m.protein = d(protein)
        m.fat = d(fat)

        // Sodium stored in mg
        if sodiumUnit == .grams {
            m.sodium = d(sodium) * 1000.0
        } else {
            m.sodium = i(sodium)
        }

        // Stimulants
        m.alcohol = d(alcohol) // grams
        m.nicotine = i(nicotine) // mg
        m.theobromine = i(theobromine) // mg
        m.caffeine = i(caffeine) // mg
        m.taurine = i(taurine) // mg

        // Sub-macros (grams)
        m.starch = d(starch)
        m.sugars = d(sugars)
        m.fibre = d(fibre)

        // Fat breakdown (grams)
        m.monounsaturatedFat = d(monounsaturatedFat)
        m.polyunsaturatedFat = d(polyunsaturatedFat)
        m.saturatedFat = d(saturatedFat)
        m.transFat = d(transFat)
        m.omega3 = d(omega3)
        m.omega6 = d(omega6)

        // Protein breakdown (grams)
        m.animalProtein = d(animalProtein)
        m.plantProtein = d(plantProtein)
        m.proteinSupplements = d(proteinSupplements)

        // Vitamins/Minerals stored in mg; UI may be mg or µg
        func toStorageMG(_ s: String) -> Double {
            let ui = Double(Int(s) ?? 0)
            return vitaminsUnit.toStorageMG(ui)
        }
        m.vitaminA = toStorageMG(vitaminA)
        m.vitaminB = toStorageMG(vitaminB)
        m.vitaminC = toStorageMG(vitaminC)
        m.vitaminD = toStorageMG(vitaminD)
        m.vitaminE = toStorageMG(vitaminE)
        m.vitaminK = toStorageMG(vitaminK)

        m.calcium = toStorageMG(calcium)
        m.iron = toStorageMG(iron)
        m.potassium = toStorageMG(potassium)
        m.zinc = toStorageMG(zinc)
        m.magnesium = toStorageMG(magnesium)

        // Guess flags
        m.caloriesIsGuess = caloriesIsGuess
        m.carbohydratesIsGuess = carbohydratesIsGuess
        m.proteinIsGuess = proteinIsGuess
        m.sodiumIsGuess = sodiumIsGuess
        m.fatIsGuess = fatIsGuess

        m.alcoholIsGuess = alcoholIsGuess
        m.nicotineIsGuess = nicotineIsGuess
        m.theobromineIsGuess = theobromineIsGuess
        m.caffeineIsGuess = caffeineIsGuess
        m.taurineIsGuess = taurineIsGuess

        m.starchIsGuess = starchIsGuess
        m.sugarsIsGuess = sugarsIsGuess
        m.fibreIsGuess = fibreIsGuess

        m.monounsaturatedFatIsGuess = monounsaturatedFatIsGuess
        m.polyunsaturatedFatIsGuess = polyunsaturatedFatIsGuess
        m.saturatedFatIsGuess = saturatedFatIsGuess
        m.transFatIsGuess = transFatIsGuess
        m.omega3IsGuess = omega3IsGuess
        m.omega6IsGuess = omega6IsGuess

        m.animalProteinIsGuess = animalProteinIsGuess
        m.plantProteinIsGuess = plantProteinIsGuess
        m.proteinSupplementsIsGuess = proteinSupplementsIsGuess

        m.vitaminAIsGuess = vitaminAIsGuess
        m.vitaminBIsGuess = vitaminBIsGuess
        m.vitaminCIsGuess = vitaminCIsGuess
        m.vitaminDIsGuess = vitaminDIsGuess
        m.vitaminEIsGuess = vitaminEIsGuess
        m.vitaminKIsGuess = vitaminKIsGuess

        m.calciumIsGuess = calciumIsGuess
        m.ironIsGuess = ironIsGuess
        m.potassiumIsGuess = potassiumIsGuess
        m.zincIsGuess = zincIsGuess
        m.magnesiumIsGuess = magnesiumIsGuess

        // Coordinates from last known location (optional)
        if let loc = locationManager.lastLocation {
            m.latitude = loc.coordinate.latitude
            m.longitude = loc.coordinate.longitude
        }

        // Associate person if eligible and selected (model shows Person.meal to-many without inverse)
        if let person = selectedPerson {
            person.addToMeal(m)
        }

        do {
            try context.save()
            // Keep reference if it was new
            if meal == nil { meal = m }
            dismiss()
        } catch {
            // In a production app, surface an alert; for now, log
            #if DEBUG
            print("Failed to save meal: \(error)")
            #endif
        }
    }

    // ... rest of file remains unchanged ...
}

// MARK: - Numeric input sanitizers used by MetricField bindings

private extension MealFormView {
    // Allow only digits and a single decimal separator.
    // Normalize comma to dot and collapse multiple dots to one.
    func numericBindingDecimal(_ source: Binding<String>) -> Binding<String> {
        Binding<String>(
            get: {
                source.wrappedValue
            },
            set: { newValue in
                var s = newValue

                // Normalize comma to dot
                s = s.replacingOccurrences(of: ",", with: ".")

                // Keep digits and dots only
                s = s.filter { ("0"..."9").contains($0) || $0 == "." }

                // Collapse multiple dots to a single one (keep first)
                if let firstDot = s.firstIndex(of: ".") {
                    let after = s.index(after: firstDot)
                    let tail = s[after...].replacingOccurrences(of: ".", with: "")
                    s = String(s[..<after]) + tail
                }

                // Optional: prevent leading zeros like "00" (keep "0." cases intact)
                if s.hasPrefix("00") {
                    // reduce to single leading zero
                    while s.hasPrefix("00") { s.removeFirst() }
                    if s.isEmpty { s = "0" }
                }

                source.wrappedValue = s
            }
        )
    }

    // Allow only digits (non-negative integers).
    func numericBindingInt(_ source: Binding<String>) -> Binding<String> {
        Binding<String>(
            get: {
                source.wrappedValue
            },
            set: { newValue in
                let filtered = newValue.filter { ("0"..."9").contains($0) }
                source.wrappedValue = filtered
            }
        )
    }
}
