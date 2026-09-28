import Foundation

struct Wallpaper: Identifiable, Hashable {
    let id: String
    let imageURL: URL
    let title: String
}

private struct APIEnvelope<Value: Decodable>: Decodable {
    let code: Int?
    let message: String?
    let data: Value
}

private struct SpecialSummary: Decodable {
    let id: String
}

private struct SpecialDetail: Decodable {
    let headline: String?
    let pictureList: [Picture]?
}

private struct Picture: Decodable {
    let id: String
    let url: String
    let title: String?
    let titleEn: String?
}

enum WallpaperServiceError: LocalizedError {
    case noWallpapers

    var errorDescription: String? {
        switch self {
        case .noWallpapers:
            return "暂时没有取到壁纸，请稍后再试。"
        }
    }
}

actor WallpaperService {
    static let shared = WallpaperService()

    private let apiBase = URL(string: "https://claritywallpaper.com/clarity/api/")!
    private let imageBase = URL(string: "http://wallpapers.claritywallpaper.com/")!
    private let decoder = JSONDecoder()
    private var detailCache: [String: [Wallpaper]] = [:]

    func randomWallpapers(count: Int) async throws -> [Wallpaper] {
        let target = max(2, min(count, 20))
        // About 2–3 images per category. A request for 20 images therefore
        // normally uses eight different categories instead of only one or two.
        let desiredCategoryCount = min(8, max(2, (target * 2 + 4) / 5))
        var candidates = try await fetchSpecialPool(size: 80).shuffled()
        var categoryGroups: [[Wallpaper]] = []

        while categoryGroups.count < desiredCategoryCount && !candidates.isEmpty {
            let requestCount = min(4, desiredCategoryCount - categoryGroups.count, candidates.count)
            let batch = Array(candidates.prefix(requestCount))
            candidates.removeFirst(requestCount)
            categoryGroups.append(contentsOf: await fetchDetails(for: batch))
        }

        var result = balancedSample(from: categoryGroups, count: target)

        // Most categories contain enough images. If an unusually small or
        // unavailable category leaves a gap, top up in batches of at most four.
        while result.count < target && !candidates.isEmpty {
            let requestCount = min(4, candidates.count)
            let batch = Array(candidates.prefix(requestCount))
            candidates.removeFirst(requestCount)
            categoryGroups.append(contentsOf: await fetchDetails(for: batch))
            result = balancedSample(from: categoryGroups, count: target)
        }

        guard !result.isEmpty else { throw WallpaperServiceError.noWallpapers }
        return Array(result.prefix(target))
    }

    private func fetchSpecialPool(size: Int) async throws -> [SpecialSummary] {
        // The API treats `number` as a cursor. Randomizing the cursor gives us
        // one broad, inexpensive pool request without always using newest items.
        let cursor = Int.random(in: max(size + 2, 102)...1162)
        var query = URLComponents(url: apiBase.appendingPathComponent("special/query"), resolvingAgainstBaseURL: false)!
        query.queryItems = [
            URLQueryItem(name: "size", value: String(size)),
            URLQueryItem(name: "number", value: String(cursor))
        ]

        let (summaryData, summaryResponse) = try await URLSession.shared.data(from: query.url!)
        try validate(summaryResponse)
        let summary = try decoder.decode(APIEnvelope<[SpecialSummary]>.self, from: summaryData)
        return summary.data
    }

    private func fetchDetails(for summaries: [SpecialSummary]) async -> [[Wallpaper]] {
        await withTaskGroup(of: [Wallpaper].self) { group in
            for summary in summaries {
                group.addTask { [self] in
                    (try? await fetchSpecial(id: summary.id)) ?? []
                }
            }

            var results: [[Wallpaper]] = []
            for await wallpapers in group where !wallpapers.isEmpty {
                results.append(wallpapers)
            }
            return results
        }
    }

    private func fetchSpecial(id specialID: String) async throws -> [Wallpaper] {
        if let cached = detailCache[specialID] {
            return cached
        }

        let detailURL = apiBase.appendingPathComponent("special/\(specialID)")
        let (detailData, detailResponse) = try await URLSession.shared.data(from: detailURL)
        try validate(detailResponse)
        let detail = try decoder.decode(APIEnvelope<SpecialDetail>.self, from: detailData).data

        let wallpapers: [Wallpaper] = (detail.pictureList ?? []).compactMap { picture -> Wallpaper? in
            guard let url = URL(string: picture.url, relativeTo: imageBase)?.absoluteURL else { return nil }
            let title = [picture.title, picture.titleEn, detail.headline]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first(where: { !$0.isEmpty }) ?? "克拉壁纸"
            return Wallpaper(id: picture.id, imageURL: url, title: title)
        }
        detailCache[specialID] = wallpapers
        return wallpapers
    }

    private func balancedSample(from groups: [[Wallpaper]], count: Int) -> [Wallpaper] {
        let shuffledGroups = groups.shuffled().map { $0.shuffled() }
        var result: [Wallpaper] = []
        var seen = Set<String>()
        var itemIndex = 0

        while result.count < count {
            var addedAny = false
            for group in shuffledGroups where itemIndex < group.count {
                let wallpaper = group[itemIndex]
                if seen.insert(wallpaper.id).inserted {
                    result.append(wallpaper)
                    addedAny = true
                    if result.count == count { break }
                }
            }
            if !addedAny { break }
            itemIndex += 1
        }
        return result
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

