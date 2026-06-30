# Development Guide — DM Batch Renamer

## Prerequisites

| Requirement | Why |
|-------------|-----|
| **REAPER** | Host application and Lua interpreter. There is no standalone runtime. |
| **ReaImGui** | Required. The entire UI is `reaper.ImGui_*`. Install via ReaPack (ReaTeam Extensions repo). |
| **SWS Extension** *(optional)* | Accurate region/marker click-selection in the companion scripts. |
| **js_ReaScriptAPI** *(optional)* | Shift-modifier multi-select in `TrackRegionMarkerSelection`. |
| **A text editor** | Any editor. No language server or toolchain is needed. |

There is **no `package.json` / no dependency manifest in the repo** — dependencies are
declared for end users in `index.xml` (ReaPack) and resolved by REAPER, not by a build tool.

## Project Layout for Development

All runtime code is under `DM Batch Renamer/`:

- `DM_RENAMER_Main.lua` — entry point (UI + state + loop)
- `Modules/DM_RENAMER_*.lua` — modules and companion scripts
- `Icons/*.png` — UI assets

See [source-tree-analysis.md](./source-tree-analysis.md) for the annotated tree.

## Running the Script Locally (edit-test loop)

You develop against your real REAPER install. Two common setups:

**Option A — symlink the repo into REAPER's Scripts folder**

```
# Linux/macOS example — point REAPER at your working copy
ln -s "/mnt/reaper-batch-renamer/DM Batch Renamer" \
      "<REAPER ResourcePath>/Scripts/DM Batch Renamer"
```

**Option B — work directly inside `<ResourcePath>/Scripts/`** and keep that folder under git.

`<ResourcePath>` is what `reaper.GetResourcePath()` returns (REAPER → *Options → Show
REAPER resource path*).

Then, in REAPER:

1. *Actions → Show action list → New action → Load ReaScript…* and pick
   `DM_RENAMER_Main.lua` (only needed once).
2. Run it. The dockable DM Batch Renamer window appears.
3. After editing any `.lua` file, **re-run the action** to reload — REAPER re-`dofile`s the
   modules on each launch, so a relaunch picks up module changes. No build, no restart.

> Tip: keep the **ReaScript console** open (it's where `Common.msg()` /
> `reaper.ShowConsoleMsg()` print) for quick debugging.

## Build

**None.** Lua is interpreted by REAPER. "Building" only means making sure every file the
script `dofile`s is present next to `DM_RENAMER_Main.lua` in the same relative layout
(`Modules/`, `Icons/`).

## Coding Conventions

Match the surrounding code — it is internally consistent:

- **Modules return a table**; expose functions as `Module.fn`. No globals leak from modules
  (the lone exceptions: `Settings` auto-loads config on require; `Presets` computes its file
  path on require).
- **Functions**: `camelCase` (`refreshCurrentList`, `updatePreview`, `applyTrackRename`).
- **Module locals**: `PascalCase` when bound (`local Items = dofile(...)`).
- **Constants / URLs**: `SCREAMING_SNAKE_CASE` (`URL_WEBSITE`, `DM_RENAMER_VERSION`).
- **Settings keys**: `camelCase` (`caseSensitive`, `excludeTags`).
- **Comments**: `-- Section header in caps` for blocks; inline `--` for one-offs. Keep
  `--@noindex` at the top of module files (it tells REAPER's action indexer to ignore them).
- **Colour literals**: `0xRRGGBBAA` (alpha last).

## Common Development Tasks

### Add a transformation option (find/replace, case, etc.)
- Most rename logic lives in `Modules/DM_RENAMER_Common.lua`. Add or extend a helper there
  (it's pure Lua — easy to reason about and the highest-value place to centralise logic).
- Wire the option into each renamer's `updatePreview` priority pipeline (template →
  operation → find/replace → space → prefix/suffix → numbering → case → truncate → dedupe).
- Add the control to the Main left column (`DM_RENAMER_Main.lua:1491-2022`) and store its
  value on the global `state` table (`:95-227`).

### Add a new renamer target type (new tab)
1. Create `Modules/DM_RENAMER_<Type>.lua` implementing the four-function contract:
   `getList`, `getListWithSelection`, `updatePreview`, `applyChanges`
   (see [architecture.md](./architecture.md#4-the-renamer-module-contract)).
2. `dofile` it in Main (`:60-70`) and add a tab in the tab bar (`:1395-1480`).
3. Wire it into `refreshCurrentList` / `updatePreview` / `applyChanges` dispatch.
4. Optionally add it to `Modules/DM_RENAMER_All.lua` so it appears in the **All** tab.
5. Wrap every `reaper.*` mutation in `Common.beginUndoBlock()` / `endUndoBlock()`.

### Add a persisted setting
- Add the key to `Settings.getDefaultSettings()` (`DM_RENAMER_Settings.lua:11-124`).
- Add a getter/setter; call `Settings.save()` in the setter if it must persist.
- Deep-merge on load means old stored configs won't break. Add a migration in
  `Settings.load()` only if you rename/restructure an existing key.

### Add a preset field
- Add the field in `Presets.save()` and `Presets.load()`
  (`DM_RENAMER_Presets.lua`), plus a migration if you change an existing field's shape.
- Serialisation is automatic; test a save → manual-file-edit → load round-trip.

## Testing & Verification

No automated tests exist (host-embedded GUI script). Verify manually in REAPER:

1. Create a throwaway project with a handful of items / regions / markers / tracks.
2. Launch the script, exercise the changed control, confirm the **preview** column updates
   and colour-codes correctly *before* applying.
3. Click **Apply Changes**, then press **Ctrl+Z** — confirm the rename undoes as a single
   step (validates undo-block wrapping).
4. For settings/presets: change a value, **restart REAPER**, relaunch — confirm it persisted.
5. For companion scripts: bind them, click a region/marker, confirm the Main window reflects
   the selection (and that Shift multi-select works if `js_ReaScriptAPI` is installed).

`Common`'s pure functions (case, numbering, pattern, templating, duplicate handling) have no
`reaper.*` dependency and are the natural target if you ever introduce a real test harness.

## Debugging

- `Common.msg(text)` / `reaper.ShowConsoleMsg(text)` → ReaScript console.
- `Common.showError(text)` / `Common.confirm(text)` → `reaper.MB()` dialogs.
- Lua errors surface in REAPER's ReaScript console with a file:line traceback — start there.
