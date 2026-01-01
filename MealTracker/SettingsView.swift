import SwiftUI
import CoreData
import Combine

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject var session: SessionManager

    @AppStorage("energyUnit") private var energyUnit: EnergyUnit = .calories
    @AppStorage("appLanguageCode") private var appLanguageCode: String = LocalizationManager.defaultLanguageCode
    @AppStorage("sodiumUnit") private var sodiumUnit: SodiumUnit = .milligrams
    @AppStorage("showVitamins") private var showVitamins: Bool = false
    @AppStorage("vitaminsUnit") private var vitaminsUnit: VitaminsUnit = .milligrams
    @AppStorage("showMinerals") private var showMinerals: Bool = false
    @AppStorage("handedness") private var handedness: Handedness = .right
    @AppStorage("dataSharingPreference") private var dataSharing: DataSharingPreference = .public
    @AppStorage("showSimulants") private var showSimulants: Bool = false
    @AppStorage("openToNewMealOnLaunch") private var openToNewMealOnLaunch: Bool = false
    @AppStorage("aiFeedbackSeverity") private var aiFeedbackSeverity: AIFeedbackSeverity = .balanced
    // Keep storage but do not show any UI for it for now.
    @AppStorage("aiFeaturesEnabled") private var aiFeaturesEnabled: Bool = false

    @State private var syncedDateText: String = "—"
    @State private var isSyncing: Bool = false
    @State private var syncError: String?

    @State private var showingLogin = false

    @FetchRequest(fetchRequest: Person.fetchAllRequest())
    private var people: FetchedResults<Person>

    @State private var showingAddPersonSheet: Bool = false
    @State private var newPersonName: String = ""
    @State private var addPersonError: String?

    @State private var personPendingDeletion: Person?

    // OFF download UI state
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @State private var offStatusText: String = "Not downloaded"
    @State private var offProgress: Double = 0.0
    @State private var offExpectedBytes: Int64 = -1
    @State private var offReceivedBytes: Int64 = 0
    @State private var showingOFFConfirm: Bool = false
    @State private var offConfirmMessage: String = ""
    @State private var offError: String?
    @State private var offFreeBytes: Int64 = 0

    // Meals seeder UI state (kept for background logic, but no UI will reference it now)
    @State private var seederStatusText: String = "Idle"
    @State private var seederDownloaded: Int = 0
    @State private var seederTotal: Int = 0
    @State private var seederPhase: String = ""
    @State private var showingSeederConfirm: Bool = false
    @State private var seederError: String?

    // Meals DB file info
    @State private var mealsDBExists: Bool = false
    @State private var mealsDBSizeBytes: Int64 = 0

    // New: confirm removal of downloaded meals
    @State private var showingMealsDeleteConfirm: Bool = false

    // Durable completion from MealsSeedingManager
    private var durableCompleted: Bool {
        UserDefaults.standard.bool(forKey: "MealsSeeding.completed")
    }
    private var durableCompletedCount: Int {
        UserDefaults.standard.integer(forKey: "MealsSeeding.completedCount")
    }

    private var isSeederCompletedForDisplay: Bool {
        if seederStatusText == "Completed" { return true }
        if durableCompleted && mealsDBExists { return true }
        return false
    }

    private var availableLanguages: [String] {
        let codes = Bundle.main.localizations.filter { $0.lowercased() != "base" }
        let list = codes.isEmpty ? Bundle.main.preferredLocalizations : codes
        return Array(Set(list)).sorted()
    }

    private let maxActivePeople = 15
    private var isAtPeopleCap: Bool { people.count >= maxActivePeople }

    #if DEBUG
    @State private var barcodeLogCount: Int = 0
    #endif

    var body: some View {
        let l = LocalizationManager(languageCode: appLanguageCode)

        let tier = Entitlements.tier(for: session)
        let isFreeTier = (tier == .free)
        let isEligibleForOfflineDB = session.isLoggedIn && tier == .paid

        let mealsRemainingText: String = {
            if let remaining = Entitlements.mealsRemainingToday(for: tier, in: context) {
                return "\(remaining)"
            } else {
                return NSLocalizedString("unlimited", comment: "")
            }
        }()
        let maxPhotos = Entitlements.maxPhotosPerMeal(for: tier)

        NavigationView {
            Form {
                // Language
                Section {
                    Picker(l.localized("choose_language"), selection: $appLanguageCode) {
                        ForEach(availableLanguages, id: \.self) { code in
                            Text(LocalizationManager.displayName(for: code)).tag(code)
                        }
                    }
                }

                // Handedness
                Section(header: Text(LocalizedStringKey("handedness_section_title"))) {
                    Picker("", selection: $handedness) {
                        Text(LocalizedStringKey("left_handed")).tag(Handedness.left)
                        Text(LocalizedStringKey("right_handed")).tag(Handedness.right)
                    }
                    .pickerStyle(.segmented)
                }

                // Nutrition options
                Section(header: Text(l.localized("nutrition_options_section_title"))) {
                    Toggle(isOn: $showVitamins) { Text(l.localized("show_vitamins")) }
                    if showVitamins {
                        Picker(l.localized("vitamin_units"), selection: $vitaminsUnit) {
                            ForEach(VitaminsUnit.allCases, id: \.self) { unit in
                                Text(unit.displaySuffix).tag(unit)
                            }
                        }
                    }
                    Toggle(isOn: $showMinerals) { Text(l.localized("show_minerals")) }
                    Toggle(isOn: $showSimulants) { Text(l.localized("show_stimulants")) }
                }

                #if DEBUG
                // Debug-only diagnostics
                Section(header: Text("Diagnostics")) {
                    NavigationLink {
                        BarcodeLogView()
                    } label: {
                        HStack {
                            Text("Barcode Verbose Log")
                            Spacer()
                            if barcodeLogCount > 0 {
                                Text("\(barcodeLogCount)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onAppear {
                        Task {
                            let count = await BarcodeLogStore.shared.lineCount()
                            await MainActor.run { barcodeLogCount = count }
                        }
                    }
                    .onReceive(BarcodeLogStore.shared.publisher.receive(on: DispatchQueue.main)) { lines in
                        barcodeLogCount = lines.count
                    }
                }
                #endif

                // About
                Section {
                    NavigationLink(destination: AboutView()) {
                        Text("About")
                    }
                }
            }
            .onAppear {
                Task { await loadSyncedDate() }
                enforceFreeTierPeopleIfNeeded(isFreeTier: isFreeTier)
                Task {
                    await refreshSeederStatus()
                    await refreshMealsDBInfo()
                }
            }
            .onChange(of: session.isLoggedIn) { _ in
                let newTier = Entitlements.tier(for: session)
                enforceFreeTierPeopleIfNeeded(isFreeTier: newTier == .free)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l.localized("done")) { dismiss() }
                }
            }
            .sheet(isPresented: $showingAddPersonSheet) {
                NavigationView {
                    Form {
                        Section(header: Text(NSLocalizedString("add_person_name_header", comment: "Name"))) {
                            TextField(NSLocalizedString("add_person_name_placeholder", comment: "Name"),
                                      text: Binding(
                                        get: { newPersonName },
                                        set: { value in
                                            newPersonName = value
                                            addPersonError = validationError(for: value)
                                        }
                                      ))
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(true)

                            if let error = addPersonError, !error.isEmpty {
                                Text(error).font(.footnote).foregroundStyle(.red)
                            }
                        }
                    }
                    .navigationTitle(NSLocalizedString("add_person_nav_title", comment: "Add Person"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(NSLocalizedString("cancel", comment: "Cancel")) {
                                showingAddPersonSheet = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(NSLocalizedString("save", comment: "Save")) {
                                attemptSaveNewPerson()
                            }
                            .disabled(validationError(for: newPersonName) != nil)
                        }
                    }
                }
            }
        }
    }

    // ... rest of file unchanged ...

    // MARK: - Missing helper implemented to fix compile error

    private func formatSyncedDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }

    private func setSyncUI(isSyncing: Bool, text: String?, error: String?) {
        self.isSyncing = isSyncing
        if let text { self.syncedDateText = text }
        self.syncError = error
    }

    private func setSyncUIOnMain(isSyncing: Bool, text: String?, error: String?) async {
        await MainActor.run {
            setSyncUI(isSyncing: isSyncing, text: text, error: error)
        }
    }

    private func loadSyncedDate() async {
        await setSyncUIOnMain(isSyncing: true, text: nil, error: nil)
        do {
            let date = try await session.dateSync.getSyncedDate()
            let text = date.map { formatSyncedDate($0) } ?? "—"
            await setSyncUIOnMain(isSyncing: false, text: text, error: nil)
        } catch {
            await setSyncUIOnMain(isSyncing: false, text: "—", error: error.localizedDescription)
        }
    }

    // MARK: - Free tier enforcement

    private func enforceFreeTierPeopleIfNeeded(isFreeTier: Bool) {
        guard isFreeTier else { return }
        // Ensure only one active person remains. Prefer the default person; otherwise keep the first.
        let active = people
        guard active.count > 1 else { return }

        // Determine keeper: default person if present, else first in fetch order.
        let keeper: Person = active.first(where: { $0.isDefault }) ?? active.first!

        // Make sure keeper is default
        if !keeper.isDefault {
            // Clear any existing default flags
            for p in active where p != keeper && p.isDefault {
                p.isDefault = false
            }
            keeper.isDefault = true
        }

        // Mark all others as removed
        for p in active where p != keeper {
            p.isRemoved = true
            p.isDefault = false
        }

        do {
            try context.save()
        } catch {
            // If save fails, silently ignore to avoid crashing settings UI
            // In a real app, you might surface an alert or log.
        }
    }

    // MARK: - Seeder status refresh

    private func refreshSeederStatus() async {
        let status = await MealsSeedingManager.shared.currentStatus()
        await MainActor.run {
            switch status {
            case .idle:
                seederStatusText = "Idle"
                seederDownloaded = 0
                seederTotal = 0
                seederPhase = ""
                seederError = nil
            case .queued:
                seederStatusText = "Queued"
                seederPhase = "Waiting…"
                seederError = nil
            case .running(let downloaded, let total, let phase):
                seederStatusText = "Running"
                seederDownloaded = downloaded
                seederTotal = total
                seederPhase = phase
                seederError = nil
            case .completed(let total):
                seederStatusText = "Completed"
                seederDownloaded = total
                seederTotal = total
                seederPhase = "Done"
                seederError = nil
            case .failed(let error):
                seederStatusText = "Failed"
                seederError = error
            case .cancelled:
                seederStatusText = "Cancelled"
                seederError = nil
            }
        }
    }

    // MARK: - Meals DB info refresh

    private func refreshMealsDBInfo() async {
        // Use ParquetDownloadManager to check the OFF Parquet file presence and size.
        let exists = await ParquetDownloadManager.shared.fileExists()
        let size = await ParquetDownloadManager.shared.existingFileSize()
        await MainActor.run {
            mealsDBExists = exists
            mealsDBSizeBytes = size
        }
    }

    // MARK: - Add Person helpers

    private func validationError(for rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        // Non-empty
        guard !trimmed.isEmpty else {
            return NSLocalizedString("person_name_error_empty", comment: "Please enter a name.")
        }

        // Reasonable length limits
        if trimmed.count > 40 {
            return NSLocalizedString("person_name_error_too_long", comment: "Name is too long.")
        }

        // Disallow names that are only punctuation/symbols
        let lettersAndDigits = trimmed.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) }
        if !lettersAndDigits {
            return NSLocalizedString("person_name_error_invalid_chars", comment: "Please use letters or numbers.")
        }

        // Uniqueness among active people (case-insensitive)
        let lower = trimmed.lowercased()
        if people.contains(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == lower }) {
            return NSLocalizedString("person_name_error_duplicate", comment: "A person with this name already exists.")
        }

        return nil
    }

    private func attemptSaveNewPerson() {
        // Validate again before saving
        if let err = validationError(for: newPersonName) {
            addPersonError = err
            return
        }

        let name = newPersonName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Insert new Person
        let person = Person(context: context)
        person.id = UUID()
        person.name = name
        person.isRemoved = false

        // Make default if none active default exists
        let hasActiveDefault = people.contains(where: { $0.isDefault })
        person.isDefault = !hasActiveDefault

        do {
            try context.save()
            // Reset UI state
            newPersonName = ""
            addPersonError = nil
            showingAddPersonSheet = false
        } catch {
            addPersonError = error.localizedDescription
        }
    }
}
