//
//  MealsGalleryView.swift
//  MealTracker
//
//  Created by Simon Lee on 25/11/2025.
//

import SwiftUI
import CoreData
import UIKit

struct MealsGalleryView: View {
    @Environment(\.managedObjectContext) private var context

    @FetchRequest(
        fetchRequest: Meal.fetchAllMealsRequest()
    ) private var meals: FetchedResults<Meal>

    // Simple grid layout
    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    @State private var showingAdd = false

    var body: some View {
        Group {
            if meals.isEmpty {
                EmptyStateView(onAdd: { showingAdd = true })
                    .padding()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(meals) { meal in
                            NavigationLink(destination: MealFormView(meal: meal)) {
                                MealTile(meal: meal)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showingAdd) {
            NavigationView {
                MealFormView()
            }
        }
    }
}

private struct EmptyStateView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(.secondary)

            Text("No meals yet")
                .font(.title3)
                .bold()

            Text("Add a meal to start your gallery. You can attach photos and record calories and nutrients.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button {
                onAdd()
            } label: {
                Label("Add Meal", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .accessibilityIdentifier("galleryAddMealButton")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct MealTile: View {
    @Environment(\.managedObjectContext) private var context
    let meal: Meal

    // Load first associated MealPhoto URL (upload preferred, else original) via inverse relationship
    private func firstPhotoURL() -> URL? {
        // Access the to-many inverse relationship without relying on generated property
        guard let set = meal.value(forKey: "photos") as? Set<MealPhoto>, !set.isEmpty else {
            return nil
        }
        // Sort by createdAt ascending; handle nils safely
        let sorted = set.sorted { (a, b) in
            let da = a.createdAt ?? .distantFuture
            let db = b.createdAt ?? .distantFuture
            return da < db
        }
        if let first = sorted.first {
            return PhotoService.urlForUpload(first) ?? PhotoService.urlForOriginal(first)
        }
        return nil
    }

    private func thumbnailImage() -> UIImage? {
        if let url = firstPhotoURL(), let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        return nil
    }

    // Convert stored sodium mg to a readable string in g with 1 decimal, if large enough
    private var sodiumDisplay: String {
        let mg = max(0, meal.sodium)
        if mg >= 1000 {
            let grams = mg / 1000.0
            let formatted = String(format: "%.1f", grams)
            return "\(formatted) g Na"
        } else {
            let val = Int(mg)
            return "\(val) mg Na"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let ui = thumbnailImage() {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 140)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 140)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        )
                }
            }

            Text(meal.mealDescription.isEmpty ? "Untitled Meal" : meal.mealDescription)
                .font(.headline)
                .lineLimit(2)

            // Compact metrics row
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    MetricChip(system: "flame", text: "\(Int(meal.calories)) kcal")
                    MetricChip(system: "leaf", text: "C \(meal.carbohydrates.cleanString)g")
                    MetricChip(system: "bolt", text: "P \(meal.protein.cleanString)g")
                }
                HStack(spacing: 10) {
                    MetricChip(system: "drop", text: "F \(meal.fat.cleanString)g")
                    MetricChip(system: "cloud.drizzle", text: sodiumDisplay)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Text(meal.date, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
        .accessibilityElement(children: .combine)
    }
}

private struct MetricChip: View {
    let system: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: system)
            Text(text)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.15))
        .clipShape(Capsule())
    }
}

private extension Double {
    var cleanString: String {
        truncatingRemainder(dividingBy: 1) == 0 ? String(Int(self)) : String(self)
    }
}

#Preview {
    let controller = PersistenceController(inMemory: true)
    let context = controller.container.viewContext

    return NavigationView {
        MealsGalleryView()
            .environment(\.managedObjectContext, context)
    }
}
