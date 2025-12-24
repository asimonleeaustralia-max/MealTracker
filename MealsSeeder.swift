//
//  MealsSeeder.swift
//  MealTracker
//
//  Seeds the bundled Meals.duckdb with real-world meals and drinks
//  from TheMealDB and TheCocktailDB. No fabricated nutrition values.
//  Alcohol grams are computed only when ABV and volume are reliably known.
//  All other nutrient fields remain nil unless sources provide values.
//

import Foundation

// MARK: - Public entry point

enum MealsSeeder {

    // Configure how many items to fetch (nil = all available).
    // Returns the number of upserts performed.
    static func seedMealsDB(maxItems: Int? = nil, log: ((String) -> Void)? = nil) async throws -> Int {
        var totalUpserts = 0
        let logger: (String) -> Void = { msg in
            #if DEBUG
            print("[MealsSeeder] \(msg)")
            #endif
            log?(msg)
        }

        // 1) Fetch and insert meals
        logger("Fetching meals from TheMealDB…")
        let meals = try await TheMealDBClient.fetchAllMeals(logger: logger, maxItems: maxItems)
        logger("Fetched \(meals.count) meals; upserting…")
        for m in meals {
            do {
                try await MealsRepository.shared.upsert(m)
                totalUpserts += 1
            } catch {
                logger("Upsert meal id=\(m.id) failed: \(error.localizedDescription)")
            }
        }
        logger("Upserted \(meals.count) meals.")

        // 2) Fetch and insert drinks
        logger("Fetching drinks from TheCocktailDB…")
        let drinks = try await TheCocktailDBClient.fetchAllDrinks(logger: logger, maxItems: maxItems)
        logger("Fetched \(drinks.count) drinks; upserting…")
        for d in drinks {
            do {
                try await MealsRepository.shared.upsert(d)
                totalUpserts += 1
            } catch {
                logger("Upsert drink id=\(d.id) failed: \(error.localizedDescription)")
            }
        }
        logger("Upserted \(drinks.count) drinks.")

        logger("Seeding complete. Total upserts: \(totalUpserts)")
        return totalUpserts
    }

    // New: Progress-enabled variant used by MealsSeedingManager.
    // Calls progress(downloaded, total, phase) repeatedly.
    static func seedMealsDBWithProgress(maxItems: Int? = nil,
                                        progress: @escaping (Int, Int, String) -> Void) async throws -> Int {
        var totalUpserts = 0

        // 1) Discover all meal IDs first to determine totals
        let meals = try await TheMealDBClient.fetchAllMeals(logger: { _ in }, maxItems: maxItems)
        progress(0, meals.count, "Downloading meals…")

        for (i, m) in meals.enumerated() {
            do {
                try await MealsRepository.shared.upsert(m)
                totalUpserts += 1
            } catch {
                // ignore individual failures
            }
            progress(min(i + 1, meals.count), meals.count, "Downloading meals…")
        }

        // 2) Discover all drink IDs
        let drinks = try await TheCocktailDBClient.fetchAllDrinks(logger: { _ in }, maxItems: maxItems)
        let base = totalUpserts
        let total = meals.count + drinks.count
        progress(base, total, "Downloading drinks…")

        for (i, d) in drinks.enumerated() {
            do {
                try await MealsRepository.shared.upsert(d)
                totalUpserts += 1
            } catch {
                // ignore
            }
            progress(base + min(i + 1, drinks.count), total, "Downloading drinks…")
        }

        return totalUpserts
    }
}

// ... TheMealDBClient and TheCocktailDBClient remain unchanged below ...
// (Keep the rest of the file exactly as you already have it.)
