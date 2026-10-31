# Climbing Notebook Design Baseline

Updated: 2026-10-30

Status: Owner-approved design baseline (2026-10-30). Implementation remains bounded by the approved feature plan and separately assigned packets.

## 1. Purpose and Authority

This document proposes the UI/UX baseline for a native, iPhone-primary personal climbing notebook targeting iOS 17+, with minimal iPad support. It is intended for design review, Google Stitch handoff, and later implementation guidance.

The existing MVP was developed to validate functionality, not visual design. Its layouts, screen density, navigation chrome, and component styling are not binding. Preserve its data-integrity guarantees, not its presentation.

- The [approved feature plan](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md) remains authoritative for scope, data models, persistence, and owner decisions, especially sections 4, 8, 9, 11, and 21.4.5.
- The [README](README.md) describes implemented capabilities. A proposed screen does not establish that a feature exists.
- This baseline introduces no APIs, schema changes, dependencies, security guarantees, or independent functional implementation authorization. Design approval does not itself authorize changing functional contracts.
- Earlier Stitch screens are visual references only. Do not inherit their invented parsing, synchronization, safety, encryption, or backup claims.

### Design Horizon and Release Profiles

Mockups describe the intended product, not just what is programmed today. Include all committed v1 workflows even when their implementation is incomplete. Also explore identified post-v1 capabilities as optional modules, with a clear v1 composition that works without them. Current implementation status is not a reason to omit a planned workflow from design.

| Profile | Design coverage | Release treatment |
| --- | --- | --- |
| V1 baseline | Area/route/pitch creation, editing, deletion and moves; ordered plain-text note sections; local name search; images/PDFs with captions, tags and ordering; sources; Photos/Files/paste/share intake; explicit URL copying; manual draft review; complete backup and replace restore; accessibility and recovery states | Complete product mockups, regardless of current implementation status |
| Post-v1 optional modules | On-device OCR, explainable field extraction with uncertainty/language/layout handling, grade/style filters, favorites, direct camera capture | Separate enabled variants; absent from v1 navigation and actions |
| Separate-planning concepts | CloudKit sync/conflicts, annotation, GPX/offline maps, selective sharing/collaboration, public data | Not committed; require a separate plan before inclusion in the product design baseline |

The optional modules reflect the feature plan's roadmap, not a guarantee that each will ship. Excluded capabilities remain excluded unless explicitly reconsidered; a future-facing mockup does not authorize them.

For each optional module, show its entry point, enabled workflow, and the same screen with the module absent. Turning it off must remove its actions, badges, settings, and empty containers without breaking navigation or the manual workflow. Do not leave disabled teasers or Coming Soon destinations in v1. Specify release visibility, not a particular feature-flag implementation; hiding a control alone does not establish that its underlying processing is disabled.

## 2. Product Principles

**A personal reference notebook, not a climbing adviser.** Users collect, organize, and consult their own notes and source material. The app does not verify beta, protection, anchors, grades, or route conditions.

**Read first, edit deliberately.** Finding useful information outdoors is the primary task. Reading controls must not mutate content; note editing and pitch reordering are separate, explicit workflows.

**Offline by design, truthful by state.** Availability describes accessible local bytes, not accuracy, completeness of the real-world route, or backup safety. A saved link is not a downloaded document.

**Native utility over decoration.** Favor clear iOS navigation, readable text, compact route identity, and predictable controls. Avoid dashboards, oversized hero imagery, promotional copy, and repeated status banners.

**Keep ownership understandable.** Pitch notes stay with their pitch when it moves. Imported originals and received text remain distinguishable from authored notes. Destructive actions explain exactly what will be removed.

## 3. Information Architecture

The primary hierarchy is Library -> Area -> Route -> Pitch. Areas are flat, not nested geographic folders. Route Detail is the main reading workspace.

