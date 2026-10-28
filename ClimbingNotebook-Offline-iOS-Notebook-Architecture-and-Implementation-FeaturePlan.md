# Climbing Notebook Offline iOS Notebook: Architecture and Implementation Feature Plan

**Status:** Owner-approved implementation plan.
**Prepared:** 2026-10-27
**Updated:** 2026-10-28
**Inputs:** `handoff.md` and the owner's clarification answers in this session.
**Deliverable boundary:** Approved implementation specification. The repository now contains a partial M0/M1 foundation; prospective files and contracts below are not claims of implemented features. Current measured evidence and remaining gates are maintained in `README.md` under Feasibility Status.

## 1. Executive Summary

Climbing Notebook is a native, offline-first personal climbing notebook, not a guidebook service or a social network. A climber owns the local library, can consult all saved originals without connectivity, needs no account, and can export and replace-restore the library without a subscription.

The first public release includes the full core notebook, images and PDF originals, plain-text and pasted-text intake, user-initiated single-page URL copying, a receiving share extension, editable import review, source attribution, and verified complete backup/restore. **OCR and automatic structured extraction are deferred.** An image or scanned PDF is useful as a viewable original in v1, without invented route fields. Digital PDF text may be offered as unstructured selectable text when PDFKit exposes it; it is not a requirement to recognize scanned text.

Recommend SwiftUI, Swift, SwiftData with explicit persistence operations, app-managed original files, PDFKit/ImageIO, PhotosPicker, Foundation file APIs, and a small share-extension inbox. The owner approved an iOS 17 minimum; verify minimum/current OS behavior during foundation testing. All required frameworks are available at that baseline; no verified v1 requirement justifies excluding those devices. Build with a currently accepted Xcode/SDK, independently of the deployment target.

The largest risks are data loss at database/file boundaries, destructive restore, share-extension interruptions, unfunded macOS automation, hostile URL content, and copyright assumptions. Address these early through persistence/restore and URL-policy spikes, fault injection, portable archive contracts, an inbox that never writes to the library database, and explicitly initiated single-page capture rather than unattended source-site crawling.

## 2. Decisions, Assumptions, and Approval

### 2.1 Confirmed Owner Decisions

| Topic | Confirmed direction |
| --- | --- |
| Product platform | Native local Swift/SwiftUI app. Service-specific Go, PostgreSQL, OIDC, Docker, health/metrics/OpenAPI requirements do not apply. |
| First-release intake | Images, PDFs, and text are required. Postpone OCR. |
| Share workflow | A receiving share extension is essential for v1, not a future enhancement. |
| Organization | Flat areas in v1; no nested-area UI or hierarchy field needed yet. |
| Pitch count | Derive from actual pitch records, not a separately editable route count. |
| Length | Optional explicitly entered route total, independent of individual pitch lengths. |
| Grades/styles | Free-text grades; small extensible style vocabulary. |
| Restore | Replace-only, with validation and rollback. No merge. |
| Source handling | Owner follow-up requires copying from a user-supplied URL after an explicit user action, not reference-only handling. Preserve selected originals and received/extracted text until explicit deletion. Camera deferred. |
| Funding | Assume Apple developer membership exists. No other recurring costs. |
| Deployment target | iOS 17+ approved. Minimum/current runtime and device testing remain implementation verification tasks. |
| Staffing/development | One volunteer developer using an existing MacBook Pro, VS Code, and GitHub. Weekly availability is not specified. |
| Repository/CI | GitHub Free, public repository confirmed by owner. Use standard hosted macOS GitHub Actions; no GitLab pipeline or runner-tag requirement. |
| Approval and execution | Owner approved the plan after the dependency recommendation and confirmed public GitHub publication. |
| Dependency exceptions | Approved plan includes native Xcode/SPM resolution on local/hosted Macs, reviewed stable ZIPFoundation resolution with committed Package.resolved, and immutable third-party Action references with deliberate updates. |
| Integrity limits/restore | Initial intake/archive/library limits and generation-based replace/revert behavior approved as measurable targets, subject to the stated validation spikes. |
| Platform presentation | Owner confirmed iPhone as primary target with minimal iPad support. |
| Code license | Owner approved starting with MIT after discussing GPLv3 distribution concerns; MIT supersedes the earlier GPLv3 selection for first-party code. Preserve third-party notices. |
| Release ownership | Leif Johnson owns signing, releases, support and privacy URLs. Owner-controlled leifdigital.com will host new app pages without additional hosting costs; pages are not yet built. |
| Language and retention | English-first UI with Unicode user content confirmed; retain originals/raw text until explicit deletion, without automatic expiry of ready deliveries or saved drafts. |
| Minimum-runtime availability | iOS 17.0 Simulator installation and execution verified on 2026-10-28: the 19-test foundation suite passes on iPhone 15 Pro, as well as iOS 27.0. Physical-device coverage remains unverified; deployment target remains iOS 17. |

The owner's explicit answers supersede handoff scope ambiguities. In particular, the handoff's OCR acceptance item becomes a later-release criterion, while non-OCR intake and share receiving become v1 requirements.

### 2.2 Proposed Defaults, Not Yet Approved

- Schedule illustrations use 10 hours/week, not an owner-specified commitment. Staffing is confirmed as one volunteer; do not assume additional reviewers are available.
- Owner-confirmed presentation: iPhone-first native UI with minimal adaptive iPad support and no iPad-exclusive features. Verify basic iPad functionality.
- Foundation/SwiftData APIs must remain within the approved iOS 17 deployment target. Do not use newer SwiftData inheritance or custom-store APIs for v1.
- SwiftData selected only after the foundation proof of concept passes migration, snapshot, and generation-switch recovery tests. Core Data is the fallback if concrete failures cannot be resolved, not a second implementation maintained in parallel.
- Minimal structured import: review manually, optionally copy unstructured text into selected sections. No heuristic name/grade/pitch extraction until the post-v1 import phase.
- Owner approved MIT as the starting first-party code license on 2026-10-28, superseding the earlier GPLv3 selection. Code licensing never licenses user-imported material. Preserve dependency notices and confirm the copyright holder before finalizing the license notice; release ownership and Novacoast builder attribution do not independently establish copyright ownership.
- Approved dependency direction: ZIPFoundation through Swift Package Manager with reviewed stable-release updates and committed Package.resolved for reproducibility. Native resolution and the narrow reproducibility exceptions are included in the owner's subsequent plan approval. No dependency installation occurs in this planning session.

### 2.3 Approval Gates

Approval of this plan authorizes only the subsequently agreed implementation scope, including user-initiated single-page copying as requested by the owner. It does not authorize payments, publishing, signing changes, unattended crawling, access-control bypasses, or uploading user data. Resolve the policy and infrastructure gates in section 16 before dependent work begins. Any failed spike that changes persistence, backup format, or deployment target requires a documented owner decision before proceeding.

## 3. Goals, Users, and Scope

### 3.1 Personas and Jobs

| Persona | Primary job | Success signal |
| --- | --- | --- |
| Multipitch trad climber | Prepare approach, pitch, belay, gear, and descent notes | Can reach relevant beta quickly in Airplane Mode |
| Screenshot collector | Organize screenshots, topos, PDFs, and text | Shares material into a reviewable inbox without transcription being mandatory |
| Privacy-conscious notebook owner | Keep and recover personal information | No app account or developer data collection; portable complete backup |
| Volunteer maintainer | Make safe incremental changes | Small project, clear contracts, meaningful tests, documented release ownership |

### 3.2 Committed V1 Requirements

| ID | Requirement | Verification |
| --- | --- | --- |
| R01 | Area and route create/edit/delete, flat organization, route moves between areas | Model and UI tests |
| R02 | Route name, area, grade, styles, optional total length, description, sources | Validation and persistence round trip |
| R03 | Pitch create/edit/reorder/delete with grade, length, description, protection, and belay notes | Five-pitch acceptance scenario |
| R04 | Approach, descent, gear, general, and custom route note sections | Empty/custom/reorder tests |
| R05 | Multiple images/PDFs associated with route, pitch, or note; captions, tags, ordering | Attachment ownership and viewer tests |
| R06 | Local area/route name search; browse with grade/style/pitch summary | Offline search tests |
| R07 | Automatic prompt persistence, clear pending/error states, recovery from interruptions | Save-failure and termination tests |
| R08 | Image/PDF/plain-text/pasted-text intake, explicit user-initiated URL copying, and share extension with manual review before commit | Intake/URL matrix and inbox recovery tests |
| R09 | Complete versioned backup and validated replace restore, preserving IDs, sources, drafts, and media | Semantic and byte-level round trip |
| R10 | Safe deletion, shared-file protection, orphan reconciliation | Reference-count and fault-injection tests |
| R11 | Dynamic Type, VoiceOver, readable contrast, alternative pitch reorder actions | Manual accessibility and UI tests |
| R12 | Honest offline/local status and external-link warnings | Airplane Mode and missing-file tests |

### 3.3 Deferred or Excluded

P1 after v1: Vision OCR, explainable field extraction, uncertainty indicators and language/layout handling, grade/style filters, optional favorites, direct camera capture.

P2 only after separate planning: CloudKit synchronization, conflict resolution, annotation, GPX/offline maps, selective sharing/collaboration, public data. Stable IDs and provenance are preparation, not a promise of CloudKit compatibility.

Excluded: backend, authentication, subscriptions, ads, paid APIs, analytics SDKs, LLM calls, background/bulk source downloads, recursive crawling, private endpoints, access-control circumvention, navigation/weather services, and public redistribution of imported copyrighted material. Explicit user-initiated copying of one supplied page is included; it is not a claim that all sites permit copying.

## 4. Screen and Interaction Specifications

### 4.1 Navigation

Use a native library navigation stack, route detail as the primary workspace, and toolbar access to Import Inbox and Settings. On wider screens, a split presentation may reuse the same views. Avoid adding a tab solely for empty future features.

### 4.2 Library and Areas

- Library displays flat areas plus local search across areas/routes. Route rows show name, free-text grade, style summary, and entered pitch count.
- A new route requires a nonblank name and an area; create an area inline if necessary. Duplicate names are allowed and distinguished by area and metadata.
- Search is case/diacritic-insensitive substring matching of normalized names; literal user input is never executable predicate syntax. Empty search returns the current browse context. Use deterministic name/UUID tie-breaking and bounded paged fetches.
- Area deletion is blocked while routes remain. Offer moving routes to another area first; do not hide cascade deletion behind an area action. Bulk destructive route deletion is not required.
- Empty library, no search results, unreadable store, and unavailable protected files have distinct states. Store failure must never silently open a new empty library.

### 4.3 Route Detail and Editing

Display a compact header, save/availability state, overview, quick jumps to Approach/Pitches/Descent/Gear/Media, ordered pitches, note sections, media, and a Sources section. These are native readable controls, not a dense dashboard. Pitch access should take one tap from the visible list and at most a quick-jump plus a tap from a long route.

Use plain text, not HTML or an embedded rich-text engine. Common empty sections show an Add action without requiring content. Custom sections can have arbitrary titles and order. Reordering sections does not alter their kind. One common section of each predefined kind per route; multiple custom sections are allowed.

Existing-field edits use an editor buffer, a short debounce (proposed 300-500 ms), and explicit save operations on focus loss/navigation/scene transition when time permits. Show `Saving`, `Saved on this device`, or `Not saved - retry`. A saved indicator appears only after persistent save succeeds. Do not rely on SwiftData's implicit autosave timing or background callbacks for correctness. Unexpected termination can lose an edit not yet acknowledged as saved; do not promise otherwise.

New route/pitch sheets and batch import have explicit Add/Cancel semantics using separate drafts. Cancel never rolls back unrelated saved edits. Existing automatically saved edits have Done/Back, not a misleading Cancel. A locally retained draft supports recovery; destructive discard requires confirmation when nonempty. A failed save keeps the buffer and offers retry; navigation must not silently discard it.

