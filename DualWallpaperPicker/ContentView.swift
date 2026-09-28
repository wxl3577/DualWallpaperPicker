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
                    deviceRecommendation
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
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(0..<2) { column in
                                VStack(spacing: 14) {
                                    ForEach(wallpapers.indices.filter { $0 % 2 == column }, id: \.self) { index in
                                        let wallpaper = wallpapers[index]
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
                                .frame(maxWidth: .infinity)
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

    private var deviceRecommendation: some View {
        let recommendation = DeviceRecommendation.current
        return HStack(spacing: 12) {
            Image(systemName: "iphone")
                .font(.title2)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text("当前设备：\(recommendation.modelName)")
                    .font(.subheadline.weight(.semibold))
                Text("推荐图像尺寸：\(recommendation.width) × \(recommendation.height) 像素")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
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
                Label(isSaving ? "正在处理…" : settingTitle, systemImage: "iphone")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled((lockWallpaper == nil && homeWallpaper == nil) || isSaving || isLoading)

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
        if lockWallpaper?.id == wallpaper.id {
            lockWallpaper = nil
            return
        }
        guard homeWallpaper?.id != wallpaper.id else {
            alertMessage = "锁屏和主屏请选择两张不同的壁纸。"
            return
        }
        lockWallpaper = wallpaper
    }

    private func chooseHome(_ wallpaper: Wallpaper) {
        if homeWallpaper?.id == wallpaper.id {
            homeWallpaper = nil
            return
        }
        guard lockWallpaper?.id != wallpaper.id else {
            alertMessage = "锁屏和主屏请选择两张不同的壁纸。"
            return
        }
        homeWallpaper = wallpaper
    }

    private var settingTitle: String {
        if lockWallpaper != nil && homeWallpaper == nil { return "直接设置锁屏" }
        if homeWallpaper != nil && lockWallpaper == nil { return "直接设置主屏" }
        return "直接设置锁屏与主屏"
    }

    private func preparedImage(for wallpaper: Wallpaper?) async throws -> UIImage? {
        guard let wallpaper else { return nil }
        let data = try await downloadImage(from: wallpaper.imageURL)
        guard let image = UIImage(data: data) else { throw WallpaperError.invalidImage }
        return WallpaperCanvas.prepare(image)
    }

    @MainActor
    private func applySelectedWallpapers() async {
        guard !isSaving && !isLoading, lockWallpaper != nil || homeWallpaper != nil else { return }
        let selectedLock = lockWallpaper
        let selectedHome = homeWallpaper
        isSaving = true
        defer { isSaving = false }
        do {
            let lockCanvas = try await preparedImage(for: selectedLock)
            let homeCanvas = try await preparedImage(for: selectedHome)
            try WallpaperBridge.applyLock(lockCanvas, homeImage: homeCanvas)
            if selectedLock != nil && selectedHome != nil {
                alertMessage = "锁屏与主图已设置完成。"
            } else {
                alertMessage = selectedLock != nil ? "锁屏已设置完成。" : "主屏已设置完成。"
            }
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
    @State private var loadedImage: UIImage?
    @State private var imageSizeText: String?
    @State private var imageLoadFailed = false

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let loadedImage {
                    Image(uiImage: loadedImage)
                        .resizable()
                        .scaledToFit()
                } else if imageLoadFailed {
                    ZStack {
                        Color.secondary.opacity(0.12)
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 230)
                } else {
                    ZStack {
                        Color.secondary.opacity(0.08)
                        ProgressView()
                    }
                    .frame(height: 230)
                }
            }
            .frame(maxWidth: .infinity)
            .clipped()
            .contentShape(Rectangle())
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 2) {
                Text(wallpaper.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(imageSizeText ?? "正在读取图片尺寸…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
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
        .task(id: wallpaper.id) {
            await loadImage()
        }
    }

    @MainActor
    private func loadImage() async {
        loadedImage = nil
        imageSizeText = nil
        imageLoadFailed = false
        do {
            let (data, response) = try await URLSession.shared.data(from: wallpaper.imageURL)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  let image = UIImage(data: data) else {
                throw URLError(.cannotDecodeContentData)
            }
            guard !Task.isCancelled else { return }
            loadedImage = image
            if let cgImage = image.cgImage {
                imageSizeText = "\(cgImage.width) × \(cgImage.height) 像素"
            } else {
                let width = Int((image.size.width * image.scale).rounded())
                let height = Int((image.size.height * image.scale).rounded())
                imageSizeText = "\(width) × \(height) 像素"
            }
        } catch is CancellationError {
            return
        } catch {
            imageLoadFailed = true
            imageSizeText = "尺寸读取失败"
        }
    }
}

private struct DeviceRecommendation {
    let modelName: String
    let width: Int
    let height: Int

    static var current: DeviceRecommendation {
        let identifier = modelIdentifier
        let modelName = modelNames[identifier] ?? fallbackName(for: identifier)
        let screen = UIScreen.main
        let pointSize = screen.fixedCoordinateSpace.bounds.size
        let pixelWidth = min(pointSize.width, pointSize.height) * screen.scale
        let pixelHeight = max(pointSize.width, pointSize.height) * screen.scale
        return DeviceRecommendation(
            modelName: modelName,
            width: Int(pixelWidth.rounded()),
            height: Int(pixelHeight.rounded())
        )
    }

    private static var modelIdentifier: String {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "Simulator"
        #else
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = Mirror(reflecting: systemInfo.machine).children
            .compactMap { element -> UInt8? in
                guard let value = element.value as? Int8, value != 0 else { return nil }
                return UInt8(bitPattern: value)
            }
        return String(bytes: machine, encoding: .utf8) ?? UIDevice.current.model
        #endif
    }

    private static func fallbackName(for identifier: String) -> String {
        if identifier == "Simulator" { return "iPhone 模拟器" }
        if identifier.hasPrefix("iPhone") { return "iPhone（\(identifier)）" }
        if identifier.hasPrefix("iPad") { return "iPad（\(identifier)）" }
        return UIDevice.current.model
    }

    private static let modelNames: [String: String] = [
        "iPhone8,1": "iPhone 6s",
        "iPhone8,2": "iPhone 6s Plus",
        "iPhone8,4": "iPhone SE（第一代）",
        "iPhone9,1": "iPhone 7", "iPhone9,3": "iPhone 7",
        "iPhone9,2": "iPhone 7 Plus", "iPhone9,4": "iPhone 7 Plus",
        "iPhone10,1": "iPhone 8", "iPhone10,4": "iPhone 8",
        "iPhone10,2": "iPhone 8 Plus", "iPhone10,5": "iPhone 8 Plus",
        "iPhone10,3": "iPhone X", "iPhone10,6": "iPhone X",
        "iPhone11,2": "iPhone XS",
        "iPhone11,4": "iPhone XS Max", "iPhone11,6": "iPhone XS Max",
        "iPhone11,8": "iPhone XR",
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE（第二代）",
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        "iPhone14,6": "iPhone SE（第三代）",
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max"
    ]
}

