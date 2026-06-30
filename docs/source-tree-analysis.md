# Source Tree Analysis — DM Batch Renamer

Repository type: **monolith** (single ReaPack package). All runtime code lives under
`DM Batch Renamer/`. Everything else is repo metadata, packaging, or generated docs.

```
Reaper-Batch-Renamer/
├── DM Batch Renamer/                         # The deliverable package (this folder ships via ReaPack)
│   ├── DM_RENAMER_Main.lua                    # ★ ENTRY POINT — UI + defer loop + global state (~2546 LOC)
│   ├── Modules/                               # All logic modules (loaded by Main via dofile)
│   │   ├── DM_RENAMER_Common.lua              # Shared helpers: string/pattern/case/number/time/undo (★ most reused)
│   │   ├── DM_RENAMER_Items.lua               # Renamer: media-item (take) names
│   │   ├── DM_RENAMER_FolderItems.lua         # Renamer: empty "folder items" via region/track hierarchy patterns
│   │   ├── DM_RENAMER_Regions.lua             # Renamer: project regions (+ create/delete/ripple)
│   │   ├── DM_RENAMER_Markers.lua             # Renamer: project markers (+ create/delete/renumber/navigate)
│   │   ├── DM_RENAMER_Tracks.lua              # Renamer: tracks (+ color/folder/duplicate)
│   │   ├── DM_RENAMER_All.lua                 # Aggregator: merges all renamer types into one list
│   │   ├── DM_RENAMER_Settings.lua            # Persisted config (REAPER ExtState) + appearance/colors
│   │   ├── DM_RENAMER_Settings_UI.lua         # ImGui settings panel (General/Appearance/Scale/Presets tabs)
│   │   ├── DM_RENAMER_Presets.lua             # Save/load/delete rename presets to a .dat file on disk
│   │   ├── DM_RENAMER_TrackRegionMarkerSelection.lua  # Companion ACTION: capture region/marker click → ExtState
│   │   └── DM_RENAMER_ClearRegionMarkerSelection.lua  # Companion ACTION: clear region/marker selection ExtState
│   └── Icons/                                 # UI assets attached at startup
│       ├── DEMUTE-logoW.png
│       ├── android-icon-24x24.png             # website link button
│       ├── Discord-Symbol-Blurple.png
│       └── Documentation_Logo_W.png
├── index.xml                                  # ReaPack repository index (declares packages, versions, file sources)
├── README.md                                  # User-facing readme (carries the canonical version string)
├── .gitignore                                 # Excludes _bmad-output/ and .claude/
├── docs/                                      # ← Generated documentation (this folder)
└── _bmad/                                      # BMad tooling (not shipped)
```

## Entry Point

`DM Batch Renamer/DM_RENAMER_Main.lua` is the single script a user runs from REAPER's
Action list. On launch it:

1. Sets the toolbar toggle state and registers `reaper.atexit()` cleanup
   (`DM_RENAMER_Main.lua:48-57`).
2. Resolves its own folder via `debug.getinfo()` and loads every module with `dofile()`
   (`DM_RENAMER_Main.lua:60-70`).
3. Creates the ImGui context and attaches icon images (`DM_RENAMER_Main.lua:73-84`).
4. Initialises the global `state` table (`DM_RENAMER_Main.lua:95-227`).
5. Enters the `loop()` defer cycle (`DM_RENAMER_Main.lua:1061`, scheduled at line 2521).

## Critical Directories

| Path | Role | Notes |
|------|------|-------|
| `DM Batch Renamer/` | Package root | The unit ReaPack installs |
| `DM Batch Renamer/Modules/` | All logic | 12 Lua files; 10 are `dofile`-loaded modules, 2 are standalone action scripts |
| `DM Batch Renamer/Icons/` | UI assets | PNGs loaded via `reaper.ImGui_CreateImage()` |
| `index.xml` (repo root) | Packaging | Must be updated on every release (see deployment guide) |

## Two Kinds of Files in `Modules/`

- **Modules** (return a table, loaded by Main via `dofile`): `Common`, `Items`,
  `FolderItems`, `Regions`, `Markers`, `Tracks`, `All`, `Settings`, `Settings_UI`,
  `Presets`. They expose functions and have **no side effects on load** (except `Settings`,
  which auto-loads config, and `Presets`, which computes its file path).
- **Action scripts** (no public surface, executed directly from the Action list):
  `TrackRegionMarkerSelection`, `ClearRegionMarkerSelection`. They only read/write REAPER
  **ExtState** under section `"DM_RENAMER"`.

## Integration Points (single part, but worth noting)

The Main script and the two companion action scripts are **decoupled** — they never call
each other. They communicate only through REAPER ExtState keys:

- `DM_RENAMER / SelectedRegions` — comma-separated region indices
- `DM_RENAMER / SelectedMarkers` — comma-separated marker indices

This lets a user bind the selection scripts to a mouse modifier / toolbar and have the Main
window pick up the selection on its next frame. See
[architecture.md](./architecture.md#extstate-the-decoupling-bus) for details.
