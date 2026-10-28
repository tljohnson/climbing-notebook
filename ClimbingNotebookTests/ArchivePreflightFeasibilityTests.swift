import XCTest
import ZIPFoundation

extension ArchiveHostileFeasibilityTests {
    func testPreflightCannotProveExactDeflateConsumption() throws {
        // Structurally accounted payload has a valid stream followed by non-stream bytes.
        // ZIPFoundation returns matching content/CRC but exposes no consumed-input count.
        let payload = Data([0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0, 0xde, 0xad])
        let archive = try open(fixture([Record(payload: payload, method: 8)]))
        let metadata = try ArchivePreflightProbe.inspect(archive.url)
        XCTAssertEqual(metadata.items[0].compressed, 9)
        let entry = try XCTUnwrap(Array(archive).first)
        var bytes = Data()
        let crc = try archive.extract(entry, bufferSize: 32) { bytes.append($0) }
        XCTAssertEqual(bytes, Data("hello".utf8))
        XCTAssertEqual(crc, entry.checksum)
        // Not acceptance: this reproduces a separate missing extraction guarantee.
    }

    func testPreflightDescriptorsWithAndWithoutSignatureAndSmallZIP64() throws {
        for zip64 in [false, true] {
            for signed in [false, true] {
                var descriptor = Data(count: (signed ? 4 : 0) + 4 + (zip64 ? 16 : 8))
                let base = signed ? 4 : 0
                if signed { put(0x08074b50, in: &descriptor, at: 0, width: 4) }
                put(0x3610a686, in: &descriptor, at: base, width: 4)
                put(5, in: &descriptor, at: base + 4, width: 4)
                put(5, in: &descriptor, at: base + (zip64 ? 12 : 8), width: 4)
                var extra = Data()
                if zip64 {
                    extra = Data(count: 20)
                    put(1, in: &extra, at: 0, width: 2); put(16, in: &extra, at: 2, width: 2)
                    put(5, in: &extra, at: 4, width: 4); put(5, in: &extra, at: 12, width: 4)
                }
                let record = Record(flags: 0x808, localExtra: extra, centralExtra: extra, descriptor: descriptor,
                                    localPatches: [(4, zip64 ? 45 : 20, 2), (14, 0, 4),
                                                   (18, zip64 ? 0xffffffff : 0, 4), (22, zip64 ? 0xffffffff : 0, 4)],
                                    centralPatches: zip64 ? [(6, 45, 2), (20, 0xffffffff, 4), (24, 0xffffffff, 4)] : [])
                let archive = try open(fixture([record]))
                let result = try ArchivePreflightProbe.inspect(archive.url)
                XCTAssertEqual(result.items[0].descriptor.count, descriptor.count)
                XCTAssertEqual(result.items[0].inflated, 5)
                XCTAssertEqual(Array(archive).count, 1)
                var count = 0
                let crc = try archive.extract(try XCTUnwrap(Array(archive).first), bufferSize: 2) { count += $0.count }
                XCTAssertEqual(count, 5); XCTAssertEqual(crc, 0x3610a686)
                var broken = record
                broken.descriptor = Data(descriptor.dropLast())
                XCTAssertThrowsError(try ArchivePreflightProbe.inspect(open(fixture([broken])).url))
            }
        }
    }

    func testPreflightValidControlsAndExtractionReconciliation() throws {
        for record in [Record(), Record(payload: Data([0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0]), method: 8),
                       Record(name: "media/\u{e9}")] {
            let archive = try open(fixture([record]))
            let result = try ArchivePreflightProbe.inspect(archive.url)
            XCTAssertEqual(result.items.count, 1)
            let metadata = try XCTUnwrap(result.items.first)
            let entry = try XCTUnwrap(Array(archive).first)
            XCTAssertEqual(metadata.name, Data(entry.path.utf8))
            XCTAssertEqual(metadata.compressed, entry.compressedSize)
            XCTAssertEqual(metadata.inflated, entry.uncompressedSize)
            XCTAssertEqual(metadata.crc, UInt64(entry.checksum))
            var bytes = 0
            let crc = try archive.extract(entry, bufferSize: 2) {
                guard $0.count <= 5 - bytes else { throw ArchivePreflightProbe.Failure.budget }
                bytes += $0.count
            }
            XCTAssertEqual(bytes, 5)
            XCTAssertEqual(UInt64(crc), metadata.crc)
            XCTAssertLessThanOrEqual(result.largestRead, 65_557)
        }
    }