| Destination | Purpose | Navigation |
| --- | --- | --- |
| Library | Browse areas; search area and route names | Root native navigation stack |
| Area | Browse routes in one area | Push from Library |
| Route | Read notes, pitches, media, and sources | Push from area or search result |
| Pitch | Read a pitch and select adjacent pitches | Push from Route |
| Note Editor | Edit one clearly identified note field | Focused modal editor |
| Pitch Order Editor | Change the route's pitch sequence | Separate focused modal editor |
| Import Inbox | Review received material before adding it | Consistent Library toolbar access |
| Settings | Local data, privacy, backup, and app information | Consistent Library toolbar access |

Use one title/navigation bar per screen. Back returns to the actual originating context. Do not add account/profile icons, placeholder tabs, or a separate Saved Routes destination that duplicates the route library. On iPad, a native split presentation may reuse the hierarchy; do not require fixed sidebar widths.

Search belongs near the top of lists. Results show area context so duplicate route names are distinguishable. Creation actions use specific labels such as Add Area or Add Route, not an ambiguous New button. Show planned creation actions in the product mockups; the fixture-only application must not claim those actions work before implementation.

## 4. Core Screen Requirements

### Library and Area

- Use compact, generously tappable rows rather than promotional cards. Area rows prioritize name and route count; route rows prioritize name, entered grade, styles, and entered pitch count.
- Allow names to wrap. Optional thumbnails are secondary and must not reduce essential text to ellipses.
- V1 search matches names under the feature plan's search contract. Grade/style filters and favorites belong in optional post-v1 variants, not implied v1 search capabilities. Full-text, rock-type, and voice search are not committed.
- Distinguish first-use empty content, no search matches, loading, and store failure. A failed store must never look like a new empty library.

### Route Detail

- Start with route name, area, optional entered grade/styles/total length, and entered pitch count. Do not force unknown fields into placeholder metrics.
- Provide discoverable quick access to Approach, Pitches, Descent, Gear, and Media; keep Sources available in the content. Descent must not be discoverable only by horizontally scrolling an unlabeled shortcut strip.
- Use readable plain-text sections with clear headings. Empty common sections can offer Add; custom sections retain their authored titles and order.
- Show a pitch list with one-tap access to each visible pitch. From a long route, reaching a pitch should take at most a quick-jump and a tap.
- Use labeled Edit Notes actions. Put less frequent route actions in a clearly labeled menu rather than crowding the header with unexplained icons.
- Do not permanently promote one hardcoded crux, hide unrepresented pitch ranges, or put decorative images ahead of essential beta.

### Pitch Detail

- Show current position, optional authored name, optional grade/length, and readable notes. A fallback title such as Pitch 2 is presentation, not an authored name.
- Previous/Next changes selection only; disable unavailable directions at the boundaries. Keep these controls discoverable without scrolling to the bottom of long notes.
- Provide Edit Notes and access to associated originals/sources. Full-screen media viewing supports zoom/pan without obscuring necessary viewer controls.
- Do not invent send tracking, live conditions, anchor verification, generated micro-topos, or computed gear specifications.

### Focused Editors

- Identify both owner and field, for example Paper Skyline / Gear Notes. Editing an existing note must not be titled New Route Entry.
- Keep route metadata creation, note editing, attachment management, and pitch reordering separate; do not turn a note edit into a full route configuration form.
- Retain entered text and selection when presenting validation or save errors. Hide Keyboard changes focus only; it is not a save action.
- Reorder rows prioritize full pitch names, position, and optional grade/length. Provide drag handles plus Move Up/Down with target-specific accessibility labels.
- Reordering preserves authored names, IDs, notes, and selection identity. Save the whole sequence together. Do not combine reorder with pitch insertion or deletion in this mockup round.

## 5. Save and Dismissal Contract

**Target-product baseline: buffered automatic saving for existing fields, with Done/Back.** Design the planned v1 experience rather than inheriting the fixture implementation's explicit-save limitation.

The approved plan section 4.3 specifies buffered automatic saves for existing fields with Done/Back. Section 21.4.5 allows explicit completion saves for the current bounded fixture slice only. The earlier explicit Save/Cancel proposal is not the default for these full-product mockups. Any comparison variant must be labeled as an alternative requiring a plan decision, not mixed into the baseline.

