# Climbing Notebook

Updated: 2026-11-01

Native, iPhone-primary climbing notebook for iOS 17+ with minimal iPad support. Product requirements and integrity contracts are in the [approved plan](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md).

## Current Capabilities

The owner-approved complete text-notebook milestone (§21.6) is **blocked, not implementation-complete or acceptance-ready**. Committed implementation opens an initially empty ordered notebook with area/route/pitch creation, rename, reorder and confirmed deletion, General/pitch text notes, isolated examples and retained read-only prototype access. The [verified disposition](docs/verification/NotebookPrototype.md#consolidated-final-disposition) records confirmed iOS17 native model-identity failures and active UI/audit gaps. Complete phone suites failed despite passing both combined coverage gates. The older accepted baseline is not acceptance of this milestone. Use only replaceable content; backup/recovery remain unavailable.

Historical prototype: CF-07A's owner-accepted synthetic-data browsing/explicit editing and CF-07C reading/navigation are preserved. The retained ordinary-entry reader is read-only; legacy mutation tests remain active separately. CF-07B's explicit durable note/order saves still have separate owner acceptance pending. Do not enter personal climbing data.

CF-07C shows full General notes, Jump to Pitches and pinned adjacent-pitch navigation. Historical CF-07D adds name-only Add/Cancel route drafts in existing fixture areas; its verification remains paused with tests retained and owner acceptance pending. The new notebook carries creation/cancel/retry requirements forward without retroactively accepting CF-07D; see [current results](docs/verification/NotebookPrototype.md#cf-07d-current-results). Neither slice establishes automatic saving or full-product completion.

Add, Save, Finish Editing, Done and confirmed Delete save on this device before closing. Cancel confirms discard when changed. Unsaved drafts/edits can be lost if the app closes; failures retain the editor for retry. The complete text hierarchy is implemented but not accepted; media intake, share delivery, URL copying and backup/restore are not implemented. M1 remains incomplete; archive research is paused, not a prerequisite for ordinary notebook increments. See the [Kanban](docs/WIP_KANBAN.md) and [verification references](#verification-references) for actual status and remaining gaps.

## Prerequisites

- macOS, Xcode and installed iOS Simulator runtimes; verify using `xcodebuild -version` and `xcrun simctl list devices available`.
- Git and network access for the approved Swift Package Manager dependency.
- No backend, account, environment variables, secrets or database service required.

## Build and Test

Open `ClimbingNotebook.xcodeproj`, select the ClimbingNotebook scheme and a simulator, then Run. For signing-free unit/UI tests and combined first-party coverage:

```sh
SIMULATOR_ID="installed-simulator-UUID" bash Scripts/test-ios.sh -quiet -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300 -collect-test-diagnostics never
bash Scripts/check-coverage.sh <result.xcresult>
bash Scripts/check-coverage.sh --self-test
git diff --check
```

The test script prints a unique result path by default. To choose one, set `RESULT_BUNDLE_PATH` to a new `.xcresult` path. During development, run only affected focused tests on iPhone 18 Pro. At final phase acceptance, run the full unit/UI suite once on iPhone 15 and once on iPhone 18 Pro; a completed full run supersedes a separate focused run on unchanged code. After fixes, rerun affected checks and invalidate only acceptance results affected by the changes. Reserve iterative iPad checks for layout-related changes. The selected Device Hub matrix is iPhone 15 / iOS 17.0 (`FB17E53E-C6B7-419C-8D52-6205AD037B52`), iPhone 18 Pro / iOS 27.0 (`087CDB20-DD15-43C5-8CBB-69D32A5A7478`), and iPad (10th generation) / iOS 26.4 (`A6DB0B3A-AD70-435D-AC6C-46B370A06BA7`), verified 2026-10-30. Reverify availability before execution; iPhone Duo is excluded from future suites. Do not create destinations or change simulator settings implicitly. The >=70% coverage gate combines app and extension Swift lines, excluding dependencies, tests and generated sources. Coverage does not override failing behavior tests. Current suites have two unresolved migration failures; do not skip them or weaken their assertions.

Focus durable-slice checks by adding `-only-testing:ClimbingNotebookTests/NotebookPersistenceTests -only-testing:ClimbingNotebookTests/NotebookPrototypeTests -only-testing:ClimbingNotebookUITests`. UI relaunch checks use a generated test-store UUID retained across launches, not a launch-time reset. Resolve the approved dependency with native tooling when needed:

```sh
xcodebuild -resolvePackageDependencies -project ClimbingNotebook.xcodeproj -scheme ClimbingNotebook
```

## Try the Text Notebook

1. Start in the empty notebook, choose Add Area, enter a replaceable name and Add. Open it and Add Route, then create five pitches with distinct names.
2. Edit General and each pitch's notes. Hide Keyboard changes focus only; Finish Editing explicitly saves.
3. Read full notes and use Jump to Pitches and Previous/Next. Navigation never reorders or saves.
4. Rename or reorder areas, routes and pitches using their separate editors. Save/Done commits the complete change; Cancel confirms discard when changed.
5. Try canceled and confirmed deletion. Nonempty areas cannot be deleted; route deletion removes its General note and pitches.
6. Terminate/relaunch to inspect acknowledged content. Unacknowledged edits may be lost. Open Examples is separate; Retained Prototype is read-only and never initializes an absent legacy root. These are development checks, not a claim that the blocked iOS17 workflow is reliable.

## Architecture and Data

The app opens the separately versioned SwiftData `Application Support/TextNotebook/notebook.store`, initially with only its initialization marker. `TextNotebookExamples/` initializes fictional examples only when explicitly opened. Retained `NotebookFixtureSlice/` content keeps its unchanged `NotebookSchemaV1` format and is read-only through ordinary app entry; saved legacy edits have unknown importance and are not classified as disposable. Editors buffer plain values separately from acknowledged snapshots; autosave is disabled. UUIDs, ownership, contiguous sibling order, exact text and revisions are validated. Invalid/incomplete stores fail visibly without reset, reseeding or empty-library fallback. Separate two-entity `LibraryStore` and generation descriptor/journal harnesses remain unchanged and isolated. The hidden share extension does not accept deliveries. No hosted API, telemetry, analytics, OCR, cloud sync or AI calls exist in this scope.

Technical project/scheme/module names use `ClimbingNotebook`. `DEVELOPMENT_DISPLAY_NAME` supplies generated display branding. Bundle identifiers rooted at `com.climbingnotebook.foundation` are provisional, not registered release identities.

## Dependencies

ZIPFoundation 0.9.20 is resolved at `22787ffb59de99e5dc1fbfe80b19c97a904ad48d` in the shared `Package.resolved` and linked only to unit tests. Its MIT notice is in `THIRD_PARTY_NOTICES`. Native Xcode/SPM resolution and the committed resolution file are approved project exceptions. Review dependency updates monthly and before release, with archive regression testing; do not modify cached checkouts. Public-API inspection/extraction gaps prevent production restore acceptance.

## CI and Distribution

GitHub Actions runs on pull requests/main using `macos-15`, read-only permissions, a pinned checkout Action, cancellation of superseded runs and a 30-minute timeout. It uses the runner's Xcode/simulator and uploads no artifacts or caches. Hosted CI has not been verified from this local work. Signing, permanent identifiers, releases and support/privacy URLs remain owner-controlled release prerequisites; no publication or repository-setting change is authorized by implementation approval.

## Verification References

| Topic | Canonical Evidence |
| --- | --- |
| Accepted prototype, simulator results and accessibility limits | [Notebook prototype](docs/verification/NotebookPrototype.md) |
| Migration/recovery blockers and URL-policy findings | [Persistence and URL policy](docs/verification/Persistence.md) |
| ZIP64 measurements, hostile-input counterexamples and paused research | [Archives](docs/verification/Archives.md) |

These references retain decisive evidence and reproduction commands, not per-turn logs. Raw local `.xcresult`/logs live under ignored `.build/` and may not exist in another checkout. Git retains superseded history. None of the bounded measurements establishes release readiness or safety for valuable user data.

## Contributing

Read [.kilo/AGENTS.md](.kilo/AGENTS.md), [SYSTEM_DOCS.md](SYSTEM_DOCS.md), and the task-relevant approved plan. Use synthetic fixtures, preserve unrelated changes and report failed/unrun checks accurately. Keep README limited to current behavior and reusable setup; update topic evidence in place rather than appending execution diaries. Owner decisions belong in the plan, task status in Kanban, and release/change history in Git or a release-worthy changelog entry.
