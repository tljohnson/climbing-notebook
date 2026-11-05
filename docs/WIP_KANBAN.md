# WIP Kanban

Updated: 2026-11-05

Historical prototype cards, completed work and deferred archive/migration investigations are preserved in the [2026-11-05 archive](WIP_KANBAN_ARCHIVE_2026-11-05.md). Archived unchecked work is not complete or an active blocker. Current acceptance follows plan §21.6.8; coverage percentages and audit flags alone are not MVP gates.

## Ready

- [ ] `TN-EXPORT-01` Plan a bounded text-only notebook export
  - Priority: P1
  - Owner: Unassigned
  - Depends on: Verify updated hosted CI first; export implementation requires approval of the bounded contract.
  - Plan: `../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md` §21.7
  - Done when: A concise export contract covers complete ordered hierarchy/full notes, native sharing, source/save boundaries, file format, failures and focused tests; owner approves implementation scope.

## In Progress

## Blocked

## Review

- [ ] `CF-07E` Deliver the complete text-first notebook milestone
  - Priority: P0
  - Owner: Kilo/local
  - Depends on: Verify latest hosted unit/smoke jobs after environment and stable-list fixes, then explicit owner milestone acceptance.
  - Plan: `../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md` §§21.6,21.6.8
  - Done when: Current notebook functionality and saved-data integrity pass the fast MVP gate, relevant UI checks and honest limits are recorded, then owner accepts.
  - Evidence: [Notebook verification](verification/NotebookPrototype.md#conclusion); local fast77/77 and subsequent smoke2/2; owner light/dark regular/maximum-text workflows passed. Hosted units passed; prior smoke failures remain pending hosted revalidation. VoiceOver untested; no backup/restore.

## Done

Prior completion records are preserved in the dated archive. Do not mark deferred/superseded research Done to clear the board.
