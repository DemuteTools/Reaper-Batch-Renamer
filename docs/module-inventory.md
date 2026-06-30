# Module Inventory — DM Batch Renamer

Per-module reference. Line numbers are `file:line` into `DM Batch Renamer/`.
Two kinds of files: **modules** (return a table, loaded by Main via `dofile`) and
**action scripts** (no public surface, run directly from REAPER's Action list).

---

## Entry point

### `DM_RENAMER_Main.lua` — UI, global state, defer loop (~2546 LOC)
Bootstraps modules, holds the global `state`, draws the whole UI, runs the frame loop.

| Concern | Where |
|---------|-------|
| Toggle/atexit init | `:48-57` |
| Module loading (`dofile`) | `:60-70` |
| ImGui context + icon images | `:73-84` |
| Global `state` table | `:95-227` |
| `refreshCurrentList()` | `:301` |
| `updatePreview()` | `:607` |
| `applyChanges()` | `:716` |
| `applyDirectEdit()` (inline edit) | `:771` |
| `jumpToItemPosition()` | `:815` |
| `hasProjectStateChanged()` | `:386` |
| `hasSelectionChanged()` | `:472` |
| `loop()` (defer render) | `:1061` |
| Preset bar / tab bar / columns | `:1240` / `:1395` / `:1491` & `:2025` |
| defer schedule | `:2521` |

---

## Shared infrastructure

### `Modules/DM_RENAMER_Common.lua` — shared helpers (★ most reused)
No dependencies; depended on by every renamer. Pure Lua except the thin Reaper wrappers.

| Function | Line | Purpose |
|----------|------|---------|
| `escapePattern` | `8` | Escape Lua-pattern metacharacters |
| `applyOperation` | `16` | removeBrackets / removeParens / addTimestamp / addDate |
| `applyCase` | `57` | 9 case transforms |
| `padNumber` | `133` | Zero-pad to width |
| `numberToLetters` | `143` | 1→A, 27→AA … |
| `splitString` | `157` | Split by delimiter |
| `validatePattern` | `170` | Validate Lua pattern via `pcall` |
| `testPattern` | `188` | Preview a pattern result |
| `matchPattern` | `208` | Literal/Lua match (case & whole-word aware) |
| `replacePattern` | `241` | Literal/Lua replace (case-insensitive aware) |
| `generateVariables` | `298` | Build `$num/$name/$date/$time/…` table |
| `applyTemplate` | `329` | Substitute `$var` tokens |
| `insertAtPosition` / `removeCharacters` | `342` / `351` | Positional edits |
| `removePrefix` / `removeSuffix` / `truncate` | `363` / `373` / `383` | Trim / cap length |
| `extractBetween` / `getExtension` / `removeExtension` | `394` / `407` | Substring helpers |
| `beginUndoBlock` / `endUndoBlock` | `421` | Wrap `reaper.Undo_*Block2` |
| `msg` / `showError` / `confirm` / `getProject` | `432` / `439` / `450` | Reaper I/O wrappers |
| `formatTime` / `parseTime` | `455` / `462` | Seconds ↔ `M:SS.mmm` |
| `handleDuplicateNames` | `473` | Suffix duplicates `_01/_A` |
| `applyTransformation` | `523` | find/replace → operation → case → prefix/suffix wrapper |

### `Modules/DM_RENAMER_Settings.lua` — persisted config
Storage: REAPER ExtState section `DM_RENAMER`, key `settings` (serialised Lua table) plus
fast keys `lastTab`, `windowPos`, `folderItemUser`. Auto-loads on `dofile`.

- Core: `load()`, `save()`, `reset()`, `getDefaultSettings()` (`:11-124`), `current` table.
- Options getters/setters: search / replace / display / appearance / column widths.
- History: `addSearchHistory`/`addReplaceHistory`/`getSearchHistory`/`clearHistory`.
- Colour utils: `colorToRGBA`/`rgbaToColor`, `generateLighter/Darker/Highlight`,
  `getHoverColor`/`getHighlightColor`/`getSelectionColor`.
- Folder-item gate: `getFolderItemUser`/`setFolderItemUser` (`true`/`false`/`"undecided"`).
- Back-compat migrations on load (`:236-242`): `autoIncrement`→`incrementMode`,
  `folderItemExcludeTag`→`excludeTags`; deep-merge over defaults.

### `Modules/DM_RENAMER_Settings_UI.lua` — settings panel
ImGui window with **General / Appearance / Scale / Presets** tabs (`:378-405`). Edits a
`tempSettings` buffer with live preview; commits on Apply, rolls back on Cancel.

- `init(settingsModule, imguiContext)`, `showSettingsWindow(open)`, `isOpen`/`setOpen`.
- Must call `init` before `showSettingsWindow`; `ctx` must not be nil.

### `Modules/DM_RENAMER_Presets.lua` — rename presets
Storage: `<reaper.GetResourcePath()>/Data/DM_RENAMER_Presets.dat` (serialised Lua table
literal; survives package updates).

- `save(name, state)`, `load(name)`, `load_all()`, `delete(name)`, `list()`,
  `serialize`/`deserialize`.
- Saves a flat config dict (find/replace, options, case, operation, prefix/suffix,
  increment, folder-item settings, excludeTags, spaceReplacement).
- Back-compat migrations in `load()`; `save()` silently overwrites same-name presets.
- Prefer `load_all()` once over `load()` in a loop.

---

## Renamer modules (shared four-function contract)

All implement `getList(excludeTags)`, `getListWithSelection(selectedOnly, excludeTags)`,
`updatePreview(list, find, replace, options)`, `applyChanges(list)`. All depend on `Common`.
`updatePreview` priority: template → operation → find/replace → space → prefix/suffix →
numbering → case → truncate → dedupe.

### `DM_RENAMER_Items.lua` — media-item (take) names
Renames active-take names; multi-mode enumeration (selected / time-selection / all);
excludes empty items via `FolderItems.isEmptyItem` and skips exclude-tag prefixes.

- `getItemList` `:76`, `createItemData` `:26`, `filterItems` `:171`, `updatePreview` `:527`,
  `applyItemRename` `:273`, `sortItems` `:444`.
- Creates a take on demand if an item has none (`:304`). Depends on
  `FolderItems.isEmptyItem` to skip folder items.

### `DM_RENAMER_FolderItems.lua` — empty "folder items"
Detects empty items, names them from region/track **hierarchy** patterns, writes name to
**both** item notes (`P_NOTES`) and take name (`P_NAME`) for NVK compatibility.

- `isEmptyItem` `:33`, `getRegionsAtPosition` `:70`, `getTrackHierarchy` `:110`,
  `generateName` `:153`, `updatePreview` `:419`, `applyChanges` `:492`, `setOptions`.
- Patterns: **simple** (first region + first track), **hierarchical** (all regions then all
  tracks), **custom** (`$regionN`/`$trackN`/`$position`/`$index`, with `<<EMPTY>>` cleanup —
  don't use that token in patterns). Items tagged `[JOIN]` are skipped.

### `DM_RENAMER_Regions.lua` — project regions
Enumerate / filter / preview / rename; plus create, delete (reverse-index), ripple, time-
selection helpers. Selection comes from ExtState (then time selection, then all).

- `getRegionList` `:48`, `getSelectedRegionsList` `:123`, `previewRegionRename` `:236`,
  `applyRegionRename` `:312`, `deleteRegions` `:477`.
- Gotcha: `EnumProjectMarkers3` gives enum `idx` **and** `markrgnindexnumber` — use the
  region number for `SetProjectMarker3`.

### `DM_RENAMER_Markers.lua` — project markers
Mirror of Regions for markers (`isRegion=false`); plus create-at-item-starts, delete,
renumber (sorted by position), and prev/next navigation.

- `getMarkerList` `:46`, `getSelectedMarkersList` `:119`, `updatePreview` `:697`,
  `applyMarkerRename` `:254`, `createMarkersAtItemStarts` `:468`, `renumberMarkers` `:634`.
- Gotcha: markers set end=start in `SetProjectMarker3`; cursor tolerance 0.1s hardcoded.

### `DM_RENAMER_Tracks.lua` — tracks
Enumerate (with folder-depth/parent/item-count/sends metadata) / preview / rename; plus
color, folder creation, duplication.

- `getTrackList` `:84`, `getChildTracks` `:105`, `updatePreview` `:585`,
  `applyTrackRename` `:254`, `colorTracks` `:390`, `createFolderFromTracks` `:410`,
  `duplicateTracks` `:513`.
- Gotchas: folder-depth semantics (start=1, end<0); unselect via `Main_OnCommand(40297)`;
  duplicate via action `40062` then account for index shift.

### `DM_RENAMER_All.lua` — aggregator
Loads the five renamers, merges their lists with `type`/`sortName`/`contextInfo` tags, and
delegates `updatePreview`/`applyChanges` back per type under **one** undo block.

- `getList` `:16`, `getListWithSelection` `:67`, `updatePreview` `:117`, `applyChanges` `:178`.
- Gotcha: submodules must **not** open their own undo block when called from `All` (`:213`).

---

## Companion action scripts (no public surface; ExtState bus)

### `DM_RENAMER_TrackRegionMarkerSelection.lua`
On run: find region/marker under mouse (SWS `BR_GetMouseCursorContext*`, cursor-position
fallback), write its index into ExtState `DM_RENAMER / SelectedRegions|SelectedMarkers`.
Shift (via `JS_Mouse_GetState`, needs js_ReaScriptAPI) toggles multi-select; single click
clears the other type. Bind it to a mouse modifier / toolbar.

### `DM_RENAMER_ClearRegionMarkerSelection.lua`
8-line script: empties both `SelectedRegions` and `SelectedMarkers` ExtState keys and logs
to the console. Idempotent.

---

## Quick lookup: "where do I change X?"

| I want to… | Go to |
|------------|-------|
| Add/extend a string transform | `Common.lua` (then wire into each renamer's `updatePreview`) |
| Add a UI control | `Main.lua:1491-2022` + a field on `state` (`:95-227`) |
| Add a renamer tab/type | new `Modules/DM_RENAMER_<Type>.lua` + Main dispatch + `All.lua` |
| Add a persisted setting | `Settings.getDefaultSettings()` + getter/setter |
| Add a preset field | `Presets.save`/`Presets.load` |
| Change region/marker selection behaviour | `TrackRegionMarkerSelection.lua` + Regions/Markers `getSelected*` |
| Touch undo behaviour | `Common.beginUndoBlock`/`endUndoBlock` (one block per Apply) |
