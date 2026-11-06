# WIP Kanban

Updated: 2026-11-06

Historical prototype cards, completed work and deferred archive/migration investigations are preserved in the [2026-11-05 archive](WIP_KANBAN_ARCHIVE_2026-11-05.md). Archived unchecked work is not complete or an active blocker. Current acceptance follows plan §21.6.8; coverage percentages and audit flags alone are not MVP gates.

## Ready

## In Progress

## Blocked

## Review

- [ ] `TN-IMAGE-01` Plan image-supported route and pitch notebooks
  - Priority: P1
  - Owner: Kilo/local
  - Depends on: None; owner-authorized planning and Stitch exploration only.
  - Plan: [Image-Supported-Notebooks-FeaturePlan.md](../Image-Supported-Notebooks-FeaturePlan.md) §§1–6 (proposed, unapproved)
  - Done when: Source-grounded image/storage/Save contract and visually reviewed Stitch journey are ready for explicit owner approval before implementation.
  - Evidence: [Proposed image contract](../Image-Supported-Notebooks-FeaturePlan.md#1-selected-journey-and-scope), [Stitch comparison/references](../Image-Supported-Notebooks-FeaturePlan.md#6-proposed-image-notebook-exploration); documentation checks passed; owner approval pending, no app implementation.

- [ ] `CF-07E` Deliver the complete text-first notebook milestone
  - Priority: P0
  - Owner: Kilo/local
  - Depends on: Explicit owner milestone acceptance.
  - Plan: `../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md` §§21.6,21.6.8
  - Done when: Current notebook functionality and saved-data integrity pass the fast MVP gate, relevant UI checks and honest limits are recorded, then owner accepts.
  - Evidence: [Notebook verification](verification/NotebookPrototype.md#conclusion); [hosted run42130921302](https://github.com/tljohnson/climbing-notebook/actions/runs/42130921302) at `d742ea6`, both routine jobs passed; local fast77/77 and subsequent smoke2/2; owner light/dark regular/maximum-text workflows passed. VoiceOver untested; no backup/restore; milestone acceptance pending.

## Done

- [x] `TN-EXPORT-01` Plan a bounded text-only notebook export
  - Priority: P1
  - Owner: Kilo/local
  - Depends on: None; CI handoff closed and export contract approved.
  - Plan: `../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md` §21.7
  - Done when: A concise export contract covers complete ordered hierarchy/full notes, native sharing, source/save boundaries, file format, failures and focused tests; owner approves implementation scope.
  - Completed: 2026-11-06
  - Evidence: [Approved export contract](../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#217-text-only-notebook-export-contract-approved); explicit owner approval in planning session; documentation diff check passed. Export implementation not started.

Prior completion records are preserved in the dated archive. Do not mark deferred/superseded research Done to clear the board.