Route deletion confirms the route name and counts of affected pitches, notes, and attachments. Committed deletion is durable before file reclamation begins. It does not delete unrelated drafts or files referenced by other routes.

### 4.4 Pitch Editor

Sequence is contiguous, zero-based internally; show 1-based position. Optional display name is separate from sequence and is never renumbered as authored text. Expose Move Up/Down for accessibility as well as drag reorder. Reorder commits the whole sibling sequence in one database save. A stale editor revision causes a reload/review conflict, not a last-write-wins overwrite.

Length accepts positive finite decimal values plus meters/feet; no implicit unit or silent conversion. Unknown grade/length stays blank. Route count displays `0 pitches entered` when none exist, not a claim that the route has no pitches. Users can write an expected total in overview/general notes; there is no second count field in v1. Route total and entered-pitch sum may differ; a computed sum, if shown, is labeled and never updates the route total.

### 4.5 Media and PDF Viewer

Use generated thumbnails for grids, ImageIO downsampling for display, zoom/pan for images, and PDFKit for offline multipage PDF viewing. Preserve the received original bytes; Photos providers may supply a compatible representation rather than the camera's archival original, so do not claim recovery of an unavailable original. No recompression on backup.

Show caption, tags, source, association, and original file type. A PDF can be attached directly to any supported owner and opened without rasterizing all pages. Corrupt or unsupported originals yield an explicit error without deleting the file. Missing files show an incomplete-local-content state, not an offline-ready badge. Dynamic Type applies to surrounding controls; image captions provide VoiceOver context but do not claim to make topo geometry accessible.

### 4.6 Intake, Inbox, and Review

1. Intake via PhotosPicker, Files, user-triggered Paste, user-supplied URL with explicit Copy Page action, or Share with Climbing Notebook. Receiving/pasting a URL alone saves a reference draft and does not make a network request.
2. Copy provider-owned files into durable managed intake storage before acknowledging receipt; original provider URLs are temporary, not persistent references.
3. Display an Inbox draft with file list, previews, optional source URL/title/attribution, and any available raw text. Images and scanned PDFs explicitly say `Text recognition is not included in this version`.
4. User selects New Route or Add to Existing Route. For New Route, manually enter name/area and optional fields. For Existing Route, default to adding attachments or a new imported/custom note, never replacing existing prose.
5. User selects route/pitch/note attachment targets and may copy text into chosen sections. No structured inference in v1. Any explicit replacement of existing text requires a preview and confirmation.
6. Commit validates all targets and files, persists provenance and record changes, and marks the draft consumed in the same database save. On failure keep the draft reviewable. Discard deletes only draft-owned references after confirmation.

V1 accepts JPEG, PNG, HEIC, PDF, UTF-8 plain-text files (optional UTF-8 BOM), pasted plain text, and HTTP(S) URLs for references or explicit page copying. Reject other text-file encodings with an actionable conversion message rather than replacement-character decoding. Unsupported formats, videos/Live Photo motion, folders, rich text, and encrypted/password-required PDFs are not silently flattened or downloaded. For a Live Photo, offer only an image representation if the provider supplies one.

Digital PDF text may be shown as an unstructured convenience; preserve page boundaries and warn that column reading order is unverified. No automatic pitch grouping. Keep raw received text separate from user-edited text. URLs inside received prose are not fetched. A shared URL and image/text can belong to the same draft; do not assume the host supplies the full webpage.

#### User-Initiated URL Copy Flow

From a typed/pasted/shared URL draft, offer `Keep Link Only` and `Copy Page`. Explain before loading that copying needs network access, contacts the source site, and requires the user to have applicable rights. The Copy Page tap initiates one page load, followed by preview/review; nothing is written into a saved route automatically. Allow retry, cancellation, and a link-only fallback.

Proposed implementation: an isolated, nonpersistent WKWebView preview with no app credentials, custom cookies, or privileged script bridge. Loading can execute ordinary site scripts and request subresources; disclose that this is browsing, not offline viewing. After load, let the user explicitly capture page text and select individual page images/topos to copy. Preserve received text before edits, requested/final URLs, title, capture time, and user-supplied attribution. Generic rendered-page text extraction is not automatic route/grade/pitch parsing. Show the captured text and image candidates for selection before durable draft commit; do not silently import navigation/ads as climbing beta or download every image on the site.

Copy the page's readable text as the proposed payload and selected image representations into managed storage. Capture is not a full webpage archive: no executable HTML/scripts, embedded trackers, linked pages, or live remote image references are stored as offline beta. Save selected PDF links only after a separate explicit document-copy action through the same limits/validation. Scanned images/PDFs remain viewable without OCR. If generic capture fails, offer user selection/paste, browser sharing, or manual file intake; no source integration is required for those fallbacks.

Never recurse, follow route lists, prefetch linked routes, refresh captures in the background, solve CAPTCHAs, bypass logins/paywalls/DRM, reuse another app's cookies, or access private endpoints. Public availability and a user tap do not establish legal permission; show source-specific restrictions where known and obtain appropriate review before shipping site-tailored extraction. The generic URL-copy capability is committed v1 scope, not deferred merely because a source lacks an API.

### 4.7 Settings and Data Management

Provide Export Complete Backup, Restore/Replace Library, backup history (creation/export handoff time, not a guarantee of external durability), approximate storage by originals/drafts/cache, pending inbox count, privacy/local storage explanation, source rights guidance, version, licenses, and project information.

Restore displays archive version/date/counts, validation outcome, current-library counts, an optional export-current-library action, and an explicit Replace confirmation. A restore never starts from merely opening a file. No Merge button. Warn that replacements remove all current saved records and drafts; unprocessed share deliveries remain queued and are identified as pending afterward.

## 5. Architecture and Technology Decisions

### 5.1 Boundaries

Presentation -> feature coordinators -> library persistence and managed-file services. Intake -> draft review -> the same library mutation path. Backup uses portable DTOs, not UI state or a raw database copy. The share extension writes only an App Group inbox; the main app alone owns and mutates its SwiftData library.

Use a single Xcode project with app, share-extension, unit/integration-test, and UI-test targets. Small shared source files for inbox contracts and safe file transfer can have membership in both app and extension targets; no package split is necessary. Shared files must use extension-safe APIs only. Avoid a generic repository-per-entity hierarchy, dependency injection framework, networking stack, or hypothetical sync engine.

Use `ClimbingNotebook` for project, scheme, module and source names, and `climbing-notebook` for the repository slug. The project-level `DEVELOPMENT_DISPLAY_NAME` build setting is the entry point for future display branding: it supplies the generated app `CFBundleDisplayName` and the extension display name, while the app reads `CFBundleDisplayName` for its title. Keep technical identifiers independent of future marketing names. Development bundle identifiers rooted at `com.climbingnotebook.foundation` are provisional pending permanent registration, not registered release identities. Artwork and colors remain placeholders until separately designed.

### 5.2 Framework Choices

| Concern | Choice and rationale | Constraint/spike |
| --- | --- | --- |
| UI/navigation | SwiftUI with small UIKit bridges for share receiving/PDFKit | Native accessibility and editor recovery tests |
| Persistence | SwiftData, versioned schema from first build, explicit save and rollback | Migration/reopen/delete/recovery spike; Core Data fallback only by decision |
| File storage | Foundation FileManager/FileHandle, Application Support originals, Caches thumbnails | File-first/database-second discipline and integrity journal |
| Image intake | PhotosPicker and UTType; file picker security-scoped access | No broad photo-library or camera permission required for picker-only scope |
| Image rendering | ImageIO downsampling, bounded thumbnail work | Do not decode full-resolution images for grid cells |
| PDF/text | PDFKit, Foundation strict UTF-8 decoding | Page limits, malformed PDF handling, no OCR requirement |
| User-initiated URL copy | WebKit preview, generic rendered-text capture, explicit selected-asset copying | Nonpersistent browsing session; no crawling or access-control bypass; resource and navigation policy tests |
| Receiving share | UIKit extension controller, NSItemProvider, App Group mailbox | No direct database access, no assumed main-app launch |
| Hashes | CryptoKit SHA-256, incrementally | Integrity, not authenticity or encryption |
| Archive | ZIP manifest + originals, approved ZIPFoundation direction | Verify license, stable release, ZIP64 and untrusted archive limits in M1 |
| Future OCR | Vision text recognition, separate later service | On-device, explicit uncertainty; never required for saved content |
| Testing | XCTest/XCUITest with real temporary on-disk stores | In-memory tests alone cannot validate migrations or recovery |

### 5.3 Concurrency and Persistence

A single LibraryCoordinator serializes library mutations and owns contexts on their required executor. UI consumes stable-ID snapshots or main-actor reads and submits typed commands; do not transfer live persistent models across actors. File hashing/copying and thumbnails run off the main actor with bounded concurrency and cancellation. No unbounded task per image or background indexing of the entire library at launch.

Use a library-level operation gate for restore, export snapshot capture, and migration. Editing is paused during destructive replacement. Route-scoped revisions detect stale editors; persistence commands return the updated revision. Two views must not independently save conflicting copies without detection. Mutation rollback refreshes affected presentation snapshots.

CloudKit is explicitly disabled and no iCloud entitlement is added. Configure the SwiftData store URL inside the active library generation. Do not share that store with the extension or infer that future sync will fit its constraints without migration work.

### 5.4 Deployment Recommendation

Recommend iOS 17+ to retain the handoff's older-device support without introducing an API compatibility layer. SwiftData's ModelContainer and VersionedSchema are documented from iOS 17 [S1-S2]. App Groups and NSItemProvider predate that target [S3-S4]. Newer deployment alone does not prove better integrity, so acceptance tests, not anecdotal reliability claims, determine fitness.

At foundation, test the oldest supported iPhone and minimum OS runtime available to the team, plus a current OS. If the team cannot test iOS 17 or encounters reproducible platform defects, propose raising the minimum to the oldest supportable version, with device impact documented. Do not silently raise it during coding. Xcode/SDK upload requirements are separate: Apple's dated notice requires Xcode 26+ and iOS 26 SDK+ since April 28, 2026 [S5]; recheck the live submission rules before each release.

## 6. Logical Data Model

### 6.1 Conventions and Relationships

All durable IDs are UUID strings in portable output. Use UTC RFC 3339 timestamps with milliseconds in exports. Names need not be globally unique. Optional values are null/absent, never fabricated zeroes. Lengths are decimal value plus unit enum `m` or `ft`; export decimals as decimal strings to avoid binary rounding drift. Created/updated times are informational, not conflict-resolution clocks.

Relationships are UUID-based in portable DTOs and explicit inverse relationships in persistence where useful. One area has many routes; a route owns pitches, note sections, source references, and attachment links. Attachment links point to reusable immutable MediaAssets. Import drafts have separate asset links. No names/array indices or absolute sandbox paths serve as identity.

