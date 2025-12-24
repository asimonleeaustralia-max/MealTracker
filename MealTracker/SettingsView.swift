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
    // New: AI features master switch (default off)
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

    // Meals seeder UI state
    @State private var seederStatusText: String = "Idle"
    @State private var seederDownloaded: Int = 0
    @State private var seederTotal: Int = 0
    @State private var seederPhase: String = ""
    @State private var showingSeederConfirm: Bool = false
    @State private var seederError: String?

    // Meals DB file info
    @State private var mealsDBExists: Bool = false
    @State private var mealsDBSizeBytes: Int64 = 0

    // Durable completion from MealsSeedingManager
    private var durableCompleted: Bool {
        UserDefaults.standard.bool(forKey: "MealsSeeding.completed")
    }
    private var durableCompletedCount: Int {
        UserDefaults.standard.integer(forKey: "MealsSeeding.completedCount")
    }

    // Consider it "Completed" for display if:
    // - current polled status is Completed, OR
    // - durable completion marker is set AND the DB file exists
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

                // AI features master toggle
                Section {
                    Toggle(isOn: $aiFeaturesEnabled) {
                        Text("Enable AI features")
                    }
                }

                // Meals DB download section
                if aiFeaturesEnabled {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Status")
                                Spacer()
                                Text(seederStatusText).foregroundStyle(.secondary)
                            }

                            // Completed line inline with size when available
                            if isSeederCompletedForDisplay {
                                let count = (seederStatusText == "Completed") ? seederTotal : durableCompletedCount
                                HStack(spacing: 6) {
                                    Text("Downloaded \(count) meals")
                                    if mealsDBExists {
                                        Text("—")
                                            .foregroundStyle(.secondary)
                                        Text(byteCountString(mealsDBSizeBytes))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            // Progress/counters while running/queued
                            if isSeederRunningOrQueued {
                                let totalText = seederTotal > 0 ? "\(seederTotal)" : "—"
                                HStack {
                                    Text("Downloaded: \(seederDownloaded) of \(totalText)")
                                    Spacer()
                                    if seederTotal > 0 {
                                        let pct = Int((Double(seederDownloaded) / Double(seederTotal)) * 100.0)
                                        Text("\(pct)%")
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            // Indeterminate while discovering totals
                            if seederStatusText.hasPrefix("Running"), seederTotal == 0 {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .padding(.top, 4)
                                if !seederPhase.isEmpty {
                                    Text(seederPhase)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            // Determinate once totals are known
                            if seederTotal > 0 && (seederDownloaded <= seederTotal) && isSeederRunningOrQueued {
                                ProgressView(value: Double(seederDownloaded), total: Double(seederTotal))
                                if !seederPhase.isEmpty {
                                    Text(seederPhase)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            } else if !seederPhase.isEmpty && !(seederStatusText.hasPrefix("Running") && seederTotal == 0) && isSeederRunningOrQueued {
                                Text(seederPhase)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            if let err = seederError {
                                Text(err).font(.footnote).foregroundStyle(.red)
                            }

                            if networkMonitor.isConnected && (networkMonitor.isExpensive || !networkMonitor.isOnWiFi) {
                                Text("You are not on Wi‑Fi. Bulk download will wait for Wi‑Fi and may use cellular if you proceed.")
                                    .font(.footnote)
                                    .foregroundStyle(.orange)
                            }
                        }

                        HStack {
                            Button {
                                if networkMonitor.isExpensive || !networkMonitor.isOnWiFi {
                                    showingSeederConfirm = true
                                } else {
                                    Task { await startSeeder() }
                                }
                            } label: {
                                Text("Download Meals for AI")
                            }
                            .disabled(isSeederRunningOrQueued)

                            if isSeederRunningOrQueued {
                                Spacer()
                                Button(role: .destructive) {
                                    Task { await MealsSeedingManager.shared.cancel() }
                                } label: {
                                    Text("Cancel")
                                }
                            }
                        }

                        // New: Pro upsell note for non-Pro users under the meals downloader
                        if tier == .free {
                            Text("Pro users get advanced machine vision and personalised feedback on their meals.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 4)
                        }
                    }
                    .alert("Download Meals for AI?", isPresented: $showingSeederConfirm) {
                        Button("Cancel", role: .cancel) { }
                        Button("Start") {
                            Task { await startSeeder() }
                        }
                    } message: {
                        Text("This will download meals and drinks from public sources. It may be large and take time. The process will continue in the background.")
                    }
                    .onAppear {
                        Task {
                            await refreshSeederStatus()
                            await refreshMealsDBInfo()
                        }
                    }
                    .onReceive(timer) { _ in
                        Task {
                            await refreshSeederStatus()
                            await refreshMealsDBInfo()
                        }
                    }
                }

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

                // Offline Barcode Database (existing)
                Section(header: Text(isEligibleForOfflineDB ? "Offline Barcode Database saved locally" : "Offline Barcode Database saved locally (Pro feature)")) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Status")
                            Spacer()
                            Text(offStatusText).foregroundStyle(.secondary)
                        }
                        if case .downloading = offCurrentStatus {
                            ProgressView(value: offProgress)
                            HStack {
                                Text(byteCountString(offReceivedBytes))
                                Spacer()
                                if offExpectedBytes > 0 {
                                    Text(byteCountString(offExpectedBytes))
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        if let offError {
                            Text(offError).font(.footnote).foregroundStyle(.red)
                        }
                        if networkMonitor.isConnected && networkMonitor.isExpensive {
                            Text("You are not on Wi‑Fi. Downloading may use cellular data.")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                        let freeBytes = offFreeBytes
                        HStack {
                            Text("Free space available")
                            Spacer()
                            Text(byteCountString(freeBytes)).foregroundStyle(.secondary)
                        }
                        .font(.footnote)

                        if !isEligibleForOfflineDB {
                            Text("Sign in to Pro to download and use the offline barcode database.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 4)
                        }
                    }
                    actionButtons()
                        .disabled(!isEligibleForOfflineDB)
                        .opacity(isEligibleForOfflineDB ? 1.0 : 0.55)
                }
                .onAppear { Task { await refreshOFFStatus() } }
                .onReceive(timer) { _ in Task { await refreshOFFStatus() } }

                // People management (existing)
                Section(header: Text(NSLocalizedString("people_section_title", comment: "People")) ) {
                    Picker(NSLocalizedString("default_person_picker_title", comment: "Default person"),
                           selection: Binding<UUID?>(
                            get: { people.first(where: { $0.isDefault })?.id },
                            set: { newID in
                                let isFreeTier = (tier == .free)
                                guard !isFreeTier else { return }
                                setDefaultPerson(by: newID)
                            })) {
                        ForEach(people) { person in
                            Text(person.name)
                                .foregroundStyle(isFreeTier ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                                .tag(Optional.some(person.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(people.isEmpty || isFreeTier)
                    .opacity(isFreeTier ? 0.85 : 1.0)

                    if isFreeTier {
                        Text(LocalizedStringKey("pro_people_notice"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    } else {
                        Button {
                            newPersonName = ""
                            addPersonError = nil
                            showingAddPersonSheet = true
                        } label: {
                            Label(NSLocalizedString("add_person_nav_title", comment: "Add Person"),
                                  systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .disabled(isAtPeopleCap)
                        .opacity(isAtPeopleCap ? 0.6 : 1.0)

                        if isAtPeopleCap {
                            let fmt = NSLocalizedString("add_person_error_max_reached", comment: "Shown when reaching max active people")
                            Text(String(format: fmt, maxActivePeople))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ForEach(people) { person in
                        HStack {
                            if handedness == .left {
                                deleteButton(for: person)
                            }

                            Text(person.name)

                            Spacer()

                            if person.isDefault {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                    .accessibilityLabel(Text(NSLocalizedString("default_person_accessibility_label", comment: "Default")))
                            }

                            if handedness == .right {
                                deleteButton(for: person)
                            }
                        }
                    }
                }
            }
            .onAppear {
                Task { await loadSyncedDate() }
                enforceFreeTierPeopleIfNeeded(isFreeTier: isFreeTier)
                Task { await refreshOFFStatus() }
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
            // OFF confirmation
            .alert("Download Open Food Facts?", isPresented: $showingOFFConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Download") {
                    Task { await ParquetDownloadManager.shared.startDownload() }
                }
            } message: {
                Text(offConfirmMessage)
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

    private func loadSyncedDate() async {
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
