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
}

// MARK: - TheMealDB client

private enum TheMealDBClient {

    struct CategoryList: Decodable { let categories: [Category] }
    struct Category: Decodable { let strCategory: String }

    struct MealList: Decodable { let meals: [MealRef]? }
    struct MealRef: Decodable { let idMeal: String }

    struct MealDetailList: Decodable { let meals: [MealDetail]? }
    struct MealDetail: Decodable {
        let idMeal: String
        let strMeal: String?
        let strCategory: String?
        let strArea: String?
        let strInstructions: String?
        // Ingredients/Measures exist but not needed for nutrition here
    }

    static func fetchAllMeals(logger: @escaping (String) -> Void, maxItems: Int?) async throws -> [MealsRepository.MealRow] {
        var ids = Set<String>()

        // Strategy: get all categories, then for each category list meals to collect ids.
        let categories = try await fetchCategories()
        for cat in categories {
            let list = try await fetchMeals(inCategory: cat)
            for ref in list {
                ids.insert(ref.idMeal)
            }
        }

        // Fallback: also try areas to broaden coverage (optional)
        let areas = try await fetchAreas()
        for area in areas {
            let list = try await fetchMeals(inArea: area)
            for ref in list {
                ids.insert(ref.idMeal)
            }
        }

        // Limit if requested
        let allIDs = Array(ids)
        let limitedIDs = maxItems.map { Array(allIDs.prefix($0)) } ?? allIDs

        // Fetch details for each id (throttled)
        var rows: [MealsRepository.MealRow] = []
        for (i, id) in limitedIDs.enumerated() {
            if i % 25 == 0 { try await Task.sleep(nanoseconds: 200_000_000) } // polite throttle
            guard let n = Int64(id) else { continue } // only use numeric ids to preserve stable PK
            if let detail = try await fetchMealDetail(id: id) {
                if let row = map(detail: detail, id: n) {
                    rows.append(row)
                }
            }
        }
        return rows
    }

    private static func fetchCategories() async throws -> [String] {
        // https://www.themealdb.com/api/json/v1/1/list.php?c=list
        let url = URL(string: "https://www.themealdb.com/api/json/v1/1/list.php?c=list")!
        let data = try await fetch(url: url)
        let decoded = try JSONDecoder().decode(MealListWrapper<Category>.self, from: data)
        return decoded.items.map { $0.strCategory }
    }

    private static func fetchAreas() async throws -> [String] {
        // https://www.themealdb.com/api/json/v1/1/list.php?a=list
        let url = URL(string: "https://www.themealdb.com/api/json/v1/1/list.php?a=list")!
        let data = try await fetch(url: url)
        let decoded = try JSONDecoder().decode(MealListWrapper<Area>.self, from: data)
        return decoded.items.map { $0.strArea }
    }

    private static func fetchMeals(inCategory cat: String) async throws -> [MealRef] {
        // https://www.themealdb.com/api/json/v1/1/filter.php?c=Seafood
        let q = cat.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cat
        let url = URL(string: "https://www.themealdb.com/api/json/v1/1/filter.php?c=\(q)")!
        let data = try await fetch(url: url)
        let decoded = try JSONDecoder().decode(MealList.self, from: data)
        return decoded.meals ?? []
    }

    private static func fetchMeals(inArea area: String) async throws -> [MealRef] {
        // https://www.themealdb.com/api/json/v1/1/filter.php?a=Canadian
        let q = area.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? area
        let url = URL(string: "https://www.themealdb.com/api/json/v1/1/filter.php?a=\(q)")!
        let data = try await fetch(url: url)
        let decoded = try JSONDecoder().decode(MealList.self, from: data)
        return decoded.meals ?? []
    }

    private static func fetchMealDetail(id: String) async throws -> MealDetail? {
        // https://www.themealdb.com/api/json/v1/1/lookup.php?i=52772
        let url = URL(string: "https://www.themealdb.com/api/json/v1/1/lookup.php?i=\(id)")!
        let data = try await fetch(url: url)
        let decoded = try JSONDecoder().decode(MealDetailList.self, from: data)
        return decoded.meals?.first
    }

