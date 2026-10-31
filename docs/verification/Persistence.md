# Persistence and URL Policy Verification

Updated: 2026-10-31

## Conclusion

The diagnostic `LibraryStore`/generation components remain feasibility harnesses, not a production library or restore service. CF-07B separately implements a bounded ordinary SwiftData save/relaunch slice for synthetic route notes, pitch notes and pitch order. CF-04A established bounded in-process recovery behavior; CF-04B migration preservation and independent closed-generation recovery remain unproven. Ordinary-slice results do not accept migration, generation replacement or valuable-data safety. [Plan §§6.4, 9.5 and 21](../../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md) own contracts and sequencing; [Kanban](../WIP_KANBAN.md) owns status.

## Ordinary Fixture Store

`NotebookSchemaV1` is a separate versioned five-entity slice; it neither changes `LibrarySchemaV1` nor adopts retained diagnostic stores. `NotebookStore` owns only app-private `Application Support/NotebookFixtureSlice/Libraries/<fixed-UUID>/notebook.store`. It initializes a genuinely absent namespace once, saves fixtures/marker together, disables autosave/CloudKit, validates the entire fixed-ID graph and rejects missing/corrupt/partial existing stores without reset/reseed. Symlink checks prevent redirection within that namespace. No complete notebook schema, migration stages, generation replacement, copying or archive work is included.

Commands validate ownership, route revision, exact sibling-ID permutation and 1 MiB UTF-8 note limits before explicit save. Exact byte changes increment revision; unchanged commands do not save or invent acknowledgment. View editors hold plain snapshots, not persistent models. Errors retain their buffers and the last acknowledged snapshots. iOS 17 required insert-before-link initialization and a fresh autosave-disabled ModelContext on the same container after processPendingChanges/rollback; the focused rollback/retry assertions remain active and pass. This does not close/release a container or alter the CF-04B boundaries.

Focused on-disk/state checks include UUID ownership/order round trips, repeated loading, empty/Unicode/byte-limit cases, invalid orders/graphs, stale revisions, staged rollback/retry, missing/corrupt stores, initialization failure and namespace isolation. Actual process terminate/relaunch proof and consolidated runtime results are in [NotebookPrototype.md](NotebookPrototype.md). Fault injection proves application rollback/retry handling, not real ENOSPC or power-loss durability. Temporary diagnostic/test stores are retained rather than deleted while contexts may be alive. Physical-device file protection/backup, crash/power-loss durability and incomplete-initialization repair remain unverified/unimplemented.

## CF-07D Creation Boundary

The owner approved §21.5.1 on 2026-10-31. The implementation extends `NotebookStore` in place: UUID-valued snapshots/commands, name-only creation of additional routes in either existing area, one General section and zero pitches. `NotebookSchemaV1`, version `1.0.0`, marker `CF-07B-1`, slice path and ModelContainer configuration are unchanged; no migration or diagnostic-store adoption is performed. Fixed area/route/note/pitch identities, immutable fixture metadata and ownership remain mandatory. Validation checks global UUID uniqueness, fetched/inverse ownership sets, General shape, bounded content, revisions and exact fixture pitch membership with persisted contiguous order. Existing note bytes and pitch order are saved content, not initialization defaults.

Draft UUIDs survive validation/save errors. Creation rejects reserved IDs before idempotent matching, validates/prepares the snapshot before explicit save, and returns success only after commit. Exact repeat of an unedited nonfixture pair returns the acknowledged snapshot without another insert; collisions/differing retries fail rather than upsert. Failure rolls back and replaces the context on the same container. Existing absent-root-only initialization and retained incomplete/corrupt-store behavior remain in force. Older fixture-only binaries reject added routes; this does not establish downgrade compatibility or full-library adoption.

