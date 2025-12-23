import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        // Hand the completion handler to the download manager.
        Task {
            await ParquetDownloadManager.shared.setBackgroundCompletionHandler(completionHandler, for: identifier)
        }
    }
}