| Entity | Fields and purpose |
| --- | --- |
| Area | id, name, optional regionText and notes, createdAt, updatedAt, revision. No parentID in v1. |
| Route | id, areaID, name, optional grade string, styleLabels, optional length value/unit, description, createdAt, updatedAt, revision. Pitch count is derived. |
| Pitch | id, routeID, order, optional displayName/grade/length value/unit, description, protectionNotes, belayNotes, createdAt, updatedAt. |
| NoteSection | id, routeID, kind (`approach`, `descent`, `gear`, `general`, `custom`), title, body, order, updatedAt. Route-scoped only in v1; pitch-specific prose uses Pitch fields. |
| MediaAsset | id, managed storage key, original display filename, UTType, byteCount, SHA-256, optional pixel dimensions/pageCount, createdAt. Immutable original bytes; no blob embedded in the model. |
| MediaAttachment | id, routeID, optional pitchID, optional noteSectionID, assetID, caption, tags, order, optional sourceReferenceID, createdAt, updatedAt. One owning context: route, pitch, or note. |
| SourceReference | id, routeID, optional requestedURL/finalURL, sourceName/title, attribution, method (`manual`, `photos`, `files`, `paste`, `share`, `urlCopy`), importedAt/capturedAt, optional rawText, retainedAssetIDs through SourceAsset links. |
| SourceAsset | id, sourceReferenceID, assetID. Keeps source originals alive independently of visible gallery placement. |
| ContentOrigin | id, routeID, targetEntityID/type, fieldKey, sourceReferenceID, status (`imported`, `editedFromImport`). Marks specific prose/metadata fields created from a source without conflating all route text. |
| ImportDraft | id, state (`review`, `committed` receipt), receivedAt, optional source URL/title/attribution, immutable rawText, editable proposed fields, optional targetRouteID, validation warnings, revision. No saved route exists until confirmation. |
| DraftAsset | id, draftID, assetID, order, suggested caption/target. Original retention before route commit. |
| InboxReceipt | deliveryID, acceptedAt, optional draftID, outcome. Prevents re-ingestion after process interruption; generation-local. |

MediaAsset is the one justified addition to the handoff's entities: it separates original bytes from contextual attachment metadata. Reuse is explicit when attaching an already managed asset. Do not implement cross-file content deduplication in v1; equal hashes do not require shared asset identity.

### 6.2 Invariants

- Route area exists; pitch/note belongs to exactly one route. No cycles because areas are flat.
- Attachment route is mandatory; pitchID and noteSectionID are mutually exclusive. If set, the referenced owner belongs to that route. Gallery-only attachments have both null. Source references and origins must belong to the same route as the target.
- Asset references must resolve and originals must exist before a record is reported saved/available. Assets referenced only by retained sources or drafts are still live.
- Pitch and sibling note/attachment orders are unique contiguous nonnegative integers within their owning context. Reordering renormalizes one group atomically. Original display names are not order keys.
- Name/title validation trims only for emptiness; preserve meaningful user text. Proposed limits: 500 characters for names/titles, 1 MiB UTF-8 per prose/raw-text field, 32 tags per attachment, 100 characters per tag, 100 pitches per route. Errors are explicit; never truncate.
- Initial styles: Trad, Sport, Aid, Mixed, Ice, Alpine, Boulder, Other, plus user-entered labels. Multiple styles allowed; trim/deduplicate case-insensitively while preserving display spelling. No semantic grade ordering or grade normalization.
- Any text edit derived from an imported field retains its source link and changes the origin marker to editedFromImport. Raw received text stays immutable. Provenance is field-level lineage, not an audit log or verification claim. Explicit replacement from another source shows the old provenance before confirmation.
- Deleting a source must warn if content-origin markers or retained originals depend on it. Offer removing the link while keeping notes, or cancel; no cascading deletion of authored content.

### 6.3 Deletion and File Lifetime

Deleting a route removes its pitches, sections, attachment links, content origins, and source links in one persistent operation. Assets are not cascade-deleted by route relationships. Recompute reachability across MediaAttachment, SourceAsset, DraftAsset, and active operations before reclamation. Deleting a pitch/note removes its contextual links; the confirmation states this and offers moving attachments to route level first.

A post-commit sweeper marks unreferenced assets for cleanup, with a proposed 24-hour grace period and a fresh reference check before removal. Failed file removal is retryable and does not roll back a committed route deletion. This grace is not user-visible Undo. Journal and startup reconciliation distinguish abandoned file copies from live assets; never sweep active staging, rollback generations, or ready mailbox deliveries. A shared-asset test across two routes is mandatory even though automatic deduplication is deferred.

### 6.4 Schema Evolution

Begin with a versioned local schema and a migration plan. Local schema version, backup format version, and share-envelope version are independent. Archive v1 is never a serialized SwiftData object graph. Preserve migration fixtures from every released schema; require upgrade and export-after-upgrade tests. If migration fails, keep old files, do not recreate the store, and offer recovery/export guidance. Preserve a consistent closed-store generation before destructive migrations, including database sidecars; do not copy an open database file and assume it is complete.

## 7. Contracts and API Boundaries

There is **no hosted HTTP API**, OpenAPI document, authentication callback, or metrics endpoint in v1. Networking is limited to explicit URL-copy browsing/selected downloads and user-directed external actions. The public contracts are application operations, a receiving share mailbox, supported documents, and the backup format. The following are specifications, not Swift code.

### 7.1 Application Service Contracts

| Operation | Input | Success | Errors / guarantees |
| --- | --- | --- | --- |
| Browse/search library | area scope, literal query, page cursor | Deterministically ordered area/route summaries | Invalid/stale cursor resets page; no network |
| Create/update route or area | Validated values; UUID and expected revision for updates | Saved snapshot and revision | validation, staleRevision, unavailableStore, diskFull; no partial related update |
| Mutate/reorder pitches/notes | routeID, expected revision, full sibling ID ordering for reorder | Saved route revision | Reject duplicate/missing/foreign IDs; all-or-nothing sequence |
| Stage intake | Supported provider/file/text input, cancellation token | Durable draftID with raw input and warnings | unsupportedType, unavailableProvider, deniedAccess, limitExceeded, cancelled; no route mutation |
| Copy supplied URL | draftID, explicit Copy Page consent, validated HTTP(S) URL; later explicit text/image selections | Reviewable local draft, raw text, selected copied assets, requested/final URL and timestamp | offline, blockedSource, redirectedOrigin, timeout, unsupportedType, limitExceeded, cancelled; no route write, crawl, or implicit retry |
| Commit import | draftID/revision, destination, reviewed field mappings and replacement approvals | routeID, revision, committed draft receipt | staleTarget, missingAsset, validation, persistenceFailure; one metadata commit; retry does not duplicate |
| Attach original | owner IDs, copied validated asset, caption/tags | AttachmentID and saved state | File publication precedes metadata; recover orphan on interruption |
| Delete/detach | entityID and expected revision | Durable deletion receipt | File reclamation deferred; unrelated references preserved |
| Export complete backup | active generation, destination handoff request | Verified temporary archive URL, counts, hash, creation time | Flush/snapshot failure blocks export; no incomplete archive advertised as complete |
| Validate restore | archive URL, supported-version policy | Immutable validation token, summary, warnings | No current-library writes; token binds archive hash and current library revision |
| Replace library | validation token, explicit confirmation | New active generation ID and summary | Reject changed archive/library; retain prior generation until successful reopen |

All long operations expose phase, completed/total bytes or items when known, cancellation, and actionable typed failures. Cancellation is allowed before the restore switch; after switching, finish recovery to a coherent generation rather than leaving half a replacement. No operation reports success merely because an async task was started.

### 7.2 Share Extension Mailbox Contract

Use a registered App Group shared by the app and extension. The app's main library stays in its private container; the App Group holds only intake envelopes and their payloads.

Each delivery has `envelopeVersion`, UUID `deliveryID`, receivedAt, optional host-supplied title and HTTP(S) URL, optional UTF-8 text, and ordered items containing local item UUID, detected UTType, sanitized display filename, payload-relative key, byteCount, and SHA-256. Host bundle identity is optional and not inferred through private APIs.

Lifecycle: create `staging/<deliveryID>` -> stream/copy every supported selected payload -> write envelope -> atomically rename within the same container to `ready/<deliveryID>` -> report `Saved to Climbing Notebook Inbox. Open Climbing Notebook to review.` Never report `Route saved`. Never rely on launching the app from the extension. Failed or cancelled deliveries stay unpublished and show an error; mixed supported/unsupported items require an explicit supported-items-only choice rather than silent omission.

The main app reads only ready envelopes, validates sizes/hashes/paths, copies into its managed draft store, persists InboxReceipt and draft in one save, then removes the shared delivery. If interrupted after save but before removal, receipt lookup prevents duplicate drafts. Retrying a share with a new deliveryID intentionally creates a new draft; no name-based deduplication. An atomic ready publication plus per-delivery file coordination prevents app/extension races; an actor alone cannot synchronize processes.

Proposed envelope limit: 20 items, 50 MiB per image, 200 MiB per PDF, 1 MiB text, 250 MiB aggregate per delivery. Stream file representations, avoid in-memory loading of whole PDF/image collections, and reject oversized payloads with Files-import guidance. Extension memory/time budgets are not fixed contractual numbers; test on device. Copy provider temporary URLs before their callback lifetime ends, or use an API with a documented lifetime. Reclaim only clearly abandoned unpublished staging older than 24 hours under coordination; ready deliveries are user data and never silently expire.

## 8. Media Storage and Data Integrity

### 8.1 Storage Layout

| Location | Contents | Backup policy |
| --- | --- | --- |
| App Application Support/LibraryState | Atomic active-generation descriptor and recovery journal | Included in OS device backup |
| App Application Support/Libraries/<generationID> | SwiftData store/sidecars, immutable assets, persisted drafts and receipts | Included; required for app library |
| App Application Support/Operations | Interrupted-operation metadata and bounded staging | Recoverable staging excluded where safely reproducible |
| App Caches/Thumbnails | Regenerable previews keyed by asset/hash/size | Excluded from portable and OS backups |
| App temporary export staging | Snapshot manifest and archive | Excluded; delete after handoff lifetime or startup cleanup |
| App Group Inbox | Staging and ready envelopes/payloads | Ready user content included where platform backup behavior permits; app backup warns about unprocessed deliveries |

Do not store originals in Caches or tmp. Relative asset keys are generated from asset UUIDs, never filenames supplied by a document or archive. Apply suitable iOS file protection, proposed completeUntilFirstUserAuthentication to support ordinary post-unlock offline viewing and extension intake; fail visibly before first unlock rather than weakening protection. Verify actual app/extension backup and protection behavior on device.

### 8.2 Write and Recovery Protocol

For attachment intake: copy to managed staging, check byte limits and actual decoder type, compute hash, publish immutable asset in the current generation, then persist asset/link/draft metadata. A failed database save leaves a recoverable orphan, not a broken saved attachment. A journal identifies the operation and intended asset IDs. On restart reconcile metadata against files; report missing live assets and quarantine unexpected files rather than automatically guessing ownership.

For editing text: persistence failure must preserve editor/draft text and show retry. The app does not claim every keystroke survives a sudden kill. For large file operations: stream and update progress, preflight free space, recheck as writing progresses, and preserve the prior library on ENOSPC or protection errors.

Thumbnails may fail independently of original preservation. Bound decode size and concurrency; apply PDF page/pixel budgets before preview generation. Proposed PDF intake limit is 500 pages and image decoded dimension limit is 100 megapixels, subject to the foundation measurement gate. No original is discarded because preview generation fails.

## 9. Complete Backup and Replace-Restore Contract

### 9.1 Portable Format

Proposed extension: `.climbing-notebook-backup`, declared as an exported UTType conforming to ZIP. A user may rename it to `.zip` to inspect it with standard desktop tools. Use standard ZIP entries with stored/deflate methods; do not call Apple Archive or raw Compression streams ZIP [S6]. No password/encryption support in archive v1. Warn that archive contents, EXIF location data, sources, and personal notes are readable to anyone with the file.

Archive root contains exactly:

- `manifest.json`: UTF-8, format identifier `com.climbingnotebook.backup` (provisional namespace), integer formatVersion `1`, minReaderVersion, backupID, libraryID, createdAt, app version/build, entity counts, and portable entity arrays.
- `media/<assetUUID>/original.<validatedExtension>`: every referenced original, including draft-only/source-only assets. The manifest maps asset ID to path, byteCount, UTType, and SHA-256.

Manifest arrays: areas, routes, pitches, noteSections, mediaAssets, mediaAttachments, sourceReferences, sourceAssets, contentOrigins, importDrafts, draftAssets. Each array uses stable IDs and explicit relationships per section 6. InboxReceipt is operational state and is not exported. Transient committed draft receipts are not content and can be omitted once their delivery cleanup finishes. Reviewed but uncommitted drafts and originals are included. Device preferences, thumbnails, caches, logs, operation journals, obsolete generations, and absolute paths are excluded.

