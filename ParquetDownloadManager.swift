import Foundation

actor ParquetDownloadManager: NSObject, URLSessionDownloadDelegate {

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

    // Publicly readable state (poll from UI via Task or use async stream)
    private(set) var status: Status = .idle

    // Resume data to support pause/cancel resume if needed
    private var resumeData: Data?

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        config.timeoutIntervalForResource = 60 * 60 * 4 // up to 4 hours
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

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

    // HEAD request to get expected content length
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
                // Fallback: attempt GET with no download if HEAD fails to provide length
                await setStatus(.readyToDownload(expectedBytes: -1))
            }
        } catch {
            await setStatus(.failed(error: error.localizedDescription))
        }
    }

    // Start download (caller should confirm Wi‑Fi/disk space beforehand)
    func startDownload() async {
        do {
            let task: URLSessionDownloadTask
            if let resumeData {
                task = session.downloadTask(withResumeData: resumeData)
            } else {
                task = session.downloadTask(with: parquetURL)
            }
            await setStatus(.downloading(progress: 0.0, receivedBytes: 0, expectedBytes: expectedBytesFromStatus()))
            task.resume()
        }
    }

    func cancel() async {
        // Try to produce resume data for later resume
        switch status {
        case .downloading:
            let (_, _, downloadTasks) = await session.tasks
            downloadTasks.forEach { $0.cancel(byProducingResumeData: { _ in }) }
        default:
            break
        }
        resumeData = nil
        await setStatus(.cancelled)
    }

    // MARK: - URLSessionDownloadDelegate

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        Task {
            do {
                let dst = try await self.destinationURL()
                // Remove existing if any (replace)
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
        guard let error else { return }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            // Handled by cancel path
            return
        }
        Task {
            await self.setStatus(.failed(error: nsError.localizedDescription))
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        Task {
            let expected = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : await self.expectedBytesFromStatus()
            let progress = expected > 0 ? Double(totalBytesWritten) / Double(expected) : -1
            await self.setStatus(.downloading(progress: progress, receivedBytes: totalBytesWritten, expectedBytes: expected))
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
        // Fallback to older key
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
}
