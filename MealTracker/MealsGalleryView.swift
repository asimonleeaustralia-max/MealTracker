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

    var body: some View {
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
        .navigationTitle("Meal Gallery")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }
}

private struct MealTile: View {
    @Environment(\.managedObjectContext) private var context
    let meal: Meal

    // Load first associated MealPhoto URL (upload preferred, else original)
    private func firstPhotoURL() -> URL? {
        // Fetch photos for this meal ordered by createdAt
        let request = NSFetchRequest<MealPhoto>(entityName: "MealPhoto")
        request.predicate = NSPredicate(format: "meal == %@", meal)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        if let photos = try? context.fetch(request), let first = photos.first {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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

            HStack {
                Text("\(Int(meal.calories)) kcal")
                Spacer()
                Text(meal.date, style: .date)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
        .accessibilityElement(children: .combine)
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

