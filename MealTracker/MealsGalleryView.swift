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
                        // Use objectID for identity to avoid reading the `id` attribute
                        ForEach(meals, id: \.objectID) { meal in
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

// MARK: - Minimal supporting views to fix missing symbols

private struct EmptyStateView: View {
    var onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(.secondary)

            Text("No meals yet")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Add your first meal to start tracking.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                onAdd()
            } label: {
                Label("Add Meal", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.08))
        )
    }
}

private struct MealTile: View {
    let meal: Meal

    // Pick the most recent MealPhoto by createdAt
    private var latestPhoto: MealPhoto? {
        guard let set = meal.value(forKey: "photos") as? Set<MealPhoto>, !set.isEmpty else {
            return nil
        }
        return set.max(by: { (a, b) in
            let da = a.createdAt ?? .distantPast
            let db = b.createdAt ?? .distantPast
            return da < db
        })
    }

    private var thumbnailImage: UIImage? {
        guard let photo = latestPhoto else { return nil }
        if let url = PhotoService.urlForUpload(photo),
           let data = try? Data(contentsOf: url),
           let img = UIImage(data: data) {
            return img
        }
        // Fallback to original if upload missing
        if let url = PhotoService.urlForOriginal(photo),
           let data = try? Data(contentsOf: url),
           let img = UIImage(data: data) {
            return img
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail image (top)
            ZStack {
                if let ui = thumbnailImage {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 140)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.10))
                        .frame(height: 140)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 28, weight: .regular))
                                .foregroundStyle(.secondary)
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Title
            Text(meal.title)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // Quick stats row
            HStack(spacing: 8) {
                Label("\(Int(meal.calories))", systemImage: "flame")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)

                Text("\(Int(meal.calories)) kcal")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)
            }

            // A few nutrient badges for compactness
            HStack(spacing: 6) {
                badge("Carbs", meal.carbohydrates)
                badge("Protein", meal.protein)
                badge("Fat", meal.fat)
            }

            // Date
            Text(meal.date, style: .date)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func badge(_ title: String, _ value: Double) -> some View {
        HStack(spacing: 4) {
            Text(title)
            Text(value.cleanString)
        }
        .font(.caption)
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
