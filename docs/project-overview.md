# Project Overview — DM Batch Renamer

## Identity

| Field | Value |
|-------|-------|
| **Name** | DM Batch Renamer |
| **Purpose** | Batch renaming tool for REAPER (digital audio workstation) |
| **Author / Studio** | Anthony Deneyer — Demute Studio |
| **Version** | 0.7.0-beta |
| **Repository** | https://github.com/DemuteStudio/Reaper-Batch-Renamer |
| **Distribution** | ReaPack (REAPER's native package manager) |
| **Repository type** | Monolith — single REAPER ReaScript (Lua) package |

## Executive Summary

DM Batch Renamer is a **dockable ReaImGui window** that lets a REAPER user batch-rename
many project elements from a single interface, with a **live preview table** before any
change is committed. It is a pure REAPER ReaScript: there is no build step, no server, and
no external runtime — REAPER itself is the host and the Lua interpreter.

The tool is organized as one entry point (`DM_RENAMER_Main.lua`) plus a set of single-
responsibility modules under `Modules/`. The Main script draws the entire UI in an ImGui
`reaper.defer()` loop and dispatches rename work to the module that matches the active tab.

## What It Renames

The UI is tab-based; each tab targets one REAPER object type, plus an **All** tab that
operates across every type at once:

- **Media Items** (active take names)
- **Folder Items** — empty media items used as naming containers in game-audio pipelines
  (NVK / RenderBlock), named from region/track hierarchy via pattern variables
- **Regions**
- **Markers**
- **Tracks**
- **All** — a merged list spanning every type above

## Feature Highlights

- **Live preview** with per-row check / changed / unchanged colour coding
- **Find / Replace** (literal, with optional whole-word, case-sensitive; Lua-pattern engine
  present but mostly disabled in the current UI)
- **Prefix / Suffix**
- **9 case transforms**: lower, UPPER, Title, Sentence, camelCase, PascalCase, snake_case,
  kebab-case, CONSTANT_CASE
- **Space replacement**: underscore, dash, or remove
- **Numbering / increment** (number or letter sequences, configurable start / step / padding
  / position / separator), with automatic duplicate-name disambiguation
- **Operations**: remove brackets, remove parentheses, add date, add timestamp
- **Folder-Item naming patterns**: simple / hierarchical / custom, with variables
  `$region1…`, `$track1…`, `$position`, `$index`
- **Inline editing** directly in the preview table (double-click or F2)
- **Presets** — save / recall an entire rename configuration to disk
- **Exclude tags** — skip objects whose name starts with given tags
- **Customisable appearance** — colours, UI scale, font, theme presets
- **Companion scripts** for region/marker click-selection in the arrange view

## Technology Stack

| Category | Technology | Notes |
|----------|------------|-------|
| Language | Lua 5.x | Interpreted by REAPER; no external Lua runtime |
| Host | REAPER | Provides the `reaper.*` API and the script lifecycle |
| GUI | ReaImGui | `reaper.ImGui_*` — **required** dependency (installed via ReaPack) |
| Optional | SWS Extension | Enables accurate region/marker click-selection |
| Optional | js_ReaScriptAPI | Enables Shift-modifier detection in companion selection script |
| Packaging | ReaPack + `index.xml` | Repository index declaring all distributable files |

## Architecture at a Glance

- **One entry point** — `DM_RENAMER_Main.lua` (~2,500 LOC): bootstraps modules via
  `dofile()`, holds the global `state` table, draws the whole UI, runs the defer loop.
- **Renamer modules** — `Items`, `FolderItems`, `Regions`, `Markers`, `Tracks` implement a
  shared interface: `getList` / `getListWithSelection` / `updatePreview` / `applyChanges`.
- **Aggregator** — `All` merges every renamer type into one tagged list and delegates back.
- **Shared infrastructure** — `Common` (string/pattern/case/number/time/undo helpers, the
  single most-reused module), `Settings` (+ `Settings_UI`), `Presets`.
- **Companion action scripts** — `TrackRegionMarkerSelection` and
  `ClearRegionMarkerSelection` communicate selections to Main through REAPER **ExtState**.

See [architecture.md](./architecture.md) for the full picture and
[module-inventory.md](./module-inventory.md) for the per-module reference.

## Links

- Generated docs index: [index.md](./index.md)
- Source tree: [source-tree-analysis.md](./source-tree-analysis.md)
- Local dev / run: [development-guide.md](./development-guide.md)
- Release process: [deployment-guide.md](./deployment-guide.md)
