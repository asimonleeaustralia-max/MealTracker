import SwiftUI

struct LocalizationManager {
    let languageCode: String

    static var defaultLanguageCode: String {
        // Use first preferred localization available in the bundle
        if #available(iOS 16, *) {
            return Bundle.main.preferredLocalizations.first
                ?? Locale.current.language.languageCode?.identifier
                ?? "en"
        } else {
            // Fallback on earlier versions
            // Locale.current.languageCode is available before iOS 16
            return Bundle.main.preferredLocalizations.first
                ?? Locale.current.languageCode
                ?? "en"
        }
    }

    func bundle() -> Bundle {
        guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let b = Bundle(path: path) else {
            return Bundle.main
        }
        return b
    }

    func localized(_ key: String) -> String {
        NSLocalizedString(key, tableName: nil, bundle: bundle(), value: key, comment: "")
    }

    static func displayName(for code: String) -> String {
        let locale = Locale.current
        // Try to get a human-readable language name
        return locale.localizedString(forLanguageCode: code) ?? code
    }
}

struct LocalizedText: View {
    let key: String
    let manager: LocalizationManager

    init(_ key: String, manager: LocalizationManager) {
        self.key = key
        self.manager = manager
    }

    var body: some View {
        Text(manager.localized(key))
    }
}
