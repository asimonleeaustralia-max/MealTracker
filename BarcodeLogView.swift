//
//  BarcodeLogView.swift
//  MealTracker
//
//  Debug-only viewer for the barcode verbose log.
//

import SwiftUI
import Combine

#if DEBUG
struct BarcodeLogView: View {
    @State private var lines: [String] = []
    @State private var cancellable: AnyCancellable?

    // Fallback share sheet state for iOS < 16
    @State private var showingShareSheet = false

    var body: some View {
        VStack(spacing: 0) {
            if lines.isEmpty {
                Text("No log entries yet.")
                    .foregroundStyle(.secondary)
                    .padding()
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                                Text(line)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .id(idx)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: lines.count) { _ in
                        // Auto-scroll to bottom on new entries
                        if let lastID = (lines.indices).last {
                            withAnimation { proxy.scrollTo(lastID, anchor: .bottom) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Barcode Log")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    UIPasteboard.general.string = lines.joined(separator: "\n")
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .accessibilityLabel("Copy")

                // iOS 16+ uses ShareLink; earlier versions fall back to UIActivityViewController
                if #available(iOS 16.0, *) {
                    ShareLink(items: [lines.joined(separator: "\n")]) {
                        Image(systemName: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        showingShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }

                Button(role: .destructive) {
                    Task { await BarcodeLogStore.shared.clear() }
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Clear")
            }
        }
        .onAppear {
            // Seed with current snapshot
            Task {
                let current = await BarcodeLogStore.shared.snapshot()
                await MainActor.run { self.lines = current }
            }
            // Subscribe to live updates
            self.cancellable = BarcodeLogStore.shared.publisher
                .receive(on: DispatchQueue.main)
                .sink { newLines in
                    self.lines = newLines
                }
        }
        .onDisappear {
            cancellable?.cancel()
            cancellable = nil
        }
        // Fallback share sheet for iOS < 16
        .sheet(isPresented: $showingShareSheet) {
            ActivityView(activityItems: [lines.joined(separator: "\n")])
        }
    }
}

// Simple UIActivityViewController wrapper for SwiftUI
private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
