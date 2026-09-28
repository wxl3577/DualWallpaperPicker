import UIKit

/// Prepare a screen-shaped bitmap before handing it to the system wallpaper API.
/// Never use aspect-fill: a different source ratio must produce bars, not cropping.
enum WallpaperCanvas {
    static func contentRect(imageSize: CGSize, canvasSize: CGSize) -> CGRect {
        let scale = min(canvasSize.width / imageSize.width,
                        canvasSize.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: (canvasSize.width - size.width) / 2,
                      y: (canvasSize.height - size.height) / 2,
                      width: size.width, height: size.height)
    }

    static func render(_ image: UIImage, size: CGSize, scale: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: contentRect(imageSize: image.size, canvasSize: size))
        }
    }

    static func prepare(_ image: UIImage) -> UIImage {
        let screen = UIScreen.main
        let bounds = screen.fixedCoordinateSpace.bounds.size
        let portrait = CGSize(width: min(bounds.width, bounds.height),
                              height: max(bounds.width, bounds.height))
        // Keep UIImage's point size equal to the screen, rather than passing a
        // huge scale=1 downloaded image alongside zoomScale=1 to the private API.
        return render(image, size: portrait, scale: screen.scale)
    }

    #if DEBUG
    static func runSelfTests() {
        let canvas = CGSize(width: 390, height: 844)
        for source in [CGSize(width: 4000, height: 6000), CGSize(width: 6000, height: 4000),
                       CGSize(width: 2000, height: 2000), CGSize(width: 1170, height: 2532),
                       CGSize(width: 1000, height: 5000)] {
            let rect = contentRect(imageSize: source, canvasSize: canvas)
            assert(rect.minX >= -0.001 && rect.minY >= -0.001)
            assert(rect.maxX <= canvas.width + 0.001 && rect.maxY <= canvas.height + 0.001)
            assert(abs(rect.width / rect.height - source.width / source.height) < 0.001)
            assert(abs(rect.midX - canvas.width / 2) < 0.001)
            assert(abs(rect.midY - canvas.height / 2) < 0.001)
        }
        let sample = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 40)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 40))
        }
        let output = render(sample, size: canvas, scale: 3)
        assert(output.size == canvas && output.scale == 3)
        assert(output.cgImage?.width == 1170 && output.cgImage?.height == 2532)
        assert(output.imageOrientation == .up)
        print("WALLPAPER_CANVAS_TESTS_PASSED")
        fflush(stdout)
    }
    #endif
}