For the target-product mockups:

| State or action | Required behavior and copy |
| --- | --- |
| Unchanged editor | Done/Back exits; do not announce a new save |
| Modified existing field | Buffer changes and begin automatic persistence; show pending or Saving state |
| Save in progress | Prevent conflicting operations; leaving must not silently lose pending changes |
| Successful save | Use Saved on this device only after acknowledgment; Done/Back is not a rollback |
| Failed save | Keep editor and buffer; show Not saved with Retry; do not silently dismiss |
| New record or batch import | Separate Add/Cancel or confirm/cancel draft; confirm destructive discard when nonempty |
| Stale edit conflict | Preserve the buffer and offer review/reload; no silent overwrite |
| Relaunch | Loaded from this device describes restored content, not a new save |

Do not combine automatic saving with a Cancel action that implies already-saved edits will be discarded. Do not call local persistence synchronization. Do not promise recovery of unacknowledged field edits after termination. Record creation and batch imports have explicit commit boundaries; pitch reordering commits the complete sequence together, with pending/failure feedback rather than per-row partial saves.

## 6. Supporting Workflows

These workflows are part of the complete v1 mockup coverage, even where not yet implemented. Generate them as connected flows in manageable batches, not as disconnected placeholder screens.

- **Creation:** Separate Add/Cancel drafts; a route requires a nonblank name and area. Duplicate names are permitted. Unknown metadata stays unentered.
- **Intake:** Photos, Files, user-triggered Paste, URL references, and sharing lead to an Inbox draft, not an automatically saved route. The user chooses New Route or Existing Route and manually assigns destinations.
- **V1 manual review:** No OCR or automatic field/pitch inference. Scans remain viewable; say Text recognition is not included in this version. Optional digital-PDF text remains unstructured with page boundaries and a reading-order warning. Preserve this workflow when optional extraction is absent.
- **Web copying:** Receiving a URL does not fetch it. Keep Link Only and explicit Copy Page are distinct. Explain network access and source contact before copying; show review before committing selected material.
- **Sources:** Preserve original material and received text separately from edited notes. Adding to an existing route defaults to attachments or a new note; replacing prose needs preview and confirmation. Provenance establishes lineage, not truth.
- **Media:** Label source, caption, owner, and file type. Missing, corrupt, unsupported, and protected-file-unavailable states are explicit; do not delete originals because viewing fails.
- **Backup:** Use Export Complete Backup and Replace Library. Replacement previews archive metadata, validation, current/incoming counts, and loss of current records and drafts; offer export of the current library and a separate final confirmation. No merge or restore triggered merely by opening a file. Describe export handoff, not guaranteed external backup durability.
- **Deletion:** Name the affected content and counts. Block deleting an area containing routes and offer moving routes first. Do not hide cascading deletion behind an area action.

### Optional Post-V1 Variants

- **OCR and assisted extraction:** Show an explicit on-device recognition action, received original, recognized text, suggested fields, uncertainty, correction, and user approval before commit. Handle unsupported languages/layouts and partial recognition. Never label inferred beta verified, invent confidence percentages, or silently replace existing notes. Manual review remains fully usable without recognition. No cloud/LLM processing is implied.
- **Grade/style filters and favorites:** Add removable controls to existing lists rather than new mandatory navigation destinations. Clearly distinguish literal stored grades from semantic grade conversion, which is not planned. When absent, ordinary name search and browsing remain complete.
- **Direct camera capture:** Add an optional source beside Photos/Files with permission, denial, cancel, and capture-review states. V1 still accepts existing images through Photos/Files without a camera entry point.

## 7. Visual Direction and Tokens

Approved direction: **Alpine Technical Notebook**. Quiet neutral surfaces, charcoal text, forest-green actions, and restrained burnt-orange accents, reflecting the owner's palette preference. Approval is not a claim of tested outdoor readability.

