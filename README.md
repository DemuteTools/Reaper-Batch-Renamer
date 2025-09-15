# DM RENAMER for Reaper

A comprehensive batch renaming solution for REAPER with ReaImGui interface.

## Features

### Complete renaming functionality for:
- **Items** - Rename media items and takes
- **Regions** - Rename project regions
- **Markers** - Rename project markers
- **Tracks** - Rename tracks

### Search Options:
- Simple text search
- Regular expressions (Lua patterns)
- Case sensitive/insensitive
- Whole word matching
- Live preview of changes

### Batch Renaming Features:
- **Numbering** - Sequential numbering with padding
- **Case Changes** - UPPER, lower, Title, camelCase, snake_case, kebab-case
- **Prefix/Suffix** - Add text before/after names
- **Templates** - Use variables like $num, $name, $date, $time
- **Truncation** - Limit name length with optional ellipsis
- **Character Replacement** - Replace spaces, special characters

### Additional Features:
- **Presets** - Save and load rename configurations
- **History** - Recent searches and replacements
- **Multi-selection** - Select specific items to rename
- **Undo Support** - Full undo/redo integration
- **Import/Export** - Batch operations from files

## Requirements

- REAPER v6.0 or later
- ReaImGui extension (install via ReaPack)

## Installation

1. Install ReaImGui from ReaPack if not already installed
2. Copy the entire `DM_RENAMER` folder to your REAPER Scripts directory
3. In REAPER, go to Actions > Show action list
4. Click "Load" and navigate to `DM_RENAMER/DM_RENAMER_Main.lua`
5. Run the script or assign it to a toolbar/shortcut

## Usage

1. **Launch the script** - Run DM_RENAMER_Main.lua from the Actions list
2. **Select a tab** - Choose Items, Regions, Markers, or Tracks
3. **Enter search pattern** - Type what you want to find
4. **Enter replacement** - Type what to replace with
5. **Configure options** - Set case sensitivity, regex, etc.
6. **Preview changes** - Click Preview or enable Auto Preview
7. **Select items** - Check the items you want to rename
8. **Apply changes** - Click Apply to execute the rename

## Template Variables

When "Use Template" is enabled, you can use these variables:

### Universal Variables:
- `$num` - Sequential number
- `$num2`, `$num3`, `$num4` - Padded numbers (2, 3, 4 digits)
- `$name` - Current name
- `$NAME` - Current name in UPPERCASE
- `$Name` - Current name in Title Case
- `$date` - Current date (YYYY-MM-DD)
- `$time` - Current time (HH-MM-SS)
- `$year`, `$month`, `$day` - Date components

### Context-Specific Variables:
- **Items**: `$track`, `$tracknum`, `$position`, `$length`
- **Regions**: `$start`, `$ending`, `$length`, `$regionnum`
- **Markers**: `$position`, `$markernum`
- **Tracks**: `$tracknum`, `$parent`, `$items`, `$folder`

## Regular Expression Support

The script supports Lua pattern matching for advanced searches:
- `.` - Any character
- `%a` - Letters
- `%d` - Digits
- `%s` - Whitespace
- `*` - Zero or more
- `+` - One or more
- `?` - Zero or one
- `^` - Start of string
- `$` - End of string
- `()` - Capture groups (use $1, $2 in replacement)

## Presets

The script includes built-in presets for common operations:
- Add Track Numbers
- Remove Numbers
- Convert to Uppercase/Title Case
- Replace Spaces with Underscores
- Clean Special Characters
- And many more...

You can also save your own custom presets for frequently used operations.

## Tips

- Use **Ctrl+A** to select all items
- Use **Ctrl+I** to invert selection
- Enable **Auto Preview** to see changes in real-time
- Use **Show Only Matches** to filter the list
- Presets can be imported/exported for sharing

## Support

For issues or feature requests, please contact the script author.

## License

This script is provided as-is for use with REAPER.