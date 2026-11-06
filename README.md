# Climbing Notebook

Updated: 2026-11-06

Native, iPhone-primary climbing notebook for iOS 17.5+ with minimal iPad support. Product requirements and integrity contracts are in the [approved plan](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md).

**Build targets (owner direction,2026-11-06):** iPhone18 / iOS27 is primary for routine local builds and feature verification; the installed iPhone18Pro/iOS27 simulator is the current representative. iPhone11 / iOS17.5 is the minimum-support compatibility target, not the primary development gate. Keep the iOS17.5 deployment floor; run focused minimum-target checks when affected and before release. Results from another device model must retain its actual name rather than being labeled iPhone11 qualification.

## Current Capabilities

The notebook opens an initially empty ordered library with area/route/pitch creation, rename, reorder and confirmed deletion, General/pitch notes, isolated examples and retained read-only prototype access. Route/pitch images can be selected through the native Photos picker, reviewed and explicitly saved as independent local originals, then read with zoom/pan and complete notes. Caption/order/removal use a separate Save/Cancel editor; removing an attachment never deletes its Photos source. Image core units and focused simulator workflows pass, with actual Photos/device/VoiceOver limits and a baseline automation failure recorded in [verification](docs/verification/NotebookPrototype.md#image-implementation-handoff-2026-11-06). Prior owner checks do not accept the new feature. Backup/restore remains unimplemented. Keep another copy of important notes and images.

Historical prototype: CF-07A's owner-accepted synthetic-data browsing/explicit editing and CF-07C reading/navigation are preserved. The retained ordinary-entry reader is read-only; legacy mutation tests remain active separately. CF-07B's explicit durable note/order saves still have separate owner acceptance pending. Do not enter personal climbing data.

CF-07C shows full General notes, Jump to Pitches and pinned adjacent-pitch navigation. Historical CF-07D adds name-only Add/Cancel route drafts in existing fixture areas; its verification remains paused with tests retained and owner acceptance pending. The new notebook carries creation/cancel/retry requirements forward without retroactively accepting CF-07D; see [current results](docs/verification/NotebookPrototype.md#cf-07d-current-results). Neither slice establishes automatic saving or full-product completion.

Save commits creation, names, notes, images and ordering on this device before closing; confirmed Delete remains separate. Cancel confirms discard when changed. Unsaved drafts/edits can be lost if the app closes; failures retain the editor for retry. The retained legacy test flow keeps its historical labels. CF-07E acceptance remains separate from image implementation; share delivery, website capture, URL copying, OCR, PDF, sync, export and backup/restore are not implemented. Text export's approved contract is deferred in favor of images. M1 remains incomplete; archive research stays paused. See [Kanban](docs/WIP_KANBAN.md) and [verification](#verification-references) for status and limits.

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

`Scripts/test-ios.sh` defaults to `fast`: complete current/retained-format unit classes plus three UI workflows in `Scripts/mvp-smoke-tests.txt`. `core-unit` and `smoke` run these separately in CI. Image units cover originals, migration, metadata/state and reader rendering; smoke adds synthetic select/review/Save/read/relaunch to the existing hierarchy checks. Synthetic providers use the same file-copy/save path but do not establish actual Photos-provider behavior. `core`/`mvp-core-tests.txt` preserves extended functional regressions; `core-ui` selects those UI workflows. Update selections by risk, not coverage percentage. Existing assertions remain active.

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

### Images

Choose **Add Images** on an ordinary route/pitch, select in Photos, review copies/captions, then **Save**. Cloud-only Photos items may need a connection before copying; saved originals are read locally. Partial failures retain ready selections; Retry or explicitly Remove Selection before saving. **Image Actions → Manage Images** edits captions/order/removal; changes apply only on Save. Read with Open Image, Image Tools (Fit Width/Image, Zoom and Pan), Previous/Next Image and Notes. Pitch images and shared route references stay distinct. Examples/retained content cannot receive images.

Supported received representations: JPEG, PNG and single-primary HEIC/HEIF, up to50 MiB/50 million pixels/32,768 pixels per edge;10 selections per batch,20 saved images per owner,120-character captions. Animated/video/PDF/RAW and image editing are not supported. Exact received bytes, orientation and metadata are preserved; this is not a guarantee that Photos supplied an unedited camera master. Metadata may include location. Retain only content you have permission to use. Missing originals stay visible as actionable errors; the app does not silently repair them from Photos or use a thumbnail as the original.

The app opens separately versioned SwiftData `Application Support/TextNotebook/notebook.store`; V2 adds image assets/attachments and upgrades V1 without reseeding or changing authored IDs/text/order/revisions. `TextNotebookExamples/` stays separate. App-owned immutable originals live under the corresponding root's `Images/Originals`; staging/operation manifests track only known operation files for reference-safe cleanup. Files publish before metadata acknowledgment. Thumbnails are regenerable derivatives, not the saved originals. Retained `NotebookFixtureSlice/NotebookSchemaV1` and diagnostic LibraryStore/generation roots stay untouched. Memory-only drafts are separate from saved snapshots; autosave is disabled. Invalid/incomplete graphs fail visibly without reset or empty fallback. No extension delivery, backend, analytics, OCR, cloud sync or AI calls exist. See the [approved image contract](Image-Supported-Notebooks-FeaturePlan.md) for compatibility/file boundaries; this is not backup/recovery qualification.

Technical project/scheme/module names use `ClimbingNotebook`. `DEVELOPMENT_DISPLAY_NAME` supplies generated display branding. Bundle identifiers rooted at `com.climbingnotebook.foundation` are provisional, not registered release identities.

## Dependencies

ZIPFoundation 0.9.20 is resolved at `22787ffb59de99e5dc1fbfe80b19c97a904ad48d` in the shared `Package.resolved` and linked only to unit tests. Its MIT notice is in `THIRD_PARTY_NOTICES`. Native Xcode/SPM resolution and the committed resolution file are approved project exceptions. Review dependency updates monthly and before release, with archive regression testing; do not modify cached checkouts. Public-API inspection/extraction gaps prevent production restore acceptance.

## CI and Distribution

Per-commit development targets the latest stable toolchain/iOS runtime installed on the current `macos-26` hosted image, selected explicitly by `Scripts/select-ci-ios.rb`. It exports `DEVELOPER_DIR` and `SIMULATOR_ID` for all later steps and logs exact versions/device; it does not pick the first iPhone or use the image's default Xcode. Runner inventory checked2026-11-05 lists Xcode26.6/iOS26.5, not the local primary iPhone18Pro/iOS27.0 target. Hosted latest-available is not exact local parity or proof of global latest-release availability. Backwards compatibility is separate: iPhone11/iOS17.5 is the owner-designated minimum target, iOS17.5 remains the deployment floor, and later major versions are intended to work. Run affected compatibility checks locally and broader compatibility qualification before releases; routine CI is not a minimum-OS matrix.

GitHub Actions runs two independent30-minute jobs on PR/main: **Build + Unit Tests** (`core-unit`) and **UI Smoke Tests** (`smoke`). No mandatory coverage or merge job exists. Manual **Run workflow** offers `core`, `qualification` or exhaustive `all` in a separate180-minute extended job; use all before major releases. Jobs build independently on `macos-26` with read-only permissions, pinned Actions and superseded-run cancellation. Activity logs/summaries and compressed synthetic result bundles are retained7 days under suite-specific artifact names; no caches or user notebooks are uploaded. Both routine jobs passed in [run42130921302](https://github.com/tljohnson/climbing-notebook/actions/runs/42130921302), revision `d742ea63ab2e9c788c8afa2cdd1fedfd053ff636`; GitHub API run/job conclusions independently checked2026-11-06. Manual extended tests were not run. Previous hosted extended runs reported23 UI failures on Xcode16.4/iOS18.5; this routine pass does not resolve/relabel them or imply owner milestone acceptance. Signing, identifiers, releases and support/privacy URLs remain owner-controlled; no publication/settings changes are authorized.

## Verification References

| Topic | Canonical Evidence |
| --- | --- |
| Accepted prototype, simulator results and accessibility limits | [Notebook prototype](docs/verification/NotebookPrototype.md) |
| Migration/recovery blockers and URL-policy findings | [Persistence and URL policy](docs/verification/Persistence.md) |
| ZIP64 measurements, hostile-input counterexamples and paused research | [Archives](docs/verification/Archives.md) |

These references retain decisive evidence and reproduction commands, not per-turn logs. Raw local `.xcresult`/logs live under ignored `.build/` and may not exist in another checkout. Git retains superseded history. None of the bounded measurements establishes release readiness or safety for valuable user data.

## Contributing

Read [.kilo/AGENTS.md](.kilo/AGENTS.md), [SYSTEM_DOCS.md](SYSTEM_DOCS.md), and the task-relevant approved plan. Use synthetic fixtures, preserve unrelated changes and report failed/unrun checks accurately. Keep README limited to current behavior and reusable setup; update topic evidence in place rather than appending execution diaries. Owner decisions belong in the plan, task status in Kanban, and release/change history in Git or a release-worthy changelog entry.
