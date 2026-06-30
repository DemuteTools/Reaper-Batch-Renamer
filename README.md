# DM Batch Renamer

Batch renaming tool for REAPER. Rename multiple items, tracks, regions, and markers at once with live preview before applying changes.

<img width="1511" height="554" alt="image" src="https://github.com/user-attachments/assets/f46ec0cb-48fd-4c3e-82d1-94b8259c7643" />

## Why Use This Tool?

Renaming assets in REAPER is tedious and error-prone when done manually, especially in large sessions with hundreds of items, tracks, regions, and markers. DM Batch Renamer lets you rename everything from a single window with instant visual feedback.

- **Live preview before committing:** See exactly what every name will become before applying any change, so you never rename something by accident.
- **Powerful stacking controls:** Combine find/replace, prefix/suffix, case transforms, space replacement, and increment modes in a single pass — no need to run multiple actions.
- **Game audio workflow support:** Folder Items mode with custom naming patterns generates hierarchical names from your region and track structure, tailored for NVK and RenderBlock pipelines.

## How It Works

The script runs inside REAPER as a dockable ReaImGui window. Select a tab for the element type you want to rename, configure your renaming rules in the left panel, and review the results in the preview table on the right.

- **Tab-based element filtering:** Separate tabs for Media Items, Tracks, Regions, Markers, Folder Items, and a combined All view keep things organized.
- **Preset system:** Save and recall your entire renaming configuration so you can reuse complex setups across sessions with one click.
- **Companion scripts for region/marker selection:** Two lightweight helper scripts let you click-select regions and markers directly from the arrange view, working around REAPER's native API limitation.

---

**Version:** 0.8.0-beta
**Author:** Anthony Deneyer

---

## Table of Contents