Before export, main app ingests ready mailbox deliveries present at capture time. Export pauses final snapshot capture briefly, flushes acknowledged changes, freezes a consistent DTO/asset-ID snapshot, and pins those immutable assets against deletion until archive completion. New share deliveries after that boundary remain queued and are explicitly not part of that backup. Show a pending-inbox warning if any delivery could not be ingested; do not silently describe such an export as complete.

Contract examples, described without an implementation scaffold: a route record references `areaID`, has no stored pitchCount, and may have `length = {value: "350", unit: "m"}`. An attachment record points to assetID and its routeID, plus at most one pitchID/noteSectionID. Schema documentation later must include complete examples for each entity and nullability/enum rules.

### 9.2 Version and Compatibility Rules

For v1, accept only formatVersion 1 and minReaderVersion <= 1. Unknown additive optional fields may be ignored; unknown required entity kinds/enums or incompatible semantics reject the archive. Future version readers must have explicit converters and fixtures; do not assume major/minor compatibility. Preserve UUIDs and original createdAt/updatedAt values when replacing. Duplicate UUIDs in any entity collection are invalid, not a merge opportunity.

Use deterministic ID ordering for exported entity arrays; preserve user-visible order via order fields. CRC plus SHA-256 verifies accidental corruption, not trusted origin. A manifest cannot safely authenticate itself, so do not claim tamper-proof backups.

### 9.3 Export Algorithm

1. Reconcile pending intake, show unsaved editor state, and refuse a supposedly complete export while acknowledged library assets are missing.
2. Acquire mutation gate for flush and snapshot capture, create a manifest from portable DTOs, and pin snapshot assets. Then allow ordinary edits to resume while building from the immutable snapshot.
3. Preflight estimated media plus JSON/archive workspace. Stream originals and hashes into a temporary archive with cancellation/progress; never assemble the whole archive in RAM.
4. Reopen the finished archive, validate entry list/manifest/hashes/counts against the snapshot, and only then offer Files/share export. Failure removes only temporary output.
5. Keep export output valid for the document/share provider's required access lifetime. Record `Archive created`/`Export handed off`, not `Safely backed up` unless external durability can actually be verified. Clean old temporary exports on next launch after their access lifetime ends.

Proposed supported performance envelope: 2,000 routes, 10,000 pitches, 5,000 original assets, and 5 GiB total originals. JSON is capped at 64 MiB and archive entries at 25,000. These are explicit resource ceilings to validate, not a claim of already measured performance. Libraries approaching limits need warnings before accepting more content; never let intake create a library the exporter refuses without warning. Validate ZIP64 behavior for >4 GiB archives in the foundation spike before promising the 5 GiB envelope.

### 9.4 Validation of Untrusted Backups

Copy or hold coordinated security-scoped access to the selected file and bind validation to its SHA-256 so a provider cannot swap contents between validation and application. Validate before current-library mutation:

- Parse bounded UTF-8 JSON; check format, versions, required fields, counts, data types, string/collection limits, finite positive lengths, valid units, UUID uniqueness, dates, and ordering invariants.
- Verify all foreign keys, owner consistency, source/origin targets, and draft/asset relationships. Reject dangling references and extra unexpected payload files.
- Reject absolute paths, traversal (`..`), backslashes/alternate separators, path aliases after normalization, duplicate/case-colliding entries, symlinks, hard links, encrypted entries, unsupported methods, and directories/files outside the exact expected namespace. Generate output paths from validated IDs rather than trusting archive paths.
- Enforce total inflated-byte, per-file, manifest, entry-count, image/PDF safety, and available-disk limits during streaming as well as before extraction. Do not trust header sizes alone. Stop over-expansion even when a ZIP is internally valid; do not blindly extract with a convenience unzip API.
- Verify bytes and SHA-256 for every asset and decode eligibility for viewable types. Report specific corruption, unsupported-version, insufficient-space, or invalid-relationship failures. Current library remains untouched.

The supported envelope and per-asset limits are the same as ordinary intake so a valid exported archive restores. Hash validation never substitutes for resource/type checks.

URL-copy output uses the same original/asset and text limits as other intake. Proposed network controls: HTTPS by default; HTTP requires a visible insecure-source warning and narrowly reviewed transport policy, never a blanket App Transport Security disablement. Block non-HTTP(S) navigation, embedded credentials, loopback/link-local/private-network targets, automatic download popups, and redirects into those targets. Confirm cross-origin top-level redirects, cap redirect attempts at five, and use a proposed 30-second top-level load timeout with cancellation. Allow ordinary public CDN subresources for rendering; do not describe one page load as one HTTP request. Apply the same destination policy to selected image/PDF transfers and redirects. The M1/M4 WebKit spike must prove enforceable navigation/subresource policy, bounded rendering behavior, and safe text extraction before shipping; if WebKit cannot meet the agreed constraints, return for an alternate bounded public-HTML intake design rather than claiming protections it cannot enforce. Rate-limit retries, keep only one active preview, and validate actual transfer bytes even when Content-Length is absent or false. Never log credential-bearing/query-sensitive URLs.

### 9.5 Replace, Crash Recovery, and Rollback

Do not delete and repopulate the active store in place. Use generation directories with a tiny atomically replaced active-generation descriptor in the same filesystem.

1. Acquire the library mutation gate, flush edits, and verify the validation token still matches archive bytes and active revision. Warn if editing since validation requires another review. Share deliveries may continue to queue but are not ingested during replacement.
2. Build an isolated new generation: extract originals into generated paths, create a new store from DTOs, preserve IDs, and validate record counts/references/hashes. Existing library remains active and unchanged while staging.
3. Close all contexts/references to the old generation and ensure no file workers still use it. Persist an operation journal naming old/new generations and phase. Atomically replace the active descriptor only after the new store has been closed and successfully reopened/validated in the spike-proven sequence.
4. Rebuild presentation/services against the new generation and perform post-switch checks. If reopening fails, restore the prior descriptor and reopen the old generation; never display an empty replacement as success.
5. On startup, resolve any interrupted phase deterministically: before switch, old generation; after switch, validate new then finalize or fall back. Never infer success from a directory existing. Keep the old generation until at least a subsequent successful launch and explicit cleanup; offer a temporary Revert Previous Library action, warning that it discards edits since replacement.
6. Mark completion only after reopen checks. Resume normal edits and intake. Ready share envelopes stay queued across restore and appear as new pending drafts afterward; receipts from the replaced library cannot suppress them.

Atomic filesystem rename does not make database, memory state, and separate files one transaction. The journal/reopen protocol and fault tests supply recovery semantics. Test interruptions at every phase on actual on-disk stores. Free-space preflight includes the old generation, complete new generation, archive copy if needed, and working overhead; keep old data rather than weaken rollback to fit storage. If context release/rebind cannot be proven reliable with SwiftData, stop and review the Core Data fallback.

## 10. Source Integrations and Later OCR

### 10.1 Current Assessment (2026-10-27)

| Source | Verified evidence | V1 decision |
| --- | --- | --- |
| Mountain Project | Official Data API page says public use was deprecated in late 2020 and new requests continue to be declined [S7]. Published Adventure Projects terms, revised August 4, 2023, restrict copying/use and prohibit automated spiders/crawlers/scrapers in section 8(g); section 12 imposes additional API restrictions [S8]. | Include the generic explicit single-page URL-copy workflow, with known restrictions disclosed. No API adapter, background/bulk access, private endpoints or site-tailored extraction without permission review. A user tap is not evidence these terms permit programmatic copying; resolve that risk before advertising Mountain Project compatibility. |
| SuperTopo | Official FAQ describes printed guides and downloadable eBooks [S9]. Direct retrieval of `https://www.supertopo.com/terms.html` failed during research; no current official supported public API or general reuse grant was verified. | Include generic user-initiated URL copying where technically accessible; API/permission status remains **unverified**. No access-control bypass or site-tailored adapter without review. User-selected documents require rights assessment; purchase/free availability does not itself grant redistribution rights. |
| Generic Files/Photos/text/share | Platform intake copies only explicitly supplied representations. | Useful independent of any site's integration. Capture source/attribution, preserve originals, and never claim personal copying is automatically lawful. |

This is a technical/permission assessment, not legal advice. Before adding a source adapter, record written authorization or applicable license, content scope, redistribution limits, attribution, rate limits, endpoint stability, offline rights, and revocation handling. Generic intake must remain functional if permission is absent or withdrawn. No bundled copyrighted fixtures or screenshots without permission; use synthetic or contributor-owned material.

### 10.2 Later OCR Milestone

Add Vision extraction only after v1 integrity gates. Rasterize selected PDF pages with bounded memory; preserve page positions and original text/images. Keep OCR output, parser rule/version, candidates and alternatives separate from confirmed records. Heuristics may suggest grade/length/headings but must surface ambiguity (feet versus meters, pitch number versus grade, columns, mixed languages). Unknown values remain blank. Review is mandatory; updates are opt-in and never silently overwrite notes. Provide raw-text fallback when structured extraction fails, cancellation/resumption for large inputs, and on-device-only operation. No LLM/API is needed.

## 11. Privacy, Accessibility, and Safety

- No app account, network telemetry, crash SDK, advertising identifiers, location permission, or developer-operated server collection. Explicit URL previews/copies contact third-party sites, which may receive IP addresses, user-agent data and subresource requests; a nonpersistent WebKit session reduces retained cookies but does not make browsing anonymous. Opening source links or exporting through a cloud-backed Files provider is also user-directed external activity and may require connectivity.
- PhotosPicker avoids broad photo-library permission for selected media. Files access uses scoped access and coordinated copy with balanced release. Handle unavailable iCloud-backed originals, provider cancellation, protected files, and denied access without pretending content is already local.
- Keep clipboard access user-triggered through system paste controls. Do not poll clipboard or upload pasted beta. Only HTTP(S) source links can be previewed/opened; reject active/file/javascript schemes. No requests merely from saving/displaying a URL. Web content executes only inside the explicitly initiated isolated preview, never in saved note/media views; copied output is inert text and validated originals.
- Originals can retain EXIF location and other metadata. Preserve them to honor the byte-preservation promise, explain this in export warnings, and defer metadata-stripped sharing as a separate feature. Do not log beta text, URLs containing tokens, filenames, or user identifiers.
- Use platform file protection and OS sandbox. Portable backups are not encrypted; system device backup is user-controlled and can involve iCloud storage. Do not call OS backup guaranteed or confuse it with app synchronization. Uninstall/device loss can destroy the only copy; surface unobtrusive backup reminders based on local state only.
- Audit required-reason APIs and provide privacy manifests for each applicable target; declare accurate reasons rather than copying generic reasons. App Store privacy answers must match the shipped app and any library actually selected [S10].
- Support Dynamic Type through accessibility sizes, labeled controls/images, logical VoiceOver focus, 44-point minimum touch targets, sufficient contrast in light/dark appearances, Reduce Motion, keyboard-safe editors, non-color-only save/uncertainty states, and button alternatives to drag gestures. Test long names and localization expansion; v1 UI may be English while all user notes remain Unicode.
- State that beta is user-supplied, not verified/current navigation or safety advice. Do not label gear/anchors/descent safe or authoritative. Offline status indicates local bytes, not accuracy. Avoid a disclaimer that blocks every pitch lookup outdoors.

## 12. Planned Repository Files

The repository now contains a partial M0/M1 Xcode foundation, feasibility tests, scripts and CI configuration. Paths below remain the planned map, not an inventory of completed features; inspect source and `README.md` for actual implementation status. Preserve any existing handoff material unchanged. Combine tiny files where practical rather than treating the map as a mandate for one class per file.

