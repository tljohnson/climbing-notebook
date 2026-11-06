import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Debug-only synthetic input uses the same temporary-provider copy path as Photos.
enum TextNotebookImageTestIntake {
    static func providers(count: Int) throws -> [NSItemProvider] {
        return try (0..<count).map { index in
            let provider = NSItemProvider()
            let bytes = try sample(index: index)
            provider.suggestedName = ["Route topo", "Approach notes", "Descent sketch"][index % 3]
            provider.registerFileRepresentation(forTypeIdentifier: UTType.png.identifier, fileOptions: [], visibility: .all) { completion in
                let progress = Progress(totalUnitCount: 1)
                do {
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent("Synthetic-\(UUID().uuidString).png")
                    try bytes.write(to: url, options: .atomic)
                    // The consumer must copy before completion returns, just like a provider URL.
                    completion(url, false, nil)
                    try? FileManager.default.removeItem(at: url)
                    progress.completedUnitCount = 1
                } catch { completion(nil, false, error) }
                return progress
            }
            return provider
        }
    }

    static func sample(index: Int) throws -> Data {
        let size = CGSize(width: 900, height: index == 2 ? 4200 : index == 1 ? 2000 : 1200)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill(); context.fill(CGRect(origin: .zero, size: size))
            let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 10
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 32),
                .foregroundColor: UIColor.black, .paragraphStyle: paragraph]
            let header = ["PAPER SKYLINE — SYNTHETIC TOPO", "IMAGINARY APPROACH", "FICTIONAL DESCENT"][index % 3]
            (header as NSString).draw(in: CGRect(x: 40, y: 30, width: 820, height: 90), withAttributes: attributes)
            if index == 1 {
                let body = (1...14).map { "\($0). Synthetic example: from Gate A follow the imaginary path to ledge B. Compare these words with your own notes. Not for field use." }.joined(separator: "\n\n")
                (body as NSString).draw(in: CGRect(x: 40, y: 130, width: 820, height: 1750), withAttributes: attributes)
            } else {
                let path = UIBezierPath()
                path.move(to: CGPoint(x: 450, y: 150))
                for step in 1...8 { path.addLine(to: CGPoint(x: step.isMultiple(of: 2) ? 600 : 280, y: 150 + CGFloat(step) * (size.height - 400) / 8)) }
                UIColor.darkGray.setStroke(); path.lineWidth = 12; path.stroke()
                for step in 1...5 {
                    ("\(step) · Fictional point" as NSString).draw(at: CGPoint(x: 70, y: 150 + CGFloat(step) * (size.height - 500) / 5), withAttributes: attributes)
                }
            }
            ("END OF SYNTHETIC SAMPLE" as NSString).draw(at: CGPoint(x: 40, y: size.height - 70), withAttributes: attributes)
        }
        guard let bytes = image.pngData() else { throw CocoaError(.fileWriteUnknown) }
        return bytes
    }
}
