import ImageIO
import UIKit
import UniformTypeIdentifiers
import XCTest
@testable import ClimbingNotebook

@MainActor
final class TextNotebookImageReaderTests: XCTestCase {
    private let colors: [[UInt8]] = [
        [255, 0, 0, 255], [0, 255, 0, 255],
        [0, 0, 255, 255], [255, 255, 0, 255]
    ]

    private func fixture(orientation: Int = 1) throws -> URL {
        let width = 120, height = 80
        var pixels = [UInt8]()
        for y in 0..<height {
            for x in 0..<width { pixels += colors[(y < height / 2 ? 0 : 2) + (x < width / 2 ? 0 : 1)] }
        }
        let provider = try XCTUnwrap(CGDataProvider(data: Data(pixels) as CFData))
        let image = try XCTUnwrap(CGImage(width: width, height: height, bitsPerComponent: 8,
            bitsPerPixel: 32, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Reader-\(UUID().uuidString).jpg")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [
            kCGImagePropertyOrientation: orientation,
            kCGImageDestinationLossyCompressionQuality: 1
        ] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        addTeardownBlock { try FileManager.default.removeItem(at: url) }
        return url
    }

    private func assertColor(_ image: CGImage, _ expected: [UInt8], file: StaticString = #filePath, line: UInt = #line) throws {
        var pixel = [UInt8](repeating: 0, count: 4)
        try pixel.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: 1, height: 1,
                bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        for channel in 0..<4 {
            XCTAssertEqual(Double(pixel[channel]), Double(expected[channel]), accuracy: 20, file: file, line: line)
        }
    }

    func testOriginalOrientationAndTopOriginCornerTilesForAllEightOrientations() throws {
        // Expected visual corners: top-left, top-right, bottom-left, bottom-right.
        let expected = [[0, 1, 2, 3], [1, 0, 3, 2], [3, 2, 1, 0], [2, 3, 0, 1],
                        [0, 2, 1, 3], [2, 0, 3, 1], [3, 1, 2, 0], [1, 3, 0, 2]]
        for orientation in 1...8 {
            let original = try NotebookReaderOriginal(url: fixture(orientation: orientation))
            XCTAssertEqual(original.size, orientation < 5 ? CGSize(width: 120, height: 80) : CGSize(width: 80, height: 120))
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let view = NotebookReaderTileView(original: original)
            let rendered = UIGraphicsImageRenderer(size: original.size, format: format).image { _ in
                view.draw(CGRect(origin: .zero, size: original.size))
            }
            let renderedImage = try XCTUnwrap(rendered.cgImage)
            for scale in [CGFloat(1), CGFloat(0.5)] {
                let full = try XCTUnwrap(original.tile(rect: CGRect(origin: .zero, size: original.size), scale: scale))
                XCTAssertEqual(full.width, Int(original.size.width * scale))
                XCTAssertEqual(full.height, Int(original.size.height * scale))
                for corner in 0..<4 {
                    let x: CGFloat = corner % 2 == 0 ? 8 : original.size.width - 24
                    let y: CGFloat = corner < 2 ? 8 : original.size.height - 24
                    let rect = CGRect(x: x, y: y, width: 16, height: 16)
                    let tile = try XCTUnwrap(original.tile(rect: rect, scale: scale))
                    try assertColor(tile, colors[expected[orientation - 1][corner]])
                    let fullCorner = try XCTUnwrap(full.cropping(to: CGRect(x: x * scale, y: y * scale, width: 16 * scale, height: 16 * scale)))
                    try assertColor(fullCorner, colors[expected[orientation - 1][corner]])
                    let drawnCorner = try XCTUnwrap(renderedImage.cropping(to: rect))
                    try assertColor(drawnCorner, colors[expected[orientation - 1][corner]])
                }
            }
        }
    }

    private func scroll() throws -> NotebookReaderScroll {
        let scroll = NotebookReaderScroll(original: try NotebookReaderOriginal(url: fixture()), saved: nil)
        scroll.frame = CGRect(x: 0, y: 0, width: 30, height: 20)
        scroll.layoutIfNeeded()
        scroll.layoutSubviews()
        return scroll
    }

    func testMissingOriginalAndSymlinkAreUnavailable() throws {
        let target = try fixture()
        let link = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderLink-\(UUID().uuidString).jpg")
        XCTAssertThrowsError(try NotebookReaderOriginal(url: link))
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        defer { try? FileManager.default.removeItem(at: link) }
        XCTAssertThrowsError(try NotebookReaderOriginal(url: link))
        XCTAssertNoThrow(try NotebookReaderOriginal(url: target))
    }

    func testWhiteAdjacentTilesHaveNoGrayOrTransparentSeamsAtFractionalZoom() throws {
        let size = CGSize(width: 1537, height: 1025)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let white = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderWhite-\(UUID().uuidString).png")
        try XCTUnwrap(white.pngData()).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let view = NotebookReaderTileView(original: try NotebookReaderOriginal(url: url))
        XCTAssertTrue(view.layer is NotebookReaderTileLayer)
        XCTAssertEqual(NotebookReaderTileLayer.fadeDuration(), 0)

        for scale in [CGFloat(0.37), CGFloat(0.8), CGFloat(1.25)] {
            let width = Int(ceil(size.width * scale)), height = Int(ceil(size.height * scale))
            let rendered = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { renderer in
                UIColor.black.setFill()
                renderer.fill(CGRect(x: 0, y: 0, width: width, height: height))
                let context = renderer.cgContext
                context.scaleBy(x: scale, y: scale)
                for y in stride(from: 0, to: height, by: 128) {
                    for x in stride(from: 0, to: width, by: 128) {
                        let rect = CGRect(x: CGFloat(x) / scale, y: CGFloat(y) / scale,
                                          width: 128 / scale, height: 128 / scale)
                        context.saveGState()
                        context.clip(to: rect)
                        view.draw(rect)
                        context.restoreGState()
                    }
                }
            }
            let image = try XCTUnwrap(rendered.cgImage)
            var pixels = [UInt8](repeating: 0, count: width * height * 4)
            try pixels.withUnsafeMutableBytes { bytes in
                let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: width, height: height,
                    bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
            var darkest: UInt8 = 255
            // Ignore the partially covered outside edge, but inspect every internal tile boundary.
            for y in 2..<(height - 2) {
                for x in 2..<(width - 2) {
                    let offset = (y * width + x) * 4
                    darkest = min(darkest, pixels[offset], pixels[offset + 1], pixels[offset + 2], pixels[offset + 3])
                }
            }
            XCTAssertGreaterThanOrEqual(darkest, 254, "White tile seam at scale \(scale)")
        }
    }

    func testResizePreservesSourceCenterAndZoom() throws {
        let scroll = try scroll()
        scroll.setZoomScale(1, animated: false)
        scroll.setContentOffset(CGPoint(x: 35, y: 25), animated: false)
        scroll.layoutSubviews()
        scroll.frame.size = CGSize(width: 60, height: 40)
        scroll.layoutSubviews()
        XCTAssertEqual(scroll.zoomScale, 1, accuracy: 0.0001)
        XCTAssertEqual(scroll.contentOffset.x, 20, accuracy: 0.0001)
        XCTAssertEqual(scroll.contentOffset.y, 15, accuracy: 0.0001)
    }

    func testZoomCommandsClampAndPanReachesAllEdges() throws {
        let scroll = try scroll()
        scroll.apply(NotebookReaderCommand(action: .fitImage))
        XCTAssertEqual(scroll.zoomScale, 0.25, accuracy: 0.0001)
        for _ in 0..<8 { scroll.apply(NotebookReaderCommand(action: .zoomIn)) }
        XCTAssertEqual(scroll.zoomScale, scroll.maximumZoomScale, accuracy: 0.0001)
        for _ in 0..<8 { scroll.apply(NotebookReaderCommand(action: .zoomOut)) }
        XCTAssertEqual(scroll.zoomScale, scroll.minimumZoomScale, accuracy: 0.0001)
        scroll.setZoomScale(1, animated: false)
        for _ in 0..<10 {
            scroll.apply(NotebookReaderCommand(action: .right))
            scroll.apply(NotebookReaderCommand(action: .down))
        }
        XCTAssertEqual(scroll.contentOffset.x, 90, accuracy: 0.0001)
        XCTAssertEqual(scroll.contentOffset.y, 60, accuracy: 0.0001)
        for _ in 0..<10 {
            scroll.apply(NotebookReaderCommand(action: .left))
            scroll.apply(NotebookReaderCommand(action: .up))
        }
        XCTAssertEqual(scroll.contentOffset.x, 0, accuracy: 0.0001)
        XCTAssertEqual(scroll.contentOffset.y, 0, accuracy: 0.0001)
    }

    func testInitialFitDoesNotReplaceSavedViewport() throws {
        let original = try NotebookReaderOriginal(url: fixture())
        let scroll = NotebookReaderScroll(original: original,
            saved: NotebookReaderViewport(zoom: 1, center: CGPoint(x: 60, y: 40)))
        scroll.apply(NotebookReaderCommand(action: .fitImage))
        scroll.frame = CGRect(x: 0, y: 0, width: 30, height: 20)
        scroll.layoutSubviews()
        XCTAssertEqual(scroll.zoomScale, 1, accuracy: 0.0001)
        XCTAssertEqual(scroll.contentOffset.x, 45, accuracy: 0.0001)
        XCTAssertEqual(scroll.contentOffset.y, 30, accuracy: 0.0001)
    }
}
