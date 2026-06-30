# Architecture — DM Batch Renamer

## 1. Executive Summary

DM Batch Renamer is a single REAPER ReaScript written in Lua. There is **no build system,
no server, and no external runtime** — REAPER hosts the script, provides the `reaper.*` API,
and runs the Lua interpreter. The UI is drawn by [ReaImGui](https://github.com/cfillion/reaimgui)
inside a `reaper.defer()` immediate-mode render loop.

The design is a classic **entry point + single-responsibility modules** layout:

- `DM_RENAMER_Main.lua` owns the UI, the global `state`, and the frame loop.
- Five **renamer modules** each own one REAPER object type behind a shared interface.
- An **aggregator** (`All`) fans work out to those five.
- Shared services (`Common`, `Settings`, `Settings_UI`, `Presets`) sit underneath.
- Two **companion action scripts** feed selections in through ExtState.

## 2. Technology Stack

| Category | Technology | Version / Notes |
|----------|------------|-----------------|
| Language | Lua | 5.x (REAPER-embedded) |
| Host / API | REAPER | `reaper.*` functions; script lifecycle via `defer`/`atexit` |
| GUI | ReaImGui | **required**; `reaper.ImGui_*` |
| Optional | SWS Extension | `BR_GetMouseCursorContext*` for accurate click-selection |
| Optional | js_ReaScriptAPI | `JS_Mouse_GetState` for Shift-modifier multi-select |
| Persistence | REAPER ExtState | settings + cross-script selection |
| Persistence | Flat file | presets at `<ResourcePath>/Data/DM_RENAMER_Presets.dat` |
| Packaging | ReaPack | `index.xml` repository index |

**Architecture style:** modular monolith, immediate-mode UI, preview-then-commit data flow.

## 3. Module Map & Dependencies

```
                      DM_RENAMER_Main.lua  (UI, state, defer loop)
                               │ dofile()
   ┌──────────┬──────────┬─────┼──────────┬───────────┬──────────────┐
   ▼          ▼          ▼     ▼          ▼           ▼              ▼
 Items   FolderItems  Regions Markers  Tracks       All        Settings ── Settings_UI
   │          │          │     │          │           │              │
   └──────────┴──────────┴─────┴──────────┴───────────┘          Presets
                               │  (All also loads the 5 renamers)
                               ▼
                      DM_RENAMER_Common.lua   (depended on by everyone)

  Standalone action scripts (NOT loaded by Main; talk via ExtState):
     TrackRegionMarkerSelection   ──►  ExtState "DM_RENAMER"  ◄── ClearRegionMarkerSelection
```

- **`Common`** is the foundation — pattern matching, replacement, case transforms,
  numbering, templating, duplicate handling, time formatting, and undo-block wrappers.
  Every renamer module depends on it. It depends on nothing.
- **`Settings`** auto-loads on `dofile` and exposes `Settings.current`; `Settings_UI`
  edits it through a temp-state buffer (so Cancel can roll back).
- **`Presets`** is independent; it serialises a flat config dict to a `.dat` file.
- **`All`** loads the five renamer modules itself and delegates per-type.

## 4. The Renamer Module Contract

Every renamer module (`Items`, `FolderItems`, `Regions`, `Markers`, `Tracks`) exposes the
**same four-function interface**, which `Main` calls based on the active tab:

```lua
module.getList(excludeTags)                                  -- enumerate all objects of this type
module.getListWithSelection(selectedOnly, excludeTags)      -- enumerate, honouring current selection
module.updatePreview(list, findText, replaceText, options)  -- fill list[i].preview and list[i].changed (in place)
module.applyChanges(list)                                   -- commit renames for checked + changed rows
```

Each list element is a table carrying at least `{ name, preview, checked, changed }` plus
type-specific fields (`position`, `startPos`, `idx`/`index`, `contextInfo`, `type`).

**To add a new renamer type, implement these four functions and wire a new tab in Main.**
`All` can then include it by adding it to its submodule table.

> Isomorphism is the key invariant: `Main` does not special-case object types in its core
> dispatch — it relies on every renamer honouring this contract. `FolderItems` is the one
> with extra surface (`setOptions`, `isEmptyItem`, pattern-driven naming).

## 5. Data Flow — Preview-then-Commit

```
 user edits a control
        │  (sets state.needsRefresh / state.needsPreview)
        ▼
 end of frame ──► refreshCurrentList()  ──► module.getListWithSelection(...)  ──► state.currentList
        │                                                                            │
        └──────► updatePreview()  ──► module.updatePreview(list, find, replace, opts) ┘
                                          fills .preview / .changed; auto-checks changed rows
        ▼
 user clicks "Apply Changes"
        ▼
 applyChanges()  ──► module.applyChanges(list)  ──► reaper.* writes inside Common.beginUndoBlock/endUndoBlock
        ▼
 state.needsRefresh = true   (re-read the project, redraw)
```

Key points:

- **Deferred work**: control changes only *flag* `needsRefresh` / `needsPreview`; the actual
  recompute runs once at end of frame (`DM_RENAMER_Main.lua:2492-2512`) to batch cost.
- **Commit filter**: only rows with `checked == true` (and, for most paths, `changed == true`)
  are written.
- **Undo safety**: every mutation is wrapped in `Common.beginUndoBlock()` /
  `Common.endUndoBlock()` (which wrap `reaper.Undo_BeginBlock2`/`EndBlock2`). When `All`
  applies, it wraps a **single** undo block around all submodule calls — so submodules must
  not open their own undo block when invoked from `All`.

### Transformation pipeline (priority order)

`updatePreview` in each renamer applies transforms in a fixed priority:

```
template  →  operation  →  find/replace  →  space replacement
          →  prefix/suffix  →  numbering  →  case  →  truncate  →  duplicate disambiguation
```

If a template is set it takes precedence over find/replace. Duplicate disambiguation
(`Common.handleDuplicateNames`) runs last and can suffix `_01/_02…` or `_A/_B…`.

## 6. State Management

The whole UI is driven by one global `state` table (`DM_RENAMER_Main.lua:95-227`) holding:

- active tab, refresh/preview flags, selection-filter mode;
- find/replace text and options, operation, case, prefix/suffix, numbering parameters;
- folder-item pattern config;
- inline-editing cursor (`editingIndex`, `editingText`, `editingColumn`, double-click timing);
- sort column/direction; preset UI state;
- caches used for change detection (`lastItemCount`, `lastTrackNames`, ExtState selection
  strings, etc.).

**Change detection**: `hasProjectStateChanged()` (`:386`) and `hasSelectionChanged()`
(`:472`) compare these caches each frame so the list auto-refreshes when the REAPER project
or the user's selection changes underneath the window.

## 7. Persistence

| Data | Mechanism | Location / Keys |
|------|-----------|-----------------|
| App settings (search/replace/display/numbering/appearance/folderItems…) | REAPER ExtState (serialised Lua table) | section `DM_RENAMER`, key `settings`; plus fast keys `lastTab`, `windowPos`, `folderItemUser` |
| Rename presets | Flat file (serialised Lua table literal) | `<reaper.GetResourcePath()>/Data/DM_RENAMER_Presets.dat` |
| Region/marker selection (cross-script) | REAPER ExtState (`persist=false`) | section `DM_RENAMER`, keys `SelectedRegions`, `SelectedMarkers` |

Both serialisers escape `\ " \n \r` and deserialise via Lua `load()` in a sandboxed
environment guarded by `pcall`. Both `Settings.load()` and `Presets.load()` carry
**backwards-compatibility migrations** (e.g. boolean `autoIncrement` → string
`incrementMode`, `folderItemExcludeTag` → `excludeTags`) and deep-merge over defaults, so
older stored configs never crash a newer build.

## 8. ExtState — the Decoupling Bus

The Main window and the two companion action scripts never reference each other. A user
binds `TrackRegionMarkerSelection` to a mouse/toolbar action; when run it figures out which
region/marker is under the cursor (via SWS, with a cursor-position fallback) and writes the
index into `DM_RENAMER / SelectedRegions` or `SelectedMarkers`. The Main loop reads those
keys on its next frame and reflects the selection. `ClearRegionMarkerSelection` simply
empties both keys. Shift-held multi-select toggles indices in the comma-separated list and
requires `js_ReaScriptAPI` for modifier detection.

## 9. UI Composition (Main)

| Region | Lines | Contents |
|--------|-------|----------|
| Menu bar | `1198-1238` | File (Exit), Settings (Appearance, Reset) |
| Preset bar | `1240-1390` | Load/Save/Override/Delete preset, logo, gear |
| Tab bar | `1395-1480` | Folder Items*, All, Media Items, Regions, Markers, Tracks |
| Left column | `1491-2022` | Folder-item controls, transformations, options, selection buttons |
| Right column | `2025-2417` | Sortable preview table with inline editing & colour coding |
| Bottom bar | `2421-2487` | Apply Changes + website/Discord/docs icons + version |

\* The Folder Items tab shows an onboarding gate until the user confirms (or hides) it via
`Settings.getFolderItemUser()`.

## 10. Testing Strategy

There is **no automated test suite** — this is a host-embedded GUI ReaScript. Verification
is manual inside REAPER (see [development-guide.md](./development-guide.md#testing--verification)).
A pragmatic test harness would isolate `Common` (pure functions: case, numbering, pattern,
templating, duplicate handling) since it has no `reaper.*` dependency and is the highest-value
unit to cover.

## 11. Invariants an AI agent must preserve

1. **Renamer contract** — keep the four-function signature identical across renamers.
2. **Undo wrapping** — all `reaper.*` mutations go inside one `Common` undo block; never
   double-wrap when called from `All`.
3. **Preview purity** — `updatePreview` must not mutate the REAPER project; it only fills
   `.preview`/`.changed`.
4. **Settings serialisability** — only store serialisable values (no functions/metatables);
   add new settings to `getDefaultSettings()` and rely on deep-merge for back-compat.
5. **ExtState section** — everything shared lives under section `"DM_RENAMER"`.
6. **Release coupling** — a shipped change must bump the version in **both** `README.md`
   and `index.xml` (see deployment guide).
