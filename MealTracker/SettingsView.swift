import SwiftUI
import CoreData

enum DataSharingPreference: String, CaseIterable, Identifiable {
    case `public`
    case `private`

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .public: return NSLocalizedString("data_sharing.public", comment: "")
        case .private: return NSLocalizedString("data_sharing.private", comment: "")
        }
    }

    var explanation: String {
        switch self {
        case .public:
            return NSLocalizedString("data_sharing.public_explanation", comment: "")
        case .private:
            return NSLocalizedString("data_sharing.private_explanation", comment: "")
        }
    }
}

// New: AI Feedback Severity (stub)
enum AIFeedbackSeverity: String, CaseIterable, Identifiable {
    case kind
    case balanced
    case bootCamp

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kind:
            return NSLocalizedString("ai_feedback_severity.kind", comment: "")
        case .balanced:
            return NSLocalizedString("ai_feedback_severity.balanced", comment: "")
        case .bootCamp:
            return NSLocalizedString("ai_feedback_severity.boot_camp", comment: "")
        }
    }
}

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

    private var availableLanguages: [String] {
        let codes = Bundle.main.localizations.filter { $0.lowercased() != "base" }
        let list = codes.isEmpty ? Bundle.main.preferredLocalizations : codes
        return Array(Set(list)).sorted()
    }

    var body: some View {
        let l = LocalizationManager(languageCode: appLanguageCode)

        // Read environment-dependent values here (safe)
        let tier = Entitlements.tier(for: session)
        let isFreeTier = (tier == .free)

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
                                .foregroundStyle(isFreeTier ? .secondary : .primary)
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

    // MARK: - Add Person flow

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
        return nil
    }

    private func attemptSaveNewPerson() {
        // Guard free tier (should be unreachable since button is hidden)
        let isFreeTier = Entitlements.tier(for: session) == .free
        guard !isFreeTier else { return }

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

    // MARK: - People actions (soft delete aware)

    private func deleteButton(for person: Person) -> some View {
        Button {
            // Prevent deleting the last remaining active person
            guard people.count >= 2 else { return }
            personPendingDeletion = person
        } label: {
            Image(systemName: "trash")
                .foregroundStyle(.red)
                .imageScale(.medium)
                .accessibilityLabel(
                    Text(String(format: NSLocalizedString("delete_person_accessibility_label", comment: "Delete %@"), person.name))
                )
        }
        .buttonStyle(.borderless)
        .disabled(people.count <= 1)
    }

    private func softDeletePerson(_ person: Person) {
        // Prevent deleting the last remaining active person
        guard people.count >= 2 else { return }

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
