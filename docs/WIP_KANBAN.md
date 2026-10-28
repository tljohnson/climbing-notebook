# WIP Kanban

## Ready

- [ ] `CF-05G` Implement bounded local strict extraction and ZIP64 candidate
  - Priority: P0
  - Owner: Unassigned
  - Depends on: Explicit owner approval recorded in plan §21.4.3; Leif maintains, separate agent-assisted review
  - Plan: `../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md` §21.4.3
  - Done when: Isolated test-only candidate has traceable pinned provenance, strict-result/ZIP64 acceptance evidence, required simulator/coverage/large checks and separate review, or documented stop-condition blockers; no production adoption or decoder replacement.

## In Progress

## Blocked

- [ ] `CF-05D` Measure test-only bounded structural ZIP preflight
  - Priority: P0
  - Owner: Kilo/local
  - Blocked by: Owner/independent review of exact compressed-input consumption and unresolved extra/layout semantics; see `../README.md` CF-05D for passing bounded matrix/large probe and retained counterexample.
  - Plan: `../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md` §21.4.1
  - Done when: Bounded structural probe rejects hostile fixtures before extraction, verifies valid ZIP/ZIP64/descriptor controls and independent large fixtures, records simulator/coverage evidence and stops on unresolved compatibility/link/extraction guarantees.

- [ ] `CF-05B` Bound hostile-entry/header rejection feasibility
  - Priority: P0
  - Owner: Kilo/local
  - Blocked by: Owner review of strict preflight capability for silent enumeration/header-observability gaps; bounded matrix awaits independent verification. See `../README.md` CF-05B and `ClimbingNotebookTests/ArchiveHostileFeasibilityTests.swift`.
  - Plan: `../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md` §§9.1–9.4, §21.3 F3
  - Done when: Small synthetic hostile fixtures distinguish library behavior from whole-archive policy rejection, expose observability gaps, and record minimum/current focused/full tests, coverage and remaining owner-review gates without production validation claims.

- [ ] `CF-04B` Prove bounded on-disk migration preservation and recovery
  - Priority: P0
  - Owner: Kilo/local
  - Blocked by: Owner review of reproducible SwiftData teardown failure; see `../README.md` CF-04B evidence and proposed test-only process-boundary investigation.
  - Plan: `../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md` §6.4, §9.5, §21.3 F2
  - Done when: Test-only synthetic migration preserves IDs, Unicode and relationships after explicit save/reopen; deterministic failure preserves an independent closed generation including sidecars, supports recovery/retry without empty-library fallback, and full minimum/current simulator suites and coverage pass with documented limits.

## Review

- [ ] `CF-05F` Choose strict extraction and ZIP64 reconciliation implementation boundary
  - Priority: P0
  - Owner: Kilo/local
  - Depends on: CF-05E evidence; design review only, no dependency/decoder implementation
  - Plan: `../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md` §§21.4.2–21.4.3
  - Done when: Source-backed options, exact proposed API/source changes, maintenance ownership, acceptance matrix and explicit owner approval boundary are recorded for independent review without dependency or production changes.
  - Evidence: Plan §21.4.3; `../README.md` CF-05F; source/destinations reverified, documentation diff check passes; owner approved bounded CF-05G with Leif maintaining and agent-assisted review; capability evidence remains Review.

- [ ] `CF-05E` Review structural probe and strict extraction result boundary
  - Priority: P0
  - Owner: Kilo/local
  - Depends on: Committed CF-05D; no decoder/fork/dependency expansion
  - Plan: `../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md` §21.4.2
  - Done when: Bounded review findings have executable regressions, public progress/provider workarounds are checked, and strict extraction API requirements and remaining blockers are recorded with simulator/coverage evidence.
  - Evidence: `../README.md` CF-05E; probe corrections and three regression methods; focused 17/17 each, full 33/35 each (known CF-04B only), coverage 167/194; `.build/CF05E-large-20261028.log`.

- [ ] `CF-05C` Design the bounded archive preflight feasibility packet
  - Priority: P0
  - Owner: Kilo/local
  - Depends on: Committed CF-05B evidence; owner authorized only the recommended test-only CF-05D spike
  - Plan: `../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md` §21.4.1
  - Done when: Source-backed options, test-only API/data boundary, affected files, hostile/valid acceptance matrix and explicit approval boundary are recorded without dependency or production validator changes.
  - Evidence: Plan §21.4.1; `../README.md` CF-05C/CF-05D; release/development source inspected without package changes; design awaits independent verification.

- [ ] `CF-05A` Measure bounded ZIP64 and independent-tool interoperability
  - Priority: P0
  - Owner: Kilo/local
  - Depends on: CF-03 archive feasibility baseline; independent of blocked CF-04B
  - Plan: `../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md` §§9.1–9.4, §21.3 F3
  - Done when: Executable test-only streaming harness measures real >4 GiB entry/archive/offset boundaries and bidirectional independent interoperability; minimum/current focused/full tests, coverage and known failures are recorded with cleanup and remaining gates.
  - Evidence: `../README.md` CF-05A; `Scripts/test-archive-boundaries.sh`, `.build/CF05A-boundaries-final-20261028.log`; focused 2/2 each, full 18/20 each (only known CF-04B failures), coverage 167/194 (86.08%); owned scratch removed.

## Done

- [x] `CF-04A` Harden the generation recovery feasibility matrix
  - Priority: P0
  - Owner: Kilo/local
  - Depends on: Existing CF-03 foundation harness
  - Plan: `../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md` §9.5, §21.3 F2
  - Done when: Pending recovery cannot be overwritten; descriptor/journal interruption and invalid-generation cases pass on on-disk stores; minimum/current simulator results and coverage are recorded without claiming production restore readiness.
  - Completed: 2026-10-28
  - Evidence: `LibraryGenerationManager.swift`, `PersistenceFoundationTests.swift`, `.build/GenerationRecoveryFinal-iOS17-20261028.xcresult` and `.build/GenerationRecoveryFinal-iOS27-20261028.xcresult` (19 tests each, 167/194 lines, 86.08%); coverage rejection self-test passes.

- [x] `DEV-001` Establish neutral development identity
  - Priority: P1
  - Owner: Kilo/local
  - Depends on: None
  - Plan: `../FeaturePlan.md`
  - Done when: Current source, paths, display settings, and documentation use the development identity; simulator tests and coverage pass; repository path changes are verified or explicitly handed off.
  - Completed: 2026-10-28
  - Evidence: `ClimbingNotebook.xcodeproj`, `.build/DevelopmentIdentityFinal.xcresult` (11 tests, 82.70% coverage), `Scripts/check-coverage.sh --self-test`; local checkout/worktree repair verified, hosted-repository rename handed off.