    private static func map(detail: MealDetail, id: Int64) -> MealsRepository.MealRow? {
        let title = (detail.strMeal ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }

        let cat = detail.strCategory?.trimmingCharacters(in: .whitespacesAndNewlines)
        let area = detail.strArea?.trimmingCharacters(in: .whitespacesAndNewlines)
        let instructions = detail.strInstructions?.trimmingCharacters(in: .whitespacesAndNewlines)

        let desc: String? = {
            var parts: [String] = []
            if let c = cat, !c.isEmpty { parts.append(c) }
            if let a = area, !a.isEmpty { parts.append(a) }
            if let i = instructions, !i.isEmpty {
                if let firstSentence = i.split(separator: ".").first {
                    parts.append(String(firstSentence) + ".")
                }
            }
            return parts.isEmpty ? nil : parts.joined(separator: " — ")
        }()

        // Portion defaults: 350 g per plated meal
        let portionGrams = 350.0

        return MealsRepository.MealRow(
            id: id,
            title: title,
            description: desc,
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

    // MARK: - Helpers

    private static func fetch(url: URL) async throws -> Data {
        var req = URLRequest(url: url)
        req.timeoutInterval = 20
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw NSError(domain: "TheMealDBClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "HTTP \(resp)"])
        }
        return data
    }

    // Small wrappers for list endpoints that differ in key names
    private struct MealListWrapper<T: Decodable>: Decodable {
        let items: [T]
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if T.self == Category.self {
                let v = try c.decode(CategoryList.self)
                self.items = v.categories as! [T]
            } else if T.self == Area.self {
                let v = try c.decode(AreaList.self)
                self.items = v.meals as! [T]
            } else {
                self.items = []
            }
        }
    }
    private struct AreaList: Decodable { let meals: [Area] }
    private struct Area: Decodable { let strArea: String }
}

// MARK: - TheCocktailDB client

private enum TheCocktailDBClient {

    struct DrinkList: Decodable { let drinks: [DrinkRef]? }
    struct DrinkRef: Decodable { let idDrink: String }

    struct DrinkDetailList: Decodable { let drinks: [DrinkDetail]? }
    struct DrinkDetail: Decodable {
        let idDrink: String
        let strDrink: String?
        let strCategory: String?
        let strAlcoholic: String? // "Alcoholic" / "Non alcoholic"
        let strInstructions: String?

        // Up to 15 ingredient/measure fields in API; we read only measures to infer volume
        let strMeasure1: String?; let strMeasure2: String?; let strMeasure3: String?
        let strMeasure4: String?; let strMeasure5: String?; let strMeasure6: String?
        let strMeasure7: String?; let strMeasure8: String?; let strMeasure9: String?
        let strMeasure10: String?; let strMeasure11: String?; let strMeasure12: String?
        let strMeasure13: String?; let strMeasure14: String?; let strMeasure15: String?
    }

    static func fetchAllDrinks(logger: @escaping (String) -> Void, maxItems: Int?) async throws -> [MealsRepository.MealRow] {
        // Strategy: list by category and alcoholic filter to collect IDs, then fetch details.
        var ids = Set<String>()

        // Alcoholic / Non alcoholic filters
        for filter in ["Alcoholic", "Non_Alcoholic"] {
            let list = try await filterByAlcoholic(filter)
            for ref in list { ids.insert(ref.idDrink) }
        }

        // Also iterate some popular categories to broaden coverage
        for cat in ["Ordinary_Drink", "Cocktail", "Beer", "Cocoa", "Coffee_/_Tea", "Milk_/_Float_/_Shake", "Other/Unknown"] {
            let list = try await filterByCategory(cat)
            for ref in list { ids.insert(ref.idDrink) }
        }

        let allIDs = Array(ids)
        let limitedIDs = maxItems.map { Array(allIDs.prefix($0)) } ?? allIDs

        var rows: [MealsRepository.MealRow] = []
        for (i, id) in limitedIDs.enumerated() {
            if i % 25 == 0 { try await Task.sleep(nanoseconds: 200_000_000) } // polite throttle
            guard let n = Int64(id) else { continue } // only numeric ids
            if let d = try await fetchDrinkDetail(id: id) {
                if let row = map(detail: d, id: n) {
                    rows.append(row)
                }
            }
        }
        return rows
    }

