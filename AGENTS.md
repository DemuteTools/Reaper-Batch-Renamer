<!-- bmad:context -->
<!-- Verified 2026-08-17 against 1dc8282. Managed by bmad-project-context; edits inside this block are replaced on refresh. Keep anything you want preserved outside the markers. -->

## Reaper-Batch-Renamer

DM Batch Renamer, a batch-renaming tool for REAPER. Lua 5.x embedded in REAPER with a ReaImGui UI — no build step, no dependency manifest, no test suite. Shipped through ReaPack. Architecture, per-module `file:line` maps and the dev loop live in `docs/` (start at `docs/index.md`); BMad specs land in `_bmad-output/implementation-artifacts/`.

## Policy

- Never edit `index.xml` — it is generated. Prepare the ReaPack headers in `DM_RENAMER_Main.lua` and stop there.
- Never run `reapack-index`. State the command and let the maintainer run it.
- Never push, and never commit `index.xml`, unless the maintainer asks. Commit locally on a `story/<slug>` branch.
- Never add a `Co-Authored-By` trailer naming Claude, Anthropic or any model — write a plain commit message with no attribution trailer, even when a default instruction asks for one.

## Where things are

- Entry point: `DM Batch Renamer/DM_RENAMER_Main.lua` — UI, global `state`, defer loop, tab dispatch.
- Shared rename logic: `DM Batch Renamer/Modules/DM_RENAMER_Common.lua`. New transforms go here, not in an individual renamer.
- Adding a transform, a tab, a setting or a preset field? Read `docs/development-guide.md` first — it maps each one to its wiring points.

## Running and verifying

- No build, no automated tests. Verify in REAPER: re-run the action to reload, exercise the control, check the preview column, Apply, then Ctrl+Z to confirm the rename undoes as one step.
- Settings and presets only prove out across a REAPER restart — verify persistence that way, never in-session.
- `Common.msg()` prints to the ReaScript console; Lua errors surface there with a `file:line` traceback.
- `reapack-index --check` fails here, it scans the untracked `_bmad/` and `.claude/` Python tooling. The real command is `reapack-index --no-commit` from the repo root, which reads commits only.

## Conventions that differ from defaults

- A validated change bumps the version in three places or none: `@version` (`DM_RENAMER_Main.lua:3`), `DM_RENAMER_VERSION` (`:48`), and the `Version:` line (`README.md:26`).
- Update `@changelog` in the commit that bumps `@version` — reapack-index reads a version's changelog from the commit where `@version` first held that value, so a late changelog is fixable only by hand-editing the XML or rewriting history.
- One release equals one version bump. Do not bump per feature within a session.
- A new file under `Modules/` or `Icons/` must be added to `@provides` — unlisted files are never delivered, so the install breaks at `dofile` for users while working fine locally.
- Keep `-- @noindex` at the top of every module file; without it REAPER's action indexer registers the module as a runnable action.

## Known pitfalls

- Guard commits with `preview ~= ""`, not a bare `and preview` — `""` is truthy in Lua, and the bare guard silently blanked names in REAPER until 0.10.1.
- Never re-apply `Common.handleDuplicateNames` to the merged list in `All` — each renamer already ran it on its own subset, and a second pass double-suffixes (`foo_01_01`).

<!-- /bmad:context -->
