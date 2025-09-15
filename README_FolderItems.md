# Folder Items Feature Documentation

## Overview
The Folder Items feature detects and manages empty items (items without audio or MIDI content) in your Reaper project. It can automatically generate names based on their context (regions and tracks) and write them to the item's Notes field.

## What are Folder Items?
Folder Items are media items that contain no audio source or MIDI data. They are often used as:
- Visual markers in the timeline
- Organizational elements
- Placeholders for future content
- Section dividers

## Features

### 1. Empty Item Detection
- Automatically detects items without audio sources
- Identifies items without MIDI content
- Filters to show only empty items in the project

### 2. Context-Aware Naming
The system analyzes each empty item's context:
- **Region Context**: Detects parent and embedded (child) regions at the item's position
- **Track Hierarchy**: Identifies parent tracks and sub-tracks
- **Position Information**: Can include timeline position in naming

### 3. Naming Patterns

#### Simple Pattern
Format: `region_track`
Example: `sfx_boss`

#### Hierarchical Pattern
Format: `parent_region child_region parent_track child_track`
Example: `sfx enemy boss devil`

#### Custom Pattern
You can create custom patterns using variables:
- `{region}` or `{region_parent}` - Parent region name
- `{region_child}` - First embedded region name
- `{track}` - Current track name
- `{track_parent}` - Parent track name
- `{position}` - Timeline position
- `{index}` - Item index

Example custom pattern: `{region}_{track}_item{index}`
Result: `sfx_boss_item1`

### 4. Flexible Output Options

#### Write to Notes
- Writes the generated name to the item's Notes field
- Preserves the item's display name
- Notes are visible in the item properties

#### Write to Item Name
- Renames the item directly
- Creates a take if none exists
- Visible directly on the timeline

## How to Use

1. **Open DM RENAMER**
   - Run the main script `FR_Main.lua`

2. **Navigate to Folder Items Tab**
   - Click on the "Folder Items" tab

3. **Configure Naming Pattern**
   - Choose a pattern type (Simple, Hierarchical, or Custom)
   - Select separator character (_, -, space, or custom)
   - For custom patterns, enter your pattern string

4. **Choose Output Destination**
   - Check "Item Notes" to write to the Notes field
   - Check "Item Name" to rename the item directly

5. **Preview Changes**
   - The table shows:
     - Current Notes (or empty indicator)
     - Generated Name (preview)
     - Context information (regions and tracks)

6. **Apply Changes**
   - Select items using checkboxes
   - Click "Apply Changes" to write the names

## Example Workflow

### Scenario: Organizing SFX in a Game Project

1. Create empty items as placeholders for sound effects
2. Place them in regions named by category (e.g., "sfx", "music", "dialogue")
3. Use tracks organized by character or location (e.g., "boss", "player", "environment")
4. Run Folder Items naming with hierarchical pattern
5. Each empty item gets a descriptive name like "sfx boss attack" or "music level1 ambient"

### Complex Hierarchy Example

Given:
- Parent Region: `cinematics`
- Child Region: `intro`
- Parent Track: `characters`
- Child Track: `hero`

Result with hierarchical pattern: `cinematics intro characters hero`

## Testing

A test script `test_folder_items.lua` is included to verify functionality:
- Tests empty item detection
- Verifies region detection at item positions
- Checks track hierarchy detection
- Demonstrates name generation with different patterns

## Tips

1. **Use descriptive region and track names** for better auto-generated names
2. **The hierarchical pattern** works best with well-organized projects
3. **Custom patterns** allow for project-specific naming conventions
4. **Notes field** is non-destructive and preserves original item names
5. **Combine with search** to quickly find specific empty items later

## Troubleshooting

- **No items appearing**: Ensure you have empty items (no audio/MIDI) in your project
- **Names not generating**: Check that items are within regions or on named tracks
- **Pattern not working**: Verify custom pattern syntax with variable names in curly braces

## Integration with DM RENAMER

The Folder Items feature integrates seamlessly with DM RENAMER:
- Uses the same UI framework
- Follows the same selection and preview workflow
- Supports undo/redo operations
- Maintains consistency with other tabs