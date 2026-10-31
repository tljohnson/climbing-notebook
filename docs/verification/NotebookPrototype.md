# Notebook Prototype Verification

Updated: 2026-10-30

## Conclusion

CF-07A's native flow was accepted by Leif on 2026-10-29 (`4591da1`). CF-07B's bounded durable implementation was subsequently approved in [§21.4.5](../../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#2145-cf-07b-approved-ordinary-durable-saverelaunch-slice); owner testing/acceptance remains separate. Neither packet establishes M1 completion, migration safety, a complete notebook or release readiness. [Kanban](../WIP_KANBAN.md) owns task status.

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

Limits: final captures are light portrait; attempted dark launch arguments did not establish dark rendering and were removed. Dark-mode tint, live VoiceOver, arbitrary long-name layouts, landscape, physical devices and keyboard-open screenshots remain unverified. Typing/keyboard dismissal is exercised, but final editor captures occur after dismissal. Native navigation titles can ellipsize at XXXL. CF-07C is ready for owner review, not accepted/Done; CF-07B's acceptance remains separate.

## Retained Data Boundary

CF-07B remains limited to existing synthetic fixtures and three durable mutations. Do not accept valuable data, adopt this limited format into a complete library without a reviewed migration, connect diagnostic stores, add creation/deletion or resume archive research under this packet. Generation-replacement, restore and URL-copy gaps gate their dependent features; M1 and release integrity requirements remain unchanged. Incomplete first initialization fails closed with retained files and no repair UI. Physical-device protection/backup, actual full-disk behavior and crash/power-loss durability are not proven by simulator relaunch/fault injection.