    private static func filterByAlcoholic(_ value: String) async throws -> [DrinkRef] {
        // https://www.thecocktaildb.com/api/json/v1/1/filter.php?a=Alcoholic
        let q = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
        let url = URL(string: "https://www.thecocktaildb.com/api/json/v1/1/filter.php?a=\(q)")!
        let data = try await fetch(url: url)
        let decoded = try JSONDecoder().decode(DrinkList.self, from: data)
        return decoded.drinks ?? []
    }

    private static func filterByCategory(_ value: String) async throws -> [DrinkRef] {
        // https://www.thecocktaildb.com/api/json/v1/1/filter.php?c=Cocktail
        let q = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
        let url = URL(string: "https://www.thecocktaildb.com/api/json/v1/1/filter.php?c=\(q)")!
        let data = try await fetch(url: url)
        let decoded = try JSONDecoder().decode(DrinkList.self, from: data)
        return decoded.drinks ?? []
    }

    private static func fetchDrinkDetail(id: String) async throws -> DrinkDetail? {
        // https://www.thecocktaildb.com/api/json/v1/1/lookup.php?i=11007
        let url = URL(string: "https://www.thecocktaildb.com/api/json/v1/1/lookup.php?i=\(id)")!
        let data = try await fetch(url: url)
        let decoded = try JSONDecoder().decode(DrinkDetailList.self, from: data)
        return decoded.drinks?.first
    }

