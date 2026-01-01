//
//  BarcodeLogStore.swift
//  MealTracker
//
//  Debug-only in-memory ring buffer for verbose barcode logging.
//

import Foundation
import Combine

#if DEBUG
actor BarcodeLogStore {
    static let shared = BarcodeLogStore()

    private var lines: [String] = []
    private let capacity: Int = 1000

    // Use a PassthroughSubject to notify SwiftUI views on changes
    private let subject = PassthroughSubject<[String], Never>()

    // Public publisher (erased)
    nonisolated var publisher: AnyPublisher<[String], Never> {
        subject.eraseToAnyPublisher()
    }

    func append(_ message: String) {
        let ts = Date()
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss.SSS"
        let formatted = "[\(df.string(from: ts))] \(message)"
        lines.append(formatted)
        if lines.count > capacity {
            lines.removeFirst(lines.count - capacity)
        }
        subject.send(lines)
    }

    func snapshot() -> [String] {
        lines
    }

    func clear() {
        lines.removeAll(keepingCapacity: true)
        subject.send(lines)
    }

    func lineCount() -> Int {
        lines.count
    }
}
#endif

