import Foundation

// Note: Manager remains an actor for serialized state access, but also acts as URLSession delegate.
// We keep NSObject inheritance to serve as the delegate target.
actor ParquetDownloadManager: NSObject, URLSessionDownloadDelegate, URLSessionTaskDelegate, URLSessionDelegate {

    enum Status: Equatable {
        case idle
        case checkingSize
        case readyToDownload(expectedBytes: Int64)
        case downloading(progress: Double, receivedBytes: Int64, expectedBytes: Int64)
        case completed(fileURL: URL, bytes: Int64)
        case failed(error: String)
        case cancelled
    }

    static let shared = ParquetDownloadManager()

    // Publicly readable state (polled by UI)
    private(set) var status: Status = .idle

    // Background session identifier (must be stable across launches)
    private let sessionIdentifier = "MealTracker.ParquetBGSession"

    // Resume data to support pause/cancel resume if needed
    private var resumeData: Data?

    // Completion handler provided by AppDelegate for background session handoff
    private var backgroundSessionCompletionHandler: (() -> Void)?

    // Lazily created session; must be re-created with the same identifier on app relaunch
    private var _session: URLSession?
    private var session: URLSession {
        get {
            if let s = _session { return s }
            let s = makeBackgroundSession()
            _session = s
            return s
        }
        set { _session = newValue }
    }

    // OFF Parquet URL
    let parquetURL = URL(string: "https://huggingface.co/datasets/openfoodfacts/product-database/resolve/main/food.parquet?download=true")!

    // Destination URL in Application Support/OpenFoodFacts/food.parquet
    func destinationURL() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = base.appendingPathComponent("OpenFoodFacts", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let url = dir.appendingPathComponent("food.parquet", isDirectory: false)
        return url
    }

    func fileExists() -> Bool {
        if let url = try? destinationURL() {
            return FileManager.default.fileExists(atPath: url.path)
        }
        return false
    }

    func existingFileSize() -> Int64 {
        guard let url = try? destinationURL() else { return 0 }
        let vals = try? url.resourceValues(forKeys: [.fileSizeKey])
        if let bytes = vals?.fileSize { return Int64(bytes) }
        return 0
    }

    func excludeFromBackup(_ url: URL) {
        var res = URLResourceValues()
        res.isExcludedFromBackup = true
        var mutableURL = url
        try? mutableURL.setResourceValues(res)
    }

    // HEAD request to get expected content length (foreground OK)
    func fetchExpectedSize() async {
        await setStatus(.checkingSize)
        var request = URLRequest(url: parquetURL)
        request.httpMethod = "HEAD"
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse,
               (200..<400).contains(http.statusCode),
               let lenStr = http.allHeaderFields["Content-Length"] as? String,
               let expected = Int64(lenStr) {
                await setStatus(.readyToDownload(expectedBytes: expected))
            } else {
                await setStatus(.readyToDownload(expectedBytes: -1))
            }
        } catch {
            await setStatus(.failed(error: error.localizedDescription))
        }
    }

    // Start or resume the background download
    func startDownload() async {
        do {
            let task: URLSessionDownloadTask
            if let resumeData {
                task = session.downloadTask(withResumeData: resumeData)
            } else {
                var request = URLRequest(url: parquetURL)
                // Ask server for resume support if possible
                request.addValue("bytes=0-", forHTTPHeaderField: "Range")
                task = session.downloadTask(with: request)
            }
            await setStatus(.downloading(progress: 0.0, receivedBytes: 0, expectedBytes: expectedBytesFromStatus()))
            task.resume()
        }
    }

    func cancel() async {
        switch status {
        case .downloading:
            let (_, _, downloadTasks) = await session.tasks
            // Cancel and capture resume data when available
            for t in downloadTasks {
                t.cancel(byProducingResumeData: { data in
                    Task { await self.storeResumeData(data) }
                })
            }
        default:
            break
        }
        await setStatus(.cancelled)
    }

    // Called by AppDelegate when iOS relaunches the app to deliver background events
    func setBackgroundCompletionHandler(_ handler: @escaping () -> Void, for identifier: String) {
        // Only accept if the identifier matches our session
        guard identifier == sessionIdentifier else { return }
        backgroundSessionCompletionHandler = handler
        // Recreate session so delegate callbacks can be delivered
        session = makeBackgroundSession()
    }

    // MARK: - URLSession creation

    private func makeBackgroundSession() -> URLSession {
        let config = URLSessionConfiguration.background(withIdentifier: sessionIdentifier)
        // Enforce Wi‑Fi-only behavior
        config.allowsExpensiveNetworkAccess = false       // no cellular / hotspot
        config.allowsConstrainedNetworkAccess = false     // no Low Data Mode
        // Let the system wait for Wi‑Fi if temporarily unavailable
        config.waitsForConnectivity = true
        // Optional: system may schedule transfer intelligently on power/Wi‑Fi
        config.isDiscretionary = true
        // Longer resource timeout for large files
        config.timeoutIntervalForResource = 60 * 60 * 12  // up to 12 hours
        // Use our actor as the delegate target; delegateQueue nil => internal queue
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    // MARK: - URLSessionDownloadDelegate

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        Task {
            do {
                let dst = try await self.destinationURL()
                if FileManager.default.fileExists(atPath: dst.path) {
                    try FileManager.default.removeItem(at: dst)
                }
                try FileManager.default.moveItem(at: location, to: dst)
                await self.excludeFromBackup(dst)

                let bytes = await self.existingFileSize()
                await self.setStatus(.completed(fileURL: dst, bytes: bytes))
                await self.clearResumeData()
            } catch {
                await self.setStatus(.failed(error: error.localizedDescription))
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error as NSError? else { return }
        if error.domain == NSURLErrorDomain, error.code == NSURLErrorCancelled {
            // Cancel path handled separately
            return
        }
        // Capture resume data if present
        if let data = (error.userInfo[NSURLSessionDownloadTaskResumeData] as? Data) {
            Task { await self.storeResumeData(data) }
        }
        Task {
            await self.setStatus(.failed(error: error.localizedDescription))
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                                didWriteData bytesWritten: Int64,
                                totalBytesWritten: Int64,
                                totalBytesExpectedToWrite: Int64) {
        Task {
            let expected = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : await self.expectedBytesFromStatus()
            let progress = expected > 0 ? Double(totalBytesWritten) / Double(expected) : -1
            await self.setStatus(.downloading(progress: progress, receivedBytes: totalBytesWritten, expectedBytes: expected))
        }
    }

    // Called when all background events have been delivered for our session
    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task {
            let handler = await self.consumeBackgroundCompletionHandler()
            handler?()
        }
    }

    // MARK: - Disk space helper

    func bytesAvailableOnDisk() -> Int64 {
        let fm = FileManager.default
        let url = (try? fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false))
        guard let dir = url else { return 0 }
        if let values = try? dir.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let cap = values.volumeAvailableCapacityForImportantUsage {
            return cap
        }
        if let values = try? dir.resourceValues(forKeys: [.volumeAvailableCapacityKey]),
           let cap = values.volumeAvailableCapacity {
            return Int64(cap)
        }
        return 0
    }

    // MARK: - Private

    private func expectedBytesFromStatus() -> Int64 {
        switch status {
        case .readyToDownload(let expectedBytes):
            return expectedBytes
        case .downloading(_, _, let expectedBytes):
            return expectedBytes
        default:
            return -1
        }
    }

    private func setStatus(_ new: Status) {
        status = new
    }

    private func clearResumeData() {
        resumeData = nil
    }

    private func storeResumeData(_ data: Data?) {
        guard let data else { return }
        resumeData = data
    }

    private func consumeBackgroundCompletionHandler() -> (() -> Void)? {
        let handler = backgroundSessionCompletionHandler
        backgroundSessionCompletionHandler = nil
        return handler
    }
}

