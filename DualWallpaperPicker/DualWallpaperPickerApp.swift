import SwiftUI

@main
struct DualWallpaperPickerApp: App {
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--test-wallpaper-canvas") {
            WallpaperCanvas.runSelfTests()
            Task { @MainActor in await WallpaperDownloadTests.run() }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

