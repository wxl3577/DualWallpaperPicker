import Foundation
import Photos
import UIKit

enum WallpaperDownloadError: LocalizedError {
    case photoAccessDenied
    case photoAccessRestricted
    case invalidImage
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .photoAccessDenied:
            return "未获得添加照片的权限。请前往系统设置，允许“鱼头壁纸”添加照片后重试。"
        case .photoAccessRestricted:
            return "当前设备限制了相册访问，暂时无法保存壁纸。"
        case .invalidImage:
            return "壁纸下载失败或返回的内容不是有效图片，请稍后重试。"
        case .saveFailed:
            return "壁纸未能保存到相册，请检查设备剩余空间后重试。"
        }
    }
}

/// Saves the source bytes, without the resizing or black bars used for setting wallpaper.
struct WallpaperDownloadService {
    var authorizationStatus: () -> PHAuthorizationStatus = {
        PHPhotoLibrary.authorizationStatus(for: .addOnly)
    }
    var requestAuthorization: () async -> PHAuthorizationStatus = {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }
    var fetchImage: (URL) async throws -> (Data, URLResponse) = { url in
        try await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 60))
    }
    var saveImage: (Data) async throws -> Void = { data in
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            }) { success, error in
                if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: error ?? WallpaperDownloadError.saveFailed)
                }
            }
        }
    }

    func downloadToPhotos(from url: URL) async throws {
        var status = authorizationStatus()
        if status == .notDetermined {
            status = await requestAuthorization()
        }
        switch status {
        case .authorized, .limited:
            break
        case .restricted:
            throw WallpaperDownloadError.photoAccessRestricted
        default:
            throw WallpaperDownloadError.photoAccessDenied
        }

        try Task.checkCancellation()
        let (data, response) = try await fetchImage(url)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              UIImage(data: data) != nil else {
            throw WallpaperDownloadError.invalidImage
        }
        try Task.checkCancellation()
        try await saveImage(data)
    }
}
