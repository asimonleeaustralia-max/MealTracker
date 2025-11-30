import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject var session: SessionManager

    @AppStorage("energyUnit") private var energyUnit: EnergyUnit = .calories
    @AppStorage("measurementSystem") private var measurementSystem: MeasurementSystem = .metric
    @AppStorage("appLanguageCode") private var appLanguageCode: String = LocalizationManager.defaultLanguageCode
    @AppStorage("sodiumUnit") private var sodiumUnit: SodiumUnit = .milligrams
    @AppStorage("showVitamins") private var showVitamins: Bool = false
    @AppStorage("vitaminsUnit") private var vitaminsUnit: VitaminsUnit = .milligrams
    @AppStorage("showMinerals") private var showMinerals: Bool = false
    @AppStorage("handedness") private var handedness: Handedness = .right

    private var availableLanguages: [String] {
        let codes = Bundle.main.localizations.filter { $0.lowercased() != "base" }
        let list = codes.isEmpty ? Bundle.main.preferredLocalizations : codes
        return Array(Set(list)).sorted()
    }

    var body: some View {
        let l = LocalizationManager(languageCode: appLanguageCode)

        // Read environment-dependent values here (safe)
        let tier = Entitlements.tier(for: session)
        let mealsRemainingText: String = {
            if let remaining = Entitlements.mealsRemainingToday(for: tier, in: context) {
                return "\(remaining)"
            } else {
                return "Unlimited"
            }
        }()
        let maxPhotos = Entitlements.maxPhotosPerMeal(for: tier)

        NavigationView {
            Form {
                // Tier & limits section
                Section(header: Text("Account & Plan")) {
                    HStack {
                        Text("Access Tier")
                        Spacer()
                        Text(tier == .paid ? "Paid (Cloud)" : "Free")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Meals left today")
                        Spacer()
                        Text(mealsRemainingText)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Photos per meal (limit)")
                        Spacer()
                        Text(maxPhotos >= 9000 ? "Unlimited" : "\(maxPhotos)")
                            .foregroundStyle(.secondary)
                    }

                    Toggle("Logged into Cloud (stub)", isOn: $session.isLoggedIn)
                        .tint(.accentColor)
                }

                // Handedness (no header)
                Section {
                    Picker(l.localized("handedness"), selection: $handedness) {
                        Text(l.localized("left_handed")).tag(Handedness.left)
                        Text(l.localized("right_handed")).tag(Handedness.right)
                    }
                    .pickerStyle(.segmented)
                }

                // Energy unit (no header)
                Section {
                    Picker("", selection: $energyUnit) {
                        Text(l.localized("calories")).tag(EnergyUnit.calories)
                        Text(l.localized("kilojoules")).tag(EnergyUnit.kilojoules)
                    }
                    .pickerStyle(.segmented)
                }

                // Measurement system (no header)
                Section {
                    Picker("", selection: $measurementSystem) {
                        Text(l.localized("metric")).tag(MeasurementSystem.metric)
                        Text(l.localized("imperial")).tag(MeasurementSystem.imperial)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle(l.localized("show_vitamins_entry"), isOn: $showVitamins)
                    Picker(l.localized("vitamins_unit"), selection: $vitaminsUnit) {
                        Text("mg").tag(VitaminsUnit.milligrams)
                        Text("µg").tag(VitaminsUnit.micrograms)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle(l.localized("show_minerals_entry"), isOn: $showMinerals)
                }

                // Language (no header)
                Section {
                    Picker(l.localized("choose_language"), selection: $appLanguageCode) {
                        ForEach(availableLanguages, id: \.self) { code in
                            Text(LocalizationManager.displayName(for: code)).tag(code)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l.localized("done")) { dismiss() }
                }
            }
        }
    }
}

#Preview {
    let controller = PersistenceController(inMemory: true)
    return SettingsView()
        .environment(\.managedObjectContext, controller.container.viewContext)
        .environmentObject(SessionManager())
}
