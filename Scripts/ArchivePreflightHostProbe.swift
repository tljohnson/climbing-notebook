import Foundation

// Opt-in driver for the test-only probe; inputs are CF-05A capability fixtures, not backups.
@main
struct PreflightHostProbe {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else { throw ArchivePreflightProbe.Failure.malformed }
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        for name in ["swift-stored.zip", "swift-deflated.zip", "python-stored.zip", "python-deflated.zip"] {
            let result = try ArchivePreflightProbe.inspect(root.appendingPathComponent(name))
            guard result.items.count == 2, result.items[0].inflated == 4_294_967_419,
                  result.items[1].inflated == 23, result.readBytes < 100_000,
                  result.largestRead <= 65_557 else { throw ArchivePreflightProbe.Failure.disagreement }
            print("PASS CF-05D \(name) bytes=\(result.fileBytes) directory=\(result.directory) reads=\(result.readBytes) largest=\(result.largestRead)")
        }
    }
}