| Planned path | Action / responsibility | Phase |
| --- | --- | --- |
| `ClimbingNotebook.xcodeproj/project.pbxproj` and shared schemes | Create app, share, unit, UI targets; deployment/build settings and target membership | M0-M1 |
| `ClimbingNotebook/App/ClimbingNotebookApp.swift`, `AppDependencies.swift` | Compose views/services, recovery boot, active library binding | M1 |
| `ClimbingNotebook/Models/LibrarySchemaV1.swift`, `LibraryMigrationPlan.swift` | Persistent entities/inverses and schema versions | M1 |
| `ClimbingNotebook/Models/LibraryDTOs.swift`, `Validation.swift` | Portable value records, field/relationship constraints, revisions | M1 |
| `ClimbingNotebook/Features/Library/LibraryView.swift`, `AreaEditor.swift` | Browse, local search, area editing and moves | M2 |
| `ClimbingNotebook/Features/RouteDetail/RouteDetailView.swift`, `RouteEditor.swift`, `NoteSectionEditor.swift` | Route workspace and recoverable note editing | M2 |
| `ClimbingNotebook/Features/Pitches/PitchEditor.swift` | Pitch CRUD, protected drafts and reorder | M2 |
| `ClimbingNotebook/Features/Media/MediaGallery.swift`, `ImageViewer.swift`, `PDFViewer.swift` | Thumbnails, image zoom, offline PDF bridge | M3 |
| `ClimbingNotebook/Features/Import/ImportInboxView.swift`, `ImportReviewView.swift`, `IntakePicker.swift` | Manual draft review, destination and provenance controls | M4 |
| `ClimbingNotebook/Features/Import/URLCopyPreview.swift`, `ClimbingNotebook/Services/Import/URLCopyService.swift` | Explicit WebKit page-copy flow, navigation/download limits, selected-asset capture and raw-text provenance | M1 spike/M4 |
| `ClimbingNotebook/Features/Settings/DataManagementView.swift`, `RestoreReviewView.swift` | Export/restore progress, warnings, privacy and storage | M3-M5 |
| `ClimbingNotebook/Services/Persistence/LibraryCoordinator.swift`, `LibraryGenerationManager.swift` | Serialized commands, revisions, generation switch and recovery | M1-M3 |
| `ClimbingNotebook/Services/Media/MediaStore.swift`, `ThumbnailService.swift`, `AssetReconciler.swift` | Immutable original writes, preview cache, safe GC | M3 |
| `ClimbingNotebook/Services/Import/IntakeService.swift`, `ImportCommitService.swift` | Decode/copy, drafts and idempotent commit | M4 |
| `ClimbingNotebook/Services/Backup/BackupManifest.swift`, `BackupService.swift`, `RestoreValidator.swift` | Versioned ZIP/JSON contract, bounded validation and export | M3 |
| `SharedIntake/ShareEnvelope.swift`, `SharedIntake/InboxFileStore.swift`, `SharedIntake/IntakeLimits.swift` | Extension-safe versioned mailbox and coordinated file operations | M1/M4 |
| `ClimbingNotebookShare/ShareViewController.swift`, `Info.plist`, `ClimbingNotebookShare.entitlements` | Provider intake UI, exact activation types/counts, App Group capability | M4 |
| `ClimbingNotebook/Resources/Assets.xcassets`, `Localizable.xcstrings`, `PrivacyInfo.xcprivacy` | Branding placeholder, strings, audited privacy declarations | M1-M6 |
| `ClimbingNotebook/Info.plist`, `ClimbingNotebook/ClimbingNotebook.entitlements`, extension privacy manifest if needed | UTTypes/document handling, attribution, App Group, no CloudKit | M1/M4 |
| `ClimbingNotebookTests/ModelTests.swift`, `PersistenceRecoveryTests.swift`, `MigrationTests.swift` | Invariants, on-disk save/reopen and upgrade safety | Each phase |
| `ClimbingNotebookTests/MediaTests.swift`, `IntakeTests.swift`, `ShareInboxTests.swift`, `BackupRestoreTests.swift` | File lifetime, inbox crashes, corruption and round trips | M3-M5 |
| `ClimbingNotebookTests/Fixtures/` | Synthetic old-schema stores, safe/malicious archives, text/PDF/images | Each phase |
| `ClimbingNotebookUITests/NotebookFlows.swift`, `ImportFlows.swift`, `AccessibilityFlows.swift` | Core scenario, review confirmation and accessible actions | M2-M5 |
| `Scripts/test-ios.sh`, `Scripts/check-coverage.sh` | Standard xcodebuild test entry and real xcresult coverage gate | M1 |
| `.github/workflows/ios-ci.yml` | Pull-request/main GitHub Actions jobs on standard hosted macOS for the public repository, bounded artifacts, >=70% coverage | M1; verify runner/toolchain availability |
| Xcode project's shared SwiftPM `Package.resolved` | Commit reviewed dependency resolution for reproducible local/CI builds, only if exception approved | M1; ZIP policy gate |
| `.gitignore`, `kilo.json` | Exclude/deny secrets, signing material, generated output and caches; no broad permission weakening | M0 |
| `README.md`, `LICENSE`, `CONTRIBUTING.md` | Owner-approved license, setup/testing, architecture, release and governance | M0/M6 |
| `Documentation/BackupFormat.md`, `Privacy.md`, `ReleaseChecklist.md` | Exact v1 schema/examples, privacy policy, signing/release ownership | M3/M6 |

Future only: `Services/Import/OCRService.swift`, `HeuristicParser.swift`, their fixtures/tests, and an updated review UI. Do not create OCR stubs, CloudKit adapters, or empty future feature directories in v1.

No `.env` or server `config.yaml` is needed for this local app. If signing automation later uses credentials, document placeholder CI variable names, keep actual values outside the repository and agent access, and add `.env.example` only if an environment file genuinely becomes part of setup. Include `Built at Novacoast.` in supported app/extension manifest description metadata and About/license information; this attribution does not decide trademark or App Store seller ownership.

## 13. Test Strategy and Release Acceptance

### 13.1 Coverage and Environments

Require >=70% line coverage across first-party app/shared-intake/extension logic; do not inflate it with dependency sources or generated code. Also report core model, intake, and backup/recovery coverage separately, targeting >=85% where practical. A high percentage is not a substitute for fault-injection tests. Document any platform-only entry points outside automated reach and exercise them on device; no skipped or always-passing tests.

Use temporary on-disk stores and real files for persistence/integrity tests. Test the deployment minimum and a current simulator/runtime, plus a real older device for memory, share-host behavior, file protection, Photos, Files, and airplane-mode checks. Simulator tests cannot fully establish OS termination, data protection, or extension budgets. Run tests after every migration/dependency/SDK update and on every pull request/push to main via GitHub Actions. Use the existing MBP for minimum-runtime/device checks when hosted images lack the iOS 17 runtime; CI must not claim baseline coverage it did not execute.

### 13.2 Test Matrix

| Category | Required cases |
| --- | --- |
| Model | Duplicate names, blank name, valid/invalid decimals/units, free grades/styles, owner mismatch, no dangling origins, pitch/section order |
| Editing | Debounced save acknowledgement, navigation, stale revisions, keyboard, disk full/save error, draft cancel vs existing autosave |
| Media | HEIC/JPEG/PNG orientation, large dimensions, PDF pages, broken decoder, missing original, thumbnail eviction, shared asset references |
| Intake | Strict text decoding/BOM, empty input, huge text, unsupported types, locked PDFs, denied/unavailable provider, partial copy, cancellation |
| URL copy | No request before user action, ordinary public page, rendered text, selected image/PDF, relative URLs, cross-origin redirect, login/paywall/CAPTCHA fallback, unsafe destinations/schemes, timeouts, cancellation, false sizes, broken capture and malicious page scripts without native privileges |
| Share | Safari URL, Photos image, Files PDF/text, mixed items, multiple sequential deliveries, app not running, extension termination before/after ready publication, app crash before/after receipt |
| Backup | Full semantic round trip including provenance/drafts, byte/hash identity, same UUID preservation, large/ZIP64 archive, cancellation, full disk |
| Malicious/corrupt restore | Missing media, wrong hash, malformed JSON, unknown format, duplicate IDs/paths, traversal/symlinks, oversized inflated data, foreign owner, invalid order |
| Recovery | Terminate at each file publication/database commit/export/restore journal/descriptor step; current or new complete generation only |
| Migration | Fixtures from every released schema; failure leaves old library available; export/restore after upgrade |
| Accessibility | Largest Dynamic Type, VoiceOver route/pitch/media/source flows, Move Up/Down, non-color save/errors, light/dark contrast |
| Offline/privacy | Airplane Mode after force-quit, no app-origin network requests during core operations, explicit external links, unavailable provider content never marked local |

### 13.3 V1 Acceptance Scenarios

1. Create an area and route with five pitches, arbitrary grades, explicit meter/feet lengths, protection/belay notes, approach/descent/gear/general/custom sections. Reorder pitches and confirm displayed numbering changes without changing their names/IDs.
2. Attach images to the route and two pitches, a PDF to a note section, captions/tags, and at least one retained source original. Wait for acknowledged saved states, force-quit, enable Airplane Mode, reopen, and compare every field and view original media/PDF pages.
3. Receive an image from Photos, a PDF/text file from Files, pasted text, and a URL through Share. Confirm each appears as a draft, not a saved route. Images/scanned PDFs require no OCR. Correct/manual-enter route data, commit, and verify sources/raw text and originals remain distinguishable from personal edits.
4. Cancel/discard a nonempty draft after confirmation; verify existing notes are unchanged. Kill the extension before ready publication and after publication; only complete deliveries can be acknowledged and ingested. Kill the app after draft save before mailbox removal; no duplicate draft results.
5. Export a complete library including an uncommitted draft. Restore into a clean installation with no network. Compare UUID sets, area/route/pitch/note/attachment/asset/source/draft counts, values, order, source lineage, and all original byte hashes.
6. Replace a nonempty library only after validation and explicit confirmation. Inject interruption at every phase. Restart into the entire old or entire new generation; demonstrate recovery/revert before cleaning old files.
7. Present corrupt/unsupported/traversal/over-expanding archives and simulate insufficient storage. Existing library and originals remain unchanged, with actionable failure messages.
8. Share one MediaAsset between two routes; delete one route, run reclamation after its grace period, and confirm the other route/source/draft retains its file. Delete final references and confirm eventual cleanup. Thumbnail deletion must not affect originals.
9. With maximum Dynamic Type and VoiceOver, create/edit a route, reorder pitches without dragging, open an attachment, read a source, export, and navigate restore confirmation. No essential control is clipped or unlabeled.
10. A supplied/shared URL makes no request until Copy Page/Open is tapped. Copy a public test page's text and selected image through preview/review, preserve source/final URL and capture time, save, then view both in Airplane Mode. The uncopied source link remains visibly external, not offline content. A blocked/unavailable source offers link-only/paste/file fallback without bypassing restrictions. Missing originals prevent a misleading complete-local-content indication.
11. Exercise the agreed large-library envelope with measured memory/progress/cancellation on the minimum device. Proposed targets: warm route list/search under 500 ms for 2,000 routes and route detail interactive under 1 second excluding original decode; adjust only through a recorded owner review after measurement.

Post-v1 OCR acceptance: representative permitted images/PDFs yield editable candidates, ambiguity is visible, raw OCR remains available on parsing failure, and nothing is committed or overwritten without confirmation. This does not block v1.

## 14. Milestones, Dependencies, and Estimates

Estimates are focused contributor effort for the confirmed single volunteer, not elapsed calendar promises. At an illustrative 10 hours/week, 300-475 hours is approximately 30-48 weeks before contingency; with 20-30% contingency, allow roughly 9-15 months. Weekly availability is not specified, so do not treat that calendar range as a commitment. The existing MBP is the local build/device-testing environment; VS Code can be the editor, but Xcode, its command-line tools, and simulator runtimes are still required for native builds, signing, previews, and device debugging. No parallel team capacity is assumed.

