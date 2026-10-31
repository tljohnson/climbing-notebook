# WIP Kanban

## Ready

## In Progress

## Blocked

- [ ] `CF-07D` Add routes with explicit drafts and retained General notes
  - Priority: P0
  - Owner: Kilo/local
  - Blocked by: Owner ended further verification on 2026-10-31; retain tests and resume remaining checks/acceptance only when reprioritized. See [current results](verification/NotebookPrototype.md#cf-07d-current-results).
  - Plan: `../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md` §21.5.1
  - Done when: Existing-area Add/Cancel creates validated UUID routes, explicit General saves survive process relaunch, fixture data/order remains unchanged, required integrity/UI/coverage checks and separate implementation review pass, then owner accepts.

- [ ] `CF-05G` Implement bounded local strict extraction and ZIP64 candidate
  - Priority: P2
  - Owner: Kilo/local
  - Blocked by: Owner paused archive research under §21.4.4; requires explicit reprioritization, not file access. Unused candidate copy removed.
  - Plan: `../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md` §21.4.3
  - Done when: Isolated test-only candidate has traceable pinned provenance, strict-result/ZIP64 acceptance evidence, required simulator/coverage/large checks and separate review, or documented stop-condition blockers; no production adoption or decoder replacement.

- [ ] `CF-05D` Measure test-only bounded structural ZIP preflight
  - Priority: P0
  - Owner: Kilo/local
  - Blocked by: Restore acceptance needs exact compressed-input consumption and extra/layout semantics; research paused under §21.4.4, not a CF-07A prerequisite. See [archive evidence](verification/Archives.md) CF-05D.
  - Plan: `../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md` §21.4.1
  - Done when: Bounded structural probe rejects hostile fixtures before extraction, verifies valid ZIP/ZIP64/descriptor controls and independent large fixtures, records simulator/coverage evidence and stops on unresolved compatibility/link/extraction guarantees.

- [ ] `CF-05B` Bound hostile-entry/header rejection feasibility
  - Priority: P0
  - Owner: Kilo/local
  - Blocked by: Restore acceptance needs complete inspection despite silent enumeration/header gaps; research paused under §21.4.4, not a CF-07A prerequisite. See [archive evidence](verification/Archives.md) CF-05B.
  - Plan: `../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md` §§9.1–9.4, §21.3 F3
  - Done when: Small synthetic hostile fixtures distinguish library behavior from whole-archive policy rejection, expose observability gaps, and record minimum/current focused/full tests, coverage and remaining owner-review gates without production validation claims.

- [ ] `CF-04B` Prove bounded on-disk migration preservation and recovery
  - Priority: P0
  - Owner: Kilo/local
  - Blocked by: Generation/migration recovery needs proven store teardown; not a disposable CF-07A prerequisite. See [persistence evidence](verification/Persistence.md) CF-04B and plan §21.4.4 for sequencing.
  - Plan: `../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md` §6.4, §9.5, §21.3 F2
  - Done when: Test-only synthetic migration preserves IDs, Unicode and relationships after explicit save/reopen; deterministic failure preserves an independent closed generation including sidecars, supports recovery/retry without empty-library fallback, and full minimum/current simulator suites and coverage pass with documented limits.

## Review

- [ ] `CF-07B` Plan and deliver bounded durable fixture notes and pitch order
  - Priority: P0
  - Owner: Kilo/local
  - Depends on: Accepted CF-07A; Leif approved §21.4.5 implementation on 2026-10-29
  - Plan: `../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md` §21.4.5
  - Done when: After explicit implementation approval, fixture route/pitch notes and whole pitch order survive acknowledged saves and relaunch with stable ownership, truthful recoverable failures, required tests/coverage and separate review, then Leif accepts; no broader L2 or migration acceptance.
  - Evidence: [Notebook verification](verification/NotebookPrototype.md); selected phones 65/67 each (only known CF-04B), coverage 97.68% each, iPad26.4 UI 10/10 with orientation warnings; separate final review complete; awaiting Leif's testing.

- [ ] `CF-05F` Choose strict extraction and ZIP64 reconciliation implementation boundary
  - Priority: P0
  - Owner: Kilo/local
  - Depends on: CF-05E evidence; design review only, no dependency/decoder implementation
  - Plan: `../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md` §§21.4.2–21.4.3
  - Done when: Source-backed options, exact proposed API/source changes, maintenance ownership, acceptance matrix and explicit owner approval boundary are recorded for independent review without dependency or production changes.
  - Evidence: Plan §21.4.3; [archive evidence](verification/Archives.md) CF-05F; source/destinations reverified, documentation diff check passes; owner approved bounded CF-05G with Leif maintaining and agent-assisted review; capability evidence remains Review.

- [ ] `CF-05E` Review structural probe and strict extraction result boundary
  - Priority: P0
  - Owner: Kilo/local
  - Depends on: Committed CF-05D; no decoder/fork/dependency expansion
  - Plan: `../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md` §21.4.2
  - Done when: Bounded review findings have executable regressions, public progress/provider workarounds are checked, and strict extraction API requirements and remaining blockers are recorded with simulator/coverage evidence.
  - Evidence: [Archive evidence](verification/Archives.md) CF-05E; probe corrections and three regression methods; focused 17/17 each, full 33/35 each (known CF-04B only), coverage 167/194; `.build/CF05E-large-20261028.log`.

- [ ] `CF-05C` Design the bounded archive preflight feasibility packet
  - Priority: P0
  - Owner: Kilo/local
  - Depends on: Committed CF-05B evidence; owner authorized only the recommended test-only CF-05D spike
  - Plan: `../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md` §21.4.1
  - Done when: Source-backed options, test-only API/data boundary, affected files, hostile/valid acceptance matrix and explicit approval boundary are recorded without dependency or production validator changes.
  - Evidence: Plan §21.4.1; [archive evidence](verification/Archives.md) CF-05C/CF-05D; release/development source inspected without package changes; design awaits independent verification.

- [ ] `CF-05A` Measure bounded ZIP64 and independent-tool interoperability
  - Priority: P0
  - Owner: Kilo/local
  - Depends on: CF-03 archive feasibility baseline; independent of blocked CF-04B
  - Plan: `../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md` §§9.1–9.4, §21.3 F3
  - Done when: Executable test-only streaming harness measures real >4 GiB entry/archive/offset boundaries and bidirectional independent interoperability; minimum/current focused/full tests, coverage and known failures are recorded with cleanup and remaining gates.
  - Evidence: [Archive evidence](verification/Archives.md) CF-05A; `Scripts/test-archive-boundaries.sh`, `.build/CF05A-boundaries-final-20261028.log`; focused 2/2 each, full 18/20 each (only known CF-04B failures), coverage 167/194 (86.08%); owned scratch removed.

## Done

- [x] `CF-07C` Align fixture reading and navigation with approved design
  - Priority: P0
  - Owner: Kilo/local
  - Depends on: Owner approved DESIGN.md and §21.4.6 on 2026-10-30; CF-07B acceptance remains separate
  - Plan: `../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md` §21.4.6
  - Done when: Full General notes, pitch quick access, persistent adjacent-pitch controls and contextual editors preserve existing identities/save contracts, required simulator/accessibility/coverage checks and separate review pass, then owner accepts.
  - Completed: 2026-10-31
  - Evidence: Owner handoff reports human testing passed; accepted commit `423685d`; [Notebook verification](verification/NotebookPrototype.md) CF-07C retains exact automated results and unverified limits. CF-07B acceptance remains separate.

- [x] `CF-07A` Build disposable native notebook interaction prototype
  - Priority: P0
  - Owner: Kilo/local
  - Depends on: Owner-approved prototype-first sequencing exception; no archive or durable storage dependency
  - Plan: `../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md` §21.4.4
  - Done when: Synthetic library/area-to-route flow supports five pitches, note edits and accessible reorder with a visible reset-on-relaunch notice; simulator/test/coverage evidence and Leif's usability review are recorded without durable-save claims.
  - Completed: 2026-10-29
  - Evidence: [Prototype verification](verification/NotebookPrototype.md); Leif's testing passed 2026-10-29, accepted commit `4591da1`; final full 42/44 each (two known CF-04B failures), coverage 865/895 (96.65%), iPad UI 6/6; transient only, M1 incomplete.

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
