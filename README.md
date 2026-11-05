# Climbing Notebook

Updated: 2026-11-04

Native, iPhone-primary climbing notebook for iOS 17.5+ with minimal iPad support. Product requirements and integrity contracts are in the [approved plan](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md).

## Current Capabilities

The text notebook opens an initially empty ordered library with area/route/pitch creation, rename, reorder and confirmed deletion, General/pitch notes, isolated examples and retained read-only prototype access. Save commits before closing; Cancel protects changed drafts. Owner testing passed light/dark workflows at regular/maximum text with no draft loss; VoiceOver was not tested. Backup/restore, media and intake remain unimplemented. Keep another copy of important notes.

Historical prototype: CF-07A's owner-accepted synthetic-data browsing/explicit editing and CF-07C reading/navigation are preserved. The retained ordinary-entry reader is read-only; legacy mutation tests remain active separately. CF-07B's explicit durable note/order saves still have separate owner acceptance pending. Do not enter personal climbing data.

CF-07C shows full General notes, Jump to Pitches and pinned adjacent-pitch navigation. Historical CF-07D adds name-only Add/Cancel route drafts in existing fixture areas; its verification remains paused with tests retained and owner acceptance pending. The new notebook carries creation/cancel/retry requirements forward without retroactively accepting CF-07D; see [current results](docs/verification/NotebookPrototype.md#cf-07d-current-results). Neither slice establishes automatic saving or full-product completion.

Save commits creation, names, notes and ordering on this device before closing; confirmed Delete remains separate. Cancel confirms discard when changed. Unsaved drafts/edits can be lost if the app closes; failures retain the editor for retry. The retained legacy test flow keeps its historical labels. The complete text hierarchy is implemented but not accepted; media intake, share delivery, URL copying and backup/restore are not implemented. M1 remains incomplete; archive research is paused, not a prerequisite for ordinary notebook increments. See the [Kanban](docs/WIP_KANBAN.md) and [verification references](#verification-references) for actual status and remaining gaps.

## Prerequisites

The supported minimum is iOS17.5, with qualification limits retained in [current evidence](docs/verification/NotebookPrototype.md#consolidated-final-disposition). Historical full suites ran on17.5 and27:129/161 and153/161 passed, with coverage97.12% and98.08%. These are failed full-suite results, not a current MVP-core result. Known automation/audit findings and paused migration research are classified separately under the [MVP policy](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#2168-mvp-delivery-and-verification-policy).

- macOS, Xcode and installed iOS Simulator runtimes; verify using `xcodebuild -version` and `xcrun simctl list devices available`.
- Git and network access for the approved Swift Package Manager dependency.
- No backend, account, environment variables, secrets or database service required.

## Build and Test

Open `ClimbingNotebook.xcodeproj`, select the ClimbingNotebook scheme and a simulator, then Run. For signing-free fast unit/UI checks:

```sh
SIMULATOR_ID="installed-simulator-UUID" bash Scripts/test-ios.sh --suite fast -quiet
git diff --check
```

`Scripts/test-ios.sh` defaults to `fast`:75 meaningful unit tests from four complete current/retained-format classes plus two short UI workflows in `Scripts/mvp-smoke-tests.txt`. `core-unit` and `smoke` run these separately in CI. Smoke checks cover empty-start creation, hierarchy/notes, Save, Cancel and process relaunch. The preserved `core`/`mvp-core-tests.txt` selection is the extended100-test regression set; `core-ui` selects its25 UI workflows. Update selections for new functionality based on risk, not coverage percentage. Existing assertions are unchanged.

Use `--suite qualification` for the historical core complement (audits, diagnostics and research); use `--suite all` for every test, including the smoke additions. Run affected extended checks when warranted and manually trigger all tests before major releases. These suites can still fail on recorded findings. `--suite fast --list` prints selection without a simulator. Direct Xcode Test still runs all tests.

During development use `--suite all -only-testing:<target>/<class-or-method>` for affected tests. Named cohorts reject include/exclude overrides. Reuse unaffected evidence; docs-only edits need no simulator run. `RESULT_BUNDLE_PATH` selects a new bundle path. Do not provision/change simulator settings implicitly. Coverage is optional information: `bash Scripts/check-coverage.sh <result.xcresult>` reports app/extension lines with no threshold. The owner explicitly superseded the generic Novacoast checklist for this native iOS project; do not restore its70% gate or coverage aggregation. A focused pass never relabels a failed extended/full suite.

For example, append `--suite all -only-testing:ClimbingNotebookTests/TextNotebookPersistenceTests -only-testing:ClimbingNotebookTests/TextNotebookStateTests` directly after the script name for focused persistence/state checks. UI relaunch checks use a generated test-store UUID retained across launches, not a launch-time reset. Resolve the approved dependency with native tooling when needed:

```sh
xcodebuild -resolvePackageDependencies -project ClimbingNotebook.xcodeproj -scheme ClimbingNotebook
```

## Try the Text Notebook

1. Start in the empty notebook, choose Add Area, enter a replaceable name and Save. Open it and Add Route, then create five pitches with distinct names. Area and route names are marked required; pitch names are optional.
2. Edit General and each pitch's notes. Hide Keyboard changes focus only; Save explicitly saves.
3. Read full notes and use Jump to Pitches and Previous/Next. Navigation never reorders or saves.
4. Rename or reorder areas, routes and pitches using their separate editors. Save commits the complete change; Cancel confirms discard when changed.
5. Try canceled and confirmed deletion. Nonempty areas cannot be deleted; route deletion removes its General note and pitches.
6. Terminate/relaunch to inspect acknowledged content. Unacknowledged edits may be lost. Open Examples is separate; Retained Prototype is read-only and never initializes an absent legacy root. These checks do not establish minimum-runtime qualification or milestone acceptance.

## Architecture and Data

The app opens the separately versioned SwiftData `Application Support/TextNotebook/notebook.store`, initially with only its initialization marker. `TextNotebookExamples/` initializes fictional examples only when explicitly opened. Retained `NotebookFixtureSlice/` content keeps its unchanged `NotebookSchemaV1` format and is read-only through ordinary app entry; saved legacy edits have unknown importance and are not classified as disposable. Editors buffer plain values separately from acknowledged snapshots; autosave is disabled. UUIDs, ownership, contiguous sibling order, exact text and revisions are validated. Invalid/incomplete stores fail visibly without reset, reseeding or empty-library fallback. Separate two-entity `LibraryStore` and generation descriptor/journal harnesses remain unchanged and isolated. The hidden share extension does not accept deliveries. No hosted API, telemetry, analytics, OCR, cloud sync or AI calls exist in this scope.

Technical project/scheme/module names use `ClimbingNotebook`. `DEVELOPMENT_DISPLAY_NAME` supplies generated display branding. Bundle identifiers rooted at `com.climbingnotebook.foundation` are provisional, not registered release identities.

## Dependencies

ZIPFoundation 0.9.20 is resolved at `22787ffb59de99e5dc1fbfe80b19c97a904ad48d` in the shared `Package.resolved` and linked only to unit tests. Its MIT notice is in `THIRD_PARTY_NOTICES`. Native Xcode/SPM resolution and the committed resolution file are approved project exceptions. Review dependency updates monthly and before release, with archive regression testing; do not modify cached checkouts. Public-API inspection/extraction gaps prevent production restore acceptance.

## CI and Distribution

Per-commit development targets the latest stable toolchain/iOS runtime installed on the current `macos-26` hosted image, selected explicitly by `Scripts/select-ci-ios.rb`. It exports `DEVELOPER_DIR` and `SIMULATOR_ID` for all later steps and logs exact versions/device; it does not pick the first iPhone or use the image's default Xcode. Runner inventory checked2026-11-05 lists Xcode26.6/iOS26.5, not the local primary iPhone18Pro/iOS27.0 target. Hosted latest-available is not exact local parity or proof of global latest-release availability. Backwards compatibility is separate: iPhone11/iOS17.5 is the owner-designated minimum target, iOS17.5 remains the deployment floor, and later major versions are intended to work. Run affected compatibility checks locally and broader compatibility qualification before releases; routine CI is not a minimum-OS matrix.

GitHub Actions runs two independent30-minute jobs on PR/main: **Build + Unit Tests** (`core-unit`) and **UI Smoke Tests** (`smoke`). No mandatory coverage or merge job exists. Manual **Run workflow** offers `core`, `qualification` or exhaustive `all` in a separate180-minute extended job; use all before major releases. Jobs build independently on `macos-15` with read-only permissions, pinned Actions and superseded-run cancellation. Activity logs/summaries and compressed synthetic result bundles are retained7 days under suite-specific artifact names; no caches or user notebooks are uploaded. Previous hosted extended runs reported23 UI failures on Xcode16.4/iOS18.5; reducing routine scope does not resolve/relabel them. Hosted execution of the new split is unverified. Signing, identifiers, releases and support/privacy URLs remain owner-controlled; no publication/settings changes are authorized.

## Verification References

| Topic | Canonical Evidence |
| --- | --- |
| Accepted prototype, simulator results and accessibility limits | [Notebook prototype](docs/verification/NotebookPrototype.md) |
| Migration/recovery blockers and URL-policy findings | [Persistence and URL policy](docs/verification/Persistence.md) |
| ZIP64 measurements, hostile-input counterexamples and paused research | [Archives](docs/verification/Archives.md) |

These references retain decisive evidence and reproduction commands, not per-turn logs. Raw local `.xcresult`/logs live under ignored `.build/` and may not exist in another checkout. Git retains superseded history. None of the bounded measurements establishes release readiness or safety for valuable user data.

## Contributing

Read [.kilo/AGENTS.md](.kilo/AGENTS.md), [SYSTEM_DOCS.md](SYSTEM_DOCS.md), and the task-relevant approved plan. Use synthetic fixtures, preserve unrelated changes and report failed/unrun checks accurately. Keep README limited to current behavior and reusable setup; update topic evidence in place rather than appending execution diaries. Owner decisions belong in the plan, task status in Kanban, and release/change history in Git or a release-worthy changelog entry.