| Milestone | Dependencies | Deliverables and exit criteria | Estimate |
| --- | --- | --- | --- |
| M0: Decisions/governance | Approved plan | Record approved scope/target/limits, dependency exceptions and public single-developer GitHub workflow; identify release-only license/signing decisions without blocking simulator foundation | 10-15 h |
| M1: Integrity foundation | M0 | Single Xcode project; versioned persistence; app/extension identifiers; on-disk migration/reopen, generation switch, ZIP64/limits spike; CI proof with coverage; sample area/route survives relaunch | 40-60 h |
| M2: Core notebook | M1 accepted | Library/search, route/notes/pitches/edit drafts, revisions and save state, accessible reorder; five-pitch offline text scenario passes | 50-75 h |
| M3: Media and recovery | M1 contracts; M2 model | Originals/thumbnails/PDF viewer, safe deletion, DTO backup, archive validator, full replace recovery; byte-identical round trip and injected restore failures pass | 70-110 h |
| M4: Intake/share/URL review | M1 mailbox and URL policy spike; M2/M3 | Picker/paste/share intake, explicit one-page URL text/selected-image copy, App Group ready inbox, manual draft review/provenance, idempotent commit; host/URL matrix and interruption tests pass | 75-120 h |
| M5: Reliability beta | M2-M4 | Migration/corruption/large-library/offline/accessibility matrix, coverage gate, oldest-device tests; all v1 acceptance cases pass, no known critical data-loss bug | 35-60 h |
| M6: Community release | M5; owner distribution decisions | Complete docs/privacy/license/support URLs, TestFlight feedback, manifest attribution, App Store review checklist, reproducible release archive | 20-35 h |

Total: **300-475 hours**, plus 20-30% contingency for platform defects, URL-copy behavior, volunteer availability, and App Review. Dependencies, not estimates, are release gates. If schedule must shrink, reconsider scope with the owner; do not silently drop required share/URL intake, backup, or accessibility. OCR is already deferred and receives a separate estimate after v1, provisionally 50-90 hours for Vision, parsing, review, and fixtures.

## 15. Prioritized Implementation Backlog

Each row can become a GitHub issue in the confirmed GitHub repository. GitHub pull requests and Actions checks are the delivery workflow; no GitLab mirror or pipeline is required. Acceptance references sections 7-13.

| ID | Priority / phase | Issue and acceptance | Depends on |
| --- | --- | --- | --- |
| CF-01 | P0 / M0 | Approve scope, iOS baseline, exception decisions and contributor availability; record decisions | Plan review |
| CF-02 | P0 / M0 | Choose license/release owner and register bundle/App Group identities without credentials in repo | CF-01 |
| CF-03 | P0 / M1 | Establish Xcode targets, shared scheme, secret exclusions, attribution and versioned model | CF-01/02 |
| CF-04 | P0 / M1 | Prove SwiftData migration, explicit save/reopen, context teardown and generation recovery on disk | CF-03 |
| CF-05 | P0 / M1 | Prove standard ZIP streaming, ZIP64, bounded entry inspection, cancellation, and interoperable extraction | Approved ZIP policy; CF-03 |
| CF-06 | P0 / M1 | Wire GitHub Actions standard hosted macOS tests and real >=70% coverage failure on pull requests/main; prove failure with a controlled test change, standard-runner selection and bounded storage | Confirmed public GitHub repository, CF-03 |
| CF-07 | P0 / M2 | Implement area/route validation, edits, route moves, blocked nonempty-area deletion | CF-04 |
| CF-08 | P0 / M2 | Implement route workspace and recoverable autosave/error/revision behavior | CF-07 |
| CF-09 | P0 / M2 | Implement pitch CRUD and accessible atomic reorder; five-pitch test passes | CF-08 |
| CF-10 | P0 / M2 | Implement common/custom sections and field-origin display semantics | CF-08 |
| CF-11 | P0 / M2 | Implement paged local name search and truthful saved/local indicators | CF-07/08 |
| CF-12 | P0 / M3 | Implement staged original store, hashes/journal and startup reconciliation | CF-04 |
| CF-13 | P0 / M3 | Implement image/PDF views, captions/tags/targets, bounded previews | CF-12 |
| CF-14 | P0 / M3 | Implement reference-safe delete/reclamation, source/draft reference checks | CF-12/13 |
| CF-15 | P0 / M3 | Specify archive DTOs/schema examples and export immutable snapshot with media pins | CF-05/12 |
| CF-16 | P0 / M3 | Validate hostile/corrupt/versioned backups with no active-library writes | CF-15 |
| CF-17 | P0 / M3 | Implement staged replace/rollback/revert and every-phase interruption tests | CF-04/16 |
| CF-18 | P0 / M4 | Implement supported Files/Photos/paste intake and raw source retention | CF-12/13 |
| CF-19 | P0 / M4 | Implement receiving share extension, atomic mailbox and no-loss receipts | CF-02/18 |
| CF-20 | P0 / M4 | Implement manual import review/destination mapping and idempotent commit, no OCR | CF-08/10/18/19 |
| CF-20A | P0 / M1-M4 | Prove isolated URL preview policies, implement explicit page text/selected-image/PDF copying with provenance, no automatic fetch/crawl, and unsafe/blocked/offline-source fallbacks | CF-12/18/20; URL policy spike |
| CF-21 | P0 / M4 | Include drafts/inbox boundary in complete export and test restore with pending shares | CF-15/17/20 |
| CF-22 | P0 / M5 | Execute offline, protection/permissions, URL-copy, oldest-device and large-library matrix | CF-07 through CF-21 including CF-20A |
| CF-23 | P0 / M5 | Complete accessibility audit and core-flow XCUITests, remediate failures | CF-09/13/20 |
| CF-24 | P0 / M6 | Write final setup/backup/privacy/contribution/release docs, support ownership and license notices | CF-02/22/23 |
| CF-25 | P0 / M6 | Conduct TestFlight beta and App Store submission review with accepted SDK and no new recurring service | CF-06/24 |
| CF-26 | P1 / later | Plan and add on-device OCR with bounded PDF rasterization and raw-text recovery | Stable v1 |
| CF-27 | P1 / later | Add explainable parser candidates and uncertainty review, never silent replacement | CF-26 |
| CF-28 | P1 / later | Evaluate grade/style filters, favorites and camera against real user feedback | Stable v1 |
| CF-29 | P2 / separate plan | Assess CloudKit identity, schema/asset migration, deletion/conflicts and costs; no implementation commitment | Stable portable backups |

## 16. Policy, Costs, CI, and Distribution

### 16.1 Applicable Standards and Exceptions

The owner approved a native local app instead of a service. Do not add Go, PostgreSQL, OIDC, Docker, HTTP endpoints or API docs merely to satisfy unrelated service defaults. Apply secret protection, unit coverage, provenance, documentation, Novacoast manifest attribution, and explicit review gates.

**Dependency direction, approved with the plan:** use ZIPFoundation [S11], a free MIT-licensed Swift library, through Swift Package Manager. Select a reviewed stable release rather than a moving development branch; commit the Xcode project's shared Package.resolved and make CI honor that resolution without silently updating it. The owner approved the plan after receiving this recommendation, including its narrow exceptions permitting native Xcode/SPM resolution on the MBP and GitHub macOS runners and reproducible dependency versions/lockfiles for this app. Docker cannot supply the native iOS SDK build environment. These exceptions do not authorize unrelated dependency installations.

Rationale: portable backup is a launch-critical data recovery feature; a mature ZIP implementation is less maintenance and risk for one volunteer than implementing ZIP parsing. Reproducible dependency resolution makes failures and shipped versions traceable. Pinning is not a substitute for patching: review stable/security updates at least monthly and before releases, update via a dedicated pull request, and run archive corruption, ZIP64, cancellation and round-trip tests before merging. Record the resolved revision/license in release evidence. Keep the dependency out of the share extension unless needed. If the exception is declined, revisit a no-dependency document-package format instead of hand-writing a general ZIP parser. Foundation's ZIP upload snapshot [S12] alone does not solve bounded hostile ZIP restore.

**CI decision, approved:** GitHub Free replaces GitLab and its `shared` runner tag. Use `.github/workflows/ios-ci.yml` on pull requests and pushes to main with standard GitHub-hosted macOS runners. Do not set up GitLab or install a persistent runner on the personal MBP.

**Confirmed repository posture:** the owner reports the GitHub branch/repository is public. Verify current repository metadata before relying on it; the requested repository slug is `climbing-notebook`, not a verified remote destination. Standard hosted runners, including macOS, are free for public repositories [S13-S14], subject to platform usage limits. No paid/larger runner is permitted. Audit generated changes for secrets/content before any separately authorized publication. Do not change repository visibility.

Private-repository allowances are not the selected CI model. If live metadata contradicts the owner's public-repository report, stop the hosted-CI assumption and report the discrepancy; do not change visibility or billing. Public free runner time does not authorize larger runners, excessive artifact/cache usage, or paid storage. Keep artifacts short-lived and bounded. A prepared workflow is not an executed CI result: until separately authorized changes are published, validate locally and report hosted execution as not yet run.

### 16.2 Cost and Ownership Budget

| Item | Planned recurring cost | Caveat |
| --- | --- | --- |
| Backend/database/OCR/AI/sync | $0 | None used; OCR later stays on device |
| Apple membership | Already provided by owner | Confirm team access, signing, extension/App Group ownership and release continuity |
| Build/test hardware | No new recurring spend | Existing MBP confirmed; verify Xcode compatibility, storage and test-device access |
| CI hosting | $0 additional | Standard macOS Actions runners free for public repo; private repo limited to included allowance, with paid usage blocked |
| Repository/docs/privacy/support page | Free existing hosting | Static repository pages are acceptable if available; no custom domain/server required |
| ZIP dependency | $0 license fee | License notice and maintenance/security work; narrow resolution policy exception approved |
| User backups | No app charge | User-selected cloud provider/device storage may have independent limits/costs; local Files/computer backup remains an option |

CI should compile both targets, run unit/integration and selected UI tests, gather xcresult/coverage reports, and fail below threshold. Begin with one standard hosted macOS job on a documented supported image/Xcode combination rather than an expensive matrix; cancel superseded branch runs, cap job time, and keep failure artifacts briefly (proposed three days). Keep caches/artifacts within free storage budgets; never upload personal library data or full large-library fixtures. Perform large-device/old-runtime checks locally and before release.

Use read-only workflow permissions, no signing secrets, and simulator signing-free builds. Test untrusted contributions with the pull_request event, never pull_request_target executing contributed code with privileges. Use GitHub-hosted ephemeral runners rather than exposing the MBP to public-fork code. Use immutable commit-SHA references for third-party Actions, with reviewed updates, under the approved reproducibility/security exception; verify their real upstream revisions rather than inventing SHAs. Signed distribution remains a deliberate local Xcode operation by the owner; automatic App Store publishing is not required. Document recommended required checks where supported, but changing GitHub repository protection/settings requires separate authorization.

README requirements adapt to a native app: overview, architecture, prerequisites/Xcode, local build and test instructions, document/service contracts instead of HTTP reference, privacy/data storage, environment/signing variables if any, deployment/distribution, and contributing. Explain that Docker commands and service endpoints are intentionally not applicable.

App Store release requires a maintainable signing/release owner, support and privacy URLs, app name availability, icon/screenshots, truthful offline/privacy descriptions, age-rating answers, export-compliance answers for actual cryptography, and tested restore on the release build. Recheck current SDK/review/privacy rules at release rather than treating this plan's dated research as permanent.

## 17. Risk Register

