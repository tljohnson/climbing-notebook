# WIP Kanban

## Ready

## In Progress

## Blocked

## Review

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
