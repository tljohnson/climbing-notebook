import Foundation

// CF-05D research only. Structural metadata is NOT backup validity or extraction permission.
// Unhandled layouts/extra semantics remain explicit capability gaps, not format policy.
enum ArchivePreflightProbe {
    enum Failure: Error, Equatable {
        case truncated, malformed, disagreement, encrypted, method, link
        case unresolvedLayout, unresolvedExtra(UInt64), budget, cancelled
    }

    struct Item {
        let name: Data
        let flags: UInt64
        let method: UInt64
        let creator: UInt64
        let attributes: UInt64
        let local: Range<UInt64>
        let payload: Range<UInt64>
        let descriptor: Range<UInt64>
        let compressed: UInt64
        let inflated: UInt64
        let crc: UInt64
    }

    struct Result {
        let fileBytes: UInt64
        let directory: Range<UInt64>
        let items: [Item]
        let readBytes: Int
        let largestRead: Int
    }

    private final class Reader {
        let handle: FileHandle
        let length: UInt64
        let cancelled: () -> Bool
        var bytes = 0
        var largest = 0

        init(_ url: URL, cancelled: @escaping () -> Bool) throws {
            handle = try FileHandle(forReadingFrom: url)
            do { length = try handle.seekToEnd() }
            catch { try? handle.close(); throw error }
            self.cancelled = cancelled
        }

        deinit { try? handle.close() }

        func read(_ offset: UInt64, _ count: UInt64) throws -> Data {
            if cancelled() { throw Failure.cancelled }
            guard offset <= length, count <= length - offset else { throw Failure.truncated }
            guard count <= 196_605 else { throw Failure.budget }
            try handle.seek(toOffset: offset)
            let data = try handle.read(upToCount: Int(count)) ?? Data()
            guard data.count == Int(count) else { throw Failure.truncated }
            bytes += data.count
            largest = max(largest, data.count)
            return data
        }
    }

    private static func number(_ data: Data, _ offset: Int, _ width: Int) throws -> UInt64 {
        guard offset >= 0, width <= 8, offset <= data.count, width <= data.count - offset else {
            throw Failure.truncated
        }
        return (0..<width).reduce(UInt64(0)) { $0 | UInt64(data[offset + $1]) << (8 * $1) }
    }

    private static func end(_ start: UInt64, _ count: UInt64, within limit: UInt64) throws -> UInt64 {
        guard start <= limit, count <= limit - start else { throw Failure.truncated }
        return start + count
    }

    // Framing is checked even for fields whose semantics are not implemented.
    private static func extras(_ data: Data, reader: Reader) throws -> [UInt64: Data] {
        var result: [UInt64: Data] = [:]
        var position = 0
        while position < data.count {
            if reader.cancelled() { throw Failure.cancelled }
            // Research cardinality budget, not a production extra-field compatibility policy.
            guard result.count < 64 else { throw Failure.budget }
            let id = try number(data, position, 2)
            let count = Int(try number(data, position + 2, 2))
            guard count <= data.count - position - 4, result[id] == nil else { throw Failure.malformed }
            result[id] = data.subdata(in: position + 4..<position + 4 + count)
            position += 4 + count
        }
        return result
    }

    private static func effective(_ original: [UInt64], widths: [Int], extra: Data?) throws -> [UInt64] {
        var values = original
        var position = 0
        for index in values.indices where values[index] == (widths[index] == 4 ? 0xffff : 0xffffffff) {
            guard let data = extra else { throw Failure.malformed }
            values[index] = try number(data, position, widths[index])
            position += widths[index]
        }
        guard position == (extra?.count ?? 0) else { throw Failure.malformed }
        return values
    }