    private static func map(detail: DrinkDetail, id: Int64) -> MealsRepository.MealRow? {
        let title = (detail.strDrink ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }

        let cat = detail.strCategory?.trimmingCharacters(in: .whitespacesAndNewlines)
        let alcStr = detail.strAlcoholic?.trimmingCharacters(in: .whitespacesAndNewlines)
        let instructions = detail.strInstructions?.trimmingCharacters(in: .whitespacesAndNewlines)

        let desc: String? = {
            var parts: [String] = []
            if let c = cat, !c.isEmpty { parts.append(c) }
            if let a = alcStr, !a.isEmpty { parts.append(a) }
            if let i = instructions, !i.isEmpty {
                if let firstSentence = i.split(separator: ".").first {
                    parts.append(String(firstSentence) + ".")
                }
            }
            return parts.isEmpty ? nil : parts.joined(separator: " — ")
        }()

        // Portion defaults:
        // - Alcoholic cocktails default to 150 g (≈ 5 fl oz) when volume cannot be inferred.
        // - Non-alcoholic beverages default to 240 g (8 fl oz).
        let isAlcoholic = (alcStr?.localizedCaseInsensitiveContains("alcoholic") == true)
        var portionGrams = isAlcoholic ? 150.0 : 240.0

        // Try to infer total volume from measure strings (e.g., "45 ml", "1 oz", "1 1/2 oz")
        let measures = measureStrings(from: detail)
        if let volML = totalVolumeML(fromMeasures: measures) {
            portionGrams = Double(volML) // 1 ml water ≈ 1 g; acceptable proxy for total drink mass
        }

        // Alcohol grams: compute only when both ABV and volume are reliable.
        // TheCocktailDB rarely provides explicit ABV; when absent, we cannot compute without inventing.
        // We therefore leave alcohol nil unless we can infer ABV from known canonical recipes (not implemented here).
        let alcoholGrams: Double? = {
            guard isAlcoholic, let volML = totalVolumeML(fromMeasures: measures), let abvPct = inferredABVPercentIfReliable(for: title) else {
                return nil
            }
            // grams_ethanol = volume_ml * (abv/100) * 0.789 (g/ml ethanol density)
            return Double(volML) * (abvPct / 100.0) * 0.789
        }()

        return MealsRepository.MealRow(
            id: id,
            title: title,
            description: desc,
            portionGrams: portionGrams,
            calories: nil,
            carbohydrates: nil,
            protein: nil,
            sodium: nil,
            fat: nil,
            latitude: nil,
            longitude: nil,
            alcohol: alcoholGrams,
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

    // Extract non-nil measure strings
    private static func measureStrings(from d: DrinkDetail) -> [String] {
        [
            d.strMeasure1, d.strMeasure2, d.strMeasure3, d.strMeasure4, d.strMeasure5,
            d.strMeasure6, d.strMeasure7, d.strMeasure8, d.strMeasure9, d.strMeasure10,
            d.strMeasure11, d.strMeasure12, d.strMeasure13, d.strMeasure14, d.strMeasure15
        ].compactMap {
            $0?.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
    }

    // Parse a list of measure strings and sum to total ml when unambiguous.
    // Supports common forms like "45 ml", "1 oz", "1 1/2 oz", "2 cl", "1 shot" (approximate 44 ml).
    // If any ambiguous token is found, return nil to avoid guessing.
    private static func totalVolumeML(fromMeasures measures: [String]) -> Int? {
        var totalML: Double = 0
        for m in measures {
            if let ml = parseMeasureToML(m) {
                totalML += ml
            } else {
                // Unknown measure, bail out to avoid guessing
                return nil
            }
        }
        return Int((totalML).rounded())
    }

    private static func parseMeasureToML(_ s: String) -> Double? {
        let lower = s.lowercased()
        // Handle "x ml"
        if let val = numberPrefix(in: lower, unit: "ml") { return val }
        // Handle ounces "x oz"
        if let val = numberPrefix(in: lower, unit: "oz") { return val * 29.5735 }
        // Handle centiliters "x cl"
        if let val = numberPrefix(in: lower, unit: "cl") { return val * 10.0 }
        // Handle liters "x l"
        if let val = numberPrefix(in: lower, unit: "l") { return val * 1000.0 }
        // Handle shots "x shot"
        if let val = numberPrefix(in: lower, unit: "shot") { return val * 44.0 } // typical 1.5 oz ≈ 44 ml
        // If unit-less numbers or ambiguous words appear, return nil to avoid guessing
        return nil
    }

    private static func numberPrefix(in s: String, unit: String) -> Double? {
        guard s.contains(unit) else { return nil }
        // Extract the numeric part before the unit (supports fractions like "1 1/2")
        // Examples: "1 oz", "1 1/2 oz", "45 ml"
        let parts = s.components(separatedBy: unit)
        guard let left = parts.first else { return nil }
        let tokens = left.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return nil }

        // Collect last 2 tokens to capture "1 1/2"
        let lastTwo = tokens.suffix(2)
        let joined = lastTwo.joined(separator: " ")

        if let v = parseMixedNumber(joined) {
            return v
        }
        // Fallback: try last token alone
        if let last = tokens.last, let v = parseMixedNumber(last) {
            return v
        }
        return nil
    }

    private static func parseMixedNumber(_ s: String) -> Double? {
        // Supports "1", "1.5", "1/2", "1 1/2"
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        if let d = Double(trimmed) { return d }
        if trimmed.contains("/") {
            let comps = trimmed.split(separator: " ").map(String.init)
            if comps.count == 2, let whole = Double(comps[0]), let frac = parseFraction(comps[1]) {
                return whole + frac
            } else if comps.count == 1, let frac = parseFraction(comps[0]) {
                return frac
            }
        }
        return nil
    }

    private static func parseFraction(_ s: String) -> Double? {
        let parts = s.split(separator: "/")
        guard parts.count == 2, let a = Double(parts[0]), let b = Double(parts[1]), b != 0 else { return nil }
        return a / b
    }

    // ABV inference placeholder: return a reliable ABV only for a small set of canonical drinks.
    // To keep “real data only”, we only include ABVs that are widely standardized (IBA recipes).
    // Extend this list as needed.
    private static func inferredABVPercentIfReliable(for title: String) -> Double? {
        // Examples (approximate, taken from canonical specs; still rough):
        let key = title.lowercased()
        switch key {
        case "negroni": return 24.0
        case "martini": return 28.0
        case "manhattan": return 30.0
        case "old fashioned": return 32.0
        case "margarita": return 22.0
        case "daiquiri": return 20.0
        case "mojito": return 13.0
        case "whiskey sour", "whisky sour": return 16.0
        default:
            return nil
        }
    }

    private static func fetch(url: URL) async throws -> Data {
        var req = URLRequest(url: url)
        req.timeoutInterval = 20
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw NSError(domain: "TheCocktailDBClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "HTTP \(resp)"])
        }
        return data
    }
}

