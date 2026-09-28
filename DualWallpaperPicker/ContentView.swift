import SwiftUI
import UIKit

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
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
                            ForEach(wallpapers) { wallpaper in
                                WallpaperCard(
                                    wallpaper: wallpaper,
                                    isLock: lockWallpaper?.id == wallpaper.id,
                                    isHome: homeWallpaper?.id == wallpaper.id,
                                    selectLock: { chooseLock(wallpaper) },
                                    selectHome: { chooseHome(wallpaper) }
                                )
                                .disabled(isSaving)
                            }
                        }
                    }

                    actionPanel
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("鱼头壁纸")
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

    private var controls: some View {
        VStack(spacing: 12) {
            Stepper("候选数量：\(requestedCount) 张", value: $requestedCount, in: 2...20, step: 2)
                .disabled(isLoading || isSaving)
            Button {
                Task { await reload() }
            } label: {
                Label("随机获取 \(requestedCount) 张", systemImage: "shuffle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || isSaving)
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
                Task { await applySelectedWallpapers() }
            } label: {
                Label(isSaving ? "正在处理…" : "直接设置锁屏与主屏", systemImage: "iphone")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(lockWallpaper == nil || homeWallpaper == nil || isSaving || isLoading)

            Text("完整显示原图 · 比例不同时留黑边")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                Task { await reload() }
            } label: {
                Label(isLoading ? "正在刷新…" : "刷新 · 再来 \(requestedCount) 张", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(isLoading || isSaving)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    @MainActor
    private func reload() async {
        guard !isLoading && !isSaving else { return }
        let count = requestedCount
        isLoading = true
        lockWallpaper = nil
        homeWallpaper = nil
        defer { isLoading = false }

        do {
            wallpapers = try await service.randomWallpapers(count: count)
            if wallpapers.count < count {
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
    private func applySelectedWallpapers() async {
        guard !isSaving && !isLoading, let lockWallpaper, let homeWallpaper else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let lockData = try await downloadImage(from: lockWallpaper.imageURL)
            let homeData = try await downloadImage(from: homeWallpaper.imageURL)
            guard let lockImage = UIImage(data: lockData), let homeImage = UIImage(data: homeData) else {
                throw WallpaperError.invalidImage
            }
            let lockCanvas = WallpaperCanvas.prepare(lockImage)
            let homeCanvas = WallpaperCanvas.prepare(homeImage)
            try WallpaperBridge.applyLock(lockCanvas, homeImage: homeCanvas)
            alertMessage = "已按完整图片模式提交锁屏与主屏，不同比例会保留黑边。请查看实际显示效果。"
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func downloadImage(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              UIImage(data: data) != nil else {
            throw WallpaperError.invalidImage
        }
        return data
    }

}

private enum WallpaperError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "壁纸下载失败或返回的内容不是有效图片，请重新随机后再试。"
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
                    image.resizable().scaledToFit()
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
            .frame(height: 230)
            .background(Color.black)
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
                        .frame(height: 32)
                        .foregroundColor(isLock ? .white : .blue)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(isLock ? Color.blue : Color.blue.opacity(0.12)))
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
                        .frame(height: 32)
                        .foregroundColor(isHome ? .white : .purple)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(isHome ? Color.purple : Color.purple.opacity(0.12)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Rectangle())
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

