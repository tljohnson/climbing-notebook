# Archive Feasibility Verification

Updated: 2026-10-29

## Conclusion and Boundary

Archive research is **paused** under [plan §21.4.4](../../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#2144-owner-approved-prototype-first-reset). Do not resume CF-05G without explicit reprioritization. Bounded ZIP64 interoperability works on the host, but complete hostile-archive inspection, exact extraction consumption and compatibility guarantees remain unproven. These gate production restore, not the transient notebook or ordinary save/relaunch. [Kanban](../WIP_KANBAN.md) retains separate Review/Blocked statuses; no CF-05/M1 acceptance is implied.

ZIPFoundation 0.9.20 revision `22787ffb59de99e5dc1fbfe80b19c97a904ad48d` is linked only to unit tests. The structural preflight and host driver are research-only. No production parser, strict extraction API, fork candidate or alternative decoder is implemented. The unused byte-identical CF-05G source copy was removed; the earlier read-only file mode issue was not a capability or permission-policy blocker. Leif remains maintainer with separate agent-assisted review, not an independent human security audit. Plans §§21.4.1-21.4.3 retain design/ownership/approval contracts, superseded only in immediate sequencing by §21.4.4.

## Decisive Counterexamples

Tests: `ArchiveFeasibilityTests.swift`, `ArchiveHostileFeasibilityTests.swift`, `ArchivePreflightFeasibilityTests.swift`; research probe: `ArchivePreflightProbe.swift`. These are deterministic synthetic fixtures, not valid product backups.

| Capability | Observed Evidence | Consequence |
| --- | --- | --- |
| Complete enumeration | Central encryption and malformed records silently end iteration at a safe prefix; false EOCD count hides a valid tail. Manual next after nil can expose later records | Visible names/counts cannot authorize whole-archive acceptance |
| Header reconciliation | Local/central encryption, methods, names, sizes/CRC can disagree while extraction returns correct visible bytes; malformed ZIP64 extras can fall back to ordinary fields | Raw records and explicit comparison are required |
| Exact DEFLATE consumption | `cb48cdc9c90700dead` returns `hello` with correct CRC; concatenated streams also return the first stream. Progress5/5 and provider read-ahead do not prove input consumption at buffers2/7/32 | Require consumed bytes and explicit stream end; do not infer from output or supplied bytes |
| ZIP64 zero offset | Central offset sentinel expanded to zero is valid to the structural probe but omitted by library iteration | Presence must be distinct from zero; removing a numeric guard alone is insufficient |
| Descriptor width | Local-only ZIP64 extra with 64-bit descriptor and ordinary central header yields inflated size5 structurally but0 publicly | Width/interpretation must reconcile local and central evidence |
| Links and extras | Public types expose symlink/directory, not general hard links. UNIX0x000d target/device tails reject; ASi0x756e/unknown0xcafe remain unresolved | Symlink rejection is not complete link safety; no blanket production extra allowlist approved |
| Memory-backed hostile offset | `Archive(data:)` iteration with out-of-range local offset traps in `Archive+MemoryFile.swift` | Routine hostile fixtures use file-backed input; memory-backed safety not established |

Observable-entry policy rejects exact/case collisions, unsafe separators/components, non-NFC names using UTF-8 bytes, unexpected namespaces, symlink/directory entries, CRC mismatches, truncated DEFLATE and count/per-file/aggregate overruns. Understated sizes cannot evade consumer budgets. This is policy for returned entries, not whole-archive validity. Routine fixtures use small limits, not reductions of approved25,000-entry/64MiB-manifest/5GiB-originals limits.

For targeted source reinspection at the pinned revision: `Archive.swift:218-255` nonthrowing iteration and `233-244` descriptor selection; `Entry.swift:218-228,299-315` optional entry/zero handling; `Entry+Serialization.swift:43-68,115-149` separate records; `Entry+ZIP64.swift:25-33,83-125,143-160` presence/parsing/serialization; `Archive+Reading.swift:86-118` local method and returned CRC; `Data+Compression.swift:103-149,217-258` discarded residual input. Reverify line references before modifying a different revision. Development HEAD `e7a17d57c583067eaa6659cd6d9521265b7664e9` was source-inspected, not built; no sufficient strict capability was found. No alternative library was audited/selected.

The memory-backed trap can be recreated only in an isolated diagnostic process by iterating `fixture([Record(name: "safe.txt"), Record(centralPatches: [(42, 0xfffffff0, 4)]), Record(name: "tail.txt")])` via `Archive(data:accessMode: .read)` using the hostile-test helpers. Initial evidence: `.build/CF05B-focused-iOS17-20261028.xcresult`, `CF05B-initial-crash.ips`. Do not deliberately crash routine tests or mistake the file-backed silent prefix for a security fix.

## Structural Probe Limits

The throwing test-only probe accounts for EOCD/ZIP64 directory count/extent, central/local bounds and raw fields, framed extras, descriptors and overlapping spans. Valid stored/fixed-deflate/UTF-8 and signed/unsigned ordinary/ZIP64 descriptor controls pass; truncated descriptors reject. Fourteen hostile variants at first/middle/last positions (42 fixtures), false counts, bad directory bounds, local-name mismatch and repeated local references reject before extraction.

Default research budgets:25,000 entries,16MiB encoded metadata accounting, maximum read196,605 bytes and tail<=65,557. These are not measured heap ceilings or production compatibility limits. A64-field per-area research cardinality cap rejects the16,383-zero-length-extra amplification fixture before dictionary insertion. Cancellation is checked during inspection/tail scanning/per-extra work and before/after bounded sorting; sorting itself is not interruptible. Results are metadata, not a validation token or extraction permission.

Unresolved prefix/gap/trailing layouts, optional structures, unknown flags/extras, ambiguous EOCDs, CRC equal to descriptor signature, ZIP64 extensible records and independent nonseekable producers cannot silently become production rejection rules. Immutable/coordinated input ownership, full memory envelope, manifest/DTO/hash/type policy and adversarial concurrent writes remain separate requirements. Strict success must distinguish declared, supplied/read-ahead, consumed and inflated counts; require exact payload consumption and DEFLATE END (or exact stored-span completion), matching size/CRC, and error propagation. Valid final-byte padding must remain compatible. No mock interface or app-side decoder closes these gaps.

## Large Boundary Evidence

`Scripts/test-archive-boundaries.sh --run-large` compiles the pinned sources with `swiftc -O` on arm64 macOS, streams hashes without extracting payloads, and cross-checks Swift/Python stored/deflated archives in both directions. Input:1MiB blocks with byte `i % 251`, final123 bytes, plus23-byte `after.txt`. Checks use throwing assertions/explicit Python exceptions even under optimization.

| Measurement, Both Producers | Stored | Deflated |
| --- | --- | --- |
| Uncompressed synthetic entry | 4,294,967,419 | 4,294,967,419 |
| Compressed payload | 4,294,967,419 | 16,679,879 |
| Total archive | 4,294,967,788 | 16,680,160 |
| Later local-header offset | 4,294,967,482 | 16,679,942 |
| Central-directory offset | 4,294,967,544 | 16,680,004 |

Only stored fixtures prove >4GiB archive/compressed-offset boundaries; deflated fixtures prove the uncompressed-entry boundary. Entry CRC `4b25e7b2`, SHA256 `ed141705a19857db331456a65eab9c7a523adb4aaebc0d07ea095654f458147b`; sentinel CRC `2b7ff766`, SHA256 `99421c43f7d22113370f9122bf3a7671e10334c06939ce3e558cef7debc5fb5c`.

Host environment: Xcode27.1 (`27A9275`), Swift6.4, macOS27.2 arm64; installed Python3.9.6 `zipfile`/zlib1.2.12, application chunks<=1MiB. Initial host maxima: Swift create/self-read12,582,912 bytes RSS/15.60s, Python38,535,168/19.30s, Swift independent-read13,352,960/5.76s; not iPhone memory/performance proof. Latest CF-05E rerun structural reads65,881 stored/65,813 deflated bytes, max request65,557; reported host RSS6,504,448 bytes, not encoded-budget proof. Owned scratch was trap-cleaned and absence verified; only ignored results/logs remain. No large fixture is committed.

Unproven: large iOS/device runs; full5GiB/5,000-asset/25,000-entry/64MiB-manifest envelope; aggregate crossing with ordinary assets; exactUInt32 transitions; >4GiB incompressible deflate; broad descriptors/producers; large cancellation/low-disk behavior and hostile manifest/header/type acceptance.

## Verification and Reproduction

Latest archive-specific execution (CF-05E,2026-10-28): focused17/17 each on iOS17.0 and27.1; full33/35 each, only the two CF-04B lifetime failures,0 skipped; combined coverage167/194 (86.08%) each. Rejection self-test/diff check passed. Bundles: `.build/CF05E-focused-final-iOS17-20261028.xcresult`, `CF05E-focused-final-iOS27_1-20261028.xcresult`, `CF05E-full-final-iOS17-20261028.xcresult`, `CF05E-full-final-iOS27_1-20261028.xcresult`; stdout/stderr use matching `.log` basenames. Large rerun: `.build/CF05E-large-20261028.log`; original boundary details: `CF05A-boundaries-final-20261028.log`. Later full-suite runs are in [NotebookPrototype.md](NotebookPrototype.md#decisive-evidence); no new large probe was required by the UI packet.

If explicitly assigned to resume archive verification, use [README commands](../../README.md#build-and-test), fresh paths and these focused selections:

```sh
SIMULATOR_ID=<verified-UUID> RESULT_BUNDLE_PATH=<new.xcresult> bash Scripts/test-ios.sh -quiet -only-testing:ClimbingNotebookTests/ArchiveHostileFeasibilityTests -only-testing:ClimbingNotebookTests/ArchiveFeasibilityTests -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120 -collect-test-diagnostics never
CF05D_PREFLIGHT=1 bash Scripts/test-archive-boundaries.sh --run-large
```

The large harness requires the existing resolved checkout, >=16GiB free and about8.03GiB logical fixture space; installs nothing, checks pinned/clean sources and cleans only owned scratch on exit. An existing stale cached object-alternate warning was observed despite successful read-only verification; do not patch dependency metadata as incidental cleanup. Re-run large probes when archive/shared-harness/dependency code changes, not for unrelated UI/docs. Archived local artifacts may not exist in another checkout; source tests and these bounded conclusions remain the reproducible reference.