Verification was paused at owner direction on 2026-10-31 with tests retained, not accepted. The focused iOS27 bundle passed all 22 persistence and 11 state tests, including a direct predecessor-format V1 graph writer with independently fixed IDs/marker, distinctive Unicode bytes/revisions and reversed pitch order, followed by in-place create/edit/reopen assertions. The predecessor container is deliberately retained; this is ordinary unchanged-format preservation, not a closed-generation/migration lifetime claim. Exact completed UI evidence and unrun full-suite/coverage/tablet checks are recorded in [CF-07D current results](NotebookPrototype.md#cf-07d-current-results). Personal data, actual ENOSPC, power-loss durability and release readiness remain out of scope.

## Recovery Baseline

`LibraryGenerationManager.swift` rejects initialization/replacement over pending recovery and same-generation journals. `PersistenceFoundationTests.swift` covers prepared, descriptor-switched-before-journal-update and switched interruption checkpoints; invalid replacement metadata; corrupt/missing stores and fallbacks; repeated recovery; and retry after fixture repair. Serialized journal phases remain `prepared`/`switched`, distinct from injected checkpoints.

Recorded CF-04A evidence (2026-10-28, Xcode 27.1): 19/19 unit/UI tests on iOS 17.0 and 27.0, combined app/extension coverage 167/194 (86.08%). Bundles: `.build/GenerationRecoveryFinal-iOS17-20261028.xcresult` and `GenerationRecoveryFinal-iOS27-20261028.xcresult`. This is thrown-interruption testing in one process, not actual termination, power-loss/fsync or production restore proof.

## Migration Blocker

`MigrationFeasibilityTests.swift` uses related synthetic schemas, stable IDs, byte-exact Unicode and relationships, explicit post-migration saves/reopens, deterministic migration rejection and whole-generation preservation/recovery/retry assertions. Keep every assertion active:

- `testFailedMigrationRecoversAndRetriesFromIndependentClosedGeneration`
- `testOnDiskSyntheticMigrationPreservesRelationshipsAndSavedChangesAfterReopen`

An autorelease pool, `processPendingChanges()` and a condition-driven one-second release window did not reliably release containers/contexts. Tests fail closed at lifetime barriers, retain diagnostic directories (paths attached to results) and abort unsafe copy/move/delete operations. A weak-reference release check alone would not prove SQLite connection closure. Initial exploratory cleanup emitted `vnode unlinked while in use` warnings; do not treat scope exit as closed-generation proof or clean these diagnostic stores casually.

Final CF-07B full-suite evidence is linked in [NotebookPrototype.md](NotebookPrototype.md#decisive-evidence): 65/67 pass on each selected phone, zero skipped/runtime warnings; combined coverage is 1558/1595 (97.68%) each. iOS 17 fails both tests at ModelContainer lifetime barriers; final iOS 27.0 fails both at ModelContext barriers (failed migration context and snapshot/reopen context). Earlier iOS 27.1 failed recovery reached a **26-versus-23-byte assertion**, while migrated-store reopen failed its ModelContext barrier. These are the same failing test identities, not identical runtime assertions. No migration implementation/assertions changed; migration acceptance remains blocked. Selected iPad (10th generation)/iOS 26.4 UI passed 10/10 with orientation warnings retained in the linked evidence. Ordinary fixture-save success does not establish migration or full-library safety.

Original isolated CF-04B evidence: `.build/MigrationSafetyFinal-iOS17-20261028.xcresult` and `MigrationSafetyFinal-iOS27_1-20261028.xcresult`, 18/20 passed each, 0 skipped, coverage167/194 (86.08%). Those runs stopped at container/context barriers. Synthetic migration evidence is not released-schema compatibility. Independent post-migration reopen, closed-generation snapshot, failed-migration recovery/retry and actual process-termination recovery remain gates.

## URL Policy Finding

`URLPolicyFeasibilityTests.swift` loads synthetic HTML in a nonpersistent WebKit session, captures text and serves a synthetic image without external network access. An image subresource request occurred without a navigation-delegate decision. A top-level delegate therefore cannot establish private-subresource, DNS, redirect or size protections. Selected-media transfer and bounded public-network rendering are not proven. Production URL copying remains blocked pending an owner-reviewed enforceable design; the plan's bounded public-HTML alternative is not implemented or a scope removal.

## Reproduction and Stop Rules

Use [README test/coverage commands](../../README.md#build-and-test) with freshly verified iOS 17/current destinations and new paths. Add `-only-testing:ClimbingNotebookTests/MigrationFeasibilityTests`, `PersistenceFoundationTests` or `URLPolicyFeasibilityTests` as appropriate (each as a full `-only-testing:ClimbingNotebookTests/<class>` argument). Inspect result summaries and retained directory attachments; coverage success does not establish behavioral acceptance.

Do not copy a live generation, weaken lifetime assertions, silently switch to Core Data or investigate process boundaries under an unrelated packet. A sequential-process fixture handoff with confirmed exit and retention-path inspection was proposed, not implemented; an explicit-close fallback would require review. Under §§21.4.4-21.4.5 these gaps gate generation replacement/migration recovery, not the separately approved ordinary fixture-save slice. M1 remains incomplete.