Use the following table as the single baseline palette. Do not combine it with conflicting generated Stitch palettes. Colors are semantic roles, not instructions to encode states using color alone.

| Role | Light | Dark | Use |
| --- | --- | --- | --- |
| Canvas | `#F4F6F8` | `#12181C` | Screen background |
| Surface | `#FFFFFF` | `#1C2429` | Grouped content and editors |
| Surface secondary | `#E7EDF1` | `#273239` | Secondary grouping |
| Text primary | `#1C2429` | `#F2F5F7` | Main reading content |
| Text secondary | `#46545E` | `#BDCAD2` | Supporting information |
| Action | `#2D5A43` | `#A5D6B7` | Actions and selection |
| On action | `#FFFFFF` | `#12181C` | Text on filled action |
| Accent | `#9B4A28` | `#F3B99B` | Restrained decorative emphasis; not a safety rating |
| Success | `#244B37` | `#8DC4A2` | Acknowledged local save; separate semantic token from Action |
| Warning | `#9B4A28` | `#F3B99B` | Attention with icon and text |
| Error | `#B3261E` | `#FFB4AB` | Failed operation and destructive action |
| Control boundary | `#71808A` | `#84949F` | Boundaries needed to identify controls |

Use success/warning/error colors as foregrounds on the appropriate neutral surface until dedicated state-container pairs are specified and checked. Destructive actions are labeled, not identified by rust/red alone. Decorative dividers can be quieter, but must not be the only indication of an interactive boundary.

### Typography

Candidate pairing: Hanken Grotesk for headings and Source Sans 3 for prose. Native system typography is the fallback and comparison baseline. Custom fonts require later licensing, bundled offline availability, and accessibility validation; baseline approval adds no font dependency or custom-font selection.

| Semantic role | Default reference size | Weight |
| --- | --- | --- |
| Large title | 34 pt | Bold |
| Screen/section title | 22 pt | Semibold |
| Subheading | 20 pt | Semibold |
| Reading body and editor | 17 pt | Regular |
| Supporting body | 15 pt | Regular |
| Caption | 13 pt | Regular or medium |

Sizes are references at the default content size, not fixed constraints. Map to native text styles and scale with Dynamic Type. Essential beta and error recovery never use caption-sized text. Use sentence case, comfortable line spacing, and no full justification. Avoid uppercase paragraphs and letter-spaced micro-labels. Use tabular figures only where aligned numerical columns benefit; never treat grades as numbers to normalize or convert.

### Layout and Components

- Use a 4-point spacing base: 4, 8, 12, 16, 24, and 32 pt. Start with 16-point phone gutters; adapt to safe areas and text size.
- Candidate radii: 8 pt for controls and 12 pt for grouped surfaces. Use pills sparingly for short passive metadata, not every section or action.
- Prefer native lists, forms, toolbars, sheets, menus, and alerts. Native components retain platform geometry and behavior rather than being forced into custom tokens.
- Distinguish sections with spacing and restrained tonal planes. Avoid deep card nesting, decorative gradients, blurred toolbars, and heavy floating shadows.
- Primary actions are at least 48 pt high; all interactive targets are at least 44 x 44 pt, including icon buttons and reorder controls. Visible glyphs may be smaller than their hit areas.
- Allow rows and controls to grow with text. At accessibility sizes, stack metadata and actions vertically rather than truncating names or squeezing text into columns.
- Filled primary buttons use Action/On action. Keep one visually dominant action per task. Secondary buttons remain clearly interactive without competing with reading content.
- Use SF Symbols in the native app. Icons supplement labels; unfamiliar icon-only actions require visible names. Do not simulate an app-owned badge inside the operating system status bar.

## 8. Language and Trust

| Prefer | Avoid |
| --- | --- |
| Notes, Gear, Descent, Sources | Execution protocols, tactical ledger, hardware array |
| Available offline | 100% ready, safe off-grid, verified route |
| Link only; original unavailable | Offline-ready for a saved remote URL |
| Saved on this device | Auto-synced, permanently secured |
| 0 pitches entered | This route has no pitches |
| Sum of entered pitch lengths, if shown | Unlabeled derived route height |
| Source attached; captured date | Verified extraction, 98% match |
| Archive created; export handed off | Safely backed up |
| Replace Library | Execute atomic swap |

