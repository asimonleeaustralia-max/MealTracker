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

                // Note: AI features toggle and Meals download section intentionally hidden for now.

                // Account & Plan
                Section(header: Text(LocalizedStringKey("account_plan_section_title"))) {
                    HStack {
                        Text(LocalizedStringKey("access_tier"))
                        Spacer()
                        Text(tier == .paid ? NSLocalizedString("access_tier.paid", comment: "") : NSLocalizedString("access_tier.free", comment: ""))
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text(LocalizedStringKey("account_status"))
                        Spacer()
                        if session.isLoggedIn {
                            Text(session.displayEmail ?? NSLocalizedString("logged_in", comment: ""))
                                .foregroundStyle(.secondary)
                        } else {
                            Text(NSLocalizedString("logged_out", comment: ""))
                                .foregroundStyle(.secondary)
                        }
                    }
                    if session.isLoggedIn {
                        Button(role: .destructive) {
                            Task { await session.logout() }
                        } label: { Text(LocalizedStringKey("log_out")) }
                    } else {
                        Button { showingLogin = true } label: { Text(LocalizedStringKey("log_in")) }
                        .sheet(isPresented: $showingLogin) {
                            LoginView { email, password in
                                Task {
                                    do {
                                        try await session.login(email: email, password: password)
                                        showingLogin = false
                                    } catch {}
                                }
                            }
                        }
                    }
                    HStack {
                        Text(LocalizedStringKey("meals_left_today"))
                        Spacer()
                        Text(mealsRemainingText).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text(LocalizedStringKey("photos_per_meal_limit"))
                        Spacer()
                        Text(maxPhotos >= 9000 ? NSLocalizedString("unlimited", comment: "") : "\(maxPhotos)")
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        HStack {
                            Text(LocalizedStringKey("synced_date"))
                            Spacer()
                            Text(syncedDateText).foregroundStyle(.secondary)
                        }
                        Button {
                            Task { await syncNow() }
                        } label: {
                            if isSyncing { ProgressView().progressViewStyle(.circular) }
                            else { Text(LocalizedStringKey("sync_now")) }
                        }
                        .disabled(isSyncing || !session.isLoggedIn)
                        if let syncError {
                            Text(syncError).font(.footnote).foregroundStyle(.red)
                        }
                    }
                }

                // About
                Section {
                    NavigationLink(destination: AboutView()) {
                        Text("About")
                    }
                }

                // People management section intentionally removed for now (will return in a future release).
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

    // MARK: - Seeder helpers

    private var isSeederRunningOrQueued: Bool {
        if seederStatusText == "Queued" { return true }
        if seederStatusText.hasPrefix("Running") { return true }
        return false
    }

    @MainActor
    private func refreshSeederStatus() async {
        let s = await MealsSeedingManager.shared.currentStatus()
        switch s {
        case .idle:
            seederStatusText = "Idle"
            seederError = nil
            seederDownloaded = 0
            seederTotal = 0
            seederPhase = ""
        case .queued:
            seederStatusText = "Queued"
            seederError = nil
        case .running(let downloaded, let total, let phase):
            seederStatusText = "Running"
            seederDownloaded = downloaded
            seederTotal = max(total, downloaded)
            seederPhase = phase
            seederError = nil
        case .completed(let total):
            seederStatusText = "Completed"
            seederDownloaded = total
            seederTotal = total
            seederPhase = ""
            seederError = nil
        case .failed(let error):
            seederStatusText = "Failed"
            seederError = error
        case .cancelled:
            seederStatusText = "Cancelled"
            seederError = nil
            seederDownloaded = 0
            seederTotal = 0
            seederPhase = ""
        }
    }

    private func startSeeder() async {
        await MealsSeedingManager.shared.runNowOnMainThreadForDebug()
        await refreshSeederStatus()
        await refreshMealsDBInfo()
    }

    // Meals DB info refresh
    @MainActor
    private func refreshMealsDBInfo() async {
        let exists = await MealsDBManager.shared.databaseFileExists()
        mealsDBExists = exists
        mealsDBSizeBytes = exists ? await MealsDBManager.shared.databaseFileSizeBytes() : 0
    }

    // New: Remove meals DB and reset completion flag
    private func removeMealsDBAndReset() async {
        await MealsDBManager.shared.deleteDatabaseFileIfExists()
        await MealsSeedingManager.shared.resetCompletedMarker()
        await refreshMealsDBInfo()
        await refreshSeederStatus()
    }

    // MARK: - OFF helpers (existing below)

    private var offCurrentStatus: ParquetDownloadManager.Status {
        if offStatusText.contains("Downloading") {
            return .downloading(progress: offProgress, receivedBytes: offReceivedBytes, expectedBytes: offExpectedBytes)
        }
        if offStatusText.contains("Completed") || offStatusText.contains("Downloaded") {
            return .completed(fileURL: (try? ParquetDownloadManager.shared.destinationURL()) ?? URL(fileURLWithPath: "/dev/null"), bytes: offExpectedBytes)
        }
        if offStatusText.contains("Failed") {
            return .failed(error: offError ?? "Unknown error")
        }
        return .idle
    }

    private var timer: Publishers.Autoconnect<Timer.TimerPublisher> {
        Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    }

    private func byteCountString(_ bytes: Int64) -> String {
        let fmt = ByteCountFormatter()
        fmt.countStyle = .file
        return fmt.string(fromByteCount: bytes)
    }

    @MainActor
    private func refreshOFFStatus() async {
        let manager = ParquetDownloadManager.shared
        let status = await manager.status
        let free = await manager.bytesAvailableOnDisk()
        offFreeBytes = free

        switch status {
        case .idle:
            if await manager.fileExists() {
                let bytes = await manager.existingFileSize()
                offExpectedBytes = bytes
                offReceivedBytes = bytes
                offProgress = 1.0
                offStatusText = "Downloaded"
                offError = nil
            } else {
                offExpectedBytes = -1
                offReceivedBytes = 0
                offProgress = 0
                offStatusText = "Not downloaded"
                offError = nil
            }
        case .checkingSize:
            offStatusText = "Checking size…"
            offError = nil
        case .readyToDownload(let expectedBytes):
            offExpectedBytes = expectedBytes
            offReceivedBytes = 0
            offProgress = 0
            if expectedBytes > 0 {
                offStatusText = "Ready (\(byteCountString(expectedBytes)))"
            } else {
                offStatusText = "Ready"
            }
            offError = nil
        case .downloading(let progress, let received, let expected):
            offExpectedBytes = expected
            offReceivedBytes = received
            offProgress = max(0, min(progress, 1))
            offStatusText = "Downloading"
            offError = nil
        case .completed(_, let bytes):
            offExpectedBytes = bytes
            offReceivedBytes = bytes
            offProgress = 1.0
            offStatusText = "Completed"
            offError = nil
        case .failed(let error):
            offStatusText = "Failed"
            offError = error
        case .cancelled:
            offStatusText = "Cancelled"
            offError = nil
        }
    }

    @ViewBuilder
    private func actionButtons() -> some View {
        let manager = ParquetDownloadManager.shared
        let _ = Task { await manager.fileExists() }

        let isDownloading = offStatusText == "Downloading"
        let isCompleted = offStatusText == "Completed" || offStatusText == "Downloaded"
        let isReady = offStatusText.hasPrefix("Ready")

        HStack {
            Button {
                Task { await ParquetDownloadManager.shared.fetchExpectedSize() }
            } label: {
                Text("Check Size")
            }
            .disabled(isDownloading)

            Spacer()

            if isDownloading {
                Button(role: .destructive) {
                    Task { await ParquetDownloadManager.shared.cancel() }
                } label: { Text("Cancel") }
            } else if isCompleted {
                Button(role: .destructive) {
                    Task {
                        if let url = try? await ParquetDownloadManager.shared.destinationURL(),
                           FileManager.default.fileExists(atPath: url.path) {
                            try? FileManager.default.removeItem(at: url)
                        }
                        await refreshOFFStatus()
                    }
                } label: { Text("Delete") }
            } else {
                Button {
                    if networkMonitor.isExpensive || !networkMonitor.isOnWiFi {
                        let expected = offExpectedBytes
                        if expected > 0 {
                            offConfirmMessage = "Download size about \(byteCountString(expected)). The download will wait for Wi‑Fi when possible."
                        } else {
                            offConfirmMessage = "Download size unknown. The download will wait for Wi‑Fi when possible."
                        }
                        showingOFFConfirm = true
                    } else {
                        Task { await ParquetDownloadManager.shared.startDownload() }
                    }
                } label: {
                    Text(isReady ? "Download" : "Download")
                }
                .disabled(isDownloading)
            }
        }
    }

    // MARK: - Sync helpers

    private func formattedSyncedDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }

    private func loadSyncedDate(_ date: Date? = nil) async {
        do {
            let date = try await session.dateSync.getSyncedDate()
            await MainActor.run {
                if let d = date {
                    syncedDateText = formattedSyncedDate(d)
                } else {
                    syncedDateText = "—"
                }
                syncError = nil
            }
        } catch {
            await MainActor.run {
                syncedDateText = "—"
                syncError = error.localizedDescription
            }
        }
    }

    private func syncNow() async {
        await MainActor.run {
            isSyncing = true
            syncError = nil
        }
        defer {
            Task { @MainActor in isSyncing = false }
        }

        do {
            try await session.dateSync.setSyncedDate(Date())
            await loadSyncedDate()
        } catch {
            await MainActor.run {
                syncError = error.localizedDescription
            }
        }
    }

    // MARK: - People helpers

    private func enforceFreeTierPeopleIfNeeded(isFreeTier: Bool) {
        guard isFreeTier else { return }
        var keptDefault: Person?
        for (idx, p) in people.enumerated() {
            if idx == 0 {
                if !p.isDefault { p.isDefault = true }
                keptDefault = p
            } else {
                p.isDefault = false
                p.isRemoved = true
            }
        }
        if context.hasChanges {
            try? context.save()
        }
    }

    private func setDefaultPerson(by id: UUID?) {
        guard let id else { return }
        var didChange = false
        for p in people {
            let shouldBeDefault = (p.id == id)
            if p.isDefault != shouldBeDefault {
                p.isDefault = shouldBeDefault
                didChange = true
            }
        }
        if didChange {
            try? context.save()
        }
    }

    private func validationError(for name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return NSLocalizedString("add_person_error_empty_name", comment: "Name cannot be empty")
        }
        if trimmed.count > 40 {
            return NSLocalizedString("add_person_error_name_too_long", comment: "Name too long")
        }
        if people.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return NSLocalizedString("add_person_error_duplicate_name", comment: "Name already exists")
        }
        return nil
        }

    @ViewBuilder
    private func deleteButton(for person: Person) -> some View {
        Button(role: .destructive) {
            personPendingDeletion = person
        } label: {
            Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
        .confirmationDialog(
            NSLocalizedString("confirm_delete_person_title", comment: "Delete Person?"),
            isPresented: Binding(
                get: { personPendingDeletion?.id == person.id },
                set: { presenting in
                    if !presenting { personPendingDeletion = nil }
                }),
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                performDelete(person)
                personPendingDeletion = nil
            } label: {
                Text(NSLocalizedString("delete", comment: "Delete"))
            }
            Button(NSLocalizedString("cancel", comment: "Cancel"), role: .cancel) {
                personPendingDeletion = nil
            }
        } message: {
            Text(NSLocalizedString("confirm_delete_person_message", comment: "This will remove the person from the list."))
        }
    }

    private func performDelete(_ person: Person) {
        let activeCount = people.count
        if activeCount <= 1 { return }
        if person.isDefault {
            if let replacement = people.first(where: { $0.id != person.id }) {
                replacement.isDefault = true
            }
        }
        person.isDefault = false
        person.isRemoved = true
        try? context.save()
    }

    private func attemptSaveNewPerson() {
        let name = newPersonName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let err = validationError(for: name) {
            addPersonError = err
            return
        }
        if isAtPeopleCap {
            let fmt = NSLocalizedString("add_person_error_max_reached", comment: "Shown when reaching max active people")
            addPersonError = String(format: fmt, maxActivePeople)
            return
        }

        let p = Person(context: context)
        p.id = UUID()
        p.name = name
        p.isRemoved = false
        if !people.contains(where: { $0.isDefault }) {
            p.isDefault = true
        } else {
            p.isDefault = false
        }

        do {
            try context.save()
            newPersonName = ""
            addPersonError = nil
            showingAddPersonSheet = false
        } catch {
            addPersonError = error.localizedDescription
        }
    }
}
