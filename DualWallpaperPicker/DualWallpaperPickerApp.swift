import SwiftUI

@main
struct DualWallpaperPickerApp: App {
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--test-wallpaper-canvas") {
            WallpaperCanvas.runSelfTests()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