Use one quiet local-availability indication where useful, not repeated privacy banners. Explain partial availability at the affected item. Do not claim dedicated encryption, key ownership, zero telemetry, inspected anchors, or guaranteed preservation without an approved implementation and evidence. Offline status is not a climbing-safety endorsement.

## 9. Accessibility and Environmental Use

- Support Dynamic Type through accessibility sizes, VoiceOver, sufficient text contrast, and Reduce Motion. Layout must not require animation to explain a result.
- Target at least 4.5:1 contrast for normal text, 3:1 for large text, and 3:1 for essential control/state graphics against adjacent colors. Validate actual rendered pairs in both modes; token values alone do not establish compliance.
- Keep essential status and error messages fully readable. Use icon plus text, never color-only save, warning, or selection feedback.
- Provide logical VoiceOver order, heading semantics, current-pitch context, and specific reorder actions such as Move Corner Traverse Up. Avoid duplicate announcements from decorative icons.
- Keep editor actions reachable above the keyboard. Honor system safe areas and do not let persistent controls cover the final lines of content.
- Treat glare, cold fingers, and low light as validation conditions, not guarantees of glove compatibility or measured sunlight performance. Do not increase brightness, use the torch, or change device behavior automatically.
- Provide captions and source context for images without claiming that a topo's geometry becomes accessible through its caption.

## 10. Next Mockup Round and Review Gate

### Reviewed Core Reference Index

