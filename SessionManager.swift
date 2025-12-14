import Foundation
import Combine

// Session manager with single-user Keychain-backed credentials.
@MainActor
final class SessionManager: ObservableObject {
    // Published login state for UI
    @Published var isLoggedIn: Bool {
        didSet { UserDefaults.standard.set(isLoggedIn, forKey: "session_isLoggedIn") }
    }

    // Current single-user identifier (stable across launches)
    @Published private(set) var currentUserID: UUID? {
        didSet {
            if let id = currentUserID {
                UserDefaults.standard.set(id.uuidString, forKey: "session_userID")
            } else {
                UserDefaults.standard.removeObject(forKey: "session_userID")
            }
        }
    }

    // Non-sensitive display email (optional, for showing in UI)
    @Published var displayEmail: String? {
        didSet {
            UserDefaults.standard.set(displayEmail, forKey: "session_displayEmail")
        }
    }

    // Cloud date sync stub remains
    let dateSync: DateSyncService

    init(dateSync: DateSyncService = CloudDateSyncStub()) {
        self.isLoggedIn = UserDefaults.standard.bool(forKey: "session_isLoggedIn")
        self.dateSync = dateSync

        if let s = UserDefaults.standard.string(forKey: "session_userID"), let id = UUID(uuidString: s) {
            self.currentUserID = id
        } else {
            self.currentUserID = nil
        }
        self.displayEmail = UserDefaults.standard.string(forKey: "session_displayEmail")
    }

    // MARK: - Login / Logout

    struct LoginError: LocalizedError {
        let description: String
        var errorDescription: String? { description }
        static let invalidEmail = LoginError(description: NSLocalizedString("invalid_email_error", comment: "Invalid email"))
        static let invalidPassword = LoginError(description: NSLocalizedString("invalid_password_error", comment: "Invalid password"))
        static func keychain(_ err: Error) -> LoginError {
            LoginError(description: err.localizedDescription)
        }
    }

    func login(email: String, password: String) async throws {
        // DEV bypass: accept specific credentials in DEBUG builds
        #if DEBUG
        if email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "test@test.com",
           password == "password" {
            let userID = currentUserID ?? UUID()
            do {
                try KeychainService.saveEmail(email, for: userID)
                try KeychainService.savePassword(password, for: userID)
            } catch {
                throw LoginError.keychain(error)
            }
            currentUserID = userID
            displayEmail = email
            isLoggedIn = true
            return
        }
        #endif

        // Basic validation (client-side)
        guard isValidEmail(email) else { throw LoginError.invalidEmail }
        guard password.count >= 8 else { throw LoginError.invalidPassword }

        // In Phase 2, authenticate with Azure here and get canonical user id + tokens.
        // For now, generate or reuse a stable local UUID.
        let userID = currentUserID ?? UUID()

        // Store credentials securely in Keychain
        do {
            try KeychainService.saveEmail(email, for: userID)
            try KeychainService.savePassword(password, for: userID)
        } catch {
            throw LoginError.keychain(error)
        }

        // Persist session state
        currentUserID = userID
        displayEmail = email
        isLoggedIn = true
    }

    func logout() async {
        if let id = currentUserID {
            KeychainService.deleteAll(for: id)
        }
        // Clear local state
        currentUserID = nil
        displayEmail = nil
        isLoggedIn = false

        // Optionally clear synced date stub to reflect signed-out state
        try? await dateSync.setSyncedDate(nil)
    }

    // MARK: - Accessors for credentials (use rarely; avoid caching password)

    func loadEmail() throws -> String? {
        guard let id = currentUserID else { return nil }
        return try KeychainService.loadEmail(for: id)
    }

    func loadPassword() throws -> String? {
        guard let id = currentUserID else { return nil }
        return try KeychainService.loadPassword(for: id)
    }

    // MARK: - Helpers

    private func isValidEmail(_ email: String) -> Bool {
        // Lightweight email pattern adequate for UI validation
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return email.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}

