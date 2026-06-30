# DM Batch Renamer — Documentation Index

> Generated: 2026-06-30 · Scan mode: initial / exhaustive · This `index.md` is the primary
> entry point for AI-assisted development on this project.

## Project Overview

- **Type:** monolith — a single REAPER ReaScript (Lua) package, distributed via ReaPack
- **Primary language:** Lua 5.x (REAPER-embedded; no external runtime, no build step)
- **GUI:** ReaImGui (required) · **Optional:** SWS Extension, js_ReaScriptAPI
- **Version:** 0.7.0-beta
- **Repository:** https://github.com/DemuteStudio/Reaper-Batch-Renamer

## Quick Reference

- **Entry point:** `DM Batch Renamer/DM_RENAMER_Main.lua` (UI + global `state` + `defer` loop)
- **Most reused module:** `DM Batch Renamer/Modules/DM_RENAMER_Common.lua` (string/pattern/case/number/undo helpers)
- **Architecture pattern:** modular monolith · immediate-mode UI · preview-then-commit data flow
- **Renamer contract:** `getList` / `getListWithSelection` / `updatePreview` / `applyChanges`
- **Persistence:** REAPER ExtState (settings, cross-script selection) + `.dat` file (presets)

## Generated Documentation

- [Project Overview](./project-overview.md) — what the tool is, feature list, stack
- [Architecture](./architecture.md) — modules, renamer contract, data flow, invariants
- [Source Tree Analysis](./source-tree-analysis.md) — annotated directory tree
- [Module Inventory](./module-inventory.md) — per-module reference with `file:line` map
- [Development Guide](./development-guide.md) — prerequisites, run/edit loop, common tasks
- [Deployment Guide](./deployment-guide.md) — ReaPack release process & `index.xml` rules

## Existing Documentation

- [README.md](../README.md) — user-facing readme (carries the canonical version string)

## Getting Started (for contributors)

1. Read [project-overview.md](./project-overview.md), then
   [architecture.md](./architecture.md) — together they give the full mental model.
2. Set up the edit-test loop against your REAPER install per
   [development-guide.md](./development-guide.md#running-the-script-locally-edit-test-loop).
3. Find where to change things via the "where do I change X?" table in
   [module-inventory.md](./module-inventory.md#quick-lookup-where-do-i-change-x).
4. When shipping, follow [deployment-guide.md](./deployment-guide.md) (bump version in
   **both** `README.md` and `index.xml`).

## Key Invariants (don't break these)

1. Keep the renamer four-function contract identical across renamer modules.
2. Wrap every `reaper.*` mutation in one `Common` undo block per Apply (never double-wrap
   when called from `All`).
3. `updatePreview` must not mutate the project — it only fills `.preview` / `.changed`.
4. Only store serialisable values in Settings/Presets; add new keys to defaults and rely on
   deep-merge for backward compatibility.
5. All cross-script shared state lives under REAPER ExtState section `"DM_RENAMER"`.
6. A shipped change bumps the version in `README.md` **and** `index.xml`.