    static func inspect(_ url: URL, entryLimit: Int = 25_000, metadataLimit: Int = 16 * 1024 * 1024,
                        cancelled: @escaping () -> Bool = { false }) throws -> Result {
        guard entryLimit >= 0, metadataLimit >= 0 else { throw Failure.budget }
        let reader = try Reader(url, cancelled: cancelled)
        let tailSize = min(reader.length, 65_557)
        let tailStart = reader.length - tailSize
        let tail = try reader.read(tailStart, tailSize)
        var candidate: Int?
        if tail.count >= 22 {
            for index in 0...tail.count - 22 {
                if index % 1024 == 0, cancelled() { throw Failure.cancelled }
                guard tail[index] == 0x50 else { continue }
                if try number(tail, index, 4) == 0x06054b50,
                   index + 22 + Int(try number(tail, index + 20, 2)) == tail.count {
                    guard candidate == nil else { throw Failure.malformed }
                    candidate = index
                }
            }
        }
        guard let index = candidate else { throw Failure.malformed }
        let eocd = tail.subdata(in: index..<index + 22)
        let eocdOffset = tailStart + UInt64(index)
        guard try number(eocd, 4, 2) == 0, try number(eocd, 6, 2) == 0 else { throw Failure.unresolvedLayout }
        var count = try number(eocd, 10, 2)
        guard try number(eocd, 8, 2) == count else { throw Failure.disagreement }
        var size = try number(eocd, 12, 4)
        var offset = try number(eocd, 16, 4)
        var directoryEnd = eocdOffset
        let locator = eocdOffset >= 20 ? try reader.read(eocdOffset - 20, 20) : Data()
        if locator.count == 20, try number(locator, 0, 4) == 0x07064b50 {
            guard try number(locator, 4, 4) == 0, try number(locator, 16, 4) == 1 else {
                throw Failure.unresolvedLayout
            }
            let zipOffset = try number(locator, 8, 8)
            let zip = try reader.read(zipOffset, 56)
            guard try number(zip, 0, 4) == 0x06064b50, try number(zip, 4, 8) >= 44 else { throw Failure.malformed }
            let zipEnd = try end(zipOffset, 12, within: reader.length)
            guard try end(zipEnd, number(zip, 4, 8), within: reader.length) == eocdOffset - 20 else {
                throw Failure.disagreement
            }
            guard try number(zip, 4, 8) == 44, try number(zip, 16, 4) == 0, try number(zip, 20, 4) == 0 else {
                throw Failure.unresolvedLayout
            }
            let zipCount = try number(zip, 32, 8)
            let zipSize = try number(zip, 40, 8)
            let zipDirectory = try number(zip, 48, 8)
            guard try number(zip, 24, 8) == zipCount,
                  count == 0xffff || count == zipCount,
                  size == 0xffffffff || size == zipSize,
                  offset == 0xffffffff || offset == zipDirectory else { throw Failure.disagreement }
            count = zipCount; size = zipSize; offset = zipDirectory
            directoryEnd = zipOffset
        } else if count == 0xffff || size == 0xffffffff || offset == 0xffffffff { throw Failure.malformed }
        guard count <= UInt64(entryLimit) else { throw Failure.budget }
        guard try end(offset, size, within: reader.length) == directoryEnd else { throw Failure.disagreement }

        var items: [Item] = []
        var cursor = offset
        var retained = 0
        for _ in 0..<count {
            guard try end(cursor, 46, within: directoryEnd) <= directoryEnd else { throw Failure.truncated }
            let cd = try reader.read(cursor, 46)
            guard try number(cd, 0, 4) == 0x02014b50 else { throw Failure.malformed }
            let nameCount = try number(cd, 28, 2), extraCount = try number(cd, 30, 2)
            let variableCount = try nameCount + extraCount + number(cd, 32, 2)
            let next = try end(cursor + 46, variableCount, within: directoryEnd)
            // Encoded-byte accounting only; not a Swift heap allocation/RSS guarantee.
            guard variableCount + 256 <= UInt64(metadataLimit - retained) else { throw Failure.budget }
            retained += Int(variableCount) + 256
            let variable = try reader.read(cursor + 46, variableCount)
            let name = variable.subdata(in: 0..<Int(nameCount))
            let extra = try extras(variable.subdata(in: Int(nameCount)..<Int(nameCount + extraCount)), reader: reader)
            let values = try effective([number(cd, 24, 4), number(cd, 20, 4), number(cd, 42, 4), number(cd, 34, 2)],
                                       widths: [8, 8, 8, 4], extra: extra[1])
            guard values[3] == 0 else { throw Failure.unresolvedLayout }
            let inflated = values[0], compressed = values[1], localOffset = values[2]
            let flags = try number(cd, 8, 2), method = try number(cd, 10, 2), crc = try number(cd, 16, 4)
            let creator = try number(cd, 4, 2), attributes = try number(cd, 38, 4)
            if flags & 0x2041 != 0 { throw Failure.encrypted }
            guard method == 0 || method == 8 else { throw Failure.method }
            guard flags & ~UInt64(0x80e) == 0 else { throw Failure.unresolvedLayout }
            guard try end(localOffset, 30, within: offset) <= offset else { throw Failure.truncated }
            let local = try reader.read(localOffset, 30)
            guard try number(local, 0, 4) == 0x04034b50 else { throw Failure.malformed }
            let localFlags = try number(local, 6, 2)
            if localFlags & 0x2041 != 0 { throw Failure.encrypted }
            guard localFlags == flags, try number(local, 8, 2) == method else { throw Failure.disagreement }
            let localNames = try number(local, 26, 2), localExtras = try number(local, 28, 2)
            let payloadStart = try end(localOffset + 30, localNames + localExtras, within: offset)
            guard localNames + localExtras <= UInt64(metadataLimit - retained) else { throw Failure.budget }
            retained += Int(localNames + localExtras)
            let localVariable = try reader.read(localOffset + 30, localNames + localExtras)
            guard localVariable.prefix(Int(localNames)).elementsEqual(name) else { throw Failure.disagreement }
            let lextra = try extras(localVariable.subdata(in: Int(localNames)..<localVariable.count), reader: reader)
            var localSizes = try [number(local, 22, 4), number(local, 18, 4)]
            if let zipSizes = lextra[1] {
                // APPNOTE 4.5.3 requires BOTH local sizes, unlike conditional CD fields.
                guard zipSizes.count == 16 else { throw Failure.malformed }
                let expanded = try [number(zipSizes, 0, 8), number(zipSizes, 8, 8)]
                for index in 0..<2 {
                    guard localSizes[index] == 0xffffffff || localSizes[index] == expanded[index] else {
                        throw Failure.disagreement
                    }
                }
                localSizes = expanded
            } else if localSizes.contains(0xffffffff) { throw Failure.malformed }
            let payloadEnd = try end(payloadStart, compressed, within: offset)
            var descriptorEnd = payloadEnd
            if flags & 8 != 0 {
                guard try number(local, 14, 4) == 0 || number(local, 14, 4) == crc,
                      localSizes[0] == 0 || localSizes[0] == inflated,
                      localSizes[1] == 0 || localSizes[1] == compressed else { throw Failure.disagreement }
                let width = lextra[1] != nil || extra[1] != nil ? 8 : 4
                var ends: [UInt64] = []
                for signed in [false, true] {
                    let length = UInt64(4 + 2 * width + (signed ? 4 : 0))
                    if payloadEnd <= offset, length <= offset - payloadEnd {
                        let descriptor = try reader.read(payloadEnd, length)
                        let base = signed ? 4 : 0
                        if signed, try number(descriptor, 0, 4) != 0x08074b50 { continue }
                        if try number(descriptor, base, 4) == crc,
                           try number(descriptor, base + 4, width) == compressed,
                           try number(descriptor, base + 4 + width, width) == inflated { ends.append(payloadEnd + length) }
                    }
                }
                guard ends.count == 1 else { throw Failure.disagreement }
                descriptorEnd = ends[0]
            } else {
                guard try number(local, 14, 4) == crc, localSizes == [inflated, compressed] else {
                    throw Failure.disagreement
                }
            }
            if method == 0 && compressed != inflated { throw Failure.disagreement }
            // Raw fields are observable here, but unknown semantic extensions are NOT silently approved.
            for fields in [extra, lextra] {
                for (id, data) in fields where id != 1 {
                    if id == 0x000d {
                        guard data.count >= 12 else { throw Failure.malformed }
                        if data.count > 12 { throw Failure.link }
                        // Timestamp/ownership-only UNIX field; no target/device tail.
                    } else { throw Failure.unresolvedExtra(id) }
                }
            }
            let os = creator >> 8, mode = (attributes >> 16) & 0xf000
            if (os == 3 || os == 19) && mode == 0xa000 { throw Failure.link }
            if (os == 3 || os == 19) && mode != 0x8000 && mode != 0 { throw Failure.unresolvedLayout }
            items.append(Item(name: name, flags: flags, method: method, creator: creator, attributes: attributes,
                              local: localOffset..<payloadStart, payload: payloadStart..<payloadEnd,
                              descriptor: payloadEnd..<descriptorEnd, compressed: compressed, inflated: inflated, crc: crc))
            cursor = next
        }
        guard cursor == directoryEnd else { throw Failure.disagreement }
        var previous: UInt64 = 0
        if cancelled() { throw Failure.cancelled }
        for item in items.sorted(by: { $0.local.lowerBound < $1.local.lowerBound }) {
            if cancelled() { throw Failure.cancelled }
            guard item.local.lowerBound >= previous else { throw Failure.disagreement }
            guard item.local.lowerBound == previous else { throw Failure.unresolvedLayout }
            previous = item.descriptor.upperBound
        }
        guard previous == offset else { throw Failure.unresolvedLayout }
        if cancelled() { throw Failure.cancelled }
        return Result(fileBytes: reader.length, directory: offset..<directoryEnd, items: items,
                      readBytes: reader.bytes, largestRead: reader.largest)
    }
}
