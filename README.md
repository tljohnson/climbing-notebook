# Climbing Notebook

Updated: 2026-10-29

Native, iPhone-primary climbing notebook for iOS 17+ with minimal iPad support. Product requirements and integrity contracts are in the [approved plan](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md).

## Current Capabilities

The disposable synthetic-data notebook prototype is implemented and owner-tested. Browse areas, routes and five ordered pitches; use Previous/Next for pitch navigation. Edit Notes and Edit Pitch Order open separate editing workflows. All edits reset on relaunch, as the persistent prototype notice states. Do not enter personal climbing data.

Durable notebook editing, media intake, share delivery, URL copying and backup/restore are not implemented. M1 remains incomplete. The next recommended reviewed packet is ordinary durable save/relaunch; archive research is paused, not a prerequisite for that packet. See the [Kanban](docs/WIP_KANBAN.md) for task status and [verification references](#verification-references) for measured results and feature-specific blockers.

## Prerequisites

- macOS, Xcode and installed iOS Simulator runtimes; verify using `xcodebuild -version` and `xcrun simctl list devices available`.
- Git and network access for the approved Swift Package Manager dependency.
- No backend, account, environment variables, secrets or database service required.

## Build and Test

Open `ClimbingNotebook.xcodeproj`, select the ClimbingNotebook scheme and a simulator, then Run. For signing-free unit/UI tests and combined first-party coverage:

```sh
SIMULATOR_ID="installed-simulator-UUID" bash Scripts/test-ios.sh -quiet -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120 -collect-test-diagnostics never
bash Scripts/check-coverage.sh <result.xcresult>
bash Scripts/check-coverage.sh --self-test
git diff --check
```

The test script prints a unique result path by default. To choose one, set `RESULT_BUNDLE_PATH` to a new `.xcresult` path. Reverify destinations and run full suites on iOS 17 and the newest installed runtime. The >=70% coverage gate combines app and extension Swift lines, excluding dependencies, tests and generated sources. Coverage does not override failing behavior tests. Current suites have two unresolved migration failures; do not skip them or weaken their assertions.

Focus prototype checks by adding `-only-testing:ClimbingNotebookTests/NotebookPrototypeTests -only-testing:ClimbingNotebookUITests`. Resolve the approved dependency with native tooling when needed:

```sh
xcodebuild -resolvePackageDependencies -project ClimbingNotebook.xcodeproj -scheme ClimbingNotebook
```

## Try the Prototype

1. Open Example Granite -> Paper Skyline and read route notes and five pitches.
2. Open a pitch; Previous/Next changes selection without changing order.
3. Choose Edit Notes, enter synthetic text, Hide Keyboard, then Finish Editing.
4. From the route, choose Edit Pitch Order; move a pitch or use its drag handle, then Done. Names and notes stay attached.
5. Visit Example Meadow and Unwritten Line for empty cases. Terminate/relaunch to confirm edits reset.

## Architecture and Data

The app entry opens transient SwiftUI state under `Features/NotebookPrototype/`; it does not open a library store. Separate two-entity SwiftData and generation descriptor/journal harnesses exercise persistence/recovery feasibility, not a production schema or restore service. The share extension is hidden from the share sheet and does not accept or acknowledge deliveries. No hosted API, telemetry, analytics, OCR, cloud sync or AI calls exist in this scope.

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
