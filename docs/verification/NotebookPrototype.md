# Notebook Prototype Verification

Updated: 2026-11-01

## Conclusion

CF-07A's native flow was accepted by Leif on 2026-10-29 (`4591da1`). The 2026-10-31 owner handoff reports CF-07C human testing passed; its committed reading/navigation implementation (`423685d`) is accepted. CF-07B's bounded durable implementation was approved in [§21.4.5](../../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#2145-cf-07b-approved-ordinary-durable-saverelaunch-slice), but its separate owner acceptance remains pending. These acceptances do not establish M1 completion, migration safety, a complete notebook or release readiness. [Kanban](../WIP_KANBAN.md) owns task status.

Browse areas/routes/pitches and read notes without mutation. Previous/Next changes pitch selection; Edit Notes and Edit Pitch Order isolate editing in full-screen workflows. Reordering moves complete stable-ID pitch values, preserving names/notes. Finish Editing/Done explicitly save to a separate fixture store before closing. Cancel confirms discard, failures retain working buffers for Retry, and unacknowledged edits may be lost on termination. A commit can complete just before termination interrupts its UI acknowledgment; only successful explicit saves are presented as saved. Successful load validates fixed identities/relationships without reseeding. The earlier reported notes mismatch was clarified as navigation-versus-reorder confusion, not a reproduced data defect; that accepted separation remains intentional.

## Decisive Evidence

Final CF-07B execution on the owner-selected Device Hub matrix, 2026-10-30, Xcode 27.1 (`27A9275`), `/Applications/Xcode.app/Contents/Developer`. Final full suites supersede redundant focused runs on unchanged code:

| Destination | Result Bundle Under `.build/` | Results |
| --- | --- | --- |
| iPhone 15 / iOS 17.0, `FB17E53E-C6B7-419C-8D52-6205AD037B52` | `CF07B-acceptance-iPhone15-iOS17-20261030.xcresult` | 67 executed: 65 passed, only 2 CF-04B failures, 0 skipped/runtime warnings |
| iPhone 18 Pro / iOS 27.0, `087CDB20-DD15-43C5-8CBB-69D32A5A7478` | `CF07B-acceptance-iPhone18Pro-iOS27-20261030.xcresult` | 67 executed: 65 passed, only 2 CF-04B failures, 0 skipped/runtime warnings |
| iPad (10th generation) / iOS 26.4, `A6DB0B3A-AD70-435D-AC6C-46B370A06BA7` | `CF07B-acceptance-iPad10-iOS26_4-20261030.xcresult` | UI-only 10/10 passed, 0 skipped; 10 orientation runtime warnings |

Both phone coverage gates passed: app 1558/1573 + extension 0/22 = **1558/1595 (97.68%)**. The rejection self-test correctly rejected 6/11 (54.55%); diff check passed. Both existing [CF-04B migration tests](Persistence.md#migration-blocker) fail at ModelContainer barriers on iOS 17 and ModelContext barriers on final iOS 27.0. Earlier iOS 27.1 recovery reached 26-versus-23 bytes; do not generalize across runtimes. No migration assertions changed; full suites are not green. Tablet warnings are `Update the Info.plist: Support for all orientations will soon be required.` No orientation/project/signing settings changed; full-orientation compliance remains unresolved.

CF-07B adds on-disk and state tests for explicit save/reopen, fixed UUID relationships, whole-order permutations, revisions, invalid stores, failure rollback/retry, exact UTF-8 limits and no-op acknowledgment. Real UI tests exercise process termination/relaunch, distinct pitch notes/reorder, repeated launches, discard/unsaved termination, load/save failures, reload confirmation, unchanged finish, empty cases and accessibility XXXL. Separate internal implementation review found a no-op acknowledgment issue; it was corrected with a state regression, and re-review found no remaining material implementation defect. Runtime results, not that review, establish verification.

## Reproduction

Use [README commands](../../README.md#build-and-test), reverify current simulator availability, and choose fresh result paths. Leif revised the cadence on 2026-10-30: affected focused tests during development on iPhone 18 Pro; one final full unit/UI run each on iPhone 15 and iPhone 18 Pro, superseding redundant focused runs on unchanged code. Tablet iteration is reserved for layout changes. The selected Device Hub destinations are iPhone 15/iOS 17.0, iPhone 18 Pro/iOS 27.0 and iPad (10th generation)/iOS 26.4; UUIDs are in README. No further iPhone Duo suite is planned. Historical Duo/15 Pro/iPad17 runs remain evidence for their actual devices/runtimes, not acceptance for the replacement matrix. Full-run command:

```sh
SIMULATOR_ID=<verified-UUID> RESULT_BUNDLE_PATH=<new.xcresult> bash Scripts/test-ios.sh -quiet -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300 -collect-test-diagnostics never
bash Scripts/check-coverage.sh <new.xcresult>
bash Scripts/check-coverage.sh --self-test
git diff --check
```

For UI-only tablet checks add `-only-testing:ClimbingNotebookUITests`; focused checks also select `ClimbingNotebookTests/NotebookPersistenceTests` and `ClimbingNotebookTests/NotebookPrototypeTests`. Recorded stdout/stderr use each result basename plus `.log`. Inspect bundles with `xcrun xcresulttool get test-results summary --path <bundle>`. Each UI test uses its own debug-only generated UUID namespace, retained across its relaunches, never a reset-on-launch flag. `NOTEBOOK_FAIL_SAVE`/`NOTEBOOK_FAIL_LOAD` inject one failure per process only in that test namespace; they cannot redirect to arbitrary paths or operate in release. Local ignored artifacts are diagnostic aids, not portable prerequisites.

## Layout and Accessibility Limits

Final default-size and accessibility XXXL browsing/reorder/editor/error/retry controls were exercised on both selected phones and iPad. Screenshots exported to `.build/CF07B-acceptance-phone17-screens/`, `CF07B-acceptance-phone27-screens/` and `CF07B-acceptance-ipad-screens/` were inspected. Large text requires substantial scrolling, especially error prose; Retry/Reload/Finish/Cancel remain reachable without capping Dynamic Type. The editor uses a fixed title/Hide Keyboard header, scrollable Form and internally scrollable 300-point TextEditor. Reading uses native ScrollView; stable route-ID lookup avoids the iOS 17 nested-binding navigation layout loop. Native responder dismissal supplements focus clearing. Separate final layout review found no material defect.

Native drag execution, VoiceOver spoken focus/custom actions, IME/caret stress, physical-device keyboards, landscape, split view, real multi-window interaction and dark mode were not verified. Long Unicode is state-tested, not stress-typed through the UI. Leif's CF-07B usability acceptance remains pending; automated tests and static review do not imply unrun checks passed.

## CF-07C Reading and Navigation

Owner approved DESIGN.md and the bounded §21.4.6 packet on 2026-10-30. Route detail now displays full General prose plus Jump to Pitches; adjacent pitch selection stays above scrolling notes, with wrapping position/grade and horizontal Previous/Next controls. Note editors identify route and field. System typography and scoped semantic action tint preserve native controls; no schema, persistence, fixture, archive or dependency changes. A concise persistent synthetic/not-personal-data notice preserves reading space at XXXL; the complete original disclosure remains its accessibility label and visible Library footer. Explicit saves, failure buffers and whole-order commits are unchanged.

Final evidence under `.build/`, all dated `20261030`, with matching `.log` basenames:

| Result Bundle | Results and Disposition |
| --- | --- |
| `CF07C-final-iOS27-20261030.xcresult` | iPhone 18 Pro/27.0 full 65/69; two known CF-04B ModelContext assertions and two UI reachability failures, subsequently corrected/revalidated below. |
| `CF07C-final-iOS17-20261030.xcresult` | iPhone 15/17.0 full 66/69; two known CF-04B ModelContainer assertions and stale full-notice-label assertion, subsequently corrected/revalidated below. All notebook UI tests passed. |
| `CF07C-final-ui-iOS27-20261030.xcresult` | Final all-UI 12/12; covers the two corrected XXXL cases plus existing save/relaunch, ownership, order, discard/error/retry/reload and launch checks. |
| `CF07C-final-ui-iPad-20261030.xcresult` | Selected iPad/26.4 changed-layout checks 3/3; three existing orientation-support warnings. |
| `CF07C-launch-final-iOS17-20261030.xcresult` | Corrected launch/disclosure assertion 1/1. |

The full bundles remain failed; targeted reruns do not constitute a newly executed green full suite. Final changes are presentation/test-helper corrections, not migration fixes. Full-run combined coverage: iOS17 1742/1779 (97.92%), earlier iOS27 1717/1754 (97.89%). Final-source all-UI iOS27 coverage is 1613/1781 (90.57%); changed-UI iPad 1580/1781 (88.71%). Launch-only iOS17 is 477/1781 (26.78%), not a full-suite coverage gate. Percentages are per bundle, not merged or falsely attributed to unchanged code. Coverage rejection self-test passes.

Independent review corrected globally scoped tint, truncated XXXL pitch metadata, and insufficient long-note coverage. Screenshot/activity evidence distinguished UI crowding from test-helper problems: helpers now intersect target/container visibility and verify pitch order with a bounded forward traversal rather than repeated wrong-direction drags. Final independent review inspected 12 phone and 7 tablet screenshots with no new material defect. Exports are `.build/CF07C-independent-final-v8-screens-20261030/` and the final reviewer exports in the approved temporary directory. Long-note tests verify bottom-line reachability, stable ownership after relaunch, boundary disabling and adjacent navigation; no test timeouts were raised or migration assertions weakened.

Limits: final captures are light portrait; attempted dark launch arguments did not establish dark rendering and were removed. Dark-mode tint, live VoiceOver, arbitrary long-name layouts, landscape, physical devices and keyboard-open screenshots remain unverified. Typing/keyboard dismissal is exercised, but final editor captures occur after dismissal. Native navigation titles can ellipsize at XXXL. The 2026-10-31 owner handoff accepts CF-07C after human testing; it supplies no per-device/accessibility measurements, so it does not turn these unrun checks into passes. CF-07B's acceptance remains separate and pending.

## CF-07D Current Results

The owner approved §21.5.1 and subsequently directed recording current results, keeping automated tests and moving on (2026-10-31). Implementation is retained, but verification is incomplete and CF-07D is paused in Blocked, not Review/Done or accepted. The running creation batch was stopped at that direction; no follow-up schedules remain. CF-07B acceptance remains separate.

Implemented: existing-area name-only Add/Cancel drafts; actual UUID snapshots/commands; duplicate names, blank metadata and zero pitches; explicit General-note saves; stable-ID retry with reserved/collision rejection; strict additive graph validation and unchanged V1 schema, marker, namespace and initialization policy. No migration, reset/reseed, diagnostic-store adoption or personal data. Added tests remain active in source, not skipped or deleted.

| Completed evidence | Result |
| --- | --- |
| `.build/CF07D-focused-v1-iOS27-20261031.xcresult`, iPhone 18 Pro/iOS 27.0 | 33/33 persistence/state tests passed: 22 persistence and 11 prototype/state, including predecessor-format byte/ID/revision/order preservation, arbitrary UUIDs, ownership/corrupt graphs, duplicate names, validation and rollback/retry. The accompanying UI test failed on test-helper reachability before typing; not a known CF-04B failure. |
| `.build/CF07D-ui-v3-iOS27-20261031.xcresult` | 1/1 creation UI test passed after fixing the helper's rejection of fully visible controls shorter than 30 points. Covers failed Add with retained name/Retry, exactly one created route, explicit General save, unsaved-edit termination, acknowledged content on real process relaunch, General failure/retry and another relaunch. |
| Separate internal implementation reviews | Persistence/state/unit review found no concrete integrity defects. UI review identified weak keyboard evidence; assertions/capture were revised. These were static reviews, not runtime acceptance. |
| Simulator/toolchain verification | Selected iPhone 15/iOS17, iPhone 18 Pro/iOS27 and iPad10/iOS26.4 available; Xcode 27.0.1. Availability is not destination test coverage. |

The stricter software-keyboard prerequisite failed in `.build/CF07D-creation-v5-iOS27-20261031.xcresult` (four tests stopped at that check) and the isolated v6 diagnostic. The captured accessibility tree placed a childless keyboard off screen at y=918 on a 874-point display; full-display captures showed no software keys. This is a measured environment/evidence limit, not proof that keyboard-open actions work. Current functional tests assert focus/keyboard-container dismissal and label captures accordingly; actual software-keyboard-open reachability remains a human/device check. They no longer misrepresent container existence as rendered-keyboard evidence.

The v2 reachability reproduction failed; v4 and v7 were interrupted without valid finalized bundles. The final v8 functional batch was still running when the owner ended verification and was explicitly stopped; it supplies no completed pass claim. The four duplicate/Cancel-validation/XXXL/dark scenarios therefore have no completed functional pass under the final helper. Last passing v3 predates the final capture/assertion adjustment. Dark and XXXL screenshots alone do not establish successful flows.

Remaining, not executed/completed: final full suites on both selected phones, both final coverage gates and rejection self-test, selected-iPad touched-layout checks, final complete creation UI coverage, rendered software-keyboard/VoiceOver/physical-device checks and owner acceptance. The two historical CF-04B migration tests remain active and were not run in these focused bundles: `testFailedMigrationRecoversAndRetriesFromIndependentClosedGeneration` and `testOnDiskSyntheticMigrationPreservesRelationshipsAndSavedChangesAfterReopen`. No current CF-04B pass/failure is inferred, and none of the new UI failures is classified as known CF-04B. No valuable-data, migration, backup, actual ENOSPC or crash/power-loss safety claim follows from these results.

## Retained Data Boundary

CF-07B remains limited to existing synthetic fixtures and three durable mutations. Do not accept valuable data, adopt this limited format into a complete library without a reviewed migration, connect diagnostic stores, add creation/deletion or resume archive research under this packet. Generation-replacement, restore and URL-copy gaps gate their dependent features; M1 and release integrity requirements remain unchanged. Incomplete first initialization fails closed with retained files and no repair UI. Physical-device protection/backup, actual full-disk behavior and crash/power-loss durability are not proven by simulator relaunch/fault injection.

## CF-07E Text Notebook Milestone

Latest status: **Blocked**, not implementation-complete or owner-acceptance ready. Resumed from clean commit `8c00e04`; see the consolidated disposition below. Historical bundles remain evidence only for their actual source/runtime.

Owner approved consolidated [§21.6](../../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#216-consolidated-text-notebook-milestone-approved) on 2026-10-31. The new ordered notebook is a separate initially empty format; legacy content remains retained/read-only and examples are explicitly separate. Its user-created text workflow does not imply sole-copy personal-data safety, backup, migration or recovery acceptance.

Current decisive checks on iPhone 18 Pro/iOS27.0, Xcode27.1 (`27A9275`), result bundles under `.build/` dated `20261031`:

| Bundle | Actual result |
| --- | --- |
| `CF07E-persistence-v1-iOS27-20261031.xcresult` | Build failed on a main-actor initializer used as a default argument; no tests executed. Fixed by constructing default state inside the view initializer. |
| `CF07E-persistence-v2-iOS27-20261031.xcresult` | 38/38 new/legacy persistence tests passed, 0 skipped/runtime warnings. Includes independent predecessor graph preservation and separate namespace readback. |
| `CF07E-state-v1-iOS27-20261031.xcresult` | 29/29 new persistence/state tests passed, 0 skipped/runtime warnings. Includes strengthened exact UTF-8 comparisons after reopening, rollback/retry, source mismatch, stale windows and no-op acknowledgment. |
| `CF07E-retained-ui-v1-iOS27-20261031.xcresult` | 2/2 launch/retained read-only UI tests passed, 0 skipped/runtime warnings. |
| `CF07E-ui-smoke-v1-iOS27-20261031.xcresult` | 0/2 passed: examples had duplicate Add Area query matches across presented/underlying views; invalid-name workflow could not find the editor input. These are new failures under investigation, not CF-04B baseline failures. |
| `CF07E-minimum-integrity-v1-iOS17-20261031.xcresult` | 49/53 passed, 0 skipped/runtime warnings. Legacy create failure/retry and new creation-state checks raised an iOS17 to-many relationship `NSInvalidArgumentException`; two all-mutation failure checks reported incompatible model configuration. Ordinary rollback investigation is in scope; none is classified as the CF-04B baseline. |
| `CF07E-minimum-retry-v2-iOS17-20261031.xcresult` | 1/5 passed; replacing failed contexts without rollback did not fix the four failures. Exported exception stacks locate the relationship exception at insertion linking (`Route.area`), before save/rollback; the earlier rollback diagnosis is not supported. Candidate reverted. |
| `CF07E-minimum-link-v3-iOS17-20261031.xcresult`, `CF07E-minimum-isolated-v4-iOS17-20261031.xcresult` | Parent-side append candidate 0/4; isolated creation-state check 0/1. Append changed the relationship error direction, not the failure. Candidate reverted. |
| `CF07E-container-boundary-v5-iOS17-20261031.xcresult`, `CF07E-shared-schema-v6-iOS17-20261031.xcresult` | Three new retained/scoped same-root and retained different-root container controls each failed (0/3 per bundle) when the original store next inserted a route. Sharing an immutable Schema did not resolve it and was reverted. Fresh containers/readback assertions remain required and active. |
| `CF07E-ui-smoke-v2-iOS27-20261031.xcresult`, `CF07E-create-relaunch-v1-iOS27-20261031.xcresult` | 0/2 smoke (virtualized source-label query and unreachable name input), then 0/1 complete workflow (name-input reachability). No successful complete process-relaunch workflow is claimed; native editor layout and evidence-backed helper fixes are in progress. |
| `CF07E-native-editor-v3-iOS27-20261031.xcresult` | 0/1 General-note retry workflow: still failed name-input reachability with input-first Form/native action toolbar. No inference that this is solely a product layout defect; helper/accessibility-tree diagnosis continues. |
| `CF07E-unit-baseline-v1-iOS27-20261031.xcresult` | Complete unit suite: 102/104 passed, 0 skipped/runtime warnings. Exactly the two retained CF-04B methods failed on context-release assertions; every new notebook/state/container-control test passed. Interim coverage gate **failed**, 1809/4545 first-party lines (39.80%); this is not the required final unit/UI coverage run. |
| `CF07E-unit-baseline-v1-iOS17-20261031.xcresult` | Complete unit suite: 94/104 passed, 0 skipped/runtime warnings. Two CF-04B container-release failures; two existing CF-07D creation/retry failures; six new notebook/state/container-control failures. Interim coverage **failed**, 1787/4545 lines (39.32%). No ordinary creation failure is reclassified as migration baseline. |
| `CF07E-direct-create-v1-iOS27-20261031.xcresult` | 1/1 direct no-helper UI test passed: initially empty notebook, tap/type/Add, stable area UUID/name retained after actual `terminate()` and relaunch. Its rendered native dark area-editor attachment was exported and visually inspected: Name input, Cancel/Add and Hide Keyboard were fully visible. This isolates first-editor availability from the broader helper's false reachability rejection; it does not prove the complete hierarchy workflow. |
| `CF07E-tablet-direct-v1-iOS26-20261031.xcresult` | 1/1 same direct empty/create/actual-relaunch UI test passed on selected iPad10/iOS26.4; rendered light area editor exported/inspected. Runtime warning: `Update the Info.plist: Support for all orientations will soon be required.` This is an initial-layout check, not all changed tablet workflows; no orientation/settings change made. |
| `CF07E-minimum-direct-v1-iOS17-20261031.xcresult`, `CF07E-minimum-focus-v2-iOS17-20261031.xcresult` | 0/1 each: visible/hittable multiline name field did not acquire keyboard focus for `typeText`, even with a bounded second tap after keyboard wait. No simulator keyboard settings changed and no minimum-runtime relaunch pass inferred. |
| `CF07E-initial-model-v7-iOS17-20261031.xcresult` | 0/2 retained same/different-root controls with empty migration-plan argument omitted. Candidate did not fix insertion metadata failure and was reverted; no initial-format/schema change retained. |

Coverage rejection self-test passed (correctly rejected 6/11, 54.55%); this is not a final app coverage result. Final two-phone full suites, coverage gates, iPad/layout/accessibility checks and process-relaunch milestone acceptance remain pending. Toolchain emits SDK build-version parsing/debugger lookup diagnostics; the passed focused bundles contain no runtime warnings. Do not conflate tool diagnostics with a failed test or claim absence of all warnings.

Independent static persistence review found no material implementation defect and prompted exact-byte reopened assertions; the later iOS17 runtime failures supersede any inference of complete integrity. UI review identified stale deletion-selection and maximum-length name layout defects; source fixes passed static re-review, with targeted runtime revalidation pending. Six indexed approved design screenshots were rendered/inspected (Library, Area, Pitch, Route light/dark and Pitch Order); Note Editor/save-failure image review is not claimed. No current implementation screenshot or physical-device result is inferred from those references.

### CF-07E Blocked Handoff

#### Consolidated Final Disposition

Full suites used Xcode27.1 (`27A9275`), selected destinations, serialized builds and unchanged300s per-test limit. Both coverage gates were measured from their actual combined unit/UI bundle, not added percentages:

| Bundle under `.build/` | Exact result |
| --- | --- |
| `CF07E-final-full-iOS27-20261031.xcresult` | **138/147 passed**,9 failed,0 skipped/runtime warnings. Units106/108; legacy persistence/state all pass; new persistence22/22/state17/17. UI32/39: Foundation3/4, legacy14/16,new15/19. Coverage **4542/4635 (97.99%)**, gate passed. |
| `CF07E-final-full-iOS17-20261031.xcresult` | **111/147 passed**,36 failed,0 skipped/runtime warnings. Units98/108; UI13/39: Foundation2/4,legacy11/16,new0/19. Coverage **3500/4635 (75.51%)**, gate passed. |
| `CF07E-final-layout-iPad26-20261031.xcresult` | **3/5 passed**,0 skipped,5 existing orientation warnings. Largest-text light reading,500-character names/navigation and native area drag/process readback pass. Dark reading fails reaching Edit Route Order; default audit fails. |
| `CF07E-final-direct-v16-iOS27-20261101.xcresult` | **2/2 passed**,0 skipped/runtime warnings: corrected direct empty-to-five-pitch/General/pitch notes/actual terminate-relaunch and area smoke. |
| `CF07E-final-header-v17-iOS17-20261101.xcresult` | **0/2**,0 skipped/runtime warnings: explicit header case clears the old assertion; area smoke now fails keyboard focus, audit now reaches Dynamic Type failure. |

The full suites stay **Failed**. Two unchanged CF-04B migration methods fail lifetime assertions (minimum container/current context); no migration research resumed. Eight additional iOS17 unit failures are ordinary persistence/state, not migration baseline: legacy `testCreatePostStagingFailureRollsBackAndSameIDsRetryExactlyOnce` and `testCreateFailureRetainsDraftAndExactlyOncePublicationThenUUIDEditing`; new three fresh-container controls, `testEveryMutationFailureRollsBackFreshContextAndRetryCommitsOnce`, `testEveryCreationPublishesOnlyAfterSaveAcknowledgmentAndKeepsAllocatedIDs`, `testEveryMutationFailureRetainsDraftSnapshotAcknowledgmentAndRetryCommitsOnce`. The two all-mutation errors are save-boundary134020; others are relationship exceptions. All four added diagnostic/ownership/replay/populated-sibling exact-byte/revision regressions pass on both runtimes.

Current full UI failures are two retained legacy failures (trailing space and strict840.000020345052>840.0 bottom geometry), new default audit,500-character pitch reachability,AXXXL editor save-state reachability, cancellation/order aggregate timeout, and direct pitch4 row discovery. The last was corrected by explicit post-save Jump/bounded row revelation and passed v16; no new green full suite is inferred. The cancellation scenario reaches final relaunch around248s, then times out during graph readback; it still needs an acceptance-preserving split. iOS17's full new UI19/19 stop at native uppercasing `NOTEBOOK` versus `Notebook`; `.textCase(nil)` fixes that presentation mismatch, but only the two v17 selectors were rerun. Seven minimum legacy/Foundation UI failures are keyboard-focus synthesis. Other minimum new workflows remain unverified beyond that corrected header, not assumed passed.

Bounded UI batches v11 through v15 retained keyboard finite-frame guards, failure-context revelation, adaptive vertical route actions at accessibility sizes and the five-pitch workflow split. V11 passed5/8; v12 passed4/6; v13 passed0/3; v14/v15 each0/2. Unsuccessful scrolling/anchor/editor experiments were removed. Both split five-pitch tests pass in the complete current suite, including duplicate route UUIDs, distinct notes/order and process relaunch. Dark phone reading and failed-note/deletion retry also pass. Audit remains active, without exclusions. Phone crop identifies Loaded from this device; tablet identifies Other Notebooks. Generic audit details do not establish cause or false positive, and creation-editor audits remain unreached after the first failure.

Rendered captures and hierarchies were independently inspected from final phone/tablet bundles and bounded UI batches. Tablet light capture actually renders software keys with typing and reachable Hide Keyboard; phone captures support functional typing, not rendered software-keyboard reachability. Tablet shows full final note lines and pinned controls;500-character context wraps in the editor. Dark tablet failure shows a closed Area Actions menu, not proof of clipped menu content. Legacy exact checkpoints localize the extra space to reveal/wait after correct typing and before dismissal; no trim or input normalization added. The strict legacy geometry assertion remains failed despite readable captured content. Independent review found no additional production store/state integrity defect; raw underlying NSError descriptions were redacted after review. Final helper review still identifies incomplete-traversal detection and virtualized duplicate discovery gaps; these are unresolved, not waived.

Coverage rejection self-test and `git diff --check` pass. Full suites precede only the final fixed-header presentation and direct-test revelation changes; affected focused checks above do not replace them. No commits,pushes,installs,settings/signing/permission changes,schema changes,reset/reseed or personal-store cleanup occurred. Required remaining work: resolve the qualified-runtime decision/native defect, active UI/audit failures and helper review findings; add process-termination assertions for unsaved rename/pitch notes; rerun affected minimum/source-header workflows, changed tablet/header audit and final review. Physical devices,live VoiceOver,real phone keyboard,real disk-full/power-loss,backup/recovery and owner acceptance remain unrun/unproven. No sole-copy personal-data recommendation.

#### Historical Diagnostic Evidence

Latest resumed checks: `CF07E-identified-ui-v5-iOS27-20261031.xcresult` passed 1/2: generic creation/relaunch now passes after explicit `textEditorForm`/`textExamplesLibrary` IDs replaced presentation-order guesses. Examples reached the final isolation assertion but incorrectly queried the covered root; corrected to the active source without changing isolation semantics. `CF07E-notebook-ui-v6-iOS27-20261031.xcresult` ran all 18 new UI methods: **3 passed, 15 failed**, zero skipped/runtime warnings. Failures expose text replacement at the wrong caret, ordering element-type/disabled-control queries, a measured 27.67pt target below 44pt, Dynamic Type audit failure and largest-text reachability. Bounded fixes are in progress; no audit exclusion or reduced assertion applied.

`CF07E-ui-fixes-v7-iOS27-20261031.xcresult`: **3/4 passed**, zero skipped/runtime warnings. All-kind rename failure/retry, General-note failure/retry with hierarchy readback, and dark reading/44pt target checks pass after native Select All replacement, distinct order heading/button IDs and sizing the Previous/Next labels. The default audit still fails on `textSaveStatus` (`Loaded from this device`) despite explicit `.font(.body)` and unrestricted vertical sizing. Exported crop shows complete text, and raw detail only states the SwiftUI accessibility node cannot change font size; it records no failing category or scaling measurement. This is insufficient to prove either a product defect or false positive. The failure remains active without exclusions; the subsequent area-editor audit was not reached.

**Historical new-workflow suite:** `CF07E-notebook-ui-v8-iOS27-20261031.xcresult`: **12/18 passed**, zero skipped/runtime warnings. Its six failures and interim UI-only coverage **2381/4593 (51.84%)** are superseded for current disposition by the full suites above, not retroactively passed. No keyboard,geometry,timeout,audit or text assertion was weakened.

The historical public-only insertion diagnostic reproduced the minimum-runtime failure in `CF07E-public-identity-v9-iOS17-20261031.xcresult` (0/1), but could not expose native entity/model identity through public casts. Its temporary instrumentation and activation were removed. The [resumed standalone first-throw capture](Persistence.md#minimum-runtime-model-identity-blocker) supersedes this diagnostic limitation; no production private API/KVC/reflection workaround was introduced.

**2026-10-31: implementation incomplete, not owner-acceptance ready.** Native CRUD/order/notes workflows are committed at `8c00e04`, with resumed fixes uncommitted, but minimum-runtime integrity and required UI/coverage acceptance remain unsatisfied. No commit/push, schema adoption, reset, permissions/settings change, runtime-floor change, assertion weakening or archive/recovery research was performed in this continuation.

Additional decisive bundles under `.build/`, all suffixed `-20261031.xcresult`:

| Bundle prefix | Actual result |
| --- | --- |
| `CF07E-direct-hierarchy-v1-iOS27`, `CF07E-direct-hierarchy-v2-iOS27` | 0/1 each: test queried nonexistent `textFullNotes`, then nonexistent `textPitchPosition`. Corrected to actual `textPitchNotes` and visible `Pitch 1 of 5`; assertions retained. V2 reached post-process-relaunch graph readback. |
| `CF07E-direct-hierarchy-v3-iOS27` | 1/1 passed: genuinely empty notebook to area/route/five pitches, General and distinct pitch notes, actual terminate/relaunch and stable hierarchy UUID/full note readback. Not all structural/retry UI criteria. |
| `CF07E-legacy-ui-v1-iOS27` | 18/20 passed. Existing CF-07D largest-text creation observed one unexpected trailing space; accepted long-reading assertion observed bottom frame 840.000020345052 > 840.0. Both remain failures; no tolerance/trim/assertion change. Neither is migration baseline. |
| `CF07E-ui-helpers-v4-iOS27` | 0/2: revised modal/source helpers still reject `sourceLabel` and `textNameEditor` reachability. Direct native passes are separate evidence, not grounds to mark failed tests passed. Rendered failure captures retained. |

**Concrete blocker:** on iOS17, after a second fresh container opens (same/different root, retained/scoped), the original store's next route insertion raises `NSInvalidArgumentException` linking `Route.area`/inverse `Area.routes`, before save. Resumed standalone reproduction and first-throw LLDB now prove the inserted Route and fetched Area relationship destination belong to **different native models despite the same native context**. Identical one-container iOS17 and two-container iOS27 controls pass. Named-error v10 checks (52/59, zero skipped/runtime warnings) locate the two incompatible-model errors at **save command**, code `NSCocoaErrorDomain 134020`, not fetch. See [native identity evidence and API review](Persistence.md#minimum-runtime-model-identity-blocker). Parent-side linking, failed-context discard, shared Schema, omitted empty plan and explicit model-list Schema construction do not fix it. No schema/runtime/architecture change was retained; fresh-container assertions remain intact.

**Authorization and next decision:** the owner explicitly confirmed first-throw diagnosis and minimal reproducers are ordinary debugging within §21.6, not a new approval gate. That diagnosis is now completed. Independent public-API review found no supported iOS17 entity rebinding/context-bound construction remedy. Recommend qualifying a higher runtime floor for an explicit owner decision, or retaining the iOS17 blocker and escalating the reproducer to Apple; iOS27 success alone does not qualify an intermediate floor. No runtime-floor/schema/architecture change is made. Migration-recovery research, production private API/KVC workarounds and reduced fresh-container verification remain excluded. UI repairs and final verification continue independently.

| Criterion | Current status |
| --- | --- |
| TN-01 Empty-to-complete | Current split duplicate/five-note/reorder workflows and corrected direct process-relaunch pass; minimum input focus blocks. |
| TN-02 CRUD/order | Current store/state and rename/order/retry/native drag pass; cancellation aggregate timeout and large phone layout remain. |
| TN-03 On-disk graph | Blocked: current graph passes; minimum post-fresh-container writes fail. |
| TN-04 Process durability | Current hierarchy/notes/order/deletion/retry readback passes; unsaved aggregate times out; unsaved rename/pitch-note termination assertions missing. Minimum focus blocks. |
| TN-05 Deletion | Current ordinary/failed deletion retry and neighbor-selection UI pass; added populated-sibling exact-byte/revision tests pass both runtimes. |
| TN-06 Validation/failures | Current store/state and retry UI pass; minimum ordinary creation/retry fails. Injection is not real I/O exhaustion proof. |
| TN-07 Compatibility/isolation | Independent predecessor/source-token and explicit examples-isolation UI pass current; minimum container compatibility blocks. |
| TN-08 Accepted reading | Preserved in source, but active legacy bottom-frame assertion failed; full new long-reading matrix incomplete. |
| TN-09 UI/accessibility | Tablet largest light/max-name/native drag pass, actual tablet keyboard rendered. Phone dark functional checks pass; phoneAXXXL/max-name,tablet dark menu and all default audits fail. Live VoiceOver/device checks unrun. |
| TN-10 Quality/handoff | Full suites failed current138/147,minimum111/147; both combined coverage gates/self-test pass. Reviews/diagnostics completed but UI review gaps and acceptance remain unresolved. |

The two baseline migration methods remain active and fail separately. Complete phone suites,combined coverage and changed tablet/audits have now run with the exact failed/passed disposition above. No failed criterion is waived. Hosted CI,physical-device protection,real disk-full/power-loss behavior and backup/restore remain unverified.

Future device checklist using replaceable notes: empty-to-five-pitch creation and full notes; all-kind rename/reorder/delete/cancel; explicit saves then offline force-quit/relaunch; source separation; largest text/light-dark/VoiceOver/real keyboard. This is not a request to accept the blocked build.
