# Climbing Notebook Design

Updated: 2026-11-04

## Authority and Intent

Product design rules for a native, iPhone-primary notebook with minimal iPad support. The [approved plan](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md), especially §21.6, owns scope, data and behavior. [README](README.md) describes what exists; [verification](docs/verification/NotebookPrototype.md) records evidence. This document guides presentation, not feature authorization or release acceptance.

For MVP delivery, follow [§21.6.8](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#2168-mvp-delivery-and-verification-policy): fix concrete usability/data defects and run focused affected checks. The accessibility/design targets below remain goals; unresolved automated audit flags alone are non-gating for the pre-production MVP. Do not replace native controls or add diagnostic infrastructure merely to chase a flag.

Preserve the owner-approved Alpine Technical Notebook direction (2026-10-30), refined by the user-first/Save direction (2026-11-03). Native UI review follows [native-interface-design](.kilo/skills/native-interface-design/SKILL.md).

**Human:** a climber consulting or recording their own notes, often on a small screen outdoors. **Task:** find the right route/pitch, read complete notes, deliberately edit. **Feel:** calm, practical, legible; a notebook, not a dashboard or climbing adviser.

## Content Before Chrome

- Lead with the task and user content. Explain location through hierarchy, not an instruction paragraph. Every app-authored sentence must help the task, prevent consequential loss or explain recovery.
- Use one navigation title. Put owner/location in a compact secondary line; retain enough context to distinguish duplicate names and Notebook/Examples/retained sources. Wrap rather than truncate essential identity.
- Group related content with spacing and quiet surfaces. Do not give routine status, provenance and user notes equally prominent cards.
- Compact means fewer redundant containers and labels, not smaller text, hidden actions or smaller touch targets. Preserve authored text verbatim, including whitespace, Unicode and section order; never summarize or trim notes to fit.

## Current §21.6 Screen Patterns

| Screen | Primary content | Supporting controls |
| --- | --- | --- |
| Library / Area | Named rows and entered counts; distinct empty, loading and unavailable states | Specific Add Area/Add Route entry actions; less frequent actions in a labeled menu |
| Route | Route/area identity, complete General notes, ordered pitches | Edit Notes, Jump to Pitches, labeled actions menu; a pitch is reachable with a jump and tap |
| Pitch | Position, authored name if present, complete notes | Pinned Previous/Next with disabled boundaries; Edit Notes and actions menu |
| Route/pitch images | Owner-labeled caption/order index with uncropped identification previews; one image opens the original reader | Native Photos selection and separate review/Save; manage captions/order/removal separately; no gallery dashboard or required taxonomy |
| Image reader | Unmodified original pixels, readable zoom/pan and complete notes in a read-only sheet | Done, explicit adjacent-image navigation, Fit Image/Width and accessible zoom/pan; controls outside original viewport |
| Name editor | Task title, compact owner context, one field | `Name *` with accessible `Name, required`; pitch `Name (optional)`; validation at the field when needed |
| Note editor | Owner + field identity, generous plain-text editing surface | Save/Cancel and keyboard dismissal remain reachable; no permanent content-sized row for keyboard dismissal |
| Order editor | Full names, positions, drag handles | Target-labeled Move Up/Down alternative, disabled boundaries; one Save for the sequence |

Keep note editing, naming, ordering and deletion separate. Back returns to the actual originating context. Reading and Previous/Next never mutate order or save. Pitch fallback titles such as Pitch 2 are presentation, not authored names. Never replace an unreadable library with an empty-library screen.

Do not repeat routine “Saved/Loaded on this device” status on reading screens. Put the backup limitation in About & Data; keep unsaved-change indicators and actionable failures where they occur. Optional image captions use one persistent label, not identical label and placeholder text.

The [approved image contract](Image-Supported-Notebooks-FeaturePlan.md) adds route-owned images before General/pitches with section jumps; pitch notes stay first with their own image jump and distinct route-reference link. No images retains the existing content with a quiet Add Images action. Previews are aspect-fit and identify content, never substitute for full-original reading. Dynamic Type scales notes/controls, not raster text; provide native zoom alternatives. Dark mode changes chrome, never original image colors. Keep missing originals visible with Retry/return rather than silently dropping attachments. Photos removal remains outside app attachment removal. Feature exploration and proposal history belong in the feature plan, not this rules document.

### Editor Hierarchy

1. Native navigation bar: Cancel, task title, Save. Deletion uses its own explicit confirmation.
2. Compact location/owner context, without a redundant Editing section.
3. The field or note itself, occupying the useful space.
4. Quiet state feedback; prominent explanation only for an error or consequential action.

| State | Presentation and behavior |
| --- | --- |
| Unchanged | No new-save announcement; reopened content is loaded, not newly saved |
| Modified | Concise, readable Unsaved changes; no standalone status card or tutorial about navigation/keyboard behavior |
| Saving | Visible Saving feedback; disable conflicting actions, dismissal, Cancel and source switching |
| Save failed / conflict | Not saved plus actionable explanation and Retry/review; retain exact draft and source identity; never silently overwrite or dismiss |
| Invalid name | Explain the relevant requirement or limit, retain input; do not repeat all naming rules on every form |
| Leaving changed draft | Block interactive dismissal; offer Discard Changes/Keep Editing before abandoning it |
| Delete | Name affected content and counts, explain cascading loss; block nonempty-area deletion |

## Save and Trust Boundaries

**Current §21.6:** all non-destructive editor commits say **Save**, including creation, rename, notes and ordering. **Cancel** abandons only uncommitted work; **Delete** stays distinct and destructive. Add Area/Route/Pitch are entry actions. A committing editor dismisses only after acknowledged success; failures retain the draft/confirmation context. Unchanged dismissal must not invent a save. Keyboard dismissal and navigation do not commit. Do not introduce autosave, silent discard, draft retargeting, reset or reseeding as a layout change.

Disclose missing backup/recovery once, concisely, at the library; important notes need another copy. Keep affected-item errors and destructive/discard confirmations at the point of risk. Never promise climbing accuracy, synchronization, encryption or recovery without implementation/evidence. Offline availability describes local bytes, not safety. Examples remain clearly separate; retained content stays read-only.

The plan's future full-product buffered autosave/Done-Back contract (§4.3) is **not** the current editor behavior. Adopting it requires separately authorized work; mockups must identify which contract they depict.

## Native Visual System

Use native SwiftUI navigation, forms, lists, toolbars, menus, alerts and SF Symbols. Keep familiar interaction and platform geometry; do not replace controls merely to style them. Icons clarify actions and have accessible names; unfamiliar actions retain visible labels. Native sheets/popovers own their elevation and material treatment.

Use quiet stone-neutral surfaces, forest-green actions and restrained burnt-orange accents. Color conveys meaning, not decoration; destructive/error meaning also needs text. These approved tokens are roles, not proof of rendered contrast:

| Role | Light | Dark |
| --- | --- | --- |
| Canvas | `#F4F6F8` | `#12181C` |
| Surface | `#FFFFFF` | `#1C2429` |
| Surface secondary | `#E7EDF1` | `#273239` |
| Text primary | `#1C2429` | `#F2F5F7` |
| Text secondary | `#46545E` | `#BDCAD2` |
| Action | `#2D5A43` | `#A5D6B7` |
| On action | `#FFFFFF` | `#12181C` |
| Accent / warning | `#9B4A28` | `#F3B99B` |
| Success | `#244B37` | `#8DC4A2` |
| Error | `#B3261E` | `#FFB4AB` |
| Control boundary | `#71808A` | `#84949F` |

Use system semantic text styles: title/headline for hierarchy, body for notes and essential feedback, supporting styles for context. Do not shrink essential text into captions. No bundled custom-font choice is approved.

Use a 4-point spacing scale for app-owned layout, typically 16-point phone gutters; respect native insets and safe areas rather than forcing them onto a grid. Avoid nested cards, decorative gradients, heavy shadows and promotional headers. App-owned targets are at least 44x44 points; preserve native toolbar sizing. At large text, wrap/stack and allow scrolling instead of truncating or squeezing. Never cover the last line of a note.

## Accessibility

Support Dynamic Type through accessibility sizes, VoiceOver and Reduce Motion. Use logical reading order, heading semantics, specific reorder labels and non-color state cues. Keep Save/Cancel and keyboard dismissal reachable with the keyboard open. No settings changes or motion may be required to understand the interface.

Rendered light/dark contrast targets: 4.5:1 normal text, 3:1 large text and essential control graphics. Quiet secondary text must remain readable. Approval of tokens or appearance is not accessibility qualification; verification follows the skill and approved plan.

## Future Design Coverage, Not Current Features

Keep mockups complete for the plan's committed v1: local name search, authored note sections, metadata/moves, images/PDFs with captions/tags/order, sources, Photos/Files/paste/share intake, explicit URL copying, manual review, backup and replace restore. Do not put unavailable destinations or Coming Soon controls in the current app.

Future Route layouts provide quick access to Approach, Pitches, Descent, Gear and Media, with Sources/originals available in content; preserve authored section titles/order. Unknown metadata stays unentered; search results include area context; links differ from downloaded bytes; intake targets are reviewed before commit; originals/provenance remain distinct from authored notes; missing files remain visible errors. Replace restore previews current/incoming counts and destructive loss with export opportunity and final confirmation. Consult the plan for contracts, not mockup handlers.

OCR/extraction, grade/style filters, favorites and direct camera are optional post-v1 variants: show enabled workflows and complete compositions without them. Sync/conflicts, annotation, maps, selective sharing and public data need separate planning. Do not invent computed cruxes, verified beta or safety ratings.

## Reviewed Visual References

[Stitch project](https://stitch.withgoogle.com/projects/8970725447177276768), reviewed2026-10-30. Use these exact IDs, not duplicate titles. They illustrate composition, not approved copy, behavior, features or accessibility qualification; this document and the plan take precedence. Normalize palette and current Save/Cancel behavior. Reinspect rendered screenshots after edits; generated HTML alone is not evidence.

| Screen | ID |
| --- | --- |
| Library | `3a77417ce44348eb97eae43da0fdd647` |
| Area Routes | `4145ce3c8439444488de353d355cee3d` |
| Route Detail, light | `316294727ae74db1b2bfde9e50abdf0c` |
| Pitch Detail | `a937d0f895f74b34a8d85b6d37a25286` |
| Note Editor | `959a7308f7d04879b6adbcb7020efc6e` |
| Note Editor, failure | `2017664d56744303924fc1590e81e462` |
| Pitch Order Editor | `cf236651af9e4ac7a890dc3ebc1c9bcd` |
| Route Detail, dark | `e2e807d9f9f34e49ac65cb37e06ac191` |

Use coherent synthetic content across screens. Optional media placeholders and generated claims are not climbing guidance. Verification procedure belongs in the native-interface-design skill; results belong in the existing verification reference, not this document.
