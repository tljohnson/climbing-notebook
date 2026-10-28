import XCTest
import ZIPFoundation

// Test-only record construction, not a ZIP parser or portable-backup validator.
final class ArchiveHostileFeasibilityTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory.appendingPathComponent("CF05B-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        // Consumer extraction must never publish payload files, even for rejected fixtures.
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: scratch.path).allSatisfy { $0.hasSuffix(".zip") })
        try FileManager.default.removeItem(at: scratch)
        XCTAssertFalse(FileManager.default.fileExists(atPath: scratch.path))
    }

    private func open(_ data: Data) throws -> Archive {
        // The out-of-range-offset fixture traps in MemoryFile.readData(buffer:) when
        // opened with Archive(data:accessMode:). File-backed reading returns nil.
        // Keep using the intended file input API; initial crash evidence is retained.
        let url = scratch.appendingPathComponent("\(UUID().uuidString).zip")
        try data.write(to: url)
        return try Archive(url: url, accessMode: .read)
    }

    private enum Rejection: Error, Equatable {
        case path, type, entryCount, perEntry, aggregate, checksum, size
    }

    private struct Record {
        var name = "manifest.json"
        var payload = Data("hello".utf8)
        var crc: UInt32 = 0x3610a686
        var size: UInt32 = 5
        var method: UInt16 = 0
        var flags: UInt16 = 0x800
        var mode: UInt32 = 0o100644
        var localExtra = Data()
        var centralExtra = Data()
        var localPatches: [(Int, UInt32, Int)] = []
        var centralPatches: [(Int, UInt32, Int)] = []
    }

    private func put(_ value: UInt32, in data: inout Data, at offset: Int, width: Int) {
        for index in 0..<width { data[offset + index] = UInt8(truncatingIfNeeded: value >> (8 * index)) }
    }

    private func fixture(_ records: [Record], endPatches: [(Int, UInt32, Int)] = []) -> Data {
        var locals = Data(), central = Data()
        for record in records {
            let name = Data(record.name.utf8)
            var local = Data(count: 30)
            for (offset, value, width) in [(0, UInt32(0x04034b50), 4), (4, 20, 2),
                (6, UInt32(record.flags), 2), (8, UInt32(record.method), 2), (14, record.crc, 4),
                (18, UInt32(record.payload.count), 4), (22, record.size, 4),
                (26, UInt32(name.count), 2), (28, UInt32(record.localExtra.count), 2)] {
                put(value, in: &local, at: offset, width: width)
            }
            for (offset, value, width) in record.localPatches { put(value, in: &local, at: offset, width: width) }
            local.append(name)
            local.append(record.localExtra)
            local.append(record.payload)
            var directory = Data(count: 46)
            for (offset, value, width) in [(0, UInt32(0x02014b50), 4), (4, 0x314, 2), (6, 20, 2),
                (8, UInt32(record.flags), 2), (10, UInt32(record.method), 2), (16, record.crc, 4),
                (20, UInt32(record.payload.count), 4), (24, record.size, 4),
                (28, UInt32(name.count), 2), (30, UInt32(record.centralExtra.count), 2),
                (38, record.mode << 16, 4), (42, UInt32(locals.count), 4)] {
                put(value, in: &directory, at: offset, width: width)
            }
            for (offset, value, width) in record.centralPatches {
                put(value, in: &directory, at: offset, width: width)
            }
            directory.append(name)
            directory.append(record.centralExtra)
            central.append(directory)
            locals.append(local)
        }
        var end = Data(count: 22)
        for (offset, value, width) in [(0, UInt32(0x06054b50), 4), (8, UInt32(records.count), 2),
            (10, UInt32(records.count), 2), (12, UInt32(central.count), 4), (16, UInt32(locals.count), 4)] {
            put(value, in: &end, at: offset, width: width)
        }
        for (offset, value, width) in endPatches { put(value, in: &end, at: offset, width: width) }
        return locals + central + end
    }

    // Only observable-entry policy. A return value MUST NOT authorize whole-archive acceptance:
    // the public iterator has no error/completeness signal or raw header access.
    private func inspectVisible(_ archive: Archive, allowed: Set<String>, entries: Int = 4,
                                perEntry: Int = 32, aggregate: Int = 64) throws -> Int {
        var total = 0, count = 0
        var seen = Set<String>()
        for entry in archive {
            count += 1
            guard count <= entries else { throw Rejection.entryCount }
            let path = entry.path
            let components = path.split(separator: "/", omittingEmptySubsequences: false)
            guard !path.hasPrefix("/"), !path.contains("\\"), !path.contains(":"),
                  !path.contains("\0"), !components.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }),
                  path.utf8.elementsEqual(path.precomposedStringWithCanonicalMapping.utf8),
                  allowed.contains(path), seen.insert(path.lowercased()).inserted else { throw Rejection.path }
            guard entry.type == .file else { throw Rejection.type }
            var expanded = 0
            let crc = try archive.extract(entry, bufferSize: 2) { bytes in
                guard bytes.count <= perEntry - expanded else { throw Rejection.perEntry }
                guard bytes.count <= aggregate - total else { throw Rejection.aggregate }
                expanded += bytes.count
                total += bytes.count
            }
            guard crc == entry.checksum else { throw Rejection.checksum }
            guard UInt64(expanded) == entry.uncompressedSize else { throw Rejection.size }
        }
        return total
    }

    private func reject(_ archive: Archive, allowed: Set<String>, reason: Rejection,
                        entries: Int = 4, perEntry: Int = 32, aggregate: Int = 64,
                        file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try inspectVisible(archive, allowed: allowed, entries: entries,
                                              perEntry: perEntry, aggregate: aggregate), file: file, line: line) {
            XCTAssertEqual($0 as? Rejection, reason, file: file, line: line)
        }
    }

    func testDuplicateCaseAndAliasPathsRejectVisibleArchive() throws {
        for names in [["manifest.json", "manifest.json"], ["manifest.json", "MANIFEST.JSON"],
                      ["/absolute"], ["../escape"], ["media/../escape"], ["media\\alias"],
                      ["./manifest.json"], ["media//original"], ["C:/absolute"],
                      ["manifest.json\0alias"], ["media/e\u{301}"], ["unexpected.txt"]] {
            let data = fixture(names.map { Record(name: $0) })
            let archive = try open(data)
            XCTAssertEqual(Array(archive).map(\.path), names)
            reject(archive, allowed: Set(names.filter { $0 != "unexpected.txt" }), reason: .path)
        }
    }

    func testSymlinkAndDirectoryRejectBeforeConsumer() throws {
        for (mode, type) in [(UInt32(0o120777), Entry.EntryType.symlink), (0o040755, .directory)] {
            let archive = try open(fixture([Record(mode: mode)]))
            XCTAssertEqual(try XCTUnwrap(Array(archive).first).type, type)
            reject(archive, allowed: ["manifest.json"], reason: .type)
        }
        // No EntryType.hardlink, raw extra-field access or link-target API exists.
        // Do not equate the symlink result with general hard-link rejection.
    }

    func testEncryptedAndBrokenRecordsSilentlyEndEnumeration() throws {
        let safe = Record(name: "safe.txt")
        let tail = Record(name: "tail.txt")
        let broken = [Record(flags: 0x801),
                      Record(localPatches: [(0, 0, 4)]),
                      Record(localPatches: [(26, 65535, 2)]),
                      Record(centralPatches: [(0, 0, 4)]),
                      Record(centralPatches: [(28, 65535, 2)]),
                      Record(centralPatches: [(42, 0xfffffff0, 4)])]
        for record in broken {
            let archive = try open(fixture([safe, record, tail]))
            XCTAssertEqual(Array(archive).map(\.path), ["safe.txt"])
            // Minimal counterexample: even exact visible-name equality and CRC pass.
            // This is evidence of a missing guarantee, never a validator success.
            XCTAssertEqual(try inspectVisible(archive, allowed: ["safe.txt"]), 5)
        }
        let encrypted = try open(fixture([safe, Record(flags: 0x801), tail]))
        let iterator = encrypted.makeIterator()
        XCTAssertEqual(iterator.next()?.path, "safe.txt")
        XCTAssertNil(iterator.next())
        XCTAssertEqual(iterator.next()?.path, "tail.txt") // encrypted record advances, malformed ones do not
        XCTAssertThrowsError(try open(Data(fixture([safe]).dropLast(12))))
    }

    func testHeaderDisagreementsRemainExtractableAndUnobservable() throws {
        // Same-length local name mutation; central name stays manifest.json.
        let records = [Record(localPatches: [(6, 0x801, 2)]), // local-only encrypted flag
                       Record(centralPatches: [(10, 99, 2)]), // central-only unsupported method
                       Record(localPatches: [(18, 1, 4), (22, 1, 4)]),
                       Record(localPatches: [(14, 0, 4)])]
        for record in records {
            let archive = try open(fixture([record]))
            XCTAssertEqual(try inspectVisible(archive, allowed: ["manifest.json"]), 5)
        }
        var names = fixture([Record()])
        names[30] = UInt8(ascii: "x")
        let archive = try open(names)
        XCTAssertEqual(Array(archive).first?.path, "manifest.json")
        XCTAssertEqual(try inspectVisible(archive, allowed: ["manifest.json"]), 5)
        // A false EOCD count also hides a valid later entry, without an error.
        let hidden = try open(fixture([Record(), Record(name: "extra.txt")],
                                      endPatches: [(8, 1, 2), (10, 1, 2)]))
        XCTAssertEqual(Array(hidden).map(\.path), ["manifest.json"])
    }

    func testMalformedZIP64ExtraFieldsAreNotValidated() throws {
        // Claims 16 bytes but contains one: bounded malformed field in each location.
        let malformed = Data([1, 0, 16, 0, 0])
        for record in [Record(localExtra: malformed), Record(centralExtra: malformed)] {
            let archive = try open(fixture([record]))
            XCTAssertEqual(try inspectVisible(archive, allowed: ["manifest.json"]), 5)
        }
        let sentinel = Record(size: .max, centralExtra: malformed)
        let archive = try open(fixture([sentinel]))
        XCTAssertEqual(try XCTUnwrap(Array(archive).first).uncompressedSize, UInt64(UInt32.max))
        reject(archive, allowed: ["manifest.json"], reason: .perEntry)
    }

    func testUnsupportedMethodCRCAndTruncatedDeflate() throws {
        let unsupported = try open(fixture([Record(method: 99)]))
        XCTAssertEqual(Array(unsupported).count, 1)
        XCTAssertThrowsError(try inspectVisible(unsupported, allowed: ["manifest.json"])) {
            guard case Archive.ArchiveError.invalidCompressionMethod = $0 else {
                return XCTFail("Unexpected error: \($0)")
            }
        }
        let localUnsupported = try open(fixture([Record(localPatches: [(8, 99, 2)])]))
        XCTAssertEqual(Array(localUnsupported).count, 1)
        XCTAssertThrowsError(try inspectVisible(localUnsupported, allowed: ["manifest.json"])) {
            guard case Archive.ArchiveError.invalidCompressionMethod = $0 else {
                return XCTFail("Unexpected error: \($0)")
            }
        }
        let crc = try open(fixture([Record(crc: 0)]))
        reject(crc, allowed: ["manifest.json"], reason: .checksum)
        // Raw DEFLATE for "hello", independently fixed, no dependency on writer behavior.
        let deflated = Data([0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00])
        let good = try open(fixture([Record(payload: deflated, method: 8)]))
        XCTAssertEqual(try inspectVisible(good, allowed: ["manifest.json"]), 5)
        let truncated = try open(fixture([Record(payload: Data(deflated.prefix(3)), method: 8)]))
        XCTAssertEqual(Array(truncated).count, 1)
        XCTAssertThrowsError(try inspectVisible(truncated, allowed: ["manifest.json"])) {
            XCTAssertNil($0 as? Rejection, "Truncated DEFLATE must throw from the library, not only fail policy")
            XCTAssertEqual(String(describing: $0), "corruptedData")
        }
    }

    func testStreamingEntryPerFileAndAggregateLimits() throws {
        let archive = try open(fixture([Record(), Record(name: "second.txt")]))
        let allowed: Set<String> = ["manifest.json", "second.txt"]
        XCTAssertEqual(try inspectVisible(archive, allowed: allowed, entries: 2, perEntry: 5, aggregate: 10), 10)
        reject(archive, allowed: allowed, reason: .entryCount, entries: 1)
        reject(archive, allowed: allowed, reason: .perEntry, perEntry: 4)
        reject(archive, allowed: allowed, reason: .aggregate, aggregate: 9)
        let deflated = Data([0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00])
        let understated = try open(fixture([Record(payload: deflated, size: 1, method: 8)]))
        XCTAssertEqual(Array(understated).first?.uncompressedSize, 1)
        reject(understated, allowed: ["manifest.json"], reason: .perEntry, perEntry: 4)
        reject(understated, allowed: ["manifest.json"], reason: .aggregate, aggregate: 4)
        reject(understated, allowed: ["manifest.json"], reason: .size)
    }
}