- [Installation](#installation)
- [Getting Started](#getting-started)
- [Interface Overview](#interface-overview)
  - [Menu Bar](#menu-bar)
  - [Presets Bar](#presets-bar)
  - [Tabs](#tabs)
  - [Left Panel — Controls](#left-panel--controls)
  - [Right Panel — Preview Table](#right-panel--preview-table)
- [Tabs in Detail](#tabs-in-detail)
  - [Folder Items](#folder-items)
  - [All](#all)
  - [Media Items](#media-items)
  - [Regions](#regions)
  - [Markers](#markers)
  - [Tracks](#tracks)
- [Renaming Controls](#renaming-controls)
  - [Find and Replace](#find-and-replace)
  - [Prefix and Suffix](#prefix-and-suffix)
  - [Operations](#operations)
  - [Case Transformations](#case-transformations)
  - [Replace Spaces](#replace-spaces)
  - [Increment Mode](#increment-mode)
- [Options](#options)
- [Working with the Preview Table](#working-with-the-preview-table)
  - [Selecting Items](#selecting-items)
  - [Inline Editing](#inline-editing)
  - [Sorting Columns](#sorting-columns)
  - [Jump to Position](#jump-to-position)
- [Presets](#presets)
- [Folder Items — Advanced Usage](#folder-items--advanced-usage)
  - [Naming Patterns](#naming-patterns)
  - [Custom Pattern Variables](#custom-pattern-variables)
  - [Separator Options](#separator-options)
- [Exclude Tags](#exclude-tags)
- [Selection Behavior](#selection-behavior)
- [Appearance Settings](#appearance-settings)
  - [General Tab](#general-tab)
  - [Appearance Tab](#appearance-tab)
  - [Scale / Zoom Tab](#scale--zoom-tab)
  - [Presets Tab](#presets-tab)
- [Companion Scripts](#companion-scripts)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Common Workflows](#common-workflows)

---

## Installation

1. Install [ReaPack](https://reapack.com/) if you don't have it already.
2. Add the repository URL or install the script manually.
3. In REAPER, go to **Actions > Show action list**, search for **DM Renamer**, and run **DM_RENAMER_Main.lua**.

**Requirement:** [ReaImGui](https://forum.cockos.com/showthread.php?t=250419) (installed automatically via ReaPack dependency).

**Optional (recommended):** [SWS Extension](https://www.sws-extension.org/) — enables region/marker click-selection from the arrange view.

---

## Getting Started

1. Open the script from the REAPER Actions menu.
2. Select a tab matching what you want to rename (e.g., **Media Items**, **Tracks**).
3. Type in the **Find** field, and optionally the **Replace** field.
4. Watch the **Preview Table** update in real time.
5. Check the items you want to rename (changed items are auto-checked).
6. Click **Apply Changes** at the bottom of the window.

---

## Interface Overview

The window is divided into several sections:

### Menu Bar

- **Settings > Appearance Settings** — Open the theme/color editor.
- **Settings > Reset to Defaults** — Restore all appearance settings to defaults.

### Presets Bar

Located below the menu bar, visible on all tabs. Contains:

- **Load Preset** dropdown — Select a saved preset or choose `-- None --` to reset.
- **Save as** text field + **Save** button — Save the current configuration as a new preset.
- **Override** button — Replace the currently loaded preset with the current settings (appears only when a preset is loaded).
- **Delete** button — Delete the currently loaded preset.
- **Settings** button (right-aligned) — Quick access to Appearance Settings.

### Tabs

Six tabs control which type of REAPER element you rename:

| Tab | What it renames |
|-----|----------------|
| **Folder Items** | Empty items (no audio/MIDI content), for NVK/RenderBlock workflows. Hidden by default — see [Folder Items](#folder-items) |
| **All** | Items, tracks, regions, and markers combined in a single view |
| **Media Items** | Audio and MIDI items |
| **Regions** | Timeline regions |
| **Markers** | Timeline markers |
| **Tracks** | Track names |

### Left Panel — Controls

All renaming options: Find/Replace, Prefix/Suffix, Operations, Case, Replace Spaces, Increment mode, and checkboxes.

### Right Panel — Preview Table

A sortable table showing:

- **Checkbox** — Select/deselect individual items for renaming.
- **Current Name** — The existing name.
- **Target Name** — What the name will become after applying the current settings.
- **Context** (Folder Items and All tabs) — Shows region/track hierarchy information.
- **Type** (All tab only) — Shows the element type (Media Item, Folder Item, Track, Region, Marker).

---

## Tabs in Detail

### Folder Items

<img width="1511" height="554" alt="image" src="https://github.com/user-attachments/assets/4e688ce4-6513-41c8-95df-a1fa82f5d58d" />

Designed for **empty items** (items without audio or MIDI content). These are commonly used in game audio workflows with NVK or RenderBlock setups, where empty items serve as naming containers.

**Note:** Items with the name or notes `[JOIN]` (used by the NVK suite for folder detection) are automatically excluded from the Folder Items list.

#### First-Time Onboarding

The first time you open the Folder Items tab, an onboarding screen appears with two choices:

- **"I'm a Folder Item user"** — Confirms you use this workflow. The tab stays visible and shows the full controls.
- **"Hide this tab"** — Hides the Folder Items tab from the tab bar. The script switches to the All tab.

If you don't use NVK-style folder items, you can safely hide this tab.

#### Re-enabling the Tab

<img width="553" height="79" alt="image" src="https://github.com/user-attachments/assets/0b1d7663-e957-4178-85b8-cd2a473cfd3a" />

To show the Folder Items tab again after hiding it, go to **Settings** (`Ctrl+,` or the Settings button) and check **"Show Folder Items tab"** under the Folder Items Tab section.

#### Tab Controls

Once confirmed, this tab has its own dedicated controls at the top of the left panel:

- **Pattern** — Choose a naming pattern (Simple, Hierarchical, Custom).
- **Separator** — Choose the character between name parts.
- **Custom pattern field** — Visible when "Custom pattern" is selected.
See [Folder Items — Advanced Usage](#folder-items--advanced-usage) for full details.

### All

<img width="1511" height="554" alt="image" src="https://github.com/user-attachments/assets/dc69fc47-1d7a-439a-98b4-0d4d8b4632d7" />

Displays every renamable element in a single list. The table includes a **Type** column with color-coded labels and a **Context** column.

- Green: Media Item
- Magenta: Folder Item
- Cyan: Region
- Yellow: Marker
- Orange: Track

### Media Items

<img width="1511" height="554" alt="image" src="https://github.com/user-attachments/assets/f5742e2f-0d6c-4412-ba64-b68169664162" />

Shows all audio/MIDI items. Respects the current selection and time selection.

### Regions

<img width="1511" height="554" alt="image" src="https://github.com/user-attachments/assets/09463ad3-d611-4a9c-ab1c-18def4c818ca" />

Shows timeline regions. Supports selection via time selection or through the companion selection script (see [Companion Scripts](#companion-scripts)).

### Markers

<img width="1511" height="554" alt="image" src="https://github.com/user-attachments/assets/dc484879-ed69-4c7b-83c8-46aa3c8ae901" />

Shows timeline markers. Same selection behavior as Regions.

### Tracks

<img width="1511" height="554" alt="image" src="https://github.com/user-attachments/assets/ce113fc4-71a6-43ae-8c75-e3be425f0751" />

Shows all tracks. Respects the current track selection in REAPER.

---

## Renaming Controls

All controls below are available on **every tab**. They stack — you can combine Find/Replace with a Case transformation and a Prefix at the same time.

### Find and Replace

<img width="353" height="405" alt="image" src="https://github.com/user-attachments/assets/445b67d0-357c-48cc-97b6-91822a49f54b" />

| Field | Description |
|-------|-------------|
| **Find** | Text to search for in the current names |
| **Replace** | Text to substitute in place of the found text |

The preview updates automatically as you type.

### Prefix and Suffix

<img width="353" height="402" alt="image" src="https://github.com/user-attachments/assets/1e0751ae-dea0-4fdc-bcf9-57f053a98a7d" />

| Field | Description |
|-------|-------------|
| **Prefix** | Text added before the name |
| **Suffix** | Text added after the name |

### Operations

<img width="355" height="397" alt="image" src="https://github.com/user-attachments/assets/294e20f3-9e99-4059-8db9-62a244af499e" />

A dropdown with quick transformations. Select one from the list:

| Operation | Effect | Example |
|-----------|--------|---------|
| None | No operation | — |
| Add Date (YYYY-MM-DD) | Appends today's date | `VoiceRecording` → `VoiceRecording_2026-02-17` |
| Add Timestamp (MM-SS-mmm) | Appends the item's timeline position (minutes-seconds-milliseconds) | `VoiceRecording` → `VoiceRecording_02-34-150` |
| Remove [Brackets] and Content | Deletes `[...]` and everything inside | `VoiceRecording [old]` → `VoiceRecording ` |
| Remove (Parentheses) and Content | Deletes `(...)` and everything inside | `VoiceRecording (old)` → `VoiceRecording ` |

### Case Transformations

<img width="355" height="402" alt="image" src="https://github.com/user-attachments/assets/7ebc4a84-4800-4a9c-b385-da27784245ff" />

A dropdown to transform the case of all names:

| Style | Example |
|-------|---------|
| None | No change |
| camelCase | `helloWorld` |
| CONSTANT_CASE | `HELLO_WORLD` |
| kebab-case | `hello-world` |
| lowercase | `hello world` |
| PascalCase | `HelloWorld` |
| Sentence case | `Hello world` |
| snake_case | `hello_world` |
| Title Case | `Hello World` |
| UPPERCASE | `HELLO WORLD` |

### Replace Spaces

<img width="353" height="406" alt="image" src="https://github.com/user-attachments/assets/956c470a-ea28-4031-bc2c-4a0dd4a6c58f" />

Three toggle buttons to replace spaces in all names:

| Button | Effect |
|--------|--------|
| **_** | Replace spaces with underscores |
| **-** | Replace spaces with dashes |
| **Remove** | Delete all spaces |

Click the active button again to toggle it off.

### Increment Mode

<img width="355" height="405" alt="image" src="https://github.com/user-attachments/assets/d5bfdbb1-f6e1-4385-a04f-4afb784801a3" />

Handles duplicate names by appending a suffix. Choose one:

| Mode | Behavior | Example |
|------|----------|---------|
| **Off** | No duplicate handling | `Sfx`, `Sfx`, `Sfx` |
| **Number** | Appends `_01`, `_02`, etc. | `Sfx_01`, `Sfx_02`, `Sfx_03` |
| **Letter** | Appends `_A`, `_B`, ..., `_Z`, `_AA`, etc. | `Sfx_A`, `Sfx_B`, `Sfx_C` |

---

## Options

<img width="354" height="405" alt="image" src="https://github.com/user-attachments/assets/1a066b61-c8d8-4902-8474-8eaf8dff5677" />

| Option | Description |
|--------|-------------|
| **Case Sensitive** | Match exact case when searching (e.g., `Audio` does not match `audio`) |
| **Whole Word** | Only match complete words (e.g., `Bass` does not match `Bassist`) |
| **Jump to position on select** | When you click an item in the preview table, the REAPER arrange view scrolls to that item's position |

---

## Working with the Preview Table

<img width="1511" height="554" alt="image" src="https://github.com/user-attachments/assets/c04bb33e-82c7-4f5c-b617-1d7285cc7862" />

### Selecting Items

<img width="354" height="407" alt="image" src="https://github.com/user-attachments/assets/993fcf33-ec8f-45ff-a352-6455d7b74ec7" />

Three buttons below the options section control which items are checked:

- **Select All** — Check every item in the list.
- **Select None** — Uncheck every item.
- **Select Changed** — Check only items where the target name differs from the current name.

Items with changes are automatically checked when you modify any renaming parameter.

### Inline Editing

<img width="815" height="109" alt="image" src="https://github.com/user-attachments/assets/8792fa2a-34f9-438d-8765-37e093728405" />

**Double-click** any name in the Current Name or Target Name column to edit it directly. Press **Enter** to confirm or **Escape** to cancel.

- Editing a **Current Name** renames the item immediately.
- Editing a **Target Name** sets a custom preview name for that item.

### Sorting Columns

<img width="352" height="159" alt="image" src="https://github.com/user-attachments/assets/8f37d064-6926-4c88-8e92-4d92633e8c72" />

Click any column header (Current Name, Target Name, Context, Type) to sort the list. Click again to toggle ascending/descending. A **▲** or **▼** indicator shows the current sort direction.

### Jump to Position

When **Jump to position on select** is enabled, clicking a row in the preview table moves the REAPER arrange view to that element's timeline position.

![reaper_XPwV3yLuHa_1](https://github.com/user-attachments/assets/1a1d191f-7e1b-460c-aacb-a137df727b71)

---

## Presets

<img width="364" height="114" alt="image" src="https://github.com/user-attachments/assets/8af1d834-e671-4646-8826-a09fda88bc25" />

Presets save your entire renaming configuration so you can reuse it later.

### What a Preset Saves

- Find/Replace text
- Case sensitivity, Whole word settings
- Operation selection
- Case transformation
- Prefix and Suffix
- Increment mode
- Space replacement mode
- Folder Items pattern, separator, and custom pattern
- Exclude tags
- Jump to position setting

### How to Use Presets

1. **Save:** Configure your settings, type a name in the "Save as" field, click **Save**.
2. **Load:** Select a preset from the "Load Preset" dropdown. All settings are restored.
3. **Override:** Modify settings while a preset is loaded, then click **Override** to update it.
4. **Delete:** Select a preset, click **Delete** to remove it.
5. **Clear:** Select `-- None --` from the dropdown to reset all fields to defaults.

Presets are stored in REAPER's `Data` directory (`<REAPER Resource Path>/Data/DM_RENAMER_Presets.dat`), so they survive script updates.

The last used preset is automatically restored when you reopen the script.

---

## Folder Items — Advanced Usage

### Naming Patterns

<img width="348" height="102" alt="image" src="https://github.com/user-attachments/assets/7d79c8b2-d5d1-4ab2-a34c-eb83bfdf9d8e" />

| Pattern | Description | Example output |
|---------|-------------|----------------|
| **Simple** | First region + direct track name | `SFX_Dirt` |
| **Hierarchical** | All region levels + all track levels | `SFX_Impact_Dirt_Foley` |
| **Custom** | User-defined pattern with variables | Depends on your pattern |

### Custom Pattern Variables

<img width="335" height="142" alt="image" src="https://github.com/user-attachments/assets/c7ab47f5-42e4-4f0b-a201-5e5e8193a3cf" />

When you select the **Custom pattern** mode, you build a naming template using these variables:

| Variable | Description |
|----------|-------------|
| `$region1` | Parent region (largest region containing the item) |
| `$region2` | First child region |
| `$region3` | Second child region (and so on...) |
| `$track1` | Top-level parent track |
| `$track2` | First child track |
| `$track3` | Second child track (and so on...) |
| `$position` | Item's timeline position |
| `$index` | Item's index in the list |

**Examples:**

<img width="1490" height="174" alt="image" src="https://github.com/user-attachments/assets/6c837ffb-9783-48aa-b218-c5888089b919" />

| Pattern | Result |
|---------|--------|
|`$region2_$track1_$region1` | `Attack_A_Voice Digital_Sfx_MyAmazingSoundDesign` | 
| `$region1_$track1` | `sfx_dirt` |
| `$region2_$region3` | `boss_attack` |
| `$track2_$region1` | `grass_sfx` |

### Separator Options

<img width="283" height="31" alt="image" src="https://github.com/user-attachments/assets/3bd93322-db27-41b2-8fab-1b91002e3dbd" />

Choose the character that joins name parts:

- `_` (underscore) — default
- `-` (dash)
- ` ` (space)
- Any custom text typed in the separator field

---

## Exclude Tags

<img width="531" height="194" alt="image" src="https://github.com/user-attachments/assets/0a227e26-5908-4a6c-867f-252ec17fe2a7" />

Enter space-separated tags in the **Settings** window under **Exclude Tags**. Any item, region, or track whose name **starts with** one of these tags is excluded from the renaming list.

**Example:** If you set exclude tags to `TEMP OLD SKIP`, then:

- `TEMP_Guitar` — excluded
- `OLD_Bass` — excluded
- `SKIP_Drums` — excluded
- `My_Guitar` — included

<img width="1235" height="781" alt="image" src="https://github.com/user-attachments/assets/09f6d820-1a53-4383-a3b7-f60860940302" />

Here the track //MIX is not include in the Folder Item name because the exclude tag is `//`

---

## Selection Behavior

Each tab displays all elements of its own type:

- **Media Items** shows all media items in the project.
- **Tracks** shows all tracks.
- **Regions** shows all regions.
- **Markers** shows all markers.
- **Folder Items** shows all empty items.
- **All** shows everything combined.

**Time selection** acts as a filter: when a time selection is active, only the elements that overlap with it are shown. Remove the time selection to see everything again.

<img width="1085" height="1068" alt="image" src="https://github.com/user-attachments/assets/07e2abfc-5172-410e-b15b-e3f8cff461a9" />
<img width="894" height="1100" alt="image" src="https://github.com/user-attachments/assets/d2fc68b8-3d46-4a1f-83d8-dd224cc88fcc" />

For **Media Items** and **Folder Items**, selecting specific items in REAPER also acts as a filter — only those selected items appear in the list.

<img width="1006" height="743" alt="image" src="https://github.com/user-attachments/assets/3a1558ea-c561-4549-9955-9edf6a1eac8d" />

For **Tracks**, selecting specific tracks in REAPER filters the list to those tracks only.

**Note:** Individual selection does not work natively for **Regions** and **Markers** — REAPER does not expose region/marker selection to scripts. Use a time selection to filter them, or use the [companion selection script](#companion-scripts) as a workaround.

---

## Appearance Settings

Open via **Settings > Appearance Settings** or `Ctrl+,` or the **Settings** button.

The Settings window has four tabs and action buttons at the bottom: **Save & Close**, **Apply**, **Cancel** (restores original values), and **Reset Defaults**.

### General Tab

- **Exclude Tags** — Space-separated tags to exclude from renaming (see [Exclude Tags](#exclude-tags)).
- **Show Folder Items tab** — Toggle visibility of the Folder Items tab. Useful if you don't use NVK/RenderBlock workflows.

### Appearance Tab

#### Colors

- **Button Color** — Primary accent color for buttons, tabs, checkboxes, and sliders.
- **Button Hover Color** — Auto-computed from Button Color, but individually adjustable.
- **Background Color** — Window background.
- **Highlight Color** — Auto-computed from Button Color, but individually adjustable.
- **Text Color** — All text in the interface.
- **Header Color** — Column headers and section titles.
- **Frame Color** — Input field backgrounds.

#### Style

- **UI Elements Rounding** — Corner radius for buttons and inputs.
- **Window Rounding** — Corner radius for the window frame.
- **Item Spacing** — Vertical space between UI elements.
- **Window Padding** — Margin inside the window edges.

### Scale / Zoom Tab

- **UI Scale** — Overall interface scale (50%–200%), with quick preset buttons: 50%, 75%, 100%, 125%, 150%.
- **Font Size** — Base font size (requires restarting the script to take effect).

### Presets Tab

Four built-in appearance themes you can apply with one click:

- **Dark Theme** — Dark background with teal accents.
- **Light Theme** — Light background with neutral tones.
- **High Contrast** — Black background with high-visibility elements.
- **Blue Theme** — Navy background with blue accents.

---

## Companion Scripts

Two additional scripts are included for region/marker selection in the arrange view:

| Script | Purpose |
|--------|---------|
| **DM_RENAMER_TrackRegionMarkerSelection.lua** | Bind this to a mouse modifier or toolbar button. Clicking a region or marker in the arrange view selects it for the Renamer. Hold **Shift** to multi-select. |
| **DM_RENAMER_ClearRegionMarkerSelection.lua** | Clears the current region/marker selection. |

**Setup:** In REAPER, go to **Actions > Show action list**, find these scripts, and assign them to a keyboard shortcut or mouse modifier.

These scripts work best with the **SWS Extension** installed (Shift multi-select, precise region/marker detection). Without SWS, a fallback mode uses the cursor position for single-selection only.

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+,` | Open Appearance Settings |
| `Escape` | Cancel inline editing, or close the window if nothing is active |
| `Enter` | Confirm inline editing |
| `Double-click` | Edit a name directly in the preview table |
| `Right-click` | Edit the selected row inline |
| `F2` | Edit the selected row inline |
| `Mouse wheel` | Navigate selection up/down in the preview table |

---

## Common Workflows

### Clean Up Imported Session Names

1. Open the **Media Items** or **Tracks** tab.
2. Set **Find** to the unwanted prefix (e.g., `Track `).
3. Leave **Replace** empty.
4. Set **Case** to **Title Case**.
5. Set **Replace Spaces** to **_**.
6. Click **Apply Changes**.

**Before:** `Track 01 - raw GUITAR` → **After:** `Raw_Guitar`

### Add Sequential Numbers to Tracks

1. Open the **Tracks** tab.
2. Set **Prefix** to a numbering prefix (e.g., `01_`).
3. Or use **Find** with empty, **Replace** with empty, and **Increment Mode** set to **Number** — all tracks get unique `_01`, `_02` suffixes.

### Remove Take Numbers from Items

1. Open the **Media Items** tab.
2. Set **Find** to ` (` and **Replace** to empty — removes content like `(1)`, `(2)`.
3. Or use the **Remove (Parentheses) and Content** operation.

**Before:** `Guitar (1)` → **After:** `Guitar`

### Prepare Stems for Export

1. Open the **Tracks** tab.
2. Set **Case** to **UPPERCASE**.
3. Set **Replace spaces** to **_**.
4. Set **Prefix** to your project name (e.g., `MyProject_`).
5. Click **Apply Changes**.

**Before:** `lead vocals` → **After:** `MyProject_LEAD_VOCALS`

### Name Folder Items for Game Audio

1. Create regions in your timeline (e.g., `SFX`, `Music`, `VO`).
2. Organize tracks in folders (e.g., `Footsteps > Dirt`, `Footsteps > Grass`).
3. Open the **Folder Items** tab.
4. Select **Hierarchical** pattern.
5. Set the separator to `_`.
6. Click **Apply Changes**.

**Result:** `SFX_Footsteps_Dirt`, `SFX_Footsteps_Grass`

### Custom Patterns for Complex Game Audio Hierarchies

Imagine a project structured like this:

```
Regions (nested):
  ├── Level01              ← $region1 (parent, largest)
  │   ├── Forest           ← $region2
  │   │   ├── Ambiance     ← $region3
  │   │   └── Combat       ← $region3
  │   └── Cave             ← $region2

Tracks (nested):
  ├── SFX                  ← $track1 (top-level parent)
  │   ├── Footsteps        ← $track2
  │   │   ├── Dirt         ← $track3
  │   │   └── Stone        ← $track3
  │   └── Impacts          ← $track2
  │       └── Metal        ← $track3
```

Empty folder items sit at the intersection of a region and a track. With the **Custom pattern**, you control exactly which levels appear and in what order.

**Goal:** Name assets as `Level01_Forest_Footsteps_Dirt` (skip the top-level SFX category, keep the sub-region).

1. Open the **Folder Items** tab.
2. Set **Pattern** to **Custom pattern**.
3. Enter: `$region1_$region2_$track2_$track3`
4. Set **Separator** to `_`.
5. Set **Increment** to **Number** (handles duplicates).
6. Set **Exclude Tags** to `TEMP BUS` (skip utility tracks).
7. Click **Apply Changes**.

**Results:**

| Region context | Track context | Generated name |
|---------------|--------------|----------------|
| Level01 > Forest > Ambiance | SFX > Footsteps > Dirt | `Level01_Forest_Footsteps_Dirt` |
| Level01 > Forest > Combat | SFX > Impacts > Metal | `Level01_Forest_Impacts_Metal` |
| Level01 > Cave | SFX > Footsteps > Stone | `Level01_Cave_Footsteps_Stone` |

By skipping `$track1` (SFX), you avoid redundant prefixes. By using `$region2` instead of `$region3`, you pick the right nesting depth. The custom pattern gives you full control over the naming hierarchy without any manual editing.

Save this as a preset (e.g., `Game Export - Level Based`) to reuse it across sessions.

### Save and Reuse a Configuration

1. Set up your renaming parameters.
2. Type a name in the "Save as" field (e.g., `Game Audio Export`).
3. Click **Save**.
4. Next time, select `Game Audio Export` from the **Load Preset** dropdown.