    func testPreflightRejectsHiddenAndDisagreeingRecordsBeforeExtraction() throws {
        let bad = [Record(flags: 0x801), Record(method: 99),
                   Record(localPatches: [(0, 0, 4)]), Record(localPatches: [(26, 65535, 2)]),
                   Record(centralPatches: [(0, 0, 4)]), Record(centralPatches: [(28, 65535, 2)]),
                   Record(centralPatches: [(42, 0xfffffff0, 4)]),
                   Record(localPatches: [(6, 0x801, 2)]), Record(centralPatches: [(10, 99, 2)]),
                   Record(localPatches: [(18, 1, 4), (22, 1, 4)]), Record(localPatches: [(14, 0, 4)]),
                   Record(localExtra: Data([1, 0, 16, 0, 0])), Record(centralExtra: Data([1, 0, 16, 0, 0])),
                   Record(mode: 0o120777)]
        for record in bad {
            for index in 0..<3 {
                var records = [Record(name: "first"), Record(name: "middle"), Record(name: "last")]
                records[index] = record
                let archive = try open(fixture(records))
                XCTAssertThrowsError(try ArchivePreflightProbe.inspect(archive.url))
                // No extract call can occur before the throwing preflight has returned.
            }
        }
        for patches in [[(8, UInt32(1), 2), (10, 1, 2)], [(12, 1, 4)], [(16, 0xffffffff, 4)]] {
            let archive = try open(fixture([Record(), Record(name: "extra")], endPatches: patches))
            XCTAssertThrowsError(try ArchivePreflightProbe.inspect(archive.url))
        }
        var name = fixture([Record()]); name[30] = 0x78
        XCTAssertThrowsError(try ArchivePreflightProbe.inspect(open(name).url))
        let shared = try open(fixture([Record(), Record(centralPatches: [(42, 0, 4)])]))
        XCTAssertThrowsError(try ArchivePreflightProbe.inspect(shared.url))
    }

    func testPreflightBudgetsCancellationAndUnknownSemanticsRemainGaps() throws {
        let archive = try open(fixture([Record()]))
        XCTAssertThrowsError(try ArchivePreflightProbe.inspect(archive.url, entryLimit: 0)) {
            XCTAssertEqual($0 as? ArchivePreflightProbe.Failure, .budget)
        }
        XCTAssertThrowsError(try ArchivePreflightProbe.inspect(archive.url, metadataLimit: 1)) {
            XCTAssertEqual($0 as? ArchivePreflightProbe.Failure, .budget)
        }
        XCTAssertThrowsError(try ArchivePreflightProbe.inspect(archive.url, cancelled: { true })) {
            XCTAssertEqual($0 as? ArchivePreflightProbe.Failure, .cancelled)
        }
        let unknown = try open(fixture([Record(localExtra: Data([0xfe, 0xca, 0, 0]))]))
        XCTAssertThrowsError(try ArchivePreflightProbe.inspect(unknown.url)) {
            XCTAssertEqual($0 as? ArchivePreflightProbe.Failure, .unresolvedExtra(0xcafe))
        }
        var unix = Data([0x0d, 0, 12, 0]) + Data(count: 12)
        XCTAssertEqual(try ArchivePreflightProbe.inspect(open(fixture([Record(localExtra: unix)])).url).items.count, 1)
        unix[2] = 13; unix.append(0x61)
        XCTAssertThrowsError(try ArchivePreflightProbe.inspect(open(fixture([Record(localExtra: unix)])).url)) {
            XCTAssertEqual($0 as? ArchivePreflightProbe.Failure, .link)
        }
        let asi = try open(fixture([Record(centralExtra: Data([0x6e, 0x75, 0, 0]))]))
        XCTAssertThrowsError(try ArchivePreflightProbe.inspect(asi.url)) {
            XCTAssertEqual($0 as? ArchivePreflightProbe.Failure, .unresolvedExtra(0x756e))
        }
    }
}
