import Foundation
import Combine

// Stubbed session manager. You will replace its implementation later.
final class SessionManager: ObservableObject {
    // Toggle to simulate cloud login state. Persisted for convenience.
    @Published var isLoggedIn: Bool {
        didSet { UserDefaults.standard.set(isLoggedIn, forKey: "session_isLoggedIn") }
    }

    init() {
        self.isLoggedIn = UserDefaults.standard.bool(forKey: "session_isLoggedIn")
    }
}
