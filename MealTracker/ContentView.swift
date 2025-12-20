//
//  ContentView.swift
//  MealTracker
//
//  Created by Simon Lee on 17/11/2025.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var context

    @FetchRequest(
        fetchRequest: Meal.fetchAllMealsRequest()
    ) private var meals: FetchedResults<Meal>

    @State private var showingAdd = false
    @State private var searchText = ""

    private var filteredMeals: [Meal] {
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !term.isEmpty else { return Array(meals) }
        return meals.filter { $0.title.lowercased().contains(term) }
    }

    var body: some View {
        NavigationView {
            Group {
                if filteredMeals.isEmpty {
                    Text(LocalizedStringKey("no_meals"))
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(filteredMeals) { meal in
                            NavigationLink(destination: MealFormView(meal: meal)) {
                                MealRow(meal: meal)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationBarHidden(false)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label(LocalizedStringKey("add_meal"), systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                NavigationView {
                    MealFormView()
                }
            }
            .searchable(text: $searchText, prompt: Text(LocalizedStringKey("search_meals")))
        }
    }

    private func delete(at offsets: IndexSet) {
        // Capture objects first to keep indices stable
        let itemsToDelete = offsets.map { filteredMeals[$0] }
        itemsToDelete.forEach { context.delete($0) }
        try? context.save()
    }
}

struct MealRow: View {
    let meal: Meal

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(meal.title)
                .font(.headline)
                .lineLimit(2)

            HStack(spacing: 12) {
                Label("\(meal.calories)", systemImage: "flame")
                    .labelStyle(.iconOnly)
                Text("\(Int(meal.calories)) \(NSLocalizedString("kcal_suffix", comment: ""))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()

                // Expanded nutrient badges including new fields
                HStack(spacing: 8) {
                    NutrientBadge(title: NSLocalizedString("carbs.title", comment: ""), value: meal.carbohydrates)
                    NutrientBadge(title: NSLocalizedString("protein.title", comment: ""), value: meal.protein)
                    NutrientBadge(title: NSLocalizedString("fat.title", comment: ""), value: meal.fat)
                    NutrientBadge(title: NSLocalizedString("sodium.title", comment: ""), value: meal.sodium)
                    NutrientBadge(title: NSLocalizedString("starch.title", comment: ""), value: meal.starch)
                    NutrientBadge(title: NSLocalizedString("sugars.title", comment: ""), value: meal.sugars)
                    NutrientBadge(title: NSLocalizedString("fibre.title", comment: ""), value: meal.fibre)
                    // New fat breakdown badges
                    NutrientBadge(title: NSLocalizedString("fat.mono.short", comment: ""), value: meal.monounsaturatedFat)
                    NutrientBadge(title: NSLocalizedString("fat.poly.short", comment: ""), value: meal.polyunsaturatedFat)
                    NutrientBadge(title: NSLocalizedString("fat.sat.short", comment: ""), value: meal.saturatedFat)
                    NutrientBadge(title: NSLocalizedString("fat.trans.short", comment: ""), value: meal.transFat)
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            Text(meal.date, style: .date)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct NutrientBadge: View {
    let title: String
    let value: Double

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            Text(value.cleanString)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.15))
        .clipShape(Capsule())
    }
}