| Risk | Impact / likelihood | Mitigation and release gate |
| --- | --- | --- |
| Database/file split commits lose attachments | Critical / medium | File-first publication, journals, reachability sweeper and fault injection |
| Replace restore destroys current library | Critical / medium | Validate first, separate generation, atomic descriptor, reopen/rollback and interruption matrix |
| SwiftData teardown/migration unsuitable | High / medium | M1 empirical gate; Core Data fallback decision before UI investment |
| Share extension killed or acknowledges incomplete payload | High / high | Stream and atomically publish ready envelope, tight limits, truthful Inbox acknowledgement, host-device tests |
| Archive traversal/expansion exploits | Critical / medium | Generated paths, bounded per-entry streaming, strict whitelist, negative fixtures, library review |
| User thinks saved link/photo reference is offline content | High / medium | Copy originals locally before saved state; separate external-source and missing-file statuses |
| User mistakes imported beta for verified safety information | High / medium | Visible lineage and notebook positioning; no accuracy/current-condition claims |
| Copyright/terms violation | High / medium | Explicit one-page user action rather than crawling; disclose that initiation does not settle permission; no bundled third-party beta; review site-specific support claims/adapters before release |
| URL preview contacts trackers or hostile content | High / medium | Explicit network disclosure, nonpersistent isolated WebKit, no privileged bridge, enforceable destination/resource controls, inert saved output, safe fallbacks |
| Hosted runtime unavailable or artifact use exceeds free limits | High / medium | Public standard hosted macOS only; bound jobs/storage, local MBP baseline tests, explicit unavailable-check reporting, no paid fallback |
| Dependency/action becomes vulnerable or update regresses recovery | High / medium | Approved reviewed stable resolution/lockfile and immutable Action references; monthly/security updates, archive regression tests and release revision evidence |
| Device loss before external export | Critical / medium | Launch backup core, clear reminders and OS-backup limitations; test clean-install recovery |
| Disk-full/large-image memory termination | High / high | Preflight and enforced resource budgets, streaming/downsampling, oldest-device tests |
| Volunteer/App Store owner disappears | High / medium | Document signing/release/support ownership, backup maintainer, portable source/data and reproducible instructions |
| CloudKit later requires major schema changes | Medium / high | Explicitly defer, stable IDs and portable schema; no claim of drop-in sync |
| Sensitive EXIF/prose leaked through backup | High / medium | No app uploads, explicit readable-backup warnings and safe temporary-file cleanup |

## 18. Open Owner Decisions

### Implementation Decisions Resolved

1. **Approved:** iOS 17 minimum. Verify minimum/current runtime and device coverage during foundation; no further baseline decision needed unless testing identifies a concrete blocker.
2. **Confirmed:** one volunteer developer, existing MBP, VS Code and GitHub. OCR remains postponed; manual intake/review is v1 scope. Weekly hours remain unspecified; calendar estimates are illustrative.
3. **Approved with the plan:** ZIPFoundation via native Swift Package Manager, reviewed stable-release resolution, committed Package.resolved, and deliberate tested updates. Narrow local/hosted-macOS dependency and reproducibility exceptions apply; so do immutable third-party Action references. No blanket dependency-policy waiver.
4. **Confirmed:** public GitHub repository on GitHub Free, not GitLab. Use standard hosted macOS GitHub Actions with bounded artifacts/cache. Do not change visibility, billing or repository settings without authorization.
5. **Approved:** proposed intake/archive/library limits and generation-based replace/revert behavior, with measurement/fault-injection verification as specified.

The owner subsequently stated, `Plan is approved. GitHub branch has been published as public.` That resolves implementation authorization and item 3. Do not treat this instruction document as permission to commit, push or publish.

### Before Public Release

6. Permanent registration of bundle/UTType/App Group identities, final display branding, and App Store seller/Novacoast attribution placement. Development identifiers rooted at `com.climbingnotebook.foundation` remain provisional; future marketing names should not drive technical-identifier changes.
7. MIT is selected as the starting code license. Confirm copyright ownership and finalize license text/notices, contributor agreement/DCO if desired, issue/code review governance, and backup maintainer. The earlier GPLv3-only versus GPLv3-or-later question no longer applies.
8. Leif Johnson is the confirmed signing/release/support/privacy owner. Confirm Apple team authority, review cadence and long-term membership continuity. Build support/privacy pages on owner-controlled leifdigital.com; final page URLs are not yet selected or live.
9. Retention until explicit deletion is confirmed, with no automatic expiry of ready deliveries or saved drafts. Validate the detailed retention UX and user-visible warnings before release.
10. English-first UI with Unicode content and iPhone-primary/minimal-iPad scope are confirmed. No inferred map/location/grade-system requirements.

Generic user-initiated URL copying is included in v1 per owner direction. Site-tailored automation/support claims, sync, nested areas, merge restore, and OCR need separate review later. User initiation changes the interaction boundary, not the site's license or technical access controls.

## 19. Research References and Confidence

Consulted 2026-10-27. Official framework availability and dated submission rules are evidence; architecture recommendations are engineering judgments. Search snippets can be stale or describe future requirements, so the dated April 2026 notice below was checked directly. Revalidate all live requirements before implementation/release.

