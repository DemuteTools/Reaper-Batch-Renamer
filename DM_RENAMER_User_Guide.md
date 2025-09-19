# DM_RENAMER - Quick Guide

## What is DM_RENAMER?

Batch rename tool for REAPER - rename multiple items, tracks, regions, and markers at once with preview before applying.

## Quick Start

1. Run `DM_RENAMER_Main.lua` from Actions menu
2. Select tab for what to rename (Items, Tracks, Regions, Markers, etc.)
3. Enter find/replace or choose operation
4. Preview → Select items → Apply

---

## Interface Overview

### The 6 Tabs
- **Folder Items** - For NVK users
- **All** - Everything at once  
- **Media Items** - Audio/MIDI items
- **Regions** - Timeline regions
- **Markers** - Timeline markers
- **Tracks** - Track names

### Main Controls
- **Find/Replace** - Text substitution
- **Operations** - Quick actions (Add Date, Remove Brackets, etc.)
- **Options** - Case sensitive, whole word, patterns
- **Preview Table** - See changes before applying

### Selection Priority
1. Selected items/tracks (if any)
2. Time selection (if any)
3. All items (default)

---

## Basic Operations

### Find & Replace
```
Find: Audio → Replace: Track
Result: Audio_01 becomes Track_01
```

**Options:**
- **Case Sensitive** - Match exact case
- **Whole Word** - Complete words only
- **Lua Patterns** - Regex-like matching

### Quick Operations

| Button | What it Does | Example |
|--------|-------------|---------|
| Add Date | Adds YYYY-MM-DD | Guitar → Guitar_2024-01-15 |
| Add Timestamp | Adds HH-MM-SS | Vocals → Vocals_14-30-45 |
| Remove [Brackets] | Deletes [...] | Track [old] → Track |
| Remove (Parens) | Deletes (...) | Bass (DI) → Bass |

### Case Transformations

| Style | Example |
|-------|---------|
| lowercase | hello world |
| UPPERCASE | HELLO WORLD |
| Title Case | Hello World |
| Sentence case | Hello world |
| camelCase | helloWorld |
| PascalCase | HelloWorld |
| snake_case | hello_world |
| kebab-case | hello-world |
| CONSTANT_CASE | HELLO_WORLD |

### Space Replacement
- **Underscore** - Replace spaces with _
- **Dash** - Replace spaces with -
- **Remove** - Delete all spaces

---

## Templates & Variables

### Quick Variables
- `$num` = 1, 2, 3...
- `$num2` = 01, 02, 03...
- `$num3` = 001, 002, 003...
- `$name` = Original name
- `$NAME` = ORIGINAL NAME
- `$Name` = Original Name
- `$date` = 2024-01-15
- `$time` = 14-30-45

### Template Examples
```
Template: Track_$num2_$Name
Result: Track_01_Guitar, Track_02_Bass

Template: $date_$name_Take$num
Result: 2024-01-15_vocal_Take1
```

---

## Lua Patterns (Most Useful)

### Pattern Library

| Pattern | Find | Replace | Result |
|---------|------|---------|---------|
| Remove prefix numbers | `^%d+[%.%s%-_]*` | | 01_Track → Track |
| Remove extension | `(.+)%.%w+$` | `%1` | song.wav → song |
| Extract [brackets] | `.*%[(.-)%].*` | `%1` | Name [keep] this → keep |
| Clean spaces | `%s+` | ` ` | too    many → too many |
| Remove special chars | `[^%w%s]` | | Hello@World! → HelloWorld |

### Quick Syntax
- `%d` = digit
- `%a` = letter
- `%s` = space
- `%w` = alphanumeric
- `^` = start
- `$` = end
- `+` = one or more
- `*` = zero or more

### Custom Pattern Example
```
Find: (%w+)_(%d+)
Replace: %2_%1
Result: Bass_03 → 03_Bass
```

---

## Special Features

### Folder Items Naming

**Three Modes:**
1. **Simple** - Basic sequential (Section_01, Section_02)
2. **Hierarchical** - Region_Track names (Verse_Guitar, Chorus_Bass)
3. **Custom** - Use pattern: `{region}_{track}`

**Variables:**
- `{region}` - Parent region name
- `{track}` - Track name

### Presets

**Save Current Setup:**
1. Configure all settings
2. Click "Save Preset"
3. Name it (e.g., "Clean Import")

**Load Preset:**
1. Click "Load Preset"
2. Select from list
3. All settings restored

### Exclude Tags

Skip items starting with specific tags:
```
Exclude: TEMP OLD SKIP
Ignores: TEMP_Guitar, OLD_Bass, SKIP_Drums
```

### Auto-Increment

Prevents duplicates automatically:
```
Renaming multiple to "Drums":
→ Drums_01, Drums_02, Drums_03
```

---

## Common Tasks

### Clean Imported Session
1. Pattern: Remove prefix numbers
2. Case: Title Case  
3. Space: Replace with underscore
```
01 - raw GUITAR track → Raw_Guitar_Track
```

### Add Track Numbers
Template: `$num2_$Name`
```
Guitar → 01_Guitar
Bass → 02_Bass
```

### Remove Take Numbers
Pattern: Remove take number (from library)
```
Guitar (1) → Guitar
Vocals (2) → Vocals
```

### Export Stem Naming
Template: `ProjectName_$num2_$NAME`
```
drums → ProjectName_01_DRUMS
bass → ProjectName_02_BASS
```

### Organize by Regions
1. Create regions (Verse, Chorus, Bridge)
2. Folder Items tab → Hierarchical mode
3. Auto-generates: Verse_Guitar, Chorus_Guitar

---

## Quick Tips

### Efficiency
- **Double-click** any name to edit directly
- **Click item** to jump to its position
- **Time selection** to limit scope
- **Save presets** for repeated tasks

### Selection Tips
- Select items → Only those renamed
- Time selection → Only items in range
- No selection → All items shown

---

## Pattern Cheat Sheet

### Most Common Patterns
```
Remove numbers: %d+
Remove spaces: %s
Any letter: %a
Any digit: %d
Start of string: ^
End of string: $
```

### Useful Combinations
```
^%d+%s*%-*%s*   (Remove "01 - " prefixes)
%s*%(%d+%)$     (Remove "(1)" suffixes)
%[(.-)%]        (Capture bracket content)
```

---

## Quick Reference

### Variables
| Variable | Output |
|----------|--------|
| $num | 1, 2, 3 |
| $num2 | 01, 02 |
| $name | original |
| $NAME | ORIGINAL |
| $date | 2024-01-15 |

### Operations
| Operation | Action |
|-----------|--------|
| Find/Replace | Text substitution |
| Add Date | Append date |
| Remove [] | Delete brackets |
| Remove () | Delete parentheses |

### Options
| Option | Effect |
|--------|--------|
| Case Sensitive | Exact case match |
| Whole Word | Complete words only |
| Lua Patterns | Regex matching |
| Auto-increment | Prevent duplicates |

---