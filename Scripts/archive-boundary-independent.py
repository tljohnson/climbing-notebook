"""Synthetic fixtures only. Not an untrusted archive extractor or ZIP validator."""
import hashlib
import json
import os
from pathlib import Path
import struct
import sys
import zipfile
import zlib

CHUNK = 1024 * 1024
SIZE = (1 << 32) + 123
BLOCK = (bytes(range(251)) * (CHUNK // 251 + 1))[:CHUNK]
MARKER = b"CF-05A offset sentinel\n"


def chunks():
    remaining = SIZE
    while remaining:
        data = BLOCK[:min(CHUNK, remaining)]
        yield data
        remaining -= len(data)


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def extras(data):
    fields = {}
    while data:
        require(len(data) >= 4, "truncated extra field")
        tag, size = struct.unpack_from("<HH", data)
        require(len(data) >= size + 4, "truncated extra payload")
        fields[tag] = data[4:4 + size]
        data = data[4 + size:]
    return fields


def verify(path, stored):
    expected = hashlib.sha256()
    expected_crc = 0
    for data in chunks():
        expected.update(data)
        expected_crc = zlib.crc32(data, expected_crc)
    with zipfile.ZipFile(path) as archive, open(path, "rb") as raw:
        require(archive.namelist() == ["synthetic.bin", "after.txt"], "names/count/order")
        records = []
        for info in archive.infolist():
            big = info.filename == "synthetic.bin"
            target = SIZE if big else len(MARKER)
            require(info.file_size == target, "uncompressed metadata size")
            require(info.compress_type == (zipfile.ZIP_STORED if stored or not big else zipfile.ZIP_DEFLATED),
                    "compression method")
            count, crc, digest = 0, 0, hashlib.sha256()
            # Read to EOF so zipfile also performs its own CRC check. No disk extraction.
            with archive.open(info) as entry:
                while True:
                    data = entry.read(CHUNK)
                    if not data:
                        break
                    count += len(data)
                    require(count <= target, "inflated limit")
                    digest.update(data)
                    crc = zlib.crc32(data, crc)
            require(count == target and crc == info.CRC, "stream count/CRC")
            require(crc == (expected_crc if big else zlib.crc32(MARKER)), "expected CRC")
            require(digest.hexdigest() == (expected.hexdigest() if big else hashlib.sha256(MARKER).hexdigest()),
                    "SHA-256 identity")
            central_extra = extras(info.extra)
            raw.seek(info.header_offset)
            local = raw.read(30)
            require(local[:4] == b"PK\x03\x04", "local header signature")
            method = struct.unpack_from("<H", local, 8)[0]
            compressed32, uncompressed32, name_len, extra_len = struct.unpack_from("<IIHH", local, 18)
            raw.read(name_len)
            local_extra = extras(raw.read(extra_len))
            require(method == info.compress_type, "local method")
            if big:
                require(1 in central_extra and 1 in local_extra and info.extract_version >= 45,
                        "genuine ZIP64 entry fields")
                require(uncompressed32 == 0xffffffff, "local uncompressed sentinel")
                require(struct.unpack_from("<Q", local_extra[1])[0] == SIZE, "local ZIP64 size")
            if stored and not big:
                require(info.header_offset > (1 << 32) and 1 in central_extra, "ZIP64 later-entry offset")
            records.append(dict(name=info.filename, uncompressed=info.file_size, compressed=info.compress_size,
                                header_offset=info.header_offset, crc32=f"{crc:08x}", sha256=digest.hexdigest(),
                                method=method, central_extra=info.extra.hex(),
                                local_extra={str(k): v.hex() for k, v in local_extra.items()},
                                local_compressed32=compressed32, local_uncompressed32=uncompressed32))
        # Bounded tail inspection, not a general ZIP parser. These fixtures have no comment.
        raw.seek(-22, os.SEEK_END)
        eocd = raw.read(22)
        require(eocd[:4] == b"PK\x05\x06", "EOCD signature")
        cd_offset32 = struct.unpack_from("<I", eocd, 16)[0]
        cd_offset = cd_offset32
        if stored:
            require(path.stat().st_size > (1 << 32) and cd_offset32 == 0xffffffff, "archive/CD boundary")
            raw.seek(-42, os.SEEK_END)
            locator = raw.read(20)
            require(locator[:4] == b"PK\x06\x07", "ZIP64 locator")
            zip64_offset = struct.unpack_from("<Q", locator, 8)[0]
            raw.seek(zip64_offset)
            record = raw.read(56)
            require(record[:4] == b"PK\x06\x06", "ZIP64 EOCD")
            count, cd_size, cd_offset = struct.unpack_from("<QQQ", record, 32)
            require(count == 2 and cd_offset > (1 << 32) and cd_size < CHUNK, "ZIP64 CD metadata")
        else:
            require(path.stat().st_size < (1 << 32), "compressible fixture is NOT a large archive")
        print(json.dumps(dict(archive=path.name, total_bytes=path.stat().st_size,
                              cd_offset=cd_offset, entries=records)), flush=True)


root = Path(sys.argv[1])
print(f"Independent implementation: Python {sys.version}; zipfile stdlib; zlib {zlib.ZLIB_VERSION}", flush=True)
for stored in (True, False):
    suffix = "stored" if stored else "deflated"
    verify(root / f"swift-{suffix}.zip", stored)
    path = root / f"python-{suffix}.zip"
    with zipfile.ZipFile(path, "w", allowZip64=True) as archive:
        info = zipfile.ZipInfo("synthetic.bin", date_time=(2026, 1, 1, 0, 0, 0))
        info.file_size = SIZE
        info.compress_type = zipfile.ZIP_STORED if stored else zipfile.ZIP_DEFLATED
        with archive.open(info, "w", force_zip64=True) as entry:
            for data in chunks():
                entry.write(data)
        archive.writestr("after.txt", MARKER, compress_type=zipfile.ZIP_STORED)
    verify(path, stored)
print("PASS independent ZIP64 metadata, streamed content and bidirectional fixtures", flush=True)
