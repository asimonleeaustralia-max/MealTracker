import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("energyUnit") private var energyUnit: EnergyUnit = .calories
    @AppStorage("measurementSystem") private var measurementSystem: MeasurementSystem = .metric
    @AppStorage("appLanguageCode") private var appLanguageCode: String = LocalizationManager.defaultLanguageCode

    private var availableLanguages: [String] {
        // List localizations actually present in the app bundle
        Bundle.main.localizations.sorted()
    }

    var body: some View {
        let l = LocalizationManager(languageCode: appLanguageCode)

        NavigationView {
            Form {
                Section(header: LocalizedText("energy_unit", manager: l)) {
                    Picker("", selection: $energyUnit) {
                        Text(l.localized("calories")).tag(EnergyUnit.calories)
                        Text(l.localized("kilojoules")).tag(EnergyUnit.kilojoules)
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: LocalizedText("measurement_system", manager: l)) {
                    Picker("", selection: $measurementSystem) {
                        Text(l.localized("metric")).tag(MeasurementSystem.metric)
                        Text(l.localized("imperial")).tag(MeasurementSystem.imperial)
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: LocalizedText("language", manager: l)) {
                    Picker(l.localized("choose_language"), selection: $appLanguageCode) {
                        ForEach(availableLanguages, id: \.self) { code in
                            Text(LocalizationManager.displayName(for: code)).tag(code)
                        }
                    }
                }
            }
            .navigationTitle(l.localized("settings"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l.localized("done")) { dismiss() }
                }
            }
        }
    }
}
