import Foundation

enum EnergyUnit: String, CaseIterable, Codable, Equatable, Hashable {
    case calories
    case kilojoules

    // Used in MealFormView: energyUnit.displaySuffix(manager:)
    func displaySuffix(manager: LocalizationManager) -> String {
        switch self {
        case .calories:
            // Localize if you have keys for kcal; otherwise show standard suffix
            return "kcal"
        case .kilojoules:
            return "kJ"
        }
    }
}

enum MeasurementSystem: String, CaseIterable, Codable, Equatable, Hashable {
    case metric
    case imperial
}

enum SodiumUnit: String, CaseIterable, Codable, Equatable, Hashable {
    case milligrams
    case grams

    var displaySuffix: String {
        switch self {
        case .milligrams: return "mg"
        case .grams: return "g"
        }
    }

    // Optional helpers if you later need conversions
    func toMilligrams(from value: Double) -> Double {
        switch self {
        case .milligrams: return value
        case .grams: return value * 1000.0
        }
    }

    func fromMilligrams(_ mg: Double) -> Double {
        switch self {
        case .milligrams: return mg
        case .grams: return mg / 1000.0
        }
    }
}

enum VitaminsUnit: String, CaseIterable, Codable, Equatable, Hashable {
    case milligrams
    case micrograms

    var displaySuffix: String {
        switch self {
        case .milligrams: return "mg"
        case .micrograms: return "µg"
        }
    }

    // Storage is in milligrams as per Meal model comments
    func toStorageMG(_ uiValue: Double) -> Double {
        switch self {
        case .milligrams:
            return uiValue
        case .micrograms:
            return uiValue / 1000.0
        }
    }

    func fromStorageMG(_ mgValue: Double) -> Double {
        switch self {
        case .milligrams:
            return mgValue
        case .micrograms:
            return mgValue * 1000.0
        }
    }
}
