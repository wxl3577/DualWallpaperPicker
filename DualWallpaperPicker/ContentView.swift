import SwiftUI
import UIKit
import Photos

struct ContentView: View {
    @State private var requestedCount = 8
    @State private var wallpapers: [Wallpaper] = []
    @State private var lockWallpaper: Wallpaper?
    @State private var homeWallpaper: Wallpaper?
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var alertMessage: String?

    private let service = WallpaperService()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 18) {
                    introCard
                    controls
                    selectionSummary

                    if isLoading {
                        ProgressView("正在挑选壁纸…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 50)
                    } else if wallpapers.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 38))
                                .foregroundStyle(.secondary)
                            Text("还没有候选壁纸")
                                .font(.headline)
                            Text("选择数量，然后点“随机获取”。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(wallpapers) { wallpaper in
                                WallpaperCard(
                                    wallpaper: wallpaper,
                                    isLock: lockWallpaper?.id == wallpaper.id,
                                    isHome: homeWallpaper?.id == wallpaper.id,
                                    selectLock: { chooseLock(wallpaper) },
                                    selectHome: { chooseHome(wallpaper) }
                                )
                            }
                        }
                    }

                    actionPanel
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("双壁纸")
            .alert("提示", isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
            .task {
                if wallpapers.isEmpty {
                    await reload()
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("使用方式", systemImage: "sparkles")
                .font(.headline)
            Text("随机生成候选图，分别点选锁屏与主屏，再将两张图片保存到照片。整个过程不需要快捷指令。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Stepper("候选数量：\(requestedCount) 张", value: $requestedCount, in: 2...20, step: 2)
            Button {
                Task { await reload() }
            } label: {
                Label("随机获取 \(requestedCount) 张", systemImage: "shuffle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var selectionSummary: some View {
        HStack(spacing: 12) {
            selectionPill(icon: "lock.fill", title: "锁屏", wallpaper: lockWallpaper)
            selectionPill(icon: "house.fill", title: "主屏", wallpaper: homeWallpaper)
        }
    }

    private func selectionPill(icon: String, title: String, wallpaper: Wallpaper?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(wallpaper?.title ?? "未选择")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    private var actionPanel: some View {
        VStack(spacing: 10) {
            Button {
                Task { await saveSelectedWallpapers() }
            } label: {
                if isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Label("保存两张壁纸到照片", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(lockWallpaper == nil || homeWallpaper == nil || isSaving)

            Label("保存后打开“照片”，使用系统的“用作墙纸”功能分别设置。", systemImage: "photo")
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.subheadline)

            Label("在系统墙纸预览中可关闭视角缩放。", systemImage: "viewfinder")
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    @MainActor
    private func reload() async {
        isLoading = true
        lockWallpaper = nil
        homeWallpaper = nil
        defer { isLoading = false }

        do {
            wallpapers = try await service.randomWallpapers(count: requestedCount)
            if wallpapers.count < requestedCount {
                alertMessage = "本次取到 \(wallpapers.count) 张有效壁纸，可直接选择或再随机一次。"
            }
        } catch {
            wallpapers = []
            alertMessage = error.localizedDescription
        }
    }

    private func chooseLock(_ wallpaper: Wallpaper) {
        guard homeWallpaper?.id != wallpaper.id else {
            alertMessage = "锁屏和主屏请选择两张不同的壁纸。"
            return
        }
        lockWallpaper = wallpaper
    }

    private func chooseHome(_ wallpaper: Wallpaper) {
        guard lockWallpaper?.id != wallpaper.id else {
            alertMessage = "锁屏和主屏请选择两张不同的壁纸。"
            return
        }
        homeWallpaper = wallpaper
    }

    @MainActor
    private func saveSelectedWallpapers() async {
        guard let lockWallpaper, let homeWallpaper else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                throw PhotoSaveError.permissionDenied
            }

            let lockData = try await downloadImage(from: lockWallpaper.imageURL)
            let homeData = try await downloadImage(from: homeWallpaper.imageURL)
            try await saveImage(lockData, filename: "DualWallpaper-Lock.jpg")
            try await saveImage(homeData, filename: "DualWallpaper-Home.jpg")

            alertMessage = "已保存两张图片。锁屏：\(lockWallpaper.title)；主屏：\(homeWallpaper.title)。请打开“照片”，分别使用“用作墙纸”完成设置。"
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func downloadImage(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              UIImage(data: data) != nil else {
            throw PhotoSaveError.invalidImage
        }
        return data
    }

    private func saveImage(_ data: Data, filename: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.originalFilename = filename
                request.addResource(with: .photo, data: data, options: options)
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: PhotoSaveError.unknown)
                }
            }
        }
    }
}

private enum PhotoSaveError: LocalizedError {
    case permissionDenied
    case invalidImage
    case unknown

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "没有照片添加权限。请在系统设置中允许“双壁纸”添加照片。"
        case .invalidImage:
            return "壁纸下载失败或返回的内容不是有效图片，请重新随机后再试。"
        case .unknown:
            return "保存照片失败，请稍后再试。"
        }
    }
}

private struct WallpaperCard: View {
    let wallpaper: Wallpaper
    let isLock: Bool
    let isHome: Bool
    let selectLock: () -> Void
    let selectHome: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            AsyncImage(url: wallpaper.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    ZStack {
                        Color.secondary.opacity(0.12)
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
                default:
                    ZStack {
                        Color.secondary.opacity(0.08)
                        ProgressView()
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 320)
            .clipped()
            .contentShape(Rectangle())
            .allowsHitTesting(false)

            Text(wallpaper.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.top, 9)

            HStack(spacing: 8) {
                Button(action: selectLock) {
                    HStack(spacing: 5) {
                        Image(systemName: isLock ? "lock.fill" : "lock")
                        Text("锁屏")
                    }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundColor(.white)
                        .background(isLock ? Color.blue : Color.gray)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Rectangle())

                Button(action: selectHome) {
                    HStack(spacing: 5) {
                        Image(systemName: isHome ? "house.fill" : "house")
                        Text("主屏")
                    }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundColor(.white)
                        .background(isHome ? Color.green : Color.gray)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Rectangle())
            }
            .font(.caption)
            .padding(10)
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

