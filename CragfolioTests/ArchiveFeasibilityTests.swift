import XCTest
import CryptoKit
import ZIPFoundation

final class ArchiveFeasibilityTests: XCTestCase {
    private enum Rejection: Error { case unsafeEntry, expandedLimit, checksum }

    // Harness only: the production namespace, manifest and header validation remain unimplemented.
    private func inspect(_ archive: Archive, allowed: Set<String>, limit: Int) throws -> Int {
        var total = 0
        var seen = Set<String>()
        for entry in archive {
            guard entry.type == .file, allowed.contains(entry.path),
                  !entry.path.hasPrefix("/"), !entry.path.contains("\\"),
                  !entry.path.split(separator: "/").contains(".."),
                  seen.insert(entry.path.lowercased()).inserted else { throw Rejection.unsafeEntry }
            let crc = try archive.extract(entry, bufferSize: 64 * 1024) { bytes in
                guard bytes.count <= limit - total else { throw Rejection.expandedLimit }
                total += bytes.count
            }
            guard crc == entry.checksum else { throw Rejection.checksum }
        }
        return total
    }

    func testStreamingRoundTripWithCRCAndSHA256() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("synthetic.zip")
        let bytes = Data(repeating: 0x61, count: 512 * 1024)
        do {
            let archive = try Archive(url: url, accessMode: .create)
            try archive.addEntry(with: "manifest.json", type: .file, uncompressedSize: Int64(bytes.count),
                compressionMethod: .deflate, bufferSize: 64 * 1024) { position, size in
                bytes.subdata(in: Int(position)..<min(Int(position) + size, bytes.count))
            }
        }
        let archive = try Archive(url: url, accessMode: .read)
        let entry = try XCTUnwrap(archive["manifest.json"])
        var hash = SHA256()
        var count = 0
        let crc = try archive.extract(entry, bufferSize: 64 * 1024) {
            XCTAssertLessThanOrEqual($0.count, 64 * 1024)
            hash.update(data: $0)
            count += $0.count
        }
        XCTAssertEqual(crc, entry.checksum)
        XCTAssertEqual(count, bytes.count)
        XCTAssertEqual(Data(hash.finalize()), Data(SHA256.hash(data: bytes)))
        XCTAssertEqual(try inspect(archive, allowed: ["manifest.json"], limit: bytes.count), bytes.count)
        XCTAssertThrowsError(try inspect(archive, allowed: ["manifest.json"], limit: 100))
        let progress = Progress(totalUnitCount: 0)
        progress.cancel()
        XCTAssertThrowsError(try archive.extract(entry, progress: progress) { _ in })
    }

    func testUnsafeAndLinkEntriesAreRejectedBeforeExtraction() throws {
        for (path, type) in [("../escape", Entry.EntryType.file), ("/absolute", .file),
                             ("media\\alias", .file), ("link", .symlink)] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: root) }
            let archive = try Archive(url: root.appendingPathComponent("hostile.zip"), accessMode: .create)
            try archive.addEntry(with: path, type: type, uncompressedSize: Int64(1)) { _, _ in Data([0x61]) }
            XCTAssertThrowsError(try inspect(archive, allowed: [path], limit: 10))
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), ["hostile.zip"])
        }
    }
}
