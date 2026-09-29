#if DEBUG
import Foundation
import Photos
import UIKit

enum WallpaperDownloadTests {
    @MainActor
    static func run() async {
        let url = URL(string: "https://example.com/wallpaper.png")!
        let image = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 20)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 12, height: 20))
        }
        let original = image.pngData()!
        let ok = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        var saved: Data?
        var fetchCount = 0
        var requestCount = 0
        var service = WallpaperDownloadService(
            authorizationStatus: { .notDetermined },
            requestAuthorization: { requestCount += 1; return .authorized },
            fetchImage: { requestedURL in
                assert(requestedURL == url)
                fetchCount += 1
                return (original, ok)
            },
            saveImage: { saved = $0 }
        )

        do { try await service.downloadToPhotos(from: url) }
        catch { fatalError("Expected a successful download: \(error)") }
        assert(saved == original, "Save the original bytes without re-encoding or resizing")
        assert(requestCount == 1 && fetchCount == 1)

        for status: PHAuthorizationStatus in [.authorized, .limited] {
            service.authorizationStatus = { status }
            do { try await service.downloadToPhotos(from: url) }
            catch { fatalError("Authorized save failed: \(error)") }
        }
        assert(requestCount == 1, "Do not ask again when permission is already granted")

        for status: PHAuthorizationStatus in [.denied, .restricted, .notDetermined] {
            service.authorizationStatus = { status }
            service.requestAuthorization = { .denied }
            let before = fetchCount
            saved = nil
            do {
                try await service.downloadToPhotos(from: url)
                fatalError("Permission failure must not succeed")
            } catch WallpaperDownloadError.photoAccessDenied {
                assert(status != .restricted)
            } catch WallpaperDownloadError.photoAccessRestricted {
                assert(status == .restricted)
            } catch { fatalError("Unexpected permission error: \(error)") }
            assert(saved == nil && fetchCount == before)
        }

        service.authorizationStatus = { .authorized }
        let failure = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
        for (data, response) in [(Data("not an image".utf8), ok), (original, failure)] {
            saved = nil
            service.fetchImage = { _ in (data, response) }
            do {
                try await service.downloadToPhotos(from: url)
                fatalError("Invalid download must not succeed")
            } catch WallpaperDownloadError.invalidImage {}
            catch { fatalError("Unexpected validation error: \(error)") }
            assert(saved == nil, "Invalid downloads must never reach Photos")
        }

        service.fetchImage = { _ in throw URLError(.notConnectedToInternet) }
        do {
            try await service.downloadToPhotos(from: url)
            fatalError("Network error must propagate")
        } catch let error as URLError {
            assert(error.code == .notConnectedToInternet)
        } catch { fatalError("Unexpected network error: \(error)") }

        service.fetchImage = { _ in (original, ok) }
        service.saveImage = { _ in throw WallpaperDownloadError.saveFailed }
        do {
            try await service.downloadToPhotos(from: url)
            fatalError("A failed Photos write must not report success")
        } catch WallpaperDownloadError.saveFailed {}
        catch { fatalError("Unexpected save error: \(error)") }

        print("WALLPAPER_DOWNLOAD_TESTS_PASSED")
        fflush(stdout)
    }
}
#endif
