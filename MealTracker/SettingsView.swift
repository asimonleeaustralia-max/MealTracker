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
    // New: data sharing preference (default = public)
    @AppStorage("dataSharingPreference") private var dataSharing: DataSharingPreference = .public
    // New: Simulants group visibility (default disabled)
    @AppStorage("showSimulants") private var showSimulants: Bool = false
    // New: open app to new meal on launch
    @AppStorage("openToNewMealOnLaunch") private var openToNewMealOnLaunch: Bool = false
    // New: AI feedback severity (stub; default = balanced)
    @AppStorage("aiFeedbackSeverity") private var aiFeedbackSeverity: AIFeedbackSeverity = .balanced

    @State private var syncedDateText: String = "—"
    @State private var isSyncing: Bool = false
    @State private var syncError: String?

    // Login sheet
    @State private var showingLogin = false

    // People (Core Data) — fetch only active (non-removed)
    @FetchRequest(fetchRequest: Person.fetchAllRequest())
    private var people: FetchedResults<Person>

    // Add Person sheet state
    @State private var showingAddPersonSheet: Bool = false
    @State private var newPersonName: String = ""
    @State private var addPersonError: String?

    // Delete confirmation state
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
    // Cached free space (actor-fetched)
    @State private var offFreeBytes: Int64 = 0

    private var availableLanguages: [String] {
        let codes = Bundle.main.localizations.filter { $0.lowercased() != "base" }
        let list = codes.isEmpty ? Bundle.main.preferredLocalizations : codes
        return Array(Set(list)).sorted()
    }

    // People cap
    private let maxActivePeople = 15
    private var isAtPeopleCap: Bool { people.count >= maxActivePeople }

    var body: some View {
        let l = LocalizationManager(languageCode: appLanguageCode)

        // Read environment-dependent values here (safe)
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
                // Language (moved to top)
                Section {
                    Picker(l.localized("choose_language"), selection: $appLanguageCode) {
                        ForEach(availableLanguages, id: \.self) { code in
                            Text(LocalizationManager.displayName(for: code)).tag(code)
                        }
                    }
                }

                // Handedness (localized)
                Section(header: Text(LocalizedStringKey("handedness_section_title"))) {
                    Picker("", selection: $handedness) {
                        Text(LocalizedStringKey("left_handed")).tag(Handedness.left)
                        Text(LocalizedStringKey("right_handed")).tag(Handedness.right)
                    }
                    .pickerStyle(.segmented)
                }

                // Nutrition options: Vitamins, Minerals, Stimulants
                Section(header: Text(l.localized("nutrition_options_section_title"))) {
                    Toggle(isOn: $showVitamins) {
                        Text(l.localized("show_vitamins"))
                    }
                    if showVitamins {
                        Picker(l.localized("vitamin_units"), selection: $vitaminsUnit) {
                            ForEach(VitaminsUnit.allCases, id: \.self) { unit in
                                Text(unit.displaySuffix).tag(unit)
                            }
                        }
                    }

                    Toggle(isOn: $showMinerals) {
                        Text(l.localized("show_minerals"))
                    }

                    // Note: stored key is "showSimulants" (spelling), label shows "Stimulants"
                    Toggle(isOn: $showSimulants) {
                        Text(l.localized("show_stimulants"))
                    }
                }

                // Account & Plan section (use existing key from Localizable.strings)
                Section(header: Text(LocalizedStringKey("account_plan_section_title"))) {
                    HStack {
                        Text(LocalizedStringKey("access_tier"))
                        Spacer()
                        Text(tier == .paid ? NSLocalizedString("access_tier.paid", comment: "") : NSLocalizedString("access_tier.free", comment: ""))
                            .foregroundStyle(.secondary)
                    }

                    // Logged-in state
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

                    // Login / Logout actions
                    if session.isLoggedIn {
                        Button(role: .destructive) {
                            Task { await session.logout() }
                        } label: {
                            Text(LocalizedStringKey("log_out"))
                        }
                    } else {
                        Button {
                            showingLogin = true
                        } label: {
                            Text(LocalizedStringKey("log_in"))
                        }
                        .sheet(isPresented: $showingLogin) {
                            LoginView { email, password in
                                Task {
                                    do {
                                        try await session.login(email: email, password: password)
                                        showingLogin = false
                                    } catch {
                                        // Keep inline error UI within LoginView if needed
                                    }
                                }
                            }
                        }
                    }

                    // Limits
                    HStack {
                        Text(LocalizedStringKey("meals_left_today"))
                        Spacer()
                        Text(mealsRemainingText)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text(LocalizedStringKey("photos_per_meal_limit"))
                        Spacer()
                        Text(maxPhotos >= 9000 ? NSLocalizedString("unlimited", comment: "") : "\(maxPhotos)")
                            .foregroundStyle(.secondary)
                    }

                    // Date Synced (Cloud Stub)
                    Section {
                        HStack {
                            Text(LocalizedStringKey("synced_date"))
                            Spacer()
                            Text(syncedDateText).foregroundStyle(.secondary)
                        }
                        Button {
                            Task { await syncNow() }
                        } label: {
                            if isSyncing {
                                ProgressView().progressViewStyle(.circular)
                            } else {
                                Text(LocalizedStringKey("sync_now"))
                            }
                        }
                        .disabled(isSyncing || !session.isLoggedIn)
                        if let syncError {
                            Text(syncError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                }

                // Offline Barcode Database — always visible (Option A)
                Section(header: Text(isEligibleForOfflineDB ? "Offline Barcode Database saved locally" : "Offline Barcode Database saved locally (Pro feature)")) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Status")
                            Spacer()
                            Text(offStatusText)
                                .foregroundStyle(.secondary)
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
                            Text(offError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        // Network warning
                        if networkMonitor.isConnected && networkMonitor.isExpensive {
                            Text("You are not on Wi‑Fi. Downloading may use cellular data.")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }

                        // Free space hint
                        let freeBytes = offFreeBytes
                        HStack {
                            Text("Free space available")
                            Spacer()
                            Text(byteCountString(freeBytes))
                                .foregroundStyle(.secondary)
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

                    // Action buttons (disabled when not eligible)
                    actionButtons()
                        .disabled(!isEligibleForOfflineDB)
                        .opacity(isEligibleForOfflineDB ? 1.0 : 0.55)
                }
                .onAppear { Task { await refreshOFFStatus() } }
                .onReceive(timer) { _ in
                    Task { await refreshOFFStatus() }
                }

                // People management
                Section(header: Text(NSLocalizedString("people_section_title", comment: "People")) ) {
                    // Default person dropdown (only active people)
                    Picker(NSLocalizedString("default_person_picker_title", comment: "Default person"),
                           selection: Binding<UUID?>(
                            get: {
                                people.first(where: { $0.isDefault })?.id
                            },
                            set: { newID in
                                // Prevent changes on free tier
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
                    .disabled(people.isEmpty || isFreeTier) // greyed out on free
                    .opacity(isFreeTier ? 0.85 : 1.0) // slightly more grey when not pro

                    // Informational notice for free tier (localized key)
                    if isFreeTier {
                        Text(LocalizedStringKey("pro_people_notice"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    } else {
                        // Add Person button (paid tiers)
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

                    // List of people with in-row soft delete (no swipe)
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
            }
            .onChange(of: session.isLoggedIn) { _ in
                // When login state changes, re-evaluate and enforce
                let newTier = Entitlements.tier(for: session)
                enforceFreeTierPeopleIfNeeded(isFreeTier: newTier == .free)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l.localized("done")) { dismiss() }
                }
            }
            .alert(item: $personPendingDeletion) { person in
                Alert(
                    title: Text(NSLocalizedString("confirm_delete_person_title", comment: "Delete person?")),
                    message: Text(String(format: NSLocalizedString("confirm_delete_person_message", comment: "Are you sure you want to remove %@?"), person.name)),
                    primaryButton: .destructive(Text(NSLocalizedString("delete", comment: "Delete"))) {
                        // Block deleting the default ("Me") person at action time too
                        guard !person.isDefault else {
                            personPendingDeletion = nil
                            return
                        }
                        softDeletePerson(person)
                        personPendingDeletion = nil
                    },
                    secondaryButton: .cancel {
                        personPendingDeletion = nil
                    }
                )
            }
            // Move the Add Person sheet to the top-level NavigationView to avoid immediate close
            .sheet(isPresented: $showingAddPersonSheet) {
                NavigationView {
                    Form {
                        Section(header: Text(NSLocalizedString("add_person_name_header", comment: "Name"))) {
                            TextField(NSLocalizedString("add_person_name_placeholder", comment: "Name"),
                                      text: Binding(
                                        get: { newPersonName },
                                        set: { value in
                                            newPersonName = value
                                            // Live-validate as user types
                                            addPersonError = validationError(for: value)
                                        }
                                      ))
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(true)

                            if let error = addPersonError, !error.isEmpty {
                                Text(error)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .navigationTitle(NSLocalizedString("add_person_nav_title", comment: "Add Person"))
                    .navigationBarTitleDisplayMode(.inline) // smaller title again
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

    // MARK: - OFF helpers

    private var offCurrentStatus: ParquetDownloadManager.Status {
        // We keep local mirror via refreshOFFStatus
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
        let mgr = ParquetDownloadManager.shared
        let status = await mgr.status
        switch status {
        case .idle:
            let exists = await mgr.fileExists()
            if exists {
                let size = await mgr.existingFileSize()
                offStatusText = "Downloaded (\(byteCountString(size)))"
                offExpectedBytes = size
                offReceivedBytes = size
                offProgress = 1.0
                // Update free space cache too
                offFreeBytes = await mgr.bytesAvailableOnDisk()
            } else {
                offStatusText = "Not downloaded"
                offProgress = 0
                offExpectedBytes = -1
                offReceivedBytes = 0
                offFreeBytes = await mgr.bytesAvailableOnDisk()
            }
        case .checkingSize:
            offStatusText = "Checking size…"
            offError = nil
            offFreeBytes = await mgr.bytesAvailableOnDisk()
        case .readyToDownload(let expectedBytes):
            offExpectedBytes = expectedBytes
            let sizeText = expectedBytes > 0 ? byteCountString(expectedBytes) : "unknown size"
            offStatusText = "Ready (\(sizeText))"
            offError = nil
            // Show confirm with Wi‑Fi/disk warning
            let free = await ParquetDownloadManager.shared.bytesAvailableOnDisk()
            offFreeBytes = free
            var warnings: [String] = []
            if expectedBytes > 0 {
                if expectedBytes > free {
                    warnings.append("Not enough free space. Requires \(byteCountString(expectedBytes)), available \(byteCountString(free)).")
                } else if expectedBytes > (free / 2) {
                    warnings.append("Large download: \(byteCountString(expectedBytes)).")
                }
            } else {
                warnings.append("Large download.")
            }
            if networkMonitor.isExpensive || !networkMonitor.isOnWiFi {
                warnings.append("You are not on Wi‑Fi. Downloading may use cellular data.")
            }
            let messageLines = ["This will download the Open Food Facts database for offline use.", "Estimated size: \(sizeText)"] + warnings
            offConfirmMessage = messageLines.joined(separator: "\n\n")
            showingOFFConfirm = true
        case .downloading(let progress, let received, let expected):
            offProgress = max(0, min(1, progress))
            offReceivedBytes = received
            offExpectedBytes = expected
            offStatusText = expected > 0
                ? String(format: "Downloading… %.0f%%", offProgress * 100.0)
                : "Downloading…"
            offError = nil
            offFreeBytes = await mgr.bytesAvailableOnDisk()
        case .completed(_, let bytes):
            offStatusText = "Downloaded (\(byteCountString(bytes)))"
            offProgress = 1.0
            offError = nil
            offFreeBytes = await mgr.bytesAvailableOnDisk()
        case .failed(let error):
            offStatusText = "Failed"
            offError = error
            offFreeBytes = await mgr.bytesAvailableOnDisk()
        case .cancelled:
            offStatusText = "Cancelled"
            offError = nil
            offProgress = 0
            offFreeBytes = await mgr.bytesAvailableOnDisk()
        }
    }

    @ViewBuilder
    private func actionButtons() -> some View {
        let mgr = ParquetDownloadManager.shared
        let exists = (try? mgr.destinationURL()).map { FileManager.default.fileExists(atPath: $0.path) } ?? false

        HStack {
            if offStatusText.starts(with: "Downloading") {
                Button(role: .destructive) {
                    Task { await mgr.cancel() }
                } label: {
                    Text("Cancel Download")
                }
            } else {
                Button {
                    Task {
                        await ParquetDownloadManager.shared.fetchExpectedSize()
                        await refreshOFFStatus()
                    }
                } label: {
                    Text(exists ? "Re-download" : "Download for offline use")
                }
            }

            if exists {
                Spacer()
                Button(role: .destructive) {
                    if let url = try? mgr.destinationURL() {
                        try? FileManager.default.removeItem(at: url)
                    }
                    Task { await refreshOFFStatus() }
                } label: {
                    Text("Remove")
                }
            }
        }
    }

    // MARK: - Add Person flow (unchanged below)

    private func normalizedName(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
         .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: .current)
         .lowercased()
    }

    private func nameAlreadyExists(_ name: String) -> Bool {
        let target = normalizedName(name)
        // people excludes removed already
        return people.contains { normalizedName($0.name) == target }
    }

    private func validationError(for raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return NSLocalizedString("add_person_error_empty", comment: "Name cannot be empty")
        }
        if nameAlreadyExists(trimmed) {
            return NSLocalizedString("add_person_error_duplicate", comment: "That name already exists")
        }
        if people.count >= maxActivePeople {
            let fmt = NSLocalizedString("add_person_error_max_reached", comment: "Max active people reached")
            return String(format: fmt, maxActivePeople)
        }
        return nil
    }

    private func attemptSaveNewPerson() {
        // Guard free tier (should be unreachable since button is hidden)
        let isFreeTier = Entitlements.tier(for: session) == .free
        guard !isFreeTier else { return }

        // Enforce hard cap before proceeding
        if people.count >= maxActivePeople {
            let fmt = NSLocalizedString("add_person_error_max_reached", comment: "Max active people reached")
            addPersonError = String(format: fmt, maxActivePeople)
            return
        }

        let trimmed = newPersonName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let error = validationError(for: trimmed) {
            addPersonError = error
            return
        }

        // Passed validation — insert and save
        let p = Person(context: context)
        p.name = trimmed
        p.isRemoved = false

        // If no default person exists yet (among active), make this one default
        if people.first(where: { $0.isDefault }) == nil {
            p.isDefault = true
        }

        do {
            try context.save()
            showingAddPersonSheet = false
        } catch {
            addPersonError = error.localizedDescription
        }
    }

    private func deleteButton(for person: Person) -> some View {
        // Do not allow deleting the default ("Me") person
        let isProtected = person.isDefault
        return Button {
            // Prevent deleting the last remaining active person
            guard people.count >= 2 else { return }
            // Block if protected
            guard !isProtected else { return }
            personPendingDeletion = person
        } label: {
            Image(systemName: "trash")
                .foregroundStyle(isProtected ? AnyShapeStyle(.secondary) : AnyShapeStyle(.red))
                .imageScale(.medium)
                .accessibilityLabel(
                    Text(String(format: NSLocalizedString("delete_person_accessibility_label", comment: "Delete %@"), person.name))
                )
        }
        .buttonStyle(.borderless)
        .disabled(people.count <= 1 || isProtected)
        .opacity(isProtected ? 0.4 : 1.0)
    }

    private func softDeletePerson(_ person: Person) {
        // Prevent deleting the last remaining active person
        guard people.count >= 2 else { return }
        // Never delete the default ("Me") person
        guard !person.isDefault else { return }

        let deletedDefault = person.isDefault
        person.isDefault = false
        person.isRemoved = true

        do {
            try context.save()
        } catch {
            // Handle save error
        }

        // Reassign default if we removed the default person
        if deletedDefault {
            do {
                let remaining = try context.fetch(Person.fetchAllRequest()) // active only
                if let first = remaining.first {
                    for p in remaining { p.isDefault = (p == first) }
                    try context.save()
                }
            } catch {
                // Handle fetch/save error
            }
        }
    }

    private func softDeletePeople(at offsets: IndexSet) {
        // Retained for potential reuse; no longer wired to swipe.
        let toDelete = offsets.map { people[$0] }

        // Prevent deleting the last remaining active person
        guard people.count - toDelete.count >= 1 else {
            return
        }

        // If any target is the default ("Me"), refuse the whole operation
        guard !toDelete.contains(where: { $0.isDefault }) else {
            return
        }

        var deletedDefault = false
        for p in toDelete {
            if p.isDefault { deletedDefault = true }
            p.isDefault = false
            p.isRemoved = true
        }

        do {
            try context.save()
        } catch {
            // Handle save error
        }

        // If we removed the default, ensure one active default exists
        if deletedDefault {
            do {
                let remaining = try context.fetch(Person.fetchAllRequest()) // active only
                if let first = remaining.first {
                    // Set exactly one default among active
                    for p in remaining { p.isDefault = (p == first) }
                    try context.save()
                }
            } catch {
                // Handle fetch/save error
            }
        }
    }

    private func setDefaultPerson(by id: UUID?) {
        guard let id else { return }
        // Toggle default among active people only
        for p in people {
            p.isDefault = (p.id == id)
        }
        do {
            try context.save()
        } catch {
            // Handle save error
        }
    }

    // Enforce free plan behavior: single default person named "Me", no changes allowed.
    private func enforceFreeTierPeopleIfNeeded(isFreeTier: Bool) {
        guard isFreeTier else { return }

        // Ensure one default person exists among active and is named "Me"
        // If none exist, create one.
        let activePeople = Array(people)
        if activePeople.isEmpty {
            let p = Person(context: context)
            let defaultName = NSLocalizedString("default_person_name_me", comment: "Default person name for device owner")
            p.name = (defaultName == "default_person_name_me") ? "Me" : defaultName
            p.isDefault = true
            p.isRemoved = false
            try? context.save()
            return
        }

        // Ensure exactly one default
        var foundDefault: Person?
        for p in activePeople {
            if p.isDefault {
                if foundDefault == nil {
                    foundDefault = p
                } else {
                    p.isDefault = false
                }
            }
        }
        if foundDefault == nil, let first = activePeople.first {
            first.isDefault = true
            foundDefault = first
        }

        // Ensure default person's name is "Me"
        if let d = foundDefault {
            let desiredName = NSLocalizedString("default_person_name_me", comment: "Default person name for device owner")
            let target = (desiredName == "default_person_name_me") ? "Me" : desiredName
            if d.name != target {
                d.name = target
            }
        }

        if context.hasChanges {
            try? context.save()
        }
    }

    // MARK: - Sync stubs

    @MainActor
    private func loadSyncedDate() async {
        isSyncing = true
        syncError = nil
        defer { isSyncing = false }
        do {
            if let d = try await session.dateSync.getSyncedDate() {
                syncedDateText = DateFormatter.localizedString(from: d, dateStyle: .medium, timeStyle: .short)
            } else {
                syncedDateText = NSLocalizedString("synced_date_not_set", comment: "")
            }
        } catch {
            syncError = error.localizedDescription
        }
    }

    @MainActor
    private func syncNow() async {
        isSyncing = true
        syncError = nil
        defer { isSyncing = false }
        do {
            guard session.isLoggedIn else {
                syncError = NSLocalizedString("must_be_logged_in_to_sync", comment: "Must be logged in")
                return
            }
            // For demo: set "now" as the synced date, then read back to display
            let now = Date()
            try await session.dateSync.setSyncedDate(now)
            try await Task.sleep(nanoseconds: 150_000_000) // small delay to mimic network
            try await loadSyncedDate()
        } catch {
            syncError = error.localizedDescription
        }
    }
}

#Preview {
    let controller = PersistenceController(inMemory: true)
    return SettingsView()
        .environment(\.managedObjectContext, controller.container.viewContext)
        .environmentObject(SessionManager())
}