| Ref | Source | What it supports / limitations |
| --- | --- | --- |
| S1 | [Apple ModelContainer](https://developer.apple.com/documentation/swiftdata/modelcontainer.md) | iOS 17 availability, explicit configuration, migration plan, main context. Does not prove app-specific recovery safety. |
| S2 | [Apple VersionedSchema](https://developer.apple.com/documentation/swiftdata/versionedschema) and [migration discussion](https://developer.apple.com/videos/play/wwdc2025/291/) | Versioned schema/migration support. Newer features must not leak into minimum-target code. |
| S3 | [Apple App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups.md) | Registered shared containers for app/extension. Does not provide automatic transactions. |
| S4 | [Apple extension common scenarios](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionScenarios.html), [lifecycle](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionOverview.html), [NSItemProvider](https://developer.apple.com/documentation/foundation/nsitemprovider) | Inbox architecture and provider lifetimes; archived guide is older guidance, current behavior requires device verification. |
| S5 | [Apple SDK requirements, April 28, 2026](https://developer.apple.com/news/upcoming-requirements/?id=04282026a), [Xcode requirements](https://developer.apple.com/xcode/system-requirements), [submission guidance](https://developer.apple.com/app-store/submitting/) | Build SDK requirement is distinct from app deployment target; future changes remain possible. |
| S6 | [Apple Archive](https://developer.apple.com/documentation/applearchive), [Apple ZIP/Compression explanation](https://developer.apple.com/forums/thread/694893) | Compression algorithms/Apple Archive do not by themselves implement interoperable ZIP restore. |
| S7 | [Mountain Project official Data API](https://www.mountainproject.com/data) | Public access deprecated; new requests declined. Direct page verified. |
| S8 | [Adventure Projects Terms of Use](https://www.adventureprojects.net/ap-terms) | Current retrieved page dated August 4, 2023; sections 3, 7, 8(g), and 12 constrain use. Not a legal authorization for Climbing Notebook. |
| S9 | [SuperTopo FAQ](https://www.supertopo.com/faq.html) | Search-indexed official material describes guides/eBooks. HTTPS terms retrieval failed; API and reuse permissions unverified. |
| S10 | [Apple privacy details](https://developer.apple.com/app-store/app-privacy-details), [SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements) | Review privacy disclosures and actual SDK inventory before submission. |
| S11 | [ZIPFoundation project](https://github.com/weichsel/ZIPFoundation), [reviewed README](https://raw.githubusercontent.com/weichsel/ZIPFoundation/development/README.md) | Free MIT library, file/stream access, progress/cancellation; project claims are not proof of our security/ZIP64/performance requirements. |
| S12 | [Foundation forUploading](https://developer.apple.com/documentation/foundation/nsfilecoordinator/readingoptions/foruploading) | Directory snapshot can be ZIP; temporary URL lifetime matters. Not a complete safe restore API. |
| S13 | [GitHub Actions billing](https://docs.github.com/billing/concepts/product-billing/github-actions) | Standard hosted runners free for public repos; GitHub Free private-repo allowance currently 2,000 minutes/month, 500 MB artifact storage. Verify billing/account-specific consumption before use. |
| S14 | [GitHub-hosted runners reference](https://docs.github.com/actions/reference/runners/github-hosted-runners) | Standard macOS runner options for public/private repositories; image/runtime availability and usage policies still apply. |

## 20. Plan Review Exit

Plan approval is recorded. The next implementation assignment is the bounded M0/M1 handoff in section 21, to be executed when the owner starts or assigns the agent. No commits, pushes, repository changes, signing changes, or App Store publication are authorized merely by plan approval.

## 21. Implementation Handoff

### 21.1 Assignment and Scope

These instructions are suitable as the opening assignment for an implementation session that also has access to this full plan. Do not create another Agent Manager session or worktree automatically. This document does not claim the implementing model has started or completed any work.

Implement the approved Climbing Notebook plan, beginning with **M0/M1 only**. Read the full document before editing, particularly sections 6-9, 12-13, and 16. Deliver a buildable, tested foundation and measured feasibility findings, not an entire app in one unverified pass. Stop at the M1 handoff boundary; subsequent milestones can use section 21.5 when assigned. Do not ask again for already resolved iOS, dependency, public GitHub, restore, intake, or OCR decisions.

Inspect the actual environment, repository and current feasibility evidence rather than assuming the planned files or gates are complete. The original handoff may no longer exist in the current checkout; this approved plan is the implementation source of truth. Preserve any existing user/agent changes.

### 21.2 Permissions and Guardrails

- Use Swift/SwiftUI, iOS 17+, one Xcode project, on-device local persistence/files, and no account/backend. The approved native exceptions apply, including SPM on macOS and a committed resolution file. Do not install unrelated package managers, project generators, or dependencies to avoid learning the native project format.
- VS Code is the preferred editor; Xcode and its tools remain the native build/test environment. Validate toolchain/runtime availability and use a real installed simulator identifier. Do not invent successful builds, test device names, package versions, Action SHAs, or coverage numbers.
- No OCR, sync, nested areas, merge restore, weather/maps, paid services, analytics, LLM calls, or automatic route-field extraction. URL copying is explicit one-page user action, not reference-only and not unattended crawling.
- No commits, pushes, PR creation, repository visibility/billing/protection changes, signing credential access, developer-portal registrations, real-site scraping probes, or App Store publishing without separate owner authorization. Use signing-free simulator builds. A provisional reverse-DNS namespace is acceptable for a simulator-only spike if clearly labeled, not registered or presented as final.
- Do not choose a permanent license or invent Novacoast/App Store legal ownership. Record unresolved license/release identity items without blocking local simulator work; do not distribute a dependency without preserving its required notices.
- Do not use real personal route libraries or third-party copyrighted guidebooks as fixtures. Use synthetic/generated test data and permitted originals. Never report saved/local status before files and metadata are durably acknowledged.
- Keep changes small and executable. No empty feature scaffolds, placeholder success paths, disabled tests, in-memory-only integrity validation, generic sync layers, or permissive ZIP extraction hidden behind a convenience API.
- If a foundation spike disproves the approved design, report the precise failing test/API behavior and the smallest proposed alternative. Do not silently switch to Core Data, reduce backup guarantees/limits, remove URL-copy capability, or weaken the destination policy. Independent safe work may continue, but dependent implementation must stop.

### 21.3 First Work Packet: Foundation, WIP Limit One

Maintain a local structured todo list with one active item. Use CF issue IDs from section 15 in progress/results; this is not permission to create GitHub issues. Work through the following packets in order, except that short feasibility checks may precede scaffolding where they eliminate substantial rework.

| Packet | Work and required output | Exit evidence |
| --- | --- | --- |
| F0: Inspect and reconcile | Read repository/global instructions and this plan; inspect status/branch/remotes, Xcode/Swift versions, simulator runtimes/destinations and public repository metadata using read-only operations. Record approval in any stale plan text. Identify signing-only/license decisions as release gates. | Exact environment observations, clean/dirty file inventory, selected installed simulator, and unresolved external prerequisites. No destructive cleanup. |
| F1: Minimal native build | Create the single Xcode project with app, share-extension, XCTest and UI-test targets/shared scheme. Add minimal launchable foundation UI only, required safe ignore/access-control rules and versioned schema. Build simulator targets before expanding. | Successful xcodebuild invocation with destination, scheme, exit result; shared target membership verified. No need for live App Group registration to prove simulator compilation. |
| F2: Persistence/generation feasibility | Prove explicit save/reopen with stable IDs and representative related records; use temporary on-disk stores, versioned schemas, a synthetic migration, isolation of old/new library directories, close/rebind behavior, and injected interruption/reopen/rollback cases. | Test names/results and actual files checked. Demonstrate that missing/corrupt stores do not silently create an empty library and no restore path depends on moving only an open database file. |
| F3: Archive feasibility | Review current stable ZIPFoundation release/license, resolve it reproducibly, record the real revision, and exercise entry-by-entry streaming, CRC/hash checks, cancellation, forbidden paths/link entries, inflated-byte limits, and ZIP64 boundary. | Interoperable archive inspection/round trip, actual >4 GiB boundary test or explicitly incomplete ZIP64 gate. Large generated files stay outside git; check free space and clean only owned scratch files. Do not substitute a tiny archive for a claimed large-file test. |
| F4: URL-policy feasibility | Prototype only the smallest enforceability check for explicit load, generic text capture and selected-media copy. Use controlled local test content/test harness rather than fetching real guidebook pages. Distinguish harness-only loopback access from production public-destination policy. Verify which WebKit navigation/subresource/DNS/redirect/size protections are actually enforceable. | API availability on iOS 17, real observed behavior, test cases and limitations. A WKNavigationDelegate top-level check alone must not be called complete private-subresource/DNS-rebinding protection. Escalate the documented alternative-design decision if required guarantees cannot be enforced. |
| F5: CI and evidence | Add the GitHub Actions workflow and shared local test/coverage scripts using free standard macOS runners, read-only permissions and verified immutable Action references. Run the equivalent build/tests locally, enforce >=70% first-party line coverage, and verify the checker fails on a below-threshold sample/result. | Exact local command outputs, target coverage breakdown and failure-gate proof. Workflow is syntax/configuration-validated but hosted CI remains unrun until separately authorized publication. Do not claim local tests prove hosted execution. |

F2-F4 are **feasibility gates**, not permission to implement all route screens, full restore UX or production URL import before the findings are sound. Factor successful spike code into the modest production services only where it is already fit; do not leave duplicate prototype implementations in the shipped target. Provide a concise README for actual setup/build/tests and explain native exceptions, rather than a speculative finished-product manual.

### 21.4 M1 Definition of Done and Return Format

CF-05B bounded hostile-entry/header finding (2026-10-28): `ArchiveHostileFeasibilityTests.swift` adds seven file-backed synthetic matrix tests, separate from the two existing archive tests. Consumer-only extraction exercises exact/case duplicates, unsafe/alias/normalization paths, symlink/directory rejection, encrypted and malformed records, local/central disagreements, malformed ZIP64 extras, unsupported methods, CRC mismatch, truncated DEFLATE and streaming count/per-file/aggregate limits (including understated sizes). Visible-entry policy can abort rejected fixtures, but **cannot authorize whole-archive acceptance**. The reviewed ZIPFoundation 0.9.20 public iterator silently returns nil for encryption/record errors, exposes no completeness/error signal or raw headers/extras, and permits extractable local/central discrepancies and malformed extras. A false EOCD count can hide a valid tail, so expected visible names/counts are insufficient. Hard-link semantics are not exposed; symlink rejection is not general link rejection. The initial memory-backed out-of-file offset also traps; retained crash evidence and the same file-backed reproducer are documented in `README.md` CF-05B. No dependent production validator was implemented, no general ZIP parser or dependency change was introduced, and the approved contract/limits remain unchanged. Owner review is required for the smallest additional strict bounded preflight capability (prefer reviewed library/upstream support): throwing complete enumeration, verified CD accounting/bounds, raw local/central/ZIP64 comparison and explicit link semantics. This is a demonstrated public-API gap distinct from expected app policy, not a claim that safe preflight is impossible with a separately approved approach. CF-05B is Blocked, with its bounded evidence awaiting independent review. Final focused suites pass 9/9 on iOS 17.0 and newest-installed 27.1; full unit/UI suites each execute 27 tests, 25 passed / only 2 unchanged CF-04B failed / 0 skipped. Both coverage gates pass at 167/194 (86.08%) and the rejection self-test passes. Exact commands, source lines, matrix, result/log paths, cleanup and concurrent unrelated project edit caveat are in README. CF-05A's scripts/dependency/shared code were untouched, its large probe was not rerun and its Review status and host-only boundary evidence remain unchanged. The smallest next ready packet is independent reproducer review and bounded preflight API/options design for owner decision, not unauthorized parser implementation, persistence work or M2. Full envelope/device/manifest/type gates, CF-04B closure, sample schema/UI and URL-policy gates remain open; no production hostile-archive or restore readiness is claimed.

CF-05A bounded increment (2026-10-28): the executable opt-in host harness `Scripts/test-archive-boundaries.sh --run-large` compiles the existing resolved ZIPFoundation 0.9.20 revision without new dependencies or production linkage. Deterministic 1 MiB streaming creates and verifies a 4,294,967,419-byte entry plus a 23-byte sentinel using methods 0/8, incremental SHA-256 and CRC/count checks. Installed Python 3.9.6 `zipfile` / zlib 1.2.12 independently streams Swift output, creates compatible large fixtures, verifies ZIP64 local/central size fields and EOCD/locator/offset metadata, and ZIPFoundation reads Python output. Stored archives are 4,294,967,788 bytes, with later-entry header at 4,294,967,482 and central directory at 4,294,967,544: real archive/offset boundaries, not only large uncompressed metadata. Deflated archives are 16,680,160 bytes (payload 16,679,879), proving only their >4 GiB uncompressed-entry boundary. Exact commands, hashes, evidence paths, timing/RSS, preflight disk measurements and verified owned-scratch cleanup are in `README.md` CF-05A. Focused archive tests pass 2/2 on iOS 17.0 and 27.1; full suites each remain 18 passed / 2 known CF-04B failed / 0 skipped, with 167/194 first-party coverage (86.08%) and passing rejection self-test. No migration assertions or persistence code changed. This is host-only feasibility, not production hostile-archive validation or restore readiness. Large iOS/device runs, full 5 GiB/many-asset envelope, aggregate crossings with intake-sized files, exact threshold transitions, >4 GiB incompressible deflate, ZIP64 descriptors, large-operation cancellation/disk-failure and full manifest/header/type rejection remain gates. The smallest independent next packet is test-only CF-05B bounded hostile-entry/header rejection under §§9.4/21.3 F3. CF-04B and production URL copying stay blocked; no M2 work is authorized by this result.

CF-04B blocked finding (2026-10-28): test-only related synthetic migration/failure/recovery assertions now include an explicit lifetime barrier before filesystem operations. Both final full suites execute 20 tests with 18 passed, 2 failed, 0 skipped on iOS 17.0 and newest-installed iOS 27.1; coverage remains 167/194 (86.08%) on each. An autorelease pool, supported `processPendingChanges()` and a one-second condition-driven async wait do not reliably release containers/contexts. iOS 17 retains a container; iOS 27.1 retains contexts including a failed-migration context. Final tests throw and preserve temporary files rather than copy/move/delete after failed teardown. Initial exploratory cleanup produced SQLite open-vnode unlink warnings, so scope exit cannot be treated as a closed-store proof. No data-loss conclusion or production architecture change is established. Exact commands/results, limitations and retained result paths are in `README.md` under CF-04B. Closed-generation snapshot, migration recovery/retry and independent post-migration reopen remain unproven; dependent persistence implementation is stopped for owner review, not silently switched to Core Data. The smallest proposed diagnostic alternative is a test-only sequential-process fixture handoff with confirmed exit before whole-generation copying and retention-path inspection; if deterministic in-process closure remains unavailable, review the explicit-close Core Data fallback. Neither alternative is implemented. Actual termination/power-loss/fsync, production restore and released-schema compatibility remain separate gates. Independent CF-05A ZIP64/interoperability progress is recorded above; M2 remains unauthorized by this handoff.

CF-04A progress (2026-10-28): the generation feasibility harness now blocks initialization/replacement over pending recovery, rejects same-generation journals, and injects the descriptor-before-journal checkpoint without changing serialized journal phases. On-disk tests cover invalid replacements/metadata, missing/corrupt fallback, repeated recovery, and retry after repairing a failed-recovery fixture. The full 19-test suite passes on iOS 17.0 and iOS 27.0 with 167/194 combined first-party lines covered (86.08%). Exact commands, simulator IDs and result paths are in `README.md`. This closes only the bounded recovery-matrix increment, not CF-04 or M1: actual termination, broader migration, full schema/sample UI, ZIP64/interoperability and enforceable URL-policy gates remain.

M1 is complete only when a clean checkout can resolve the approved dependency and build both native targets, the sample area's/route's acknowledged save survives reopen, actual on-disk integrity/migration/generation tests pass, the ZIP and URL-policy gates have evidence, and the local coverage check passes with meaningful assertions. A missing runtime, unexecuted large-archive case, unproven WebKit guarantee or unavailable hosted result must be reported explicitly; it is not a pass.

Return one milestone report containing:

1. **Completed CF IDs and files changed:** distinguish finished foundation behavior from feasibility-only work.
2. **Validation:** exact commands, Xcode/runtime/destination, test counts/results, coverage numerator/denominator and exclusions, archive boundary measurements, and URL-policy observations. Reference retained local evidence paths when useful.
3. **Failed/deferred gates:** concrete errors or API constraints; distinguish unrun from failed. Explain whether each blocks dependent work or only release verification.
4. **Decisions required:** only new architecture/permission decisions supported by evidence; do not re-ask resolved scope questions. In an autonomous goal where questions are unavailable, stop dependent work and report a real blocker rather than guessing approval.
5. **Next packet:** the smallest ready CF issue(s) and dependencies. Leave uncommitted changes available for review. Do not advance past M1 automatically under this first packet.

### 21.5 Later Implementation Packets

When separately assigned to continue, use the same WIP-one and evidence rules. Re-read current code and the prior report; do not repeat completed foundation work. Implement the actual approved feature flows, not just protocol declarations or service stubs.

| Packet | Backlog | Required end-to-end checkpoint |
| --- | --- | --- |
| L2: Core notebook | CF-07 through CF-11 | Five-pitch route, common/custom notes, reorder, recoverable save errors, literal local search, accessible actions, acknowledged data retained after restart. |
| L3: Media and recovery | CF-12 through CF-17 | Immutable originals/PDF viewing, captions/tags/owners, shared-reference deletion safety, portable full export, hostile archive rejection and old-or-new generation recovery. |
| L4: Intake/share/URL review | CF-18 through CF-21 and CF-20A | Real Files/Photos/paste and extension inbox, receipt idempotence, editable manual review, explicit page/selected-media copying under proven policy, provenance and originals survive backup. |
| L5: Reliability | CF-22 and CF-23 | Full acceptance matrix, real device/offline/accessibility coverage, resource/large-library measurements, no known critical data-loss issue and real coverage gate. |
| L6: Release preparation | CF-24 and CF-25 preparation only | Accurate docs/privacy/attribution/licenses and a release checklist. TestFlight upload/App Store submission, signing changes and publication still require explicit authorization. |

Run the relevant unit/integration/UI checks for every packet and the full local suite before milestone handoff. Required failures are work to fix, not reasons to skip tests or lower coverage. This assignment creates no ongoing monitoring schedules, remote publication, new visible sessions or authority to spend money.
