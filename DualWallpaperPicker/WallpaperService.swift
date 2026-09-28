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
    private let apiBase = URL(string: "https://claritywallpaper.com/clarity/api/")!
    private let imageBase = URL(string: "http://wallpapers.claritywallpaper.com/")!
    private let decoder = JSONDecoder()

    func randomWallpapers(count: Int) async throws -> [Wallpaper] {
        let target = max(2, min(count, 20))
        let candidateNumbers = Array(2...1162).shuffled()
        let maximumAttempts = min(candidateNumbers.count, max(12, target * 4))
        var seen = Set<String>()
        var result: [Wallpaper] = []
        var cursor = 0

        while result.count < target && cursor < maximumAttempts {
            let end = min(cursor + 4, maximumAttempts)
            let batch = Array(candidateNumbers[cursor..<end])

            let batchResults = await withTaskGroup(of: [Wallpaper].self) { group in
                for number in batch {
                    group.addTask { [self] in
                        (try? await fetchSpecial(number: number)) ?? []
                    }
                }

                var wallpapers: [Wallpaper] = []
                for await items in group {
                    wallpapers.append(contentsOf: items)
                }
                return wallpapers
            }

            for wallpaper in batchResults.shuffled() where seen.insert(wallpaper.id).inserted {
                result.append(wallpaper)
                if result.count == target { break }
            }
            cursor = end
        }

        guard !result.isEmpty else { throw WallpaperServiceError.noWallpapers }
        return Array(result.prefix(target))
    }

    private func fetchSpecial(number: Int) async throws -> [Wallpaper] {
        var query = URLComponents(url: apiBase.appendingPathComponent("special/query"), resolvingAgainstBaseURL: false)!
        query.queryItems = [
            URLQueryItem(name: "size", value: "1"),
            URLQueryItem(name: "number", value: String(number))
        ]

        let (summaryData, summaryResponse) = try await URLSession.shared.data(from: query.url!)
        try validate(summaryResponse)
        let summary = try decoder.decode(APIEnvelope<[SpecialSummary]>.self, from: summaryData)
        guard let specialID = summary.data.first?.id else { return [] }

        let detailURL = apiBase.appendingPathComponent("special/\(specialID)")
        let (detailData, detailResponse) = try await URLSession.shared.data(from: detailURL)
        try validate(detailResponse)
        let detail = try decoder.decode(APIEnvelope<SpecialDetail>.self, from: detailData).data

        return (detail.pictureList ?? []).compactMap { picture in
            guard let url = URL(string: picture.url, relativeTo: imageBase)?.absoluteURL else { return nil }
            let title = [picture.title, picture.titleEn, detail.headline]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first(where: { !$0.isEmpty }) ?? "克拉壁纸"
            return Wallpaper(id: picture.id, imageURL: url, title: title)
        }
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

