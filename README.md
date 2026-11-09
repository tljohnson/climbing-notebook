# Climbing Notebook

Updated: 2026-11-09

Native, iPhone-primary climbing notebook for iOS 17.5+ with minimal iPad support. Product requirements and integrity contracts are in the [approved plan](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md).

**Build targets (owner direction,2026-11-06):** iPhone18 / iOS27 is primary for routine local builds and feature verification; the installed iPhone18Pro/iOS27 simulator is the current representative. iPhone11 / iOS17.5 is the minimum-support compatibility target, not the primary development gate. Keep the iOS17.5 deployment floor; run focused minimum-target checks when affected and before release. Results from another device model must retain its actual name rather than being labeled iPhone11 qualification.

## Current Capabilities

The notebook opens an initially empty ordered library with area/route/pitch creation, rename, reorder and confirmed deletion, General/pitch notes, isolated examples and retained read-only prototype access. Route/pitch images can be selected through the native Photos picker, reviewed and explicitly saved as independent local originals, then read with zoom/pan and complete notes. Caption/order/removal use a separate Save/Cancel editor; removing an attachment never deletes its Photos source. Read complete notes with Jump to Pitches and pinned adjacent-pitch navigation. Examples and retained content stay separate from the ordinary notebook.

Save commits creation, names, notes, images and ordering on this device before closing; confirmed Delete remains separate. Cancel confirms discard when changed. Unsaved drafts/edits can be lost if the app closes; failures retain the editor for retry. Backup/restore, share delivery, website capture, URL copying, OCR, PDF, sync and export are not implemented. Keep another copy of important notes and images; this app is not qualified as the only copy of valuable data. Use synthetic fixtures for development and verification, not personal climbing data.

Implemented capability is not milestone or release acceptance. [Kanban](docs/WIP_KANBAN.md) owns current status; [verification topics](#verification-references) own results, failed checks and unverified Photos/device/VoiceOver limits. Historical CF-07B/CF-07D were superseded by CF-07E with no separate acceptance or resumed qualification requested; this does not retroactively accept those slices. Retained data and legacy tests remain preserved; see the [archive disposition](docs/WIP_KANBAN_ARCHIVE_2026-11-05.md) only for history.

## Prerequisites

- macOS, Xcode and installed iOS Simulator runtimes; verify using `xcodebuild -version` and `xcrun simctl list devices available`.
- Git and network access for the approved Swift Package Manager dependency.
- No backend, account, environment variables, secrets or database service required.

## Build and Test

Open `ClimbingNotebook.xcodeproj`, select the ClimbingNotebook scheme and a simulator, then Run. For signing-free fast unit/UI checks:

```sh
SIMULATOR_ID="installed-simulator-UUID" bash Scripts/test-ios.sh --suite fast -quiet
git diff --check
```

`Scripts/test-ios.sh` defaults to `fast`: complete current/retained-format unit classes plus the UI workflows in `Scripts/mvp-smoke-tests.txt`. `core-unit` and `smoke` run these separately in CI. Image units cover originals, migration, metadata/state and reader rendering; smoke adds synthetic select/review/Save/read/relaunch to the existing hierarchy checks. Synthetic providers use the same file-copy/save path but do not establish actual Photos-provider behavior. `core`/`mvp-core-tests.txt` preserves extended functional regressions; `core-ui` selects those UI workflows. Update selections by risk, not coverage percentage. Existing assertions remain active.

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

GitHub Actions runs native build/unit and UI smoke checks on pull requests and pushes to `main`. `Scripts/select-ci-ios.rb` explicitly selects the latest stable Xcode and available iOS runtime installed on the hosted runner, exports `DEVELOPER_DIR` and `SIMULATOR_ID`, and logs actual versions/device. Hosted latest-available is not exact local parity or proof of global latest-release availability. Routine CI is not minimum-OS qualification; use the [runtime targets](#climbing-notebook) for affected local compatibility checks and broader qualification before releases.

Use Actions → **iOS MVP Core** → **Run workflow** to select `core`, `qualification` or exhaustive `all` for extended checks; use `all` before major releases. The [workflow](.github/workflows/ios-ci.yml) owns the job matrix, runner image, timeouts, artifact retention and other execution settings. No mandatory coverage or merge job exists. Artifacts contain synthetic test evidence, not user notebooks or caches. Consult [verification](docs/verification/NotebookPrototype.md#conclusion) for hosted outcomes and limits, not an inferred full-suite pass or owner acceptance. Signing, identifiers, releases and support/privacy URLs remain owner-controlled; no publication/settings changes are authorized.

## Verification References

| Topic | Canonical Evidence |
| --- | --- |
| Current notebook/image results, historical prototype evidence and accessibility limits | [Notebook prototype](docs/verification/NotebookPrototype.md) |
| Migration/recovery blockers and URL-policy findings | [Persistence and URL policy](docs/verification/Persistence.md) |
| ZIP64 measurements, hostile-input counterexamples and paused research | [Archives](docs/verification/Archives.md) |

These references retain decisive evidence and reproduction commands, not per-turn logs. Raw local `.xcresult`/logs live under ignored `.build/` and may not exist in another checkout. Git retains superseded history. None of the bounded measurements establishes release readiness or safety for valuable user data.

## Contributing

Read [.kilo/AGENTS.md](.kilo/AGENTS.md), [SYSTEM_DOCS.md](SYSTEM_DOCS.md), and the task-relevant approved plan. Use synthetic fixtures, preserve unrelated changes and report failed/unrun checks accurately. Keep README limited to current behavior and reusable setup; update topic evidence in place rather than appending execution diaries. Owner decisions belong in the plan, task status in Kanban, and release/change history in Git or a release-worthy changelog entry.
