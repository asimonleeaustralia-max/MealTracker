//
//  TheCocktailDBClient.swift
//  MealTracker
//
//  Minimal client to fetch drinks from TheCocktailDB and map into MealsRepository.MealRow.
//

import Foundation

enum TheCocktailDBClient {

    static func fetchAllDrinks(logger: ((String) -> Void)? = nil, maxItems: Int? = nil) async throws -> [MealsRepository.MealRow] {
        var rows: [MealsRepository.MealRow] = []

        // Strategy similar to meals:
        // 1) List categories
        // 2) List drinks per category
        // 3) Fetch details per id and map

        let categories = try await listCategories()
        logger?("TheCocktailDB: found \(categories.count) categories")

        var seenIDs = Set<String>()
        var budget = maxItems ?? Int.max

        for cat in categories {
            if budget <= 0 { break }
            let summaries = try await listDrinks(inCategory: cat)
            logger?("TheCocktailDB: \(cat) -> \(summaries.count) drinks")
            for s in summaries {
                if budget <= 0 { break }
                guard !seenIDs.contains(s.idDrink) else { continue }
                seenIDs.insert(s.idDrink)
                do {
                    if let detail = try await lookupDrinkDetail(id: s.idDrink) {
                        if let row = map(detail: detail) {
                            rows.append(row)
                            budget -= 1
                        }
                    }
                } catch {
                    logger?("TheCocktailDB: failed detail for id \(s.idDrink): \(error.localizedDescription)")
                }
            }
        }

        return rows
    }

    // MARK: - Models

    private struct CategoriesResponse: Decodable {
        let drinks: [Category]
    }

    private struct Category: Decodable {
        let strCategory: String
    }

    private struct ListResponse: Decodable {
        let drinks: [DrinkSummary]?
    }

    private struct DrinkSummary: Decodable {
        let idDrink: String
        let strDrink: String
    }

    private struct DetailResponse: Decodable {
        let drinks: [DrinkDetail]?
    }

    // Only decode fields we need
    private struct DrinkDetail: Decodable {
        let idDrink: String
        let strDrink: String?
        let strCategory: String?
        let strAlcoholic: String?
        let strInstructions: String?
    }

    // MARK: - Networking

    private static func listCategories() async throws -> [String] {
        let url = URL(string: "https://www.thecocktaildb.com/api/json/v1/1/list.php?c=list")!
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(CategoriesResponse.self, from: data)
        return decoded.drinks.map { $0.strCategory }
    }

    private static func listDrinks(inCategory category: String) async throws -> [DrinkSummary] {
        guard let enc = category.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.thecocktaildb.com/api/json/v1/1/filter.php?c=\(enc)") else {
            return []
        }
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(ListResponse.self, from: data)
        return decoded.drinks ?? []
    }

    private static func lookupDrinkDetail(id: String) async throws -> DrinkDetail? {
        guard let url = URL(string: "https://www.thecocktaildb.com/api/json/v1/1/lookup.php?i=\(id)") else {
            return nil
        }
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(DetailResponse.self, from: data)
        return decoded.drinks?.first
    }

    // MARK: - Mapping

    private static func map(detail: DrinkDetail) -> MealsRepository.MealRow? {
        let id64: Int64 = Int64(detail.idDrink) ?? Int64(abs(detail.idDrink.hashValue))
        let title = detail.strDrink ?? "Drink"

        let descParts = [
            detail.strCategory,
            detail.strAlcoholic,
            detail.strInstructions
        ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let description = descParts.isEmpty ? nil : descParts.joined(separator: " • ")

        // Portion grams unknown; for drinks, 240g (~240 ml) is a common single-serving proxy
        // We keep it simple and neutral; you can refine later.
        let portionGrams = 240.0

        // Without reliable ABV and volume per recipe, keep alcohol nil to satisfy your “no fabricated values” rule.
        return MealsRepository.MealRow(
            id: id64,
            title: title,
            description: description,
            portionGrams: portionGrams,
            calories: nil,
            carbohydrates: nil,
            protein: nil,
            sodium: nil,
            fat: nil,
            latitude: nil,
            longitude: nil,
            alcohol: nil,
            nicotine: nil,
            theobromine: nil,
            caffeine: nil,
            taurine: nil,
            starch: nil,
            sugars: nil,
            fibre: nil,
            monounsaturatedFat: nil,
            polyunsaturatedFat: nil,
            saturatedFat: nil,
            transFat: nil,
            omega3: nil,
            omega6: nil,
            animalProtein: nil,
            plantProtein: nil,
            proteinSupplements: nil,
            vitaminA: nil,
            vitaminB: nil,
            vitaminC: nil,
            vitaminD: nil,
            vitaminE: nil,
            vitaminK: nil,
            calcium: nil,
            iron: nil,
            potassium: nil,
            zinc: nil,
            magnesium: nil
        )
    }
}

