# Persistence and URL Policy Verification

Updated: 2026-10-29

## Conclusion

The SwiftData/generation components are feasibility harnesses, not a production library or restore service. CF-04A established bounded in-process recovery behavior; CF-04B migration preservation and independent closed-generation recovery remain unproven. This does not establish ordinary save/reopen data loss or authorize a persistence-framework switch. [Plan §§6.4, 9.5 and 21](../../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md) own contracts and sequencing; [Kanban](../WIP_KANBAN.md) owns status.

## Recovery Baseline

`LibraryGenerationManager.swift` rejects initialization/replacement over pending recovery and same-generation journals. `PersistenceFoundationTests.swift` covers prepared, descriptor-switched-before-journal-update and switched interruption checkpoints; invalid replacement metadata; corrupt/missing stores and fallbacks; repeated recovery; and retry after fixture repair. Serialized journal phases remain `prepared`/`switched`, distinct from injected checkpoints.

Recorded CF-04A evidence (2026-10-28, Xcode 27.1): 19/19 unit/UI tests on iOS 17.0 and 27.0, combined app/extension coverage 167/194 (86.08%). Bundles: `.build/GenerationRecoveryFinal-iOS17-20261028.xcresult` and `GenerationRecoveryFinal-iOS27-20261028.xcresult`. This is thrown-interruption testing in one process, not actual termination, power-loss/fsync or production restore proof.

## Migration Blocker

`MigrationFeasibilityTests.swift` uses related synthetic schemas, stable IDs, byte-exact Unicode and relationships, explicit post-migration saves/reopens, deterministic migration rejection and whole-generation preservation/recovery/retry assertions. Keep every assertion active:

- `testFailedMigrationRecoversAndRetriesFromIndependentClosedGeneration`
- `testOnDiskSyntheticMigrationPreservesRelationshipsAndSavedChangesAfterReopen`

An autorelease pool, `processPendingChanges()` and a condition-driven one-second release window did not reliably release containers/contexts. Tests fail closed at lifetime barriers, retain diagnostic directories (paths attached to results) and abort unsafe copy/move/delete operations. A weak-reference release check alone would not prove SQLite connection closure. Initial exploratory cleanup emitted `vnode unlinked while in use` warnings; do not treat scope exit as closed-generation proof or clean these diagnostic stores casually.

Latest full-suite evidence is linked in [NotebookPrototype.md](NotebookPrototype.md#decisive-evidence): 42/44 pass on each phone. iOS 17 fails both tests at ModelContainer lifetime barriers. On iOS 27.1, failed recovery reaches a **26-versus-23-byte assertion**, while migrated-store reopen fails at a ModelContext barrier. These are the same failing test identities, not identical historical assertions. No migration implementation or assertions changed in the prototype packet; the changed assertion must be investigated before claiming migration acceptance.

Original isolated CF-04B evidence: `.build/MigrationSafetyFinal-iOS17-20261028.xcresult` and `MigrationSafetyFinal-iOS27_1-20261028.xcresult`, 18/20 passed each, 0 skipped, coverage167/194 (86.08%). Those runs stopped at container/context barriers. Synthetic migration evidence is not released-schema compatibility. Independent post-migration reopen, closed-generation snapshot, failed-migration recovery/retry and actual process-termination recovery remain gates.

## URL Policy Finding

`URLPolicyFeasibilityTests.swift` loads synthetic HTML in a nonpersistent WebKit session, captures text and serves a synthetic image without external network access. An image subresource request occurred without a navigation-delegate decision. A top-level delegate therefore cannot establish private-subresource, DNS, redirect or size protections. Selected-media transfer and bounded public-network rendering are not proven. Production URL copying remains blocked pending an owner-reviewed enforceable design; the plan's bounded public-HTML alternative is not implemented or a scope removal.

## Reproduction and Stop Rules

Use [README test/coverage commands](../../README.md#build-and-test) with freshly verified iOS 17/current destinations and new paths. Add `-only-testing:ClimbingNotebookTests/MigrationFeasibilityTests`, `PersistenceFoundationTests` or `URLPolicyFeasibilityTests` as appropriate (each as a full `-only-testing:ClimbingNotebookTests/<class>` argument). Inspect result summaries and retained directory attachments; coverage success does not establish behavioral acceptance.

Do not copy a live generation, weaken lifetime assertions, silently switch to Core Data or investigate process boundaries under an unrelated packet. A sequential-process fixture handoff with confirmed exit and retention-path inspection was proposed, not implemented; an explicit-close fallback would require review. Under §21.4.4 these gaps gate generation replacement/migration recovery, not the accepted transient UI. Ordinary durable save/relaunch is the next recommended bounded packet, subject to its own reviewed scope.
