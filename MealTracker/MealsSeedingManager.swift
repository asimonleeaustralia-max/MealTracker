import Foundation
import BackgroundTasks
import UserNotifications

// Persisted keys for progress so UI can restore across launches.
private enum SeederDefaults {
    static let status = "MealsSeeding.status"
    static let downloaded = "MealsSeeding.downloaded"
    static let total = "MealsSeeding.total"
    static let phase = "MealsSeeding.phase"
    static let queued = "MealsSeeding.queued"
    static let lastError = "MealsSeeding.lastError"
}

// Background-capable orchestrator for MealsSeeder that persists progress and can resume after relaunch.
actor MealsSeedingManager {
    static let shared = MealsSeedingManager()

    enum Status: Equatable {
        case idle
        case queued
        case running(downloaded: Int, total: Int, phase: String)
        case completed(total: Int)
        case failed(error: String)
        case cancelled
    }

    // Publicly readable status
    private(set) var status: Status

    // Used to cancel an in-process foreground run
    private var isCancelled: Bool = false

    // Initialize from persisted state
    private init() {
        let d = UserDefaults.standard
        if d.bool(forKey: SeederDefaults.queued) {
            status = .queued
        } else if let phase = d.string(forKey: SeederDefaults.phase) {
            let downloaded = d.integer(forKey: SeederDefaults.downloaded)
            let total = max(d.integer(forKey: SeederDefaults.total), downloaded)
            status = .running(downloaded: downloaded, total: total, phase: phase)
        } else if let err = d.string(forKey: SeederDefaults.lastError), !err.isEmpty {
            status = .failed(error: err)
        } else {
            status = .idle
        }
    }

    // MARK: - Public API

    // Called from Settings to request a bulk download. We mark queued and schedule a BGProcessingTask.
    func startQueued() {
        persistQueued(true)
        setStatus(.queued)
        MealTrackerApp.scheduleMealsSeedingTask()
    }

    // Settings can call to cancel only a foreground run; BG tasks are managed by the system.
    func cancel() {
        isCancelled = true
        setStatus(.cancelled)
        clearPersistence()
    }

    // Settings polling
    func currentStatus() -> Status { status }

    // Let the app decide if it should ensure the BG task is scheduled when moving to background.
    func shouldEnsureScheduled() -> Bool {
        if case .queued = status { return true }
        if case .running = status { return true }
        return false
    }

    // BGTaskScheduler entry point wired in MealTrackerApp.init()
    func handleBackgroundTask(_ task: BGProcessingTask) async {
        // Configure constraints: BGProcessingTask already implies background execution.
        task.expirationHandler = { [weak self] in
            Task { await self?.handleExpiration() }
        }

        // Run the seeding work; ensure we mark completion on exit.
        do {
            try await runSeedingInBackground()
            task.setTaskCompleted(success: true)
        } catch {
            await setStatus(.failed(error: error.localizedDescription))
            task.setTaskCompleted(success: false)
        }
    }

    // MARK: - Internal runners

    // Foreground helper (not used by Settings directly; we queue BG instead). Useful for debugging.
    func runNowOnMainThreadForDebug() async {
        do {
            try await runSeeding(progressPhase: "Discovering IDs…")
        } catch {
            await setStatus(.failed(error: error.localizedDescription))
        }
    }

    private func runSeedingInBackground() async throws {
        // Clear queued flag and enter running
        persistQueued(false)
        try await runSeeding(progressPhase: "Discovering IDs…")
    }

    // Core runner. Uses a progress-enabled variant of MealsSeeder.
    private func runSeeding(progressPhase initialPhase: String) async throws {
        isCancelled = false
        persist(downloaded: 0, total: 0, phase: initialPhase, error: nil)
        await setStatus(.running(downloaded: 0, total: 0, phase: initialPhase))

        // We wrap MealsSeeder to get discovery total and then per-item progress.
        var lastReportedDownloaded = 0
        var totalCount = 0

        // Progress callback receives (downloaded, total, phase)
        let progress: (Int, Int, String) -> Void = { [weak self] downloaded, total, phase in
            guard let self else { return }
            Task {
                await self.setStatus(.running(downloaded: downloaded, total: total, phase: phase))
                await self.persist(downloaded: downloaded, total: total, phase: phase, error: nil)
            }
            lastReportedDownloaded = downloaded
            totalCount = total
        }

        // Respect cancellation
        if isCancelled { throw CancellationError() }

        // Run the seeder (nil = all items). This call will drive the progress callback.
        let _ = try await MealsSeeder.seedMealsDBWithProgress(maxItems: nil, progress: progress)

        if isCancelled { throw CancellationError() }

        // Done
        await setStatus(.completed(total: max(totalCount, lastReportedDownloaded)))
        persist(downloaded: max(totalCount, lastReportedDownloaded), total: max(totalCount, lastReportedDownloaded), phase: "", error: nil)
        postLocalNotification(title: "Meals Download Complete", body: "Downloaded \(max(totalCount, lastReportedDownloaded)) items.")
        // Clear persisted running markers
        clearPersistence()
    }

    private func handleExpiration() {
        isCancelled = true
        setStatus(.failed(error: "Background time expired"))
        persist(error: "Background time expired")
    }

    // MARK: - Persistence

    private func setStatus(_ new: Status) {
        status = new
    }

    private func persistQueued(_ queued: Bool) {
        UserDefaults.standard.set(queued, forKey: SeederDefaults.queued)
    }

    private func persist(downloaded: Int? = nil, total: Int? = nil, phase: String? = nil, error: String? = nil) {
        let d = UserDefaults.standard
        if let downloaded { d.set(downloaded, forKey: SeederDefaults.downloaded) }
        if let total { d.set(total, forKey: SeederDefaults.total) }
        if let phase {
            d.set(phase, forKey: SeederDefaults.phase)
        } else {
            d.removeObject(forKey: SeederDefaults.phase)
        }
        if let error {
            d.set(error, forKey: SeederDefaults.lastError)
        } else {
            d.removeObject(forKey: SeederDefaults.lastError)
        }
    }

    private func clearPersistence() {
        let d = UserDefaults.standard
        d.removeObject(forKey: SeederDefaults.downloaded)
        d.removeObject(forKey: SeederDefaults.total)
        d.removeObject(forKey: SeederDefaults.phase)
        d.removeObject(forKey: SeederDefaults.lastError)
        d.set(false, forKey: SeederDefaults.queued)
    }

    // MARK: - Notifications

    private func postLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let req = UNNotificationRequest(identifier: "MealsSeeding.complete.\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }
}
