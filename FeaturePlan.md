# Climbing Notebook Development Identity

Updated: 2026-10-28

## Approval Scope

Owner-approved. This plan covers development naming only; product behavior, architecture milestones, dependencies, signing ownership, and distribution scope remain unchanged.

## Architecture and Naming

- Use `Climbing Notebook` as the working app display name and navigation title, and `Climbing Notebook Inbox` for the share extension.
- Use `ClimbingNotebook` for the Xcode project, shared scheme, app target, Swift module, source directory, and app entry point. Use matching `Share`, `Tests`, and `UITests` suffixes.
- Use `climbing-notebook` for the local repository folder and requested GitHub repository name.
- Use provisional development identifiers rooted at `com.climbingnotebook.foundation`, with corresponding extension and test suffixes. These are not claims of registered identifiers or final release identities.
- Define a clearly marked development display-name build setting consumed by the generated app Info.plist, extension display name, and app title. Keep the implementation minimal; do not introduce a branding framework. Future artwork and colors remain placeholders in the product architecture plan, not a new design task.
- Keep technical identifiers independent of later marketing-name changes. Future branding work should change display settings and resources, not require another module rename.

## Files and Folders

- Rename the project bundle, shared scheme, app/source directory, extension directory, test directories, and Swift app entry-point file to the names above.
- Update project references, product names, bundle identifiers, test hosts, module imports, error domains, synthetic URL schemes, coverage fixtures, CI commands, and local test scripts.
- Rename the canonical product architecture document to `ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md`; update its contents and all documentation links.
- Update `README.md`, `SYSTEM_DOCS.md`, applicable local agent guidance, and current project metadata to describe only the current development identity. Do not add rename history, aliases, or a historical-name note.
- Preserve unrelated untracked Xcode user settings. Update applicable text-based scheme references and inspect binary workspace state for stale names; do not discard unrelated user state silently.
- Maintain the required work card in `docs/WIP_KANBAN.md` with concise status/evidence only.
- Inspect ignored build output and local tooling metadata for stale paths. Rebuild disposable artifacts as needed without editing historical transcripts, unrelated projects, or installed application data.

## API Contracts and Data Models

- No hosted API, persistence schema, entity, relationship, or library file-layout changes.
- Update the proposed backup suffix to `.climbing-notebook-backup` and proposed manifest format identifier to `com.climbingnotebook.backup`. These contracts remain unimplemented and provisional.
- No compatibility aliases for an unreleased development identity. Changing development bundle IDs produces a separate simulator app identity; do not delete an existing installation or migrate personal data as part of this task.

## Git and Local Folder Sequence

1. Complete source, filename, documentation, and build-tool changes in the existing checkout.
2. Run local verification before moving the checkout.
3. Handle the GitHub repository rename last if supported authenticated GitHub tooling is available. The GitHub CLI is currently unavailable; do not install host dependencies, access credentials, or change visibility to work around that. If unavailable, leave an explicit handoff rather than pointing origin at an unverified destination.
4. Rename the local checkout folder after checking destination collisions and linked-worktree references. Use supported Git repair operations where needed; do not hand-edit Agent Manager recovery state or rename its managed pool directories blindly. Report any remaining managed-worktree folder cleanup separately.
5. Verify repository status, remote configuration, and linked-worktree health from the resulting location. No commits, pushes, Git-history rewrites, or remote publication are included.

## Edge Cases and Acceptance

- Preserve concurrent edits and untracked files; stop if a conflicting modification prevents a safe rename.
- A linked detached worktree exists. Renaming the main checkout must not strand it, and its separate checkout contents are not silently changed as part of this working-tree edit.
- Existing Git objects, historical commits, external chat transcripts, Xcode recents, and system caches are outside a working-tree rename. Do not rewrite history or erase unrelated state to remove historical strings.
- Search current source, documentation, configuration, filenames, and relevant local metadata case-insensitively for obsolete branding. Report any unavoidable external or historical references in the completion response, not project notes.
- Validate the renamed Xcode project and scheme, run the simulator unit/UI suite, and enforce the existing 70% coverage gate. Run script/coverage self-checks provided by the project. Report unavailable checks accurately; do not resolve new dependencies or claim hosted CI was run.
- Confirm that generated app and extension display names use the spaced working title, documentation links resolve, test imports/products agree, and repository/worktree paths are valid.