Project: [Climbing Notebook in Stitch](https://stitch.withgoogle.com/projects/8970725447177276768). The following exact screen IDs identify the reviewed core visual references as of 2026-10-30. Use these IDs rather than titles: the project contains older duplicate and broken screens. A later edit requires renewed screenshot review; these are not immutable snapshots.

| Screen | Screen ID |
| --- | --- |
| Library | `3a77417ce44348eb97eae43da0fdd647` |
| Area Routes | `4145ce3c8439444488de353d355cee3d` |
| Route Detail, light | `316294727ae74db1b2bfde9e50abdf0c` |
| Pitch Detail | `a937d0f895f74b34a8d85b6d37a25286` |
| Note Editor | `959a7308f7d04879b6adbcb7020efc6e` |
| Note Editor, save failure | `2017664d56744303924fc1590e81e462` |
| Pitch Order Editor | `cf236651af9e4ac7a890dc3ebc1c9bcd` |
| Route Detail, dark | `e2e807d9f9f34e49ac65cb37e06ac191` |

For tools, use `projects/8970725447177276768/screens/<screen-id>`. Fetch current screen details for screenshot/HTML resource names. Review the rendered screenshot, not just generated markup or an edit's success message: one DOM-only caption edit reported success without appearing in either downloaded artifact.

These screens are usable layout references, not approval of every generated detail or an implementation specification. Apply these interpretation rules:

- This document and the approved functional plan take precedence over generated copy, fields, theme guidance, and handlers. Baseline approval does not approve every generated detail or expand an implementation packet.
- Older Pitch IDs `39bea4bfddf04a6cae885dc9643e58ba` and `73ea2082930d46449dd17131da9b89a0`, Area ID `93fe84625ac34052aa7fa03ec9a104d3`, and dark Route ID `31d35bf581304fddb49e7f61ec7f83bc` are superseded. Do not use them to recover missing UI.
- Generated HTML is disposable presentation scaffolding. Placeholder links, history navigation, simulated save timers, alerts, and clipboard actions do not establish native navigation, persistence, recovery, or safe dismissal. Back, Done, and gestures must all obey section 5; copying text is not saving it.
- Some light references retain slate-blue action definitions and use the success token for green buttons. Normalize to section 7 rather than reproducing that inconsistency. Multiple generated design assets exist; none overrides this document. Ignore generated send-verification badges, gear counters, and untested sunlight/glove guarantees.
- Pitch media is intentionally a text-only illustrative placeholder with a fully visible non-guidance caption. Media elsewhere, generated anchor/bail claims, crux badges, and protection metadata are sample content, not verified climbing guidance or approval for new structured fields. Do not infer a crux by comparing grades.
- The explicit Save Pitch Order screen is a staged ordering reference: preserve the whole-sequence commit boundary and show pending/failure states. It is not a reason to give automatically saved existing-field editors a misleading Cancel action.
- Visual inspection covered ordinary rendered layouts, including the keyboard editor, save-failure state, and dark Route. Dynamic Type, VoiceOver, contrast compliance, actual hit areas, long-name layouts, native keyboard avoidance, and interactive behavior still require implementation validation. Remaining companion states and ancillary workflows below are not complete or reviewed.

### Remaining Design Coverage

Cover the full planned product, using this document plus a short generation prompt for each batch. Start with the core hierarchy to establish consistent components, then extend the same system across all v1 flows and optional variants. Batching is a generation strategy, not a reduction of design scope.

| Batch | Required connected coverage |
| --- | --- |
| Core reading and authoring | Library, Area Routes, Route Detail, Pitch Detail, Note Editor, Pitch Order Editor; area/route/pitch creation and metadata editing; route moves; note-section creation and ordering; deletion confirmations |
| Sources and collection | Photos/Files/paste/share entry, Inbox and draft recovery, URL reference versus explicit Copy Page, capture selection, New/Existing Route assignment, target review and commit, attachment metadata/ordering, image/PDF viewers and source consultation |
| Data management | Settings, storage/privacy explanation, complete backup export/history, archive selection/validation, current/incoming comparison, replace confirmation, progress/failure/recovery and rollback consequences |
| Optional roadmap | OCR/assisted extraction, grade/style filters, favorites, and direct camera capture, each paired with its clean v1-disabled composition |

Use synthetic, clearly illustrative climbing content, not real route guidance or copyrighted guidebook scans. Suggested shared fixture: Example Granite / Paper Skyline, grade 5.9, Trad, with three pitches named Corner Traverse (5.7, 25 m), Open Book (5.9, 30 m), and Summit Slab (5.6, 20 m). Leave route total length unentered. Use the same names, values, ownership, and sequence across screens; a reorder example must visibly preserve names and notes.

Required companion states: empty library, no results, store unavailable with Retry, missing attachment, pending edits, nonempty-draft discard confirmation, saving, save failure with Retry, keyboard-visible editing, dark-mode Route/Pitch, and an accessibility-size reading layout. Include relevant permission, network-copy, import, and restore failure states in their batches. Show ordinary device viewports as well as long scroll content so above-the-fold priorities can be evaluated.

Before calling the baseline approved, review:

- Can a user find a route, open a pitch, and reach Descent or an original source without searching through decorative content?
- Are navigation, save/discard behavior, terminology, and fixture data consistent across all screens?
- Can the user distinguish unknown metadata, unentered content, unavailable files, and an unreadable library?
- Do large text, long names, dark mode, keyboard presentation, and touch targets preserve the workflow?
- Does every success, availability, privacy, and safety statement describe only what the app actually knows?
- Does the mockup cover all committed v1 workflows, including those not yet programmed, and remain complete with every optional module removed?

Owner approved this baseline on 2026-10-30 and directed continuation into the next feature-plan phase. Use the semantic visual tokens as the approved direction within assigned UI scope; validate rendered contrast and accessibility rather than treating approval as measurement. Use system typography until custom-font selection, licensing and bundling are separately resolved. The v1 mockups follow the approved automatic-save contract; the existing CF-07B explicit-save exception remains in force until a separate behavioral packet changes it. Optional-module interactions remain proposals requiring review before implementation. Baseline approval does not accept CF-07B, complete the remaining mockup coverage, authorize optional features, or override the feature plan's data-adoption and implementation gates.
