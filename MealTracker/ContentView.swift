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
        return meals.filter { $0.mealDescription.lowercased().contains(term) }
    }

    var body: some View {
        NavigationView {
            Group {
                if filteredMeals.isEmpty {
                    Text("No meals")
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
            .navigationTitle("Meals")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add Meal", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                NavigationView {
                    MealFormView()
                }
            }
            .searchable(text: $searchText, prompt: Text("Search meals"))
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(filteredMeals[index])
        }
        try? context.save()
    }
}

struct MealRow: View {
    let meal: Meal

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(meal.mealDescription)
                .font(.headline)
                .lineLimit(2)

            HStack(spacing: 12) {
                Label("\(meal.calories)", systemImage: "flame")
                    .labelStyle(.iconOnly)
                Text("\(Int(meal.calories)) kcal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()

                // Expanded nutrient badges including new fields
                HStack(spacing: 8) {
                    NutrientBadge(title: "Carbs", value: meal.carbohydrates)
                    NutrientBadge(title: "Protein", value: meal.protein)
                    NutrientBadge(title: "Fat", value: meal.fat)
                    NutrientBadge(title: "Sodium", value: meal.salt)
                    NutrientBadge(title: "Starch", value: meal.starch)
                    NutrientBadge(title: "Sugars", value: meal.sugars)
                    NutrientBadge(title: "Fibre", value: meal.fibre)
                    // New fat breakdown badges
                    NutrientBadge(title: "Mono", value: meal.monounsaturatedFat)
                    NutrientBadge(title: "Poly", value: meal.polyunsaturatedFat)
                    NutrientBadge(title: "Sat", value: meal.saturatedFat)
                    NutrientBadge(title: "Trans", value: meal.transFat)
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

private extension Double {
    var cleanString: String {
        truncatingRemainder(dividingBy: 1) == 0 ? String(Int(self)) : String(self)
    }
}
