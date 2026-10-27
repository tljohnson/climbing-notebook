import CryptoKit
import Foundation
import XCTest
import ZIPFoundation
import Darwin

final class ArchiveFeasibilityTests: XCTestCase {
    func testFileBackedArchiveRoundTripAndDigest() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CragfolioArchiveTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let input = directory.appendingPathComponent("source.txt")
        let archiveURL = directory.appendingPathComponent("test.zip")
        let output = directory.appendingPathComponent("restored.txt")
        let bytes = Data("synthetic archive round trip".utf8)
        try bytes.write(to: input)

        let archive = try Archive(url: archiveURL, accessMode: .create)
        try archive.addEntry(with: "manifest.txt", fileURL: input, compressionMethod: .none)
        let reader = try Archive(url: archiveURL, accessMode: .read)
        let entry = try XCTUnwrap(reader["manifest.txt"])
        let extractedCRC = try reader.extract(entry, to: output)

        let restored = try Data(contentsOf: output)
        XCTAssertEqual(restored, bytes)
        XCTAssertEqual(SHA256.hash(data: restored), SHA256.hash(data: bytes))
        XCTAssertEqual(extractedCRC, entry.checksum)
        XCTAssertEqual(entry.checksum, bytes.crc32(checksum: 0))
    }

    func testArchiveStreamsFileLargerThanFourGiB() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CragfolioZIP64-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let input = directory.appendingPathComponent("large.bin")
        let archiveURL = directory.appendingPathComponent("large.zip")
        let size: Int64 = 4 * 1024 * 1024 * 1024 + 1
        let descriptor = open(input.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        XCTAssertGreaterThanOrEqual(descriptor, 0)
        defer { close(descriptor) }
        XCTAssertEqual(ftruncate(descriptor, off_t(size)), 0)

        let archive = try Archive(url: archiveURL, accessMode: .create)
        try archive.addEntry(with: "media/large.bin", fileURL: input, compressionMethod: .none)
        let reader = try Archive(url: archiveURL, accessMode: .read)
        let entry = try XCTUnwrap(reader["media/large.bin"])
        XCTAssertGreaterThan(entry.uncompressedSize, UInt64(UInt32.max))
        XCTAssertEqual(entry.uncompressedSize, UInt64(size))

        let eofCRC = try reader.extract(entry, bufferSize: 1024 * 1024, skipCRC32: true) { _ in }
        XCTAssertEqual(eofCRC, 0)
    }
}
