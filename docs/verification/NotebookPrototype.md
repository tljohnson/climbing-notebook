# Notebook Prototype Verification

Updated: 2026-10-29

## Conclusion

CF-07A's disposable native flow was accepted by Leif on 2026-10-29; implementation commit: `4591da1`. This acceptance covers prototype usability, not M1 completion, durable storage, migration safety or release readiness. [Plan §21.4.4](../../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#2144-owner-approved-prototype-first-reset) owns scope; [Kanban](../WIP_KANBAN.md) owns task status.

Browse areas/routes/pitches and read notes without mutation. Previous/Next changes pitch selection; Edit Notes and Edit Pitch Order isolate editing in full-screen workflows. Reordering moves complete stable-ID pitch values, preserving names/notes. Edits apply in memory only and reset on relaunch. The earlier reported notes mismatch was clarified by the owner as confusion between reordering and navigation, not a reproduced data defect; the resulting workflow separation is intentional.

## Decisive Evidence

Executed 2026-10-29 with Xcode 27.1 (`27A9275`), `/Applications/Xcode.app/Contents/Developer`:

| Destination | Result Bundle Under `.build/` | Results |
| --- | --- | --- |
| iPhone 15 Pro / iOS 17.0, `A1A7DBEF-BA07-4904-9CE9-3C6B1F5A3492` | `CF07A-workflows-full-v5-iOS17-20261029.xcresult` | 44 executed: 42 passed, 2 migration failures, 0 skipped/runtime warnings |
| iPhone Duo / newest installed iOS 27.1, `AD5A310D-DBEB-497C-8921-1A49BC52C3C6` | `CF07A-workflows-full-v5-iOS27_1-20261029.xcresult` | 44 executed: 42 passed, 2 migration failures, 0 skipped/runtime warnings |
| iPad (10th generation) / iOS 17.0, `D287E486-8D5E-4268-97A1-3AEAD2847683` | `CF07A-workflows-iPad17-v5-20261029.xcresult` | UI-only 6/6 passed |

Both phone coverage gates passed: app 865/873 + extension 0/22 = **865/895 (96.65%)**. The rejection self-test correctly rejected 6/11 (54.55%); diff check passed. Failures remain confined to the two [CF-04B migration tests](Persistence.md#migration-blocker), but the latest iOS 27.1 failed-recovery assertion differs from its historical lifetime barrier. No migration assertions were changed. Full suites are not green.

Four state tests cover stable/empty fixtures, whole-sibling multi-index reorder, boundaries/missing IDs, long Unicode byte preservation and fresh-fixture reset. Six UI tests cover honest launch, read-only browsing, Previous/Next, distinct note retention, explicit edits, reorder boundaries/repeated moves, empty cases, relaunch reset and accessibility XXXL. Separate agent-assisted initial/final source reviews found no material issues; Leif subsequently reported testing passed and committed the changes.

## Reproduction

Use [README commands](../../README.md#build-and-test), reverify current simulator availability, and choose fresh result paths. Full runs above used:

```sh
SIMULATOR_ID=<verified-UUID> RESULT_BUNDLE_PATH=<new.xcresult> bash Scripts/test-ios.sh -quiet -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120 -collect-test-diagnostics never
bash Scripts/check-coverage.sh <new.xcresult>
bash Scripts/check-coverage.sh --self-test
git diff --check
```

For UI-only tablet checks add `-only-testing:ClimbingNotebookUITests`; focused prototype checks also select `ClimbingNotebookTests/NotebookPrototypeTests`. Recorded stdout/stderr use each result basename plus `.log`. Inspect bundles with `xcrun xcresulttool get test-results summary --path <bundle>`. Local ignored artifacts are diagnostic aids, not portable prerequisites.

## Layout and Accessibility Limits

Default-size interactions and accessibility XXXL browsing, reorder and note-editor controls were exercised on both phones and iPad. Final largest-text screenshots, including the focused editor, were inspected and exported to `.build/CF07A-workflows-v5-phone-screens/` and `CF07A-workflows-v5-ipad-screens/`. Full-screen editing, vertically wrapping move controls and note-edit completion outside a navigation toolbar avoid issues observed in initial layouts. Only the editing reset notice caps at standard xxxLarge; content and controls retain full Dynamic Type. Large text requires more scrolling; route previews intentionally truncate, while full notes remain readable.

Native drag execution, VoiceOver spoken focus/custom actions, IME/caret stress, physical-device keyboards, landscape, split view and dark mode were not verified. Long Unicode is state-tested, not stress-typed through the UI. No iOS 27.0 rerun was performed for the final workflow revision. Usability acceptance does not imply these checks passed.

## Next Boundary

The smallest subsequent reviewed packet is ordinary durable save/relaunch. It must establish actual saved-state acknowledgment before valuable data is accepted. Do not silently connect this prototype to diagnostic stores or resume paused archive research. Generation-replacement, restore and URL-copy gaps gate their dependent features; M1 and release integrity requirements remain unchanged.
