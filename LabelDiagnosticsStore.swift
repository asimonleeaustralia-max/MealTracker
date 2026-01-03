//
//  LabelDiagnosticsStore.swift
//  MealTracker
//
//  DEBUG-only structured diagnostics store for label recognition.
//

import Foundation
import Combine

#if DEBUG
actor LabelDiagnosticsStore {
    static let shared = LabelDiagnosticsStore()

    private var events: [LabelDiagnosticsEvent] = []
    private let capacity: Int = 1000

    private let eventsSubject = PassthroughSubject<[LabelDiagnosticsEvent], Never>()

    nonisolated var eventsPublisher: AnyPublisher<[LabelDiagnosticsEvent], Never> { eventsSubject.eraseToAnyPublisher() }

    func appendEvent(_ event: LabelDiagnosticsEvent) {
        events.append(event)
        if events.count > capacity {
            events.removeFirst(events.count - capacity)
        }
        eventsSubject.send(events)
    }

    func snapshotEvents() -> [LabelDiagnosticsEvent] {
        events
    }

    func clear() {
        events.removeAll(keepingCapacity: true)
        eventsSubject.send(events)
    }

    func lineCount() -> Int {
        events.count
    }
}
#endif
