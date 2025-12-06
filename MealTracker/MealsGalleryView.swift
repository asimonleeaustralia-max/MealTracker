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
                                    .padding(.horizontal, 2) // ensure inner gutter so photo never touches cell edge
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 18) // slightly larger outer gutter
                    .padding(.vertical, 12)
                }
                // Respect safe-area gutters for scroll content (iOS 17+)
                .modifier(ScrollHorizontalContentMargins(8))
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

// Helper to add horizontal content margins on iOS 17+, no-op earlier
private struct ScrollHorizontalContentMargins: ViewModifier {
    let inset: CGFloat
    init(_ inset: CGFloat) { self.inset = inset }

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .contentMargins(.horizontal, inset, for: .scrollContent)
        } else {
            content
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

    // Sorted photos: earliest first (to match "first picture as hero image")
    private var sortedPhotos: [MealPhoto] {
        guard let set = meal.value(forKey: "photos") as? Set<MealPhoto>, !set.isEmpty else {
            return []
        }
        return set.sorted { (a, b) in
            let da = a.createdAt ?? .distantPast
            let db = b.createdAt ?? .distantPast
            return da < db
        }
    }

    private var heroPhoto: MealPhoto? { sortedPhotos.first }

    private var thumbnailPhotos: [MealPhoto] {
        guard sortedPhotos.count > 1 else { return [] }
        return Array(sortedPhotos.dropFirst())
    }

    // Load a UIImage for a MealPhoto using upload URL first, then original
    private func loadImage(for photo: MealPhoto) -> UIImage? {
        if let url = PhotoService.urlForUpload(photo),
           let data = try? Data(contentsOf: url),
           let img = UIImage(data: data) {
            return img
        }
        if let url = PhotoService.urlForOriginal(photo),
           let data = try? Data(contentsOf: url),
           let img = UIImage(data: data) {
            return img
        }
        return nil
    }

    // Localization manager for short labels (falls back to keys if not present)
    private var localizationManager: LocalizationManager {
        // Use device default; if you prefer app-scoped language, you can pass it via Environment.
        LocalizationManager(languageCode: LocalizationManager.defaultLanguageCode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Hero with inline thumbnails overlay
            ZStack(alignment: .bottomLeading) {
                // Hero
                if let hero = heroPhoto, let heroImg = loadImage(for: hero) {
                    Image(uiImage: heroImg)
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

                // Thumbnails overlay (up to 3)
                if !thumbnailPhotos.isEmpty {
                    let thumbs = Array(thumbnailPhotos.prefix(3))
                    HStack(spacing: 6) {
                        ForEach(Array(thumbs.enumerated()), id: \.offset) { idx, p in
                            ZStack {
                                if let img = loadImage(for: p) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.15))
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundStyle(.secondary)
                                        )
                                }
                            }
                            .frame(width: 34, height: 34)
                            .clipped()
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.9), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                        }

                        // If there are more thumbnails than shown, show a "+N" badge
                        if thumbnailPhotos.count > thumbs.count {
                            let remaining = thumbnailPhotos.count - thumbs.count
                            Text("+\(remaining)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay(
                                    Capsule().stroke(Color.white.opacity(0.9), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.15))
                            .blur(radius: 8)
                            .opacity(0.001) // visual effect only; main background via material below
                    )
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(8)
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

            // Uniform macro circles
            HStack(spacing: 10) {
                MacroCircle(
                    value: Int(meal.carbohydrates),
                    unit: "g",
                    shortLabel: shortKey("carbs.short"),
                    color: .blue
                )
                MacroCircle(
                    value: Int(meal.protein),
                    unit: "g",
                    shortLabel: shortKey("protein.short"),
                    color: .green
                )
                MacroCircle(
                    value: Int(meal.fat),
                    unit: "g",
                    shortLabel: shortKey("fat.short"),
                    color: .orange
                )
            }
            .padding(.top, 2)

            // Date + Time
            HStack(spacing: 6) {
                Text(meal.date, style: .date)
                Text(meal.date, style: .time)
            }
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

    private func shortKey(_ key: String) -> String {
        // Fallback to a reasonable English short label if key isn’t localized yet
        let localized = localizationManager.localized(key)
        switch key {
        case "carbs.short":
            return localized == key ? "Carb" : localized
        case "protein.short":
            return localized == key ? "Prot" : localized
        case "fat.short":
            return localized == key ? "Fat" : localized
        default:
            return localized
        }
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

// Uniform circular macro indicator
private struct MacroCircle: View {
    let value: Int
    let unit: String
    let shortLabel: String
    let color: Color

    // Visual constants
    private let diameter: CGFloat = 48
    private let lineWidth: CGFloat = 2

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .strokeBorder(color.opacity(0.35), lineWidth: lineWidth)

                Circle()
                    .fill(color.opacity(0.12))

                // Value + unit
                VStack(spacing: 0) {
                    Text("\(value)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    Text(unit)
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .foregroundColor(.primary)
                .padding(6)
            }
            .frame(width: diameter, height: diameter)

            // Short label under the circle
            Text(shortLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: diameter)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(shortLabel) \(value) \(unit)")
    }
}

private extension Double {
    var cleanString: String {
        truncatingRemainder(dividingBy: 1) == 0 ? String(Int(self)) : String(self)
    }
}
