import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.openURL) private var openURL
    @State private var requestedCount = 8
    @State private var wallpapers: [Wallpaper] = []
    @State private var lockWallpaper: Wallpaper?
    @State private var homeWallpaper: Wallpaper?
    @State private var isLoading = false
    @State private var alertMessage: String?

    private let service = WallpaperService()
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
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
                        LazyVGrid(columns: columns, spacing: 12) {
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
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("使用方式", systemImage: "sparkles")
                .font(.headline)
            Text("随机生成候选图，分别点选锁屏与主屏。首次使用请先安装辅助快捷指令；设置时会自动关闭预览和视角缩放。")
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
            if let shortcutURL = Bundle.main.url(forResource: "DualWallpaperSetter", withExtension: "shortcut") {
                ShareLink(item: shortcutURL) {
                    Label("首次使用：安装辅助快捷指令", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else {
                Label("构建中未包含辅助快捷指令", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }

            Button(action: applyWallpapers) {
                Label("设置锁屏与主屏壁纸", systemImage: "iphone.gen3")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(lockWallpaper == nil || homeWallpaper == nil)

            Text("应用会把两张图片地址暂存到剪贴板，再运行“DualWallpaperSetter”快捷指令。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
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

    private func applyWallpapers() {
        guard let lockWallpaper, let homeWallpaper else { return }
        UIPasteboard.general.string = "\(lockWallpaper.imageURL.absoluteString)\n\(homeWallpaper.imageURL.absoluteString)"

        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "run-shortcut"
        components.queryItems = [URLQueryItem(name: "name", value: "DualWallpaperSetter")]

        guard let url = components.url else {
            alertMessage = "无法生成快捷指令链接。"
            return
        }
        openURL(url)
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
            .frame(height: 230)
            .clipped()

            Text(wallpaper.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.top, 9)

            HStack(spacing: 8) {
                Button(action: selectLock) {
                    Label("锁屏", systemImage: isLock ? "lock.fill" : "lock")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(isLock ? .blue : .gray)

                Button(action: selectHome) {
                    Label("主屏", systemImage: isHome ? "house.fill" : "house")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(isHome ? .green : .gray)
            }
            .font(.caption)
            .padding(10)
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(isLock ? Color.blue : (isHome ? Color.green : Color.clear), lineWidth: 3)
        }
    }
}

