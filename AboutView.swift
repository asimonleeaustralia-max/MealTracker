import SwiftUI

struct AboutView: View {
    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        ?? "App"
    }

    private var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "Version \(version) (\(build))"
    }

    private var copyrightString: String? {
        Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // App icon from asset catalog (fallback to system symbol)
                AppIconView()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                Text(appName)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(versionString)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let copyright = copyrightString, !copyright.isEmpty {
                    Text(copyright)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }

                // Divider between header and content
                Divider().padding(.vertical, 6)

                // Medical disclaimer (App Store–friendly)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Medical Disclaimer")
                        .font(.headline)

                    Text("""
This app is for informational and educational purposes only and is not a substitute for professional medical advice, diagnosis, or treatment. Always seek the advice of a qualified health provider with any questions you may have regarding a medical condition. Never disregard professional medical advice or delay seeking it because of something you have read in this app. If you think you may have a medical emergency, call your local emergency number immediately.
""")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Optional links (uncomment and set URLs as needed)
                /*
                VStack(alignment: .leading, spacing: 8) {
                    Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                    Link("Terms of Use", destination: URL(string: "https://example.com/terms")!)
                    Link("Support", destination: URL(string: "mailto:support@example.com")!)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
                */

                Spacer(minLength: 12)
            }
            .padding()
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }
}

private struct AppIconView: View {
    var body: some View {
        // Attempt to load the primary app icon from the asset catalog by name.
        // If not available, show a placeholder system image.
        if let iconName = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
           let primary = iconName["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let last = files.last,
           let image = UIImage(named: last) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.secondary.opacity(0.15))
                Image(systemName: "fork.knife.circle")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
