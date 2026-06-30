-- @description DM Renamer - Batch Renaming Tool
-- @author Anthony Deneyer
-- @version 0.8.0-beta
-- @changelog
--   Configurable digit padding for the increment suffix (new Digits field)
--   New "Truncate from" control: remove N characters from the start/end of names
-- @provides
--   [nomain] Modules/DM_RENAMER_Common.lua
--   [nomain] Modules/DM_RENAMER_Items.lua
--   [nomain] Modules/DM_RENAMER_Tracks.lua
--   [nomain] Modules/DM_RENAMER_Regions.lua
--   [nomain] Modules/DM_RENAMER_Markers.lua
--   [nomain] Modules/DM_RENAMER_FolderItems.lua
--   [nomain] Modules/DM_RENAMER_All.lua
--   [nomain] Modules/DM_RENAMER_Settings.lua
--   [nomain] Modules/DM_RENAMER_Settings_UI.lua
--   [nomain] Modules/DM_RENAMER_Presets.lua
--   [main] Modules/DM_RENAMER_TrackRegionMarkerSelection.lua
--   [main] Modules/DM_RENAMER_ClearRegionMarkerSelection.lua
--   [nomain] Icons/DEMUTE-logoW.png
--   [nomain] Icons/android-icon-24x24.png
--   [nomain] Icons/Discord-Symbol-Blurple.png
--   [nomain] Icons/Documentation_Logo_W.png
-- @link GitHub https://github.com/DemuteStudio/Reaper-Batch-Renamer
-- @about
--   # DM Batch Renamer
--
--   Batch renaming tool for REAPER with live preview.
--
--   ## Features
--   - Rename **items, tracks, regions, and markers** in batch
--   - Live preview table before applying changes
--   - Find/Replace with **Lua pattern** support
--   - Prefix, Suffix, Case transformations (9 modes)
--   - Replace spaces (underscore, dash, remove)
--   - Increment mode (number or letter sequences)
--   - **Folder Items** tab with custom naming patterns ($region, $track, $position, $index)
--   - Preset system to save/load renaming configurations
--   - Inline editing directly in the preview table
--   - Customizable appearance (colors, scale, theme presets)
--   - Companion scripts for region/marker click-selection
--
--   ## Requirements
--   - [ReaImGui](https://forum.cockos.com/showthread.php?t=250419) (installed automatically via ReaPack)
--   - Optional: [SWS Extension](https://www.sws-extension.org/) for region/marker click-selection

local DM_RENAMER_VERSION = "0.8.0-beta"

-- Toggle action state (toolbar on/off indicator)
local _, _, sectionID, cmdID = reaper.get_action_context()
reaper.SetToggleCommandState(sectionID, cmdID, 1)
reaper.RefreshToolbar2(sectionID, cmdID)
reaper.atexit(function()
    reaper.SetToggleCommandState(sectionID, cmdID, 0)
    reaper.RefreshToolbar2(sectionID, cmdID)
end)

-- Load modules
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
local Common = dofile(script_path .. "Modules/DM_RENAMER_Common.lua")
local Settings = dofile(script_path .. "Modules/DM_RENAMER_Settings.lua")
local Items = dofile(script_path .. "Modules/DM_RENAMER_Items.lua")
local Regions = dofile(script_path .. "Modules/DM_RENAMER_Regions.lua")
local Markers = dofile(script_path .. "Modules/DM_RENAMER_Markers.lua")
local Tracks = dofile(script_path .. "Modules/DM_RENAMER_Tracks.lua")
local FolderItems = dofile(script_path .. "Modules/DM_RENAMER_FolderItems.lua")
local All = dofile(script_path .. "Modules/DM_RENAMER_All.lua")
local Presets = dofile(script_path .. "Modules/DM_RENAMER_Presets.lua")
local SettingsUI = dofile(script_path .. "Modules/DM_RENAMER_Settings_UI.lua")

-- Initialize ReaImGui
local ctx = reaper.ImGui_CreateContext('DM RENAMER')

-- Load icon images
local icons_path = script_path .. "Icons/"
local icon_logo = reaper.ImGui_CreateImage(icons_path .. "DEMUTE-logoW.png")
local icon_website = reaper.ImGui_CreateImage(icons_path .. "android-icon-24x24.png")
local icon_discord = reaper.ImGui_CreateImage(icons_path .. "Discord-Symbol-Blurple.png")
local icon_docs = reaper.ImGui_CreateImage(icons_path .. "Documentation_Logo_W.png")
reaper.ImGui_Attach(ctx, icon_logo)
reaper.ImGui_Attach(ctx, icon_website)
reaper.ImGui_Attach(ctx, icon_discord)
reaper.ImGui_Attach(ctx, icon_docs)

-- Icon URLs
local URL_WEBSITE = "https://www.demute.studio/"
local URL_DISCORD = "https://discord.gg/KGvhT5S8ZT"
local URL_DOCS = "https://github.com/DemuteStudio/Reaper-Batch-Renamer"

-- Initialize SettingsUI module
SettingsUI.init(Settings, ctx)

-- State management
local state = {
    currentTab = "Folder Items",
    findText = "",
    replaceText = "",
    currentList = {},
    needsRefresh = false,  -- Manual refresh only
    needsPreview = false,
    lastProject = nil,
    -- Advanced options
    caseSensitive = false,
    wholeWord = false,
    autoSelectChanged = true,  -- Auto-select items when they have changes
    selectAllByDefault = true,  -- Select all items when loading list
    useSelectedOnly = false,  -- Track if we should show only selected items
    -- Selection tracking for auto-refresh
    lastItemSelCount = 0,
    lastTrackSelCount = 0,
    lastTimeSelStart = 0,
    lastTimeSelEnd = 0,
    -- Track actual item/track pointers not just count
    lastSelectedItemPointers = {},
    lastSelectedTrackPointers = {},
    lastFolderItemSelection = {},
    -- Project state tracking for auto-refresh
    lastTrackCount = 0,
    lastItemCount = 0,
    lastMarkerCount = 0,
    lastRegionCount = 0,
    lastTimeSelStart = 0,
    lastTimeSelEnd = 0,
    lastTrackNames = {},
    -- Region/Marker selection tracking via ExtState
    lastRegionSelectionString = "",
    lastMarkerSelectionString = "",
    -- Region/Marker names cache for change detection
    lastRegionNames = {},
    lastMarkerNames = {},
    -- Operation mode
    operation = "none",  -- none, removeNumbers, removeSpecialChars, removeExtension, cleanSpaces, extractBrackets, extractParens, etc.
    -- Lua Pattern support
    useLuaPatterns = false,     -- Toggle for Lua patterns mode
    patternValid = true,        -- Pattern validation status
    patternError = "",          -- Error message if pattern invalid
    testPatternText = "",       -- Test text for pattern testing
    selectedPattern = nil,      -- Selected predefined pattern
    showPatternHelp = false,    -- Show pattern help window
    patternHistory = {},        -- Last 10 used patterns
    -- Predefined patterns with context support (alphabetically sorted)
    commonPatterns = {
        -- None option first
        {name = "-- None --", pattern = "", replace = "", desc = "No pattern", context = "all"},
        -- Universal patterns (all contexts) - alphabetical
        {name = "Add quotes", pattern = "^(.+)$", replace = "\"%1\"", desc = "Wrap text in quotes", context = "all"},
        {name = "Clean spaces", pattern = "%s+", replace = " ", desc = "Replace multiple spaces with single", context = "all"},
        {name = "Extract [brackets]", pattern = ".*%[(.-)%].*", replace = "%1", desc = "Keep ONLY bracket content", context = "all"},
        {name = "Extract (parens)", pattern = ".*%((.-)%).*", replace = "%1", desc = "Keep ONLY parentheses content", context = "all"},
        {name = "Remove all numbers", pattern = "%d+", replace = "", desc = "Remove all numbers", context = "all"},
        {name = "Remove all spaces", pattern = "%s", replace = "", desc = "Remove ALL spaces everywhere", context = "all"},
        {name = "Remove extension", pattern = "(.+)%.%w+$", replace = "%1", desc = "Remove file extension", context = "all"},
        {name = "Remove prefix numbers", pattern = "^%d+[%.%s%-_]*", replace = "", desc = "Remove leading numbers (01. 02- 03_)", context = "all"},
        {name = "Remove special chars", pattern = "[^%w%s]", replace = "", desc = "Keep only letters, numbers, spaces", context = "all"},
        {name = "Swap name_123", pattern = "(%w+)_(%d+)", replace = "%2_%1", desc = "Swap 'Name_123' to '123_Name'", context = "all"},
        {name = "Trim spaces", pattern = "^%s*(.-)%s*$", replace = "%1", desc = "Remove leading/trailing spaces", context = "all"},
        -- Context-specific patterns
        {name = "Add marker prefix", pattern = "^", replace = "M: ", desc = "Add 'M: ' prefix", context = "Markers"},
        {name = "Add region prefix", pattern = "^", replace = "Region: ", desc = "Add 'Region: ' prefix", context = "Regions"},
        {name = "Remove take number", pattern = "%s*%(%d+%)$", replace = "", desc = "Remove take number (1) (2) etc", context = "Items"},
        {name = "Remove Track prefix", pattern = "^Track%s*%d+%s*%-?%s*", replace = "", desc = "Remove 'Track 01 -' prefix", context = "Tracks"}
    },
    -- Transformation state
    transformCase = "none",  -- none, lower, upper, title, sentence, camel, pascal, snake, kebab, constant
    needsFullTransform = false,
    -- Template and advanced options
    useTemplate = false,
    templateString = "",
    prefix = "",
    suffix = "",
    removeFromStart = 0,  -- chars to strip from the start of the name (before prefix/suffix)
    removeFromEnd = 0,    -- chars to strip from the end of the name (before prefix/suffix)
    addNumbering = false,
    startNumber = 1,
    increment = 1,
    padding = 2,
    numberPosition = "suffix",  -- prefix, suffix, replace
    numberSeparator = "_",
    maxLength = 0,
    addEllipsis = false,
    -- Examples for dropdown (alphabetically sorted)
    caseExamples = {
        none = "None",
        camel = "camelCase",
        constant = "CONSTANT_CASE",
        kebab = "kebab-case",
        lower = "lowercase",
        pascal = "PascalCase",
        sentence = "Sentence case",
        snake = "snake_case",
        title = "Title Case",
        upper = "UPPERCASE"
    },
    -- Inline editing state
    editingIndex = nil,      -- Index of the item being edited
    editingText = "",        -- Temporary text during editing
    editingOriginal = "",    -- Original text before editing
    editingColumn = nil,     -- Column being edited: "current" or "target" 
    needsFocus = false,      -- Flag to set focus on next frame
    selectedIndex = nil,     -- Index of the selected item (single click)
    lastClickTime = 0,       -- Time of last click for double-click detection
    lastClickIndex = nil,    -- Index of last clicked item for double-click detection
    -- Folder Items specific state
    folderItemPattern = "hierarchical",  -- simple, hierarchical, custom
    folderItemSeparator = "_",
    folderItemCustomPattern = "$region1_$track1",
    folderItemIncrementMode = "number",  -- Increment mode for duplicates: "off", "number", "letter"
    -- Global exclude tags (space-separated)
    excludeTags = "",  -- Global tags to exclude items/regions/tracks from renaming
    -- Space replacement mode
    spaceReplacement = "",  -- "" = none, "_" = underscore, "-" = dash, "remove" = remove spaces
    -- Jump to position settings
    jumpToPosition = true,  -- Jump to selected item position (default: true)
    -- Increment mode for all tabs: "off", "number", "letter"
    incrementMode = "number",
    -- Digit count for "number" increment suffix (shared by all tabs); default 2 = legacy _01/_02
    incrementPadding = 2,
    -- Sorting state
    sortColumn = nil,
    sortDirection = "asc",
    -- Presets
    presetList = {},
    selectedPreset = nil,
    presetName = "",
    showPresetDialog = false,
    -- Manual sorting state (for ReaImGui)
    lastSortColumn = -1,
    -- Settings window state
    showSettingsWindow = false
}

-- Helper function to check if a name should be excluded
local function isExcluded(name, excludeTags)
    if not excludeTags or excludeTags == "" or not name then return false end
    
    -- Split tags by spaces and check each one
    for tag in string.gmatch(excludeTags, "%S+") do
        if name:sub(1, #tag) == tag then
            return true
        end
    end
    return false
end

-- Initialize
Settings.load()

-- If Folder Items tab is hidden, default to All tab
if Settings.getFolderItemUser() == false and state.currentTab == "Folder Items" then
    state.currentTab = "All"
end

-- Load folder items settings if they exist
if Settings.current.folderItems then
    state.folderItemPattern = Settings.current.folderItems.pattern or state.folderItemPattern
    state.folderItemSeparator = Settings.current.folderItems.separator or state.folderItemSeparator
    state.folderItemCustomPattern = Settings.current.folderItems.customPattern or state.folderItemCustomPattern
    state.folderItemIncrementMode = Settings.current.folderItems.incrementMode or state.folderItemIncrementMode
    -- Load exclude tags from settings (handle both old and new format)
    state.excludeTags = Settings.current.excludeTags or Settings.current.folderItems and Settings.current.folderItems.excludeTag or state.excludeTags
    -- Load space replacement setting
    state.spaceReplacement = Settings.current.spaceReplacement or state.spaceReplacement
end

-- Load global view preference (boolean: use ~= nil so a stored false is honored)
if Settings.current.jumpToPosition ~= nil then
    state.jumpToPosition = Settings.current.jumpToPosition
end

-- Restore last used preset on startup
if Settings.current.lastPreset then
    local preset = Presets.load(Settings.current.lastPreset)
    if preset then
        for k, v in pairs(preset) do
            state[k] = v
        end
        state.selectedPreset = Settings.current.lastPreset
        state.needsPreview = true
        -- Re-apply folder items settings from Settings (take precedence over preset
        -- so that Settings UI changes are not silently overwritten by preset values)
        if Settings.current.folderItems then
            state.folderItemPattern = Settings.current.folderItems.pattern or state.folderItemPattern
            state.folderItemSeparator = Settings.current.folderItems.separator or state.folderItemSeparator
            state.folderItemCustomPattern = Settings.current.folderItems.customPattern or state.folderItemCustomPattern
            state.folderItemIncrementMode = Settings.current.folderItems.incrementMode or state.folderItemIncrementMode
            state.excludeTags = Settings.current.excludeTags or Settings.current.folderItems.excludeTag or state.excludeTags
            state.spaceReplacement = Settings.current.spaceReplacement or state.spaceReplacement
        end
        -- Re-apply global view pref so an (old) preset can't override the Settings value
        if Settings.current.jumpToPosition ~= nil then
            state.jumpToPosition = Settings.current.jumpToPosition
        end
    else
        -- Preset no longer exists, clear the reference
        Settings.current.lastPreset = nil
        Settings.save()
    end
end

-- Function to save folder items settings
local function saveFolderItemsSettings()
    if not Settings.current.folderItems then
        Settings.current.folderItems = {}
    end
    Settings.current.folderItems.pattern = state.folderItemPattern
    Settings.current.folderItems.separator = state.folderItemSeparator
    Settings.current.folderItems.customPattern = state.folderItemCustomPattern
    Settings.current.folderItems.incrementMode = state.folderItemIncrementMode
    Settings.save()
end

-- Refresh current list
local function refreshCurrentList()
    
    -- Detect if there's a selection
    local hasSelection = false
    if state.currentTab == "Media Items" or state.currentTab == "Folder Items" then
        -- Check for item selection first, then time selection
        local selectedItems = reaper.CountSelectedMediaItems(0)
        local start_time, end_time = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
        hasSelection = selectedItems > 0 or (end_time - start_time) > 0
    elseif state.currentTab == "Tracks" then
        hasSelection = reaper.CountSelectedTracks(0) > 0
    elseif state.currentTab == "Regions" or state.currentTab == "Markers" then
        -- Check for time selection first
        local start_time, end_time = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
        hasSelection = (end_time - start_time) > 0
        
        -- Also check for ExtState selection
        if not hasSelection then
            if state.currentTab == "Regions" then
                local regionSelection = reaper.GetExtState("DM_RENAMER", "SelectedRegions") or ""
                hasSelection = regionSelection ~= ""
            else
                local markerSelection = reaper.GetExtState("DM_RENAMER", "SelectedMarkers") or ""
                hasSelection = markerSelection ~= ""
            end
        end
    elseif state.currentTab == "All" then
        -- Check any type of selection (items, tracks, or time selection)
        local start_time, end_time = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
        hasSelection = reaper.CountSelectedMediaItems(0) > 0 or
                      reaper.CountSelectedTracks(0) > 0 or
                      (end_time - start_time) > 0
    end
    
    state.useSelectedOnly = hasSelection
    
    local module = nil
    if state.currentTab == "Media Items" then
        module = Items
    elseif state.currentTab == "Regions" then
        module = Regions
    elseif state.currentTab == "Markers" then
        module = Markers
    elseif state.currentTab == "Tracks" then
        module = Tracks
    elseif state.currentTab == "Folder Items" then
        module = FolderItems
    elseif state.currentTab == "All" then
        module = All
    end
    
    if module then
        local ok, result = pcall(function()
            -- Set options for Folder Items module before getting list
            if state.currentTab == "Folder Items" and module.setOptions then
                module.setOptions({
                    excludeTag = state.excludeTags
                })
            end
            
            if module.getListWithSelection then
                state.currentList = module.getListWithSelection(state.useSelectedOnly, state.excludeTags)
            else
                state.currentList = module.getList(state.excludeTags)
            end
        end)
        if ok then
        else
            state.currentList = {}
        end
    end
    state.needsRefresh = false
    state.needsPreview = true  -- Always trigger preview after refresh
end

-- Auto-select all items in list
local function autoSelectAll()
    if state.selectAllByDefault then
        for _, item in ipairs(state.currentList) do
            item.checked = true
        end
    end
end

-- Check if project state has changed (tracks, items, regions, markers, time selection)
local function hasProjectStateChanged()
    local changed = false
    
    -- Check track count
    local trackCount = reaper.CountTracks(0)
    if trackCount ~= state.lastTrackCount then
        changed = true
        state.lastTrackCount = trackCount
    end
    
    -- Check item count
    local itemCount = reaper.CountMediaItems(0)
    if itemCount ~= state.lastItemCount then
        changed = true
        state.lastItemCount = itemCount
    end
    
    -- Check region/marker count AND names
    local retval, num_markers, num_regions = reaper.CountProjectMarkers(0)
    if num_markers ~= state.lastMarkerCount or num_regions ~= state.lastRegionCount then
        changed = true
        state.lastMarkerCount = num_markers
        state.lastRegionCount = num_regions
    end
    
    -- Check for region/marker changes: name, position, or size (important for Folder Items)
    local currentRegionNames = {}
    local currentMarkerNames = {}

    for i = 0, num_markers + num_regions - 1 do
        local _, isRegion, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers3(0, i)

        if isRegion then
            local key = tostring(markrgnindexnumber)
            local value = name .. "|" .. string.format("%.4f", pos) .. "|" .. string.format("%.4f", rgnend)
            currentRegionNames[key] = value
            -- Check if name, position, or size changed
            if state.lastRegionNames[key] and state.lastRegionNames[key] ~= value then
                changed = true
            end
        else
            local key = tostring(markrgnindexnumber)
            local value = name .. "|" .. string.format("%.4f", pos)
            currentMarkerNames[key] = value
            -- Check if name or position changed
            if state.lastMarkerNames[key] and state.lastMarkerNames[key] ~= value then
                changed = true
            end
        end
    end

    -- Update caches
    state.lastRegionNames = currentRegionNames
    state.lastMarkerNames = currentMarkerNames
    
    -- Check time selection
    local startTime, endTime = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    if startTime ~= state.lastTimeSelStart or endTime ~= state.lastTimeSelEnd then
        changed = true
        state.lastTimeSelStart = startTime
        state.lastTimeSelEnd = endTime
    end
    
    -- Check track names (for all tabs, especially important for Folder Items)
    local currentTrackNames = {}
    for i = 0, trackCount - 1 do
        local track = reaper.GetTrack(0, i)
        local _, trackName = reaper.GetTrackName(track)
        local trackKey = tostring(track)
        currentTrackNames[trackKey] = trackName
        
        if state.lastTrackNames[trackKey] and state.lastTrackNames[trackKey] ~= trackName then
            changed = true
        end
    end
    state.lastTrackNames = currentTrackNames
    
    -- Force refresh for Folder Items tab if any project change detected
    if state.currentTab == "Folder Items" and changed then
        return true
    end
    
    return changed
end

-- Check if selection has changed
local function hasSelectionChanged()
    local changed = false
    
    if state.currentTab == "Media Items" then
        -- Build current selection set
        local currentItems = {}
        local itemCount = reaper.CountSelectedMediaItems(0)
        for i = 0, itemCount - 1 do
            local item = reaper.GetSelectedMediaItem(0, i)
            currentItems[tostring(item)] = true  -- Use string key for pointer
        end
        
        -- Check if selection count changed
        if itemCount ~= state.lastItemSelCount then
            changed = true
            state.lastItemSelCount = itemCount
        else
            -- Count same, check if items changed
            for itemPtr in pairs(state.lastSelectedItemPointers) do
                if not currentItems[itemPtr] then
                    changed = true
                    break
                end
            end
            if not changed then
                for itemPtr in pairs(currentItems) do
                    if not state.lastSelectedItemPointers[itemPtr] then
                        changed = true
                        break
                    end
                end
            end
        end
        
        state.lastSelectedItemPointers = currentItems
        
    elseif state.currentTab == "Tracks" then
        -- Build current selection set
        local currentTracks = {}
        local trackCount = reaper.CountSelectedTracks(0)
        for i = 0, trackCount - 1 do
            local track = reaper.GetSelectedTrack(0, i)
            currentTracks[tostring(track)] = true  -- Use string key for pointer
        end
        
        -- Check if selection count changed
        if trackCount ~= state.lastTrackSelCount then
            changed = true
            state.lastTrackSelCount = trackCount
        else
            -- Count same, check if tracks changed
            for trackPtr in pairs(state.lastSelectedTrackPointers) do
                if not currentTracks[trackPtr] then
                    changed = true
                    break
                end
            end
            if not changed then
                for trackPtr in pairs(currentTracks) do
                    if not state.lastSelectedTrackPointers[trackPtr] then
                        changed = true
                        break
                    end
                end
            end
        end
        
        state.lastSelectedTrackPointers = currentTracks
        
    elseif state.currentTab == "Folder Items" then
        -- Special handling for folder items
        local currentSelection = {}
        local FolderItems = dofile(script_path .. "Modules/DM_RENAMER_FolderItems.lua")
        
        for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
            local item = reaper.GetSelectedMediaItem(0, i)
            if FolderItems.isEmptyItem(item) then
                currentSelection[tostring(item)] = true
            end
        end
        
        -- Compare selections
        for itemPtr in pairs(state.lastFolderItemSelection) do
            if not currentSelection[itemPtr] then
                changed = true
                break
            end
        end
        if not changed then
            for itemPtr in pairs(currentSelection) do
                if not state.lastFolderItemSelection[itemPtr] then
                    changed = true
                    break
                end
            end
        end
        
        state.lastFolderItemSelection = currentSelection
        
    elseif state.currentTab == "Regions" then
        -- Check ExtState for region selection changes
        local currentSelection = reaper.GetExtState("DM_RENAMER", "SelectedRegions") or ""
        if currentSelection ~= state.lastRegionSelectionString then
            changed = true
            state.lastRegionSelectionString = currentSelection
        end
        
        -- Also check time selection
        local start_time, end_time = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
        if start_time ~= state.lastTimeSelStart or end_time ~= state.lastTimeSelEnd then
            state.lastTimeSelStart = start_time
            state.lastTimeSelEnd = end_time
            changed = true
        end
    elseif state.currentTab == "Markers" then
        -- Check ExtState for marker selection changes
        local currentSelection = reaper.GetExtState("DM_RENAMER", "SelectedMarkers") or ""
        if currentSelection ~= state.lastMarkerSelectionString then
            changed = true
            state.lastMarkerSelectionString = currentSelection
        end
        
        -- Also check time selection
        local start_time, end_time = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
        if start_time ~= state.lastTimeSelStart or end_time ~= state.lastTimeSelEnd then
            state.lastTimeSelStart = start_time
            state.lastTimeSelEnd = end_time
            changed = true
        end
    end
    
    return changed
end

-- Update preview
local function updatePreview()
    
    local module = nil
    if state.currentTab == "Media Items" then
        module = Items
    elseif state.currentTab == "Regions" then
        module = Regions
    elseif state.currentTab == "Markers" then
        module = Markers
    elseif state.currentTab == "Tracks" then
        module = Tracks
    elseif state.currentTab == "Folder Items" then
        module = FolderItems
    elseif state.currentTab == "All" then
        module = All
    end
    
    if module and module.updatePreview then
        local ok, err = pcall(function()
            -- Special handling for Folder Items
            if state.currentTab == "Folder Items" then
                module.updatePreview(state.currentList, state.folderItemPattern, {
                    separator = state.folderItemSeparator,
                    customPattern = state.folderItemCustomPattern,
                    incrementMode = state.folderItemIncrementMode,
                    incrementPadding = state.incrementPadding,
                    excludeTag = state.excludeTags,
                    -- Add all transformation options for full pattern system
                    operation = state.operation,
                    findText = state.findText,
                    replaceText = state.replaceText,
                    caseSensitive = state.caseSensitive,
                    wholeWord = state.wholeWord,
                    useLuaPatterns = state.useLuaPatterns,
                    transformCase = state.transformCase,
                    prefix = state.prefix,
                    suffix = state.suffix,
                    removeFromStart = state.removeFromStart,
                    removeFromEnd = state.removeFromEnd,
                    spaceReplacement = state.spaceReplacement
                })
            elseif state.currentTab == "All" then
                -- Pass all options for All tab
                module.updatePreview(state.currentList, state.findText, state.replaceText, {
                    operation = state.operation,
                    caseSensitive = state.caseSensitive,
                    wholeWord = state.wholeWord,
                    useLuaPatterns = state.useLuaPatterns,
                    transformCase = state.transformCase,
                    useTemplate = state.useTemplate,
                    templateString = state.templateString,
                    prefix = state.prefix,
                    suffix = state.suffix,
                    removeFromStart = state.removeFromStart,
                    removeFromEnd = state.removeFromEnd,
                    addNumbering = state.addNumbering,
                    startNumber = state.startNumber,
                    increment = state.increment,
                    padding = state.padding,
                    numberPosition = state.numberPosition,
                    numberSeparator = state.numberSeparator,
                    maxLength = state.maxLength,
                    addEllipsis = state.addEllipsis,
                    incrementMode = state.incrementMode,
                    incrementPadding = state.incrementPadding,
                    -- Folder items options
                    folderItemPattern = state.folderItemPattern,
                    separator = state.folderItemSeparator,
                    customPattern = state.folderItemCustomPattern,
                    folderItemIncrementMode = state.folderItemIncrementMode,
                    excludeTag = state.excludeTags,
                    spaceReplacement = state.spaceReplacement
                })
            else
                -- Pass options to updatePreview for other tabs
                module.updatePreview(state.currentList, state.findText, state.replaceText, {
                    operation = state.operation,  -- Pass operation type
                    caseSensitive = state.caseSensitive,
                    wholeWord = state.wholeWord,
                    useLuaPatterns = state.useLuaPatterns,  -- Pass Lua patterns flag
                    transformCase = state.transformCase,  -- Pass case transformation
                    -- Template and advanced options
                    useTemplate = state.useTemplate,
                    templateString = state.templateString,
                    prefix = state.prefix,
                    suffix = state.suffix,
                    removeFromStart = state.removeFromStart,
                    removeFromEnd = state.removeFromEnd,
                    addNumbering = state.addNumbering,
                    startNumber = state.startNumber,
                    increment = state.increment,
                    padding = state.padding,
                    numberPosition = state.numberPosition,
                    numberSeparator = state.numberSeparator,
                    maxLength = state.maxLength,
                    addEllipsis = state.addEllipsis,
                    incrementMode = state.incrementMode,
                    incrementPadding = state.incrementPadding,
                    spaceReplacement = state.spaceReplacement
                })
            end
        end)
    end
    state.needsPreview = false
    
    -- Auto-check items with changes
    if state.autoSelectChanged ~= false then  -- Default to true
        local changedCount = 0
        for _, item in ipairs(state.currentList) do
            if item.changed then
                item.checked = true
                changedCount = changedCount + 1
            end
        end
    end
end

-- Apply changes
local function applyChanges()
    
    -- Count selected and changed items
    local selectedCount = 0
    local changedCount = 0
    for _, item in ipairs(state.currentList) do
        if item.checked then
            selectedCount = selectedCount + 1
        end
        if item.changed then
            changedCount = changedCount + 1
        end
    end
    
    if selectedCount == 0 then
        return
    end
    
    local module = nil
    if state.currentTab == "Media Items" then
        module = Items
    elseif state.currentTab == "Regions" then
        module = Regions
    elseif state.currentTab == "Markers" then
        module = Markers
    elseif state.currentTab == "Tracks" then
        module = Tracks
    elseif state.currentTab == "Folder Items" then
        module = FolderItems
    elseif state.currentTab == "All" then
        module = All
    end
    
    if module and module.applyChanges then
        local ok, err = pcall(function()
            module.applyChanges(state.currentList)
        end)
        if ok then
            -- For Folder Items, don't refresh the entire list (it would lose the changes)
            if state.currentTab == "Folder Items" then
                -- Just clear the preview since changes are applied
                for _, item in ipairs(state.currentList) do
                    if item.checked and item.changed then
                        item.checked = false  -- Uncheck applied items
                    end
                end
                state.needsPreview = true  -- Regenerate preview
            else
                state.needsRefresh = true
            end
        end
    end
end

-- Apply direct edit to a single item
local function applyDirectEdit(index, newName)
    local item = state.currentList[index]
    if not item then return end
    
    -- Get the appropriate module
    local module = nil
    if state.currentTab == "Media Items" then
        module = Items
    elseif state.currentTab == "Regions" then
        module = Regions
    elseif state.currentTab == "Markers" then
        module = Markers
    elseif state.currentTab == "Tracks" then
        module = Tracks
    elseif state.currentTab == "Folder Items" then
        module = FolderItems
    elseif state.currentTab == "All" then
        module = All
    end
    
    if module and module.applyChanges then
        -- Create a temporary list with just this one item
        local tempList = {item}
        item.preview = newName
        if state.currentTab == "Folder Items" then
            item.changed = (item.notes ~= newName) or (item.name ~= newName)
        else
            item.changed = (item.name ~= newName)
        end
        item.checked = true
        
        -- Apply the change
        local ok, err = pcall(function()
            module.applyChanges(tempList)
        end)
        
        if ok then
            -- Refresh the list to show the change
            state.needsRefresh = true
        end
    end
end

-- Jump to selected item position
local function jumpToItemPosition(index)
    if not state.jumpToPosition then return end
    
    local item = state.currentList[index]
    if not item then return end
    
    local position = nil
    
    if state.currentTab == "Media Items" or state.currentTab == "Folder Items" then
        position = item.position
    elseif state.currentTab == "Regions" then
        position = item.startPos
    elseif state.currentTab == "Markers" then
        position = item.position
    elseif state.currentTab == "All" then
        -- Handle different types in All tab
        if item.type == "Media Item" or item.type == "Folder Item" then
            position = item.position
        elseif item.type == "Region" then
            position = item.startPos
        elseif item.type == "Marker" then
            position = item.position
        elseif item.type == "Track" then
            -- Tracks don't have position
            return
        end
    elseif state.currentTab == "Tracks" then
        -- Tracks don't have position
        return
    end
    
    if position then
        -- Move edit cursor to position
        reaper.SetEditCurPos(position, true, true)  -- moveview=true, seekplay=true
    end
end

-- Pattern help window
local function drawPatternHelpWindow()
    if not state.showPatternHelp then return end
    
    local flags = reaper.ImGui_WindowFlags_None()
    reaper.ImGui_SetNextWindowSize(ctx, 600, 400, reaper.ImGui_Cond_FirstUseEver())
    
    local visible, open = reaper.ImGui_Begin(ctx, "Lua Pattern Reference", true, flags)
    if visible then
        -- Tabs for different sections
        if reaper.ImGui_BeginTabBar(ctx, "PatternTabs") then
            -- Character Classes tab
            if reaper.ImGui_BeginTabItem(ctx, "Character Classes") then
                reaper.ImGui_Text(ctx, "BASIC PATTERNS:")
                reaper.ImGui_BulletText(ctx, ". - any character except newline")
                reaper.ImGui_BulletText(ctx, "%a - letter")
                reaper.ImGui_BulletText(ctx, "%d - digit")
                reaper.ImGui_BulletText(ctx, "%s - space character")
                reaper.ImGui_BulletText(ctx, "%w - alphanumeric")
                reaper.ImGui_BulletText(ctx, "%p - punctuation")
                reaper.ImGui_BulletText(ctx, "%c - control character")
                reaper.ImGui_BulletText(ctx, "%x - hexadecimal digit")
                reaper.ImGui_Separator(ctx)
                reaper.ImGui_Text(ctx, "UPPERCASE = OPPOSITE:")
                reaper.ImGui_BulletText(ctx, "%A - non-letter")
                reaper.ImGui_BulletText(ctx, "%D - non-digit")
                reaper.ImGui_BulletText(ctx, "%S - non-space")
                reaper.ImGui_BulletText(ctx, "%W - non-alphanumeric")
                reaper.ImGui_Separator(ctx)
                reaper.ImGui_Text(ctx, "SPECIAL CHARACTERS:")
                reaper.ImGui_BulletText(ctx, "%% - literal %")
                reaper.ImGui_BulletText(ctx, "%[ - literal [")
                reaper.ImGui_BulletText(ctx, "%] - literal ]")
                reaper.ImGui_BulletText(ctx, "%. - literal .")
                reaper.ImGui_EndTabItem(ctx)
            end
            
            -- Quantifiers tab
            if reaper.ImGui_BeginTabItem(ctx, "Quantifiers") then
                reaper.ImGui_Text(ctx, "REPETITION:")
                reaper.ImGui_BulletText(ctx, "* - 0 or more (greedy)")
                reaper.ImGui_BulletText(ctx, "+ - 1 or more (greedy)")
                reaper.ImGui_BulletText(ctx, "- - 0 or more (lazy)")
                reaper.ImGui_BulletText(ctx, "? - 0 or 1")
                reaper.ImGui_Separator(ctx)
                reaper.ImGui_Text(ctx, "EXAMPLES:")
                reaper.ImGui_BulletText(ctx, "%d+ - one or more digits")
                reaper.ImGui_BulletText(ctx, "%s* - zero or more spaces")
                reaper.ImGui_BulletText(ctx, ".* - any characters (greedy)")
                reaper.ImGui_BulletText(ctx, ".- - any characters (lazy)")
                reaper.ImGui_BulletText(ctx, "%a+%d* - letters followed by optional digits")
                reaper.ImGui_Separator(ctx)
                reaper.ImGui_Text(ctx, "ANCHORS:")
                reaper.ImGui_BulletText(ctx, "^ - start of string")
                reaper.ImGui_BulletText(ctx, "$ - end of string")
                reaper.ImGui_BulletText(ctx, "%f[set] - frontier pattern")
                reaper.ImGui_EndTabItem(ctx)
            end
            
            -- Captures tab
            if reaper.ImGui_BeginTabItem(ctx, "Captures") then
                reaper.ImGui_Text(ctx, "CAPTURING:")
                reaper.ImGui_BulletText(ctx, "() - capture group")
                reaper.ImGui_BulletText(ctx, "%1 to %9 - back references in replacement")
                reaper.ImGui_BulletText(ctx, "%0 - entire match")
                reaper.ImGui_Separator(ctx)
                reaper.ImGui_Text(ctx, "EXAMPLES:")
                reaper.ImGui_Text(ctx, "Find: (\\w+)_(\\d+)")
                reaper.ImGui_Text(ctx, "Replace: %2_%1")
                reaper.ImGui_TextColored(ctx, 0x00FF00FF, "Effect: Swaps name and number")
                reaper.ImGui_Separator(ctx)
                reaper.ImGui_Text(ctx, "Find: ^(.-)%s*$")
                reaper.ImGui_Text(ctx, "Replace: %1")
                reaper.ImGui_TextColored(ctx, 0x00FF00FF, "Effect: Trims trailing spaces")
                reaper.ImGui_Separator(ctx)
                reaper.ImGui_Text(ctx, "Find: (%w)(.*)")
                reaper.ImGui_Text(ctx, "Replace: %1:upper()..%2")
                reaper.ImGui_TextColored(ctx, 0x00FF00FF, "Effect: Capitalizes first letter")
                reaper.ImGui_EndTabItem(ctx)
            end
            
            -- Practical Examples tab
            if reaper.ImGui_BeginTabItem(ctx, "Examples") then
                reaper.ImGui_Text(ctx, "COMMON PATTERNS:")
                
                local examples = {
                    {"Remove numbers", "%d+", ""},
                    {"Keep numbers only", "%D+", ""},
                    {"Trim spaces", "^%s*(.-)%s*$", "%1"},
                    {"Remove extension", "(.+)%.%w+$", "%1"},
                    {"Extract [brackets]", "%[(.-)%]", "%1"},
                    {"Extract (parens)", "%((.-)%)", "%1"},
                    {"Swap parts", "(%w+)_(%w+)", "%2_%1"},
                    {"Clean spaces", "%s+", " "},
                    {"Add quotes", "^(.+)$", "\"%1\""},
                    {"Number prefix", "^", "%d%d_"},
                    {"Remove prefix", "^%d+_", ""},
                    {"CamelCase split", "(%u)", " %1"}
                }
                
                -- Create table
                if reaper.ImGui_BeginTable(ctx, "ExamplesTable", 3, reaper.ImGui_TableFlags_Borders()) then
                    reaper.ImGui_TableSetupColumn(ctx, "Purpose", reaper.ImGui_TableColumnFlags_WidthFixed(), 150)
                    reaper.ImGui_TableSetupColumn(ctx, "Find Pattern", reaper.ImGui_TableColumnFlags_WidthFixed(), 200)
                    reaper.ImGui_TableSetupColumn(ctx, "Replace", reaper.ImGui_TableColumnFlags_WidthFixed(), 150)
                    reaper.ImGui_TableHeadersRow(ctx)
                    
                    for _, ex in ipairs(examples) do
                        reaper.ImGui_TableNextRow(ctx)
                        reaper.ImGui_TableSetColumnIndex(ctx, 0)
                        reaper.ImGui_Text(ctx, ex[1])
                        reaper.ImGui_TableSetColumnIndex(ctx, 1)
                        reaper.ImGui_TextColored(ctx, 0x00FF00FF, ex[2])
                        reaper.ImGui_TableSetColumnIndex(ctx, 2)
                        reaper.ImGui_TextColored(ctx, 0x00FFFFFF, ex[3])
                    end
                    
                    reaper.ImGui_EndTable(ctx)
                end
                reaper.ImGui_EndTabItem(ctx)
            end
            
            reaper.ImGui_EndTabBar(ctx)
        end
    end
    reaper.ImGui_End(ctx)
    
    if not open then
        state.showPatternHelp = false
    end
end

-- Track region/marker selection continuously using SWS
local function trackRegionMarkerSelection()
    -- Only track if we have the necessary extensions
    if not reaper.APIExists("BR_GetMouseCursorContext") then
        return
    end
    
    -- Check if mouse was clicked
    local mouseState = reaper.JS_Mouse_GetState and reaper.JS_Mouse_GetState(1) or 0
    if mouseState == 1 then
        local window, segment, details = reaper.BR_GetMouseCursorContext()
        
        if window == "timeline" and (segment == "region_lane" or details and details:match("marker")) then
            -- Get position under mouse
            local x = reaper.BR_GetMouseCursorContext_Position and reaper.BR_GetMouseCursorContext_Position() or reaper.GetCursorPosition()
            local markeridx, regionidx = reaper.GetLastMarkerAndCurRegion(0, x)
            
            -- Check if Shift is held for multi-selection
            local shiftState = reaper.JS_Mouse_GetState and reaper.JS_Mouse_GetState(0x0004) > 0 or false
            
            if regionidx >= 0 and (state.currentTab == "Regions" or state.currentTab == "All") then
                -- Handle region selection
                local current = reaper.GetExtState("DM_RENAMER", "SelectedRegions") or ""
                
                if shiftState and current ~= "" then
                    -- Multi-selection: add to existing selection
                    local found = false
                    for index in string.gmatch(current, "([^,]+)") do
                        if tonumber(index) == regionidx then
                            found = true
                            break
                        end
                    end
                    if not found then
                        current = current .. "," .. tostring(regionidx)
                    end
                else
                    -- Single selection
                    current = tostring(regionidx)
                end
                
                reaper.SetExtState("DM_RENAMER", "SelectedRegions", current, false)
            elseif markeridx >= 0 and (state.currentTab == "Markers" or state.currentTab == "All") then
                -- Handle marker selection
                local current = reaper.GetExtState("DM_RENAMER", "SelectedMarkers") or ""
                
                if shiftState and current ~= "" then
                    -- Multi-selection: add to existing selection
                    local found = false
                    for index in string.gmatch(current, "([^,]+)") do
                        if tonumber(index) == markeridx then
                            found = true
                            break
                        end
                    end
                    if not found then
                        current = current .. "," .. tostring(markeridx)
                    end
                else
                    -- Single selection
                    current = tostring(markeridx)
                end
                
                reaper.SetExtState("DM_RENAMER", "SelectedMarkers", current, false)
            end
        elseif window == "timeline" and mouseState == 1 and not shiftState then
            -- Click outside regions/markers - clear selection
            if state.currentTab == "Regions" then
                reaper.SetExtState("DM_RENAMER", "SelectedRegions", "", false)
            elseif state.currentTab == "Markers" then
                reaper.SetExtState("DM_RENAMER", "SelectedMarkers", "", false)
            end
        end
    end
end

-- Main loop
local function loop()
    -- Track region/marker selection before ImGui processing
    trackRegionMarkerSelection()
    
    -- Apply appearance settings
    local appearance = Settings.getAppearanceSettings()
    
    -- Apply colors with dynamic shades
    local dynamicHoverColor = Settings.getHoverColor(appearance.buttonColor)
    local dynamicHighlightColor = Settings.getHighlightColor(appearance.buttonColor)
    local dynamicSelectionColor = Settings.getSelectionColor(appearance.buttonColor)
    
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), appearance.backgroundColor)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), appearance.frameColor)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), appearance.buttonColor)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), dynamicHoverColor)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), dynamicHighlightColor)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), appearance.textColor)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), dynamicSelectionColor)  -- Use subtle button color tint for selections
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(), dynamicHoverColor)  -- Use hover color for better readability
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(), dynamicHighlightColor)
    
    -- Apply button color to tabs (check if constants exist first)
    local extraColorsPushed = 0
    
    -- Tab colors - try new constants first, fall back to old ones if needed
    if reaper.ImGui_Col_Tab then
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Tab(), appearance.buttonColor)
        extraColorsPushed = extraColorsPushed + 1
    end
    if reaper.ImGui_Col_TabHovered then
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabHovered(), dynamicHoverColor)
        extraColorsPushed = extraColorsPushed + 1
    end
    -- Try TabSelected (new) or TabActive (old)
    if reaper.ImGui_Col_TabSelected then
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabSelected(), dynamicHighlightColor)
        extraColorsPushed = extraColorsPushed + 1
    elseif reaper.ImGui_Col_TabActive then
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabActive(), dynamicHighlightColor)
        extraColorsPushed = extraColorsPushed + 1
    end
    -- Try TabDimmed (new) or TabUnfocused (old)
    if reaper.ImGui_Col_TabDimmed then
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabDimmed(), appearance.buttonColor)
        extraColorsPushed = extraColorsPushed + 1
    elseif reaper.ImGui_Col_TabUnfocused then
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabUnfocused(), appearance.buttonColor)
        extraColorsPushed = extraColorsPushed + 1
    end
    -- Try TabDimmedSelected (new) or TabUnfocusedActive (old)
    if reaper.ImGui_Col_TabDimmedSelected then
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabDimmedSelected(), appearance.buttonColor)
        extraColorsPushed = extraColorsPushed + 1
    elseif reaper.ImGui_Col_TabUnfocusedActive then
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabUnfocusedActive(), appearance.buttonColor)
        extraColorsPushed = extraColorsPushed + 1
    end
    
    -- Apply button color to slider knobs (check if constants exist)
    if reaper.ImGui_Col_SliderGrab then
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrab(), appearance.buttonColor)
        extraColorsPushed = extraColorsPushed + 1
    end
    if reaper.ImGui_Col_SliderGrabActive then
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrabActive(), dynamicHighlightColor)
        extraColorsPushed = extraColorsPushed + 1
    end
    
    -- Apply button color to checkboxes (check if constant exists)
    if reaper.ImGui_Col_CheckMark then
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_CheckMark(), appearance.buttonColor)
        extraColorsPushed = extraColorsPushed + 1
    end
    
    -- Store the count for later PopStyleColor
    state.extraColorsPushed = extraColorsPushed
    
    -- Apply style variables
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), appearance.uiRounding)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), appearance.frameRounding)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), appearance.itemSpacing, appearance.itemSpacing)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), appearance.windowPadding, appearance.windowPadding)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_GrabRounding(), appearance.uiRounding)  -- Apply rounding to slider knobs
    
    local visible, open = reaper.ImGui_Begin(ctx, 'DM RENAMER', true)
    
    if visible then
        -- Note: UI scaling through font is not directly available in ReaImGui
        -- Scale factor is stored but not applied visually at this time
        -- TODO: Implement manual UI element scaling or wait for API support
        
        -- Check for keyboard shortcuts
        if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftCtrl()) or
           reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_RightCtrl()) then
            if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Comma()) then
                state.showSettingsWindow = true
            end
        end

        -- ESC key: close window only when no input field is active
        -- (ImGui natively handles ESC to cancel active InputText widgets)
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
            if not reaper.ImGui_IsAnyItemActive(ctx) then
                -- Also clear inline editing state if somehow still set
                if state.editingIndex then
                    state.editingIndex = nil
                    state.editingText = ""
                    state.editingColumn = nil
                else
                    open = false  -- Close the window
                end
            end
        end
        
        -- Draw pattern help window if open
        drawPatternHelpWindow()
        
        -- Handle Settings window if open
        if state.showSettingsWindow then
            state.showSettingsWindow = SettingsUI.showSettingsWindow(state.showSettingsWindow)
        end

        -- Sync exclude tags and space replacement from Settings to state
        -- (must be outside Settings window check to catch changes after window closes)
        local settingsExclude = Settings.current.excludeTags or ""
        if settingsExclude ~= state.excludeTags then
            state.excludeTags = settingsExclude
            state.needsRefresh = true
            state.needsPreview = true
        end
        local settingsSpaceReplace = Settings.current.spaceReplacement or ""
        if settingsSpaceReplace ~= state.spaceReplacement then
            state.spaceReplacement = settingsSpaceReplace
            state.needsPreview = true
        end
        
        -- Menu bar
        if reaper.ImGui_BeginMenuBar(ctx) then
            if reaper.ImGui_BeginMenu(ctx, "File") then
                if reaper.ImGui_MenuItem(ctx, "Exit") then
                    open = false
                end
                reaper.ImGui_EndMenu(ctx)
            end
            
            if reaper.ImGui_BeginMenu(ctx, "Settings") then
                if reaper.ImGui_MenuItem(ctx, "Appearance Settings...", "Ctrl+,") then
                    state.showSettingsWindow = true
                end
                -- Checkable item rendered via the label (works across all ReaImGui versions)
                local jumpLabel = (state.jumpToPosition and "[x]" or "[  ]") .. " Jump to position on select"
                if reaper.ImGui_MenuItem(ctx, jumpLabel) then
                    state.jumpToPosition = not state.jumpToPosition
                    Settings.current.jumpToPosition = state.jumpToPosition
                    Settings.save()
                end
                reaper.ImGui_Separator(ctx)
                if reaper.ImGui_MenuItem(ctx, "Reset to Defaults") then
                    -- Reset appearance to defaults
                    local defaultButtonColor = 0x15856DFF
                    local defaults = {
                        buttonColor = defaultButtonColor,
                        buttonHoverColor = Settings.getHoverColor(defaultButtonColor),
                        backgroundColor = 0x2E2E2EFF,
                        frameColor = 0x3A3A3AFF,
                        textColor = 0xD5D5D5FF,
                        highlightColor = Settings.getHighlightColor(defaultButtonColor),
                        headerColor = 0x454545FF,
                        uiRounding = 3.0,
                        frameRounding = 4.0,
                        itemSpacing = 4.0,
                        windowPadding = 10.0,
                        uiScale = 1.0,
                        fontSize = 14
                    }
                    for k, v in pairs(defaults) do
                        Settings.setAppearanceOption(k, v)
                    end
                end
                reaper.ImGui_EndMenu(ctx)
            end
            
            reaper.ImGui_EndMenuBar(ctx)
        end
        
        -- PRESETS SECTION (Above tabs, available for all tabs)
        reaper.ImGui_Separator(ctx)

        local leftColumnWidth = 340

        -- Create a child window for presets to contain them properly
        if reaper.ImGui_BeginChild(ctx, "PresetSection", -1, 50, reaper.ImGui_WindowFlags_None()) then
            local labelWidth = 100
            local controlPosX = labelWidth + 10

            -- Load preset dropdown
            reaper.ImGui_Text(ctx, "Load Preset:")
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetCursorPosX(ctx, controlPosX)
            reaper.ImGui_SetNextItemWidth(ctx, leftColumnWidth - controlPosX - 15)

            local presetNames = Presets.list()
            table.insert(presetNames, 1, "-- None --")

            if reaper.ImGui_BeginCombo(ctx, "##LoadPreset", state.selectedPreset or "-- None --") then
                for _, name in ipairs(presetNames) do
                    if reaper.ImGui_Selectable(ctx, name, name == state.selectedPreset) then
                        if name ~= "-- None --" then
                            local preset = Presets.load(name)
                            if preset then
                                -- Apply preset to state
                                for k, v in pairs(preset) do
                                    state[k] = v
                                end
                                -- jumpToPosition is a global Settings pref, not a rename preset:
                                -- don't let an old preset (which may still carry the key) override it
                                if Settings.current.jumpToPosition ~= nil then
                                    state.jumpToPosition = Settings.current.jumpToPosition
                                end
                                state.selectedPreset = name
                                state.needsPreview = true
                                -- Save last used preset
                                Settings.current.lastPreset = name
                                Settings.save()
                            end
                        else
                            state.selectedPreset = nil
                            -- Reset all preset fields to defaults
                            state.findText = ""
                            state.replaceText = ""
                            state.prefix = ""
                            state.suffix = ""
                            state.removeFromStart = 0
                            state.removeFromEnd = 0
                            state.operation = "none"
                            state.transformCase = "none"
                            state.caseSensitive = false
                            state.wholeWord = false
                            state.useLuaPatterns = false
                            state.selectedPattern = nil
                            state.patternValid = true
                            state.patternError = ""
                            state.spaceReplacement = ""
                            state.folderItemPattern = "hierarchical"
                            state.needsPreview = true
                            -- Clear last used preset and sync settings
                            Settings.current.lastPreset = nil
                            Settings.current.spaceReplacement = state.spaceReplacement
                            Settings.save()
                        end
                    end
                end
                reaper.ImGui_EndCombo(ctx)
            end

            -- Save preset
            reaper.ImGui_Text(ctx, "Save as:")
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetCursorPosX(ctx, controlPosX)
            reaper.ImGui_SetNextItemWidth(ctx, leftColumnWidth - controlPosX - 60)
            local nameChanged, newName = reaper.ImGui_InputText(ctx, "##PresetName", state.presetName)
            if nameChanged then
                state.presetName = newName
            end

            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Save") then
                if state.presetName ~= "" then
                    if Presets.save(state.presetName, state) then
                        state.selectedPreset = state.presetName
                        state.presetName = ""
                    end
                end
            end

            -- Override preset button (only visible when a preset is selected)
            if state.selectedPreset and state.selectedPreset ~= "-- None --" then
                reaper.ImGui_SameLine(ctx)
                if reaper.ImGui_Button(ctx, "Override") then
                    if Presets.save(state.selectedPreset, state) then
                        -- Preset overridden successfully
                        -- Could add a notification here if needed
                    end
                end
                if reaper.ImGui_IsItemHovered(ctx) then
                    reaper.ImGui_BeginTooltip(ctx)
                    reaper.ImGui_Text(ctx, "Replace the selected preset with current settings")
                    reaper.ImGui_EndTooltip(ctx)
                end
            end

            -- Delete preset
            if state.selectedPreset and state.selectedPreset ~= "-- None --" then
                reaper.ImGui_SameLine(ctx)
                if reaper.ImGui_Button(ctx, "Delete") then
                    if Presets.delete(state.selectedPreset) then
                        state.selectedPreset = nil
                    end
                end
            end

            -- Center: DEMUTE logo (absolute positioned, centered in the child)
            local childW = reaper.ImGui_GetWindowWidth(ctx)
            local childH = 50
            local logoW, logoH = reaper.ImGui_Image_GetSize(icon_logo)
            local logoDisplayH = 26
            local logoDisplayW = logoW * (logoDisplayH / logoH)
            local logoCenterX = (leftColumnWidth + (childW - leftColumnWidth - 100)) / 2 - logoDisplayW / 2 + 50
            local logoCenterY = (childH - logoDisplayH) / 2

            reaper.ImGui_SetCursorPos(ctx, logoCenterX, logoCenterY)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x00000000)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x00000000)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0x00000000)
            if reaper.ImGui_ImageButton(ctx, "##LogoBtn", icon_logo, logoDisplayW, logoDisplayH) then
                reaper.CF_ShellExecute(URL_WEBSITE)
            end
            reaper.ImGui_PopStyleColor(ctx, 3)
            if reaper.ImGui_IsItemHovered(ctx) then
                reaper.ImGui_BeginTooltip(ctx)
                reaper.ImGui_Text(ctx, "Visit demute.studio")
                reaper.ImGui_EndTooltip(ctx)
            end

            -- Right: Settings button (absolute positioned, vertically centered)
            local settingsBtnText = "Settings \xE2\x9A\x99"
            local settingsBtnW = reaper.ImGui_CalcTextSize(ctx, settingsBtnText) + 16
            local btnH = reaper.ImGui_GetFrameHeight(ctx)
            local settingsX = childW - settingsBtnW - 10
            local settingsY = (childH - btnH) / 2

            reaper.ImGui_SetCursorPos(ctx, settingsX, settingsY)
            if reaper.ImGui_Button(ctx, "Settings ⚙") then
                state.showSettingsWindow = true
            end
            if reaper.ImGui_IsItemHovered(ctx) then
                reaper.ImGui_BeginTooltip(ctx)
                reaper.ImGui_Text(ctx, "Open appearance settings (Ctrl+,)")
                reaper.ImGui_EndTooltip(ctx)
            end
            
            reaper.ImGui_EndChild(ctx)
        end
        
        reaper.ImGui_Separator(ctx)
        
        -- Tabs (new order: Folder Items first, then All, then the rest)
        if reaper.ImGui_BeginTabBar(ctx, "MainTabs") then
            -- 1. Folder Items (first and default) - only show if not explicitly hidden
            if Settings.getFolderItemUser() ~= false then
                if reaper.ImGui_BeginTabItem(ctx, "Folder Items") then
                    if state.currentTab ~= "Folder Items" then
                        state.currentTab = "Folder Items"
                        state.needsRefresh = true
                        state.needsPreview = true
                        state.lastFolderItemSelection = {}  -- Reset selection tracking
                        -- Clear any region/marker selections
                        reaper.SetExtState("DM_RENAMER", "SelectedRegions", "", false)
                        reaper.SetExtState("DM_RENAMER", "SelectedMarkers", "", false)
                    end
                    reaper.ImGui_EndTabItem(ctx)
                end
            end

            -- 2. All (new tab)
            if reaper.ImGui_BeginTabItem(ctx, "All") then
                if state.currentTab ~= "All" then
                    state.currentTab = "All"
                    state.needsRefresh = true
                    state.needsPreview = true
                    -- Clear any region/marker selections when leaving specific tabs
                    reaper.SetExtState("DM_RENAMER", "SelectedRegions", "", false)
                    reaper.SetExtState("DM_RENAMER", "SelectedMarkers", "", false)
                end
                reaper.ImGui_EndTabItem(ctx)
            end

            -- 3. Media Items (renamed from Items)
            if reaper.ImGui_BeginTabItem(ctx, "Media Items") then
                if state.currentTab ~= "Media Items" then
                    state.currentTab = "Media Items"
                    state.needsRefresh = true
                    state.needsPreview = true
                    state.lastSelectedItemPointers = {}  -- Reset selection tracking
                    -- Clear any region/marker selections
                    reaper.SetExtState("DM_RENAMER", "SelectedRegions", "", false)
                    reaper.SetExtState("DM_RENAMER", "SelectedMarkers", "", false)
                end
                reaper.ImGui_EndTabItem(ctx)
            end

            -- 4. Regions
            if reaper.ImGui_BeginTabItem(ctx, "Regions") then
                if state.currentTab ~= "Regions" then
                    state.currentTab = "Regions"
                    state.needsRefresh = true
                    state.needsPreview = true
                    -- Clear any previous region/marker selections when switching tabs
                    reaper.SetExtState("DM_RENAMER", "SelectedRegions", "", false)
                    reaper.SetExtState("DM_RENAMER", "SelectedMarkers", "", false)
                end
                reaper.ImGui_EndTabItem(ctx)
            end

            -- 5. Markers
            if reaper.ImGui_BeginTabItem(ctx, "Markers") then
                if state.currentTab ~= "Markers" then
                    state.currentTab = "Markers"
                    state.needsRefresh = true
                    state.needsPreview = true
                    -- Clear any previous region/marker selections when switching tabs
                    reaper.SetExtState("DM_RENAMER", "SelectedRegions", "", false)
                    reaper.SetExtState("DM_RENAMER", "SelectedMarkers", "", false)
                end
                reaper.ImGui_EndTabItem(ctx)
            end

            -- 6. Tracks
            if reaper.ImGui_BeginTabItem(ctx, "Tracks") then
                if state.currentTab ~= "Tracks" then
                    state.currentTab = "Tracks"
                    state.needsRefresh = true
                    state.needsPreview = true
                    state.lastSelectedTrackPointers = {}  -- Reset selection tracking
                    -- Clear any region/marker selections
                    reaper.SetExtState("DM_RENAMER", "SelectedRegions", "", false)
                    reaper.SetExtState("DM_RENAMER", "SelectedMarkers", "", false)
                end
                reaper.ImGui_EndTabItem(ctx)
            end

            reaper.ImGui_EndTabBar(ctx)
        end
        
        -- Create 2-column layout
        local windowWidth = reaper.ImGui_GetContentRegionAvail(ctx)
        
        -- Check if we're showing folder item onboarding (used to skip controls/preview)
        local folderItemUser = Settings.getFolderItemUser()
        local showFolderItemOnboarding = (state.currentTab == "Folder Items" and folderItemUser == "undecided")

        -- LEFT COLUMN (Options)
        -- Adjust height to account for preset section above
        if reaper.ImGui_BeginChild(ctx, "LeftColumn", leftColumnWidth, -30, reaper.ImGui_WindowFlags_None()) then
            -- Define alignment constants
            local labelWidth = 100
            local controlPosX = labelWidth + 10

            
            -- FOLDER ITEMS SPECIFIC SECTION
            if state.currentTab == "Folder Items" then
                -- Onboarding gate: show intro message if user hasn't confirmed yet
                if folderItemUser == "undecided" then
                    reaper.ImGui_Spacing(ctx)
                    reaper.ImGui_Spacing(ctx)
                    reaper.ImGui_TextColored(ctx, 0xFFAA00FF, "Welcome to the Folder Items tab!")
                    reaper.ImGui_Spacing(ctx)
                    reaper.ImGui_TextWrapped(ctx, "This tab is designed for users of NVK Workflow tools or similar setups (like RenderBlock) who are familiar with the concept of Folder Items (empty items used as naming containers).")
                    reaper.ImGui_Spacing(ctx)
                    reaper.ImGui_TextWrapped(ctx, "If you're not sure what Folder Items are, you probably don't need this tab and can safely hide it.")
                    reaper.ImGui_Spacing(ctx)
                    reaper.ImGui_Spacing(ctx)

                    if reaper.ImGui_Button(ctx, "I'm a Folder Item user", 250, 30) then
                        Settings.setFolderItemUser(true)
                        state.needsRefresh = true
                        state.needsPreview = true
                    end

                    reaper.ImGui_Spacing(ctx)

                    if reaper.ImGui_Button(ctx, "Hide this tab", 250, 30) then
                        Settings.setFolderItemUser(false)
                        -- Switch to another tab since this one will be hidden
                        state.currentTab = "All"
                        state.needsRefresh = true
                        state.needsPreview = true
                    end
                end -- end onboarding gate
            end -- end Folder Items onboarding check

            -- Normal Folder Items controls (only when user is confirmed)
            if state.currentTab == "Folder Items" and folderItemUser == true then
                -- Pattern dropdown
                reaper.ImGui_Text(ctx, "Pattern:")
                reaper.ImGui_SameLine(ctx)
                reaper.ImGui_SetCursorPosX(ctx, controlPosX)
                reaper.ImGui_SetNextItemWidth(ctx, -1)

                local patterns = {
                    simple = "Simple (region_track)",
                    hierarchical = "Hierarchical (all levels)",
                    custom = "Custom pattern"
                }
                
                if reaper.ImGui_BeginCombo(ctx, "##FolderPattern", patterns[state.folderItemPattern]) then
                    for key, label in pairs(patterns) do
                        local isSelected = (state.folderItemPattern == key)
                        if reaper.ImGui_Selectable(ctx, label, isSelected) then
                            state.folderItemPattern = key
                            state.needsPreview = true
                            saveFolderItemsSettings()
                        end
                        if isSelected then
                            reaper.ImGui_SetItemDefaultFocus(ctx)
                        end
                    end
                    reaper.ImGui_EndCombo(ctx)
                end
                
                -- Separator choice
                reaper.ImGui_Text(ctx, "Separator:")
                reaper.ImGui_SameLine(ctx)
                reaper.ImGui_SetCursorPosX(ctx, controlPosX)
                
                if reaper.ImGui_Button(ctx, "_##Sep") then
                    state.folderItemSeparator = "_"
                    state.needsPreview = true
                    saveFolderItemsSettings()
                end
                reaper.ImGui_SameLine(ctx)
                if reaper.ImGui_Button(ctx, "-##Sep") then
                    state.folderItemSeparator = "-"
                    state.needsPreview = true
                    saveFolderItemsSettings()
                end
                reaper.ImGui_SameLine(ctx)
                if reaper.ImGui_Button(ctx, "Space##Sep") then
                    state.folderItemSeparator = " "
                    state.needsPreview = true
                    saveFolderItemsSettings()
                end
                reaper.ImGui_SameLine(ctx)
                reaper.ImGui_SetNextItemWidth(ctx, 50)
                local sepChanged, newSep = reaper.ImGui_InputText(ctx, "##CustomSep", state.folderItemSeparator)
                if sepChanged then
                    state.folderItemSeparator = newSep
                    state.needsPreview = true
                    saveFolderItemsSettings()
                end
                
                -- Custom pattern input (if custom selected)
                if state.folderItemPattern == "custom" then
                    reaper.ImGui_Text(ctx, "Pattern:")
                    reaper.ImGui_SameLine(ctx)
                    reaper.ImGui_SetCursorPosX(ctx, controlPosX)
                    reaper.ImGui_SetNextItemWidth(ctx, -1)
                    local patternChanged, newPattern = reaper.ImGui_InputText(ctx, "##CustomPattern", state.folderItemCustomPattern)
                    if patternChanged then
                        state.folderItemCustomPattern = newPattern
                        state.needsPreview = true
                        saveFolderItemsSettings()
                    end
                    
                    -- Pattern help
                    reaper.ImGui_Text(ctx, "Variables: $region1, $region2, $region3... (regions by hierarchy)")
                    reaper.ImGui_Text(ctx, "           $track1, $track2, $track3... (tracks by hierarchy)")
                    reaper.ImGui_Text(ctx, "           $position, $index")
                end
                
                reaper.ImGui_Separator(ctx)
            end

            -- TRANSFORMATIONS SECTION (for ALL tabs including Folder Items)
            -- Skip if showing folder item onboarding
          if not showFolderItemOnboarding then
            -- reaper.ImGui_Text(ctx, "TRANSFORMATIONS")
            -- reaper.ImGui_Separator(ctx)
            
            -- Truncate from: remove N chars from the start/end of the SOURCE name first
            -- (acts on the original name, before Find/Replace and every other tool)
            reaper.ImGui_Text(ctx, "Truncate from:")
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetCursorPosX(ctx, controlPosX)
            reaper.ImGui_Text(ctx, "Start:")
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 70)
            local changedTrimStart, newTrimStart = reaper.ImGui_InputInt(ctx, "##truncStart", state.removeFromStart)
            if changedTrimStart then
                state.removeFromStart = math.max(0, math.floor(newTrimStart))
                state.needsPreview = true
            end
            if reaper.ImGui_IsItemHovered(ctx) then
                reaper.ImGui_BeginTooltip(ctx)
                reaper.ImGui_Text(ctx, "Remove this many characters from the start/end of the source name, before Find/Replace and all other tools. 0 = off.")
                reaper.ImGui_EndTooltip(ctx)
            end
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Text(ctx, "End:")
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 70)
            local changedTrimEnd, newTrimEnd = reaper.ImGui_InputInt(ctx, "##truncEnd", state.removeFromEnd)
            if changedTrimEnd then
                state.removeFromEnd = math.max(0, math.floor(newTrimEnd))
                state.needsPreview = true
            end
            if reaper.ImGui_IsItemHovered(ctx) then
                reaper.ImGui_BeginTooltip(ctx)
                reaper.ImGui_Text(ctx, "Remove this many characters from the start/end of the source name, before Find/Replace and all other tools. 0 = off.")
                reaper.ImGui_EndTooltip(ctx)
            end

            reaper.ImGui_Separator(ctx)

            -- Find/Replace controls with pattern support
            reaper.ImGui_Text(ctx, "Find:")
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetCursorPosX(ctx, controlPosX)
            reaper.ImGui_SetNextItemWidth(ctx, -1)

            -- Color input red if pattern is invalid
            if state.useLuaPatterns and not state.patternValid then
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), 0x4040FFFF)
            end

            local changed, newFind = reaper.ImGui_InputText(ctx, "##Find", state.findText)
            
            if state.useLuaPatterns and not state.patternValid then
                reaper.ImGui_PopStyleColor(ctx)
            end
            
            if changed then
                state.findText = newFind
                -- Validate pattern if in Lua pattern mode
                if state.useLuaPatterns then
                    state.patternValid, state.patternError = Common.validatePattern(newFind)
                end
                state.needsPreview = true  -- Trigger automatic preview
            end
            
            -- Pattern Help button (hidden - Lua patterns disabled for now)
            -- reaper.ImGui_SameLine(ctx)
            -- if reaper.ImGui_Button(ctx, "?") then
            --     state.showPatternHelp = not state.showPatternHelp
            -- end
            -- if reaper.ImGui_IsItemHovered(ctx) then
            --     reaper.ImGui_BeginTooltip(ctx)
            --     reaper.ImGui_Text(ctx, "Lua Pattern Reference & Tester")
            --     reaper.ImGui_EndTooltip(ctx)
            -- end
            
            reaper.ImGui_Text(ctx, "Replace:")
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetCursorPosX(ctx, controlPosX)
            reaper.ImGui_SetNextItemWidth(ctx, -1)
            local changed2, newReplace = reaper.ImGui_InputText(ctx, "##Replace", state.replaceText)
            if changed2 then
                state.replaceText = newReplace
                state.needsPreview = true  -- Trigger automatic preview
            end
            
            -- Search modifiers (Case Sensitive / Whole Word) kept next to Find/Replace
            reaper.ImGui_SetCursorPosX(ctx, controlPosX)
            local caseChanged, newCase = reaper.ImGui_Checkbox(ctx, "Case Sensitive", state.caseSensitive)
            if caseChanged then
                state.caseSensitive = newCase
                state.needsPreview = true
            end
            if reaper.ImGui_IsItemHovered(ctx) then
                reaper.ImGui_BeginTooltip(ctx)
                reaper.ImGui_Text(ctx, "Match exact case (uppercase/lowercase) when searching")
                reaper.ImGui_EndTooltip(ctx)
            end
            reaper.ImGui_SetCursorPosX(ctx, controlPosX)
            local wholeChanged, newWhole = reaper.ImGui_Checkbox(ctx, "Whole Word", state.wholeWord)
            if wholeChanged then
                state.wholeWord = newWhole
                state.needsPreview = true
            end
            if reaper.ImGui_IsItemHovered(ctx) then
                reaper.ImGui_BeginTooltip(ctx)
                reaper.ImGui_Text(ctx, "Only match complete words, not partial matches")
                reaper.ImGui_EndTooltip(ctx)
            end

            reaper.ImGui_Separator(ctx)

            -- CLEAN UP family: Operation, Replace spaces, Truncate
            -- Operation dropdown
            reaper.ImGui_Text(ctx, "Operation:")
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetCursorPosX(ctx, controlPosX)
            reaper.ImGui_SetNextItemWidth(ctx, -1)

            -- Operation descriptions (simplified - duplicates removed)
            local operationLabels = {
                none = "None",
                addDate = "Add Date (YYYY-MM-DD)",
                addTimestamp = "Add Timestamp (HH-MM-SS)",
                removeBrackets = "Remove [Brackets] and Content",
                removeParens = "Remove (Parentheses) and Content"
            }

            -- Operations in display order (None first, then alphabetical)
            local operationOrder = {"none", "addDate", "addTimestamp", "removeBrackets", "removeParens"}

            local currentOpLabel = operationLabels[state.operation] or "None"

            if reaper.ImGui_BeginCombo(ctx, "##Operations", currentOpLabel) then
                for _, op in ipairs(operationOrder) do
                    local label = operationLabels[op]
                    local isSelected = (state.operation == op)
                    if reaper.ImGui_Selectable(ctx, label, isSelected) then
                        state.operation = op
                        state.needsPreview = true
                    end
                    if isSelected then
                        reaper.ImGui_SetItemDefaultFocus(ctx)
                    end
                end
                reaper.ImGui_EndCombo(ctx)
            end

            -- Replace spaces buttons
            reaper.ImGui_Text(ctx, "Replace spaces:")
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetCursorPosX(ctx, controlPosX)

            -- Underscore button
            local isActive_underscore = state.spaceReplacement == "_"
            if isActive_underscore then
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x4CAF50FF)
            end
            if reaper.ImGui_Button(ctx, "_") then
                if state.spaceReplacement == "_" then
                    state.spaceReplacement = ""  -- Toggle off
                else
                    state.spaceReplacement = "_"  -- Set to underscore
                end
                Settings.current.spaceReplacement = state.spaceReplacement
                Settings.save()
                state.needsPreview = true
            end
            if isActive_underscore then
                reaper.ImGui_PopStyleColor(ctx)
            end

            reaper.ImGui_SameLine(ctx)

            -- Dash button
            local isActive_dash = state.spaceReplacement == "-"
            if isActive_dash then
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x4CAF50FF)
            end
            if reaper.ImGui_Button(ctx, "-") then
                if state.spaceReplacement == "-" then
                    state.spaceReplacement = ""  -- Toggle off
                else
                    state.spaceReplacement = "-"  -- Set to dash
                end
                Settings.current.spaceReplacement = state.spaceReplacement
                Settings.save()
                state.needsPreview = true
            end
            if isActive_dash then
                reaper.ImGui_PopStyleColor(ctx)
            end

            reaper.ImGui_SameLine(ctx)

            -- Remove button
            local isActive_remove = state.spaceReplacement == "remove"
            if isActive_remove then
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x4CAF50FF)
            end
            if reaper.ImGui_Button(ctx, "Remove") then
                if state.spaceReplacement == "remove" then
                    state.spaceReplacement = ""  -- Toggle off
                else
                    state.spaceReplacement = "remove"  -- Set to remove
                end
                Settings.current.spaceReplacement = state.spaceReplacement
                Settings.save()
                state.needsPreview = true
            end
            if isActive_remove then
                reaper.ImGui_PopStyleColor(ctx)
            end

            reaper.ImGui_Separator(ctx)

            -- ADD & FORMAT family: Prefix, Suffix, Case
            -- Prefix/Suffix controls
            reaper.ImGui_Text(ctx, "Prefix:")
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetCursorPosX(ctx, controlPosX)
            reaper.ImGui_SetNextItemWidth(ctx, -1)
            local changedPrefix, newPrefix = reaper.ImGui_InputText(ctx, "##Prefix", state.prefix)
            if changedPrefix then
                state.prefix = newPrefix
                state.needsPreview = true
            end

            reaper.ImGui_Text(ctx, "Suffix:")
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetCursorPosX(ctx, controlPosX)
            reaper.ImGui_SetNextItemWidth(ctx, -1)
            local changedSuffix, newSuffix = reaper.ImGui_InputText(ctx, "##Suffix", state.suffix)
            if changedSuffix then
                state.suffix = newSuffix
                state.needsPreview = true
            end

            -- Transform Case dropdown
            reaper.ImGui_Text(ctx, "Case:")
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetCursorPosX(ctx, controlPosX)
            reaper.ImGui_SetNextItemWidth(ctx, -1)

            -- Build display text for dropdown with sorted order
            local caseOrder = {"none", "camel", "constant", "kebab", "lower", "pascal", "sentence", "snake", "title", "upper"}
            local caseDisplay = state.caseExamples[state.transformCase] or "None"

            if reaper.ImGui_BeginCombo(ctx, "##CaseTransform", caseDisplay) then
                for _, caseType in ipairs(caseOrder) do
                    local example = state.caseExamples[caseType]
                    local isSelected = (state.transformCase == caseType)
                    if reaper.ImGui_Selectable(ctx, example, isSelected) then
                        state.transformCase = caseType
                        state.needsPreview = true
                    end
                    if isSelected then
                        reaper.ImGui_SetItemDefaultFocus(ctx)
                    end
                end
                reaper.ImGui_EndCombo(ctx)
            end

            reaper.ImGui_Separator(ctx)

            -- NUMBERING family: Increment + Digits
            -- Increment mode option (use different state for Folder Items tab)
            local currentIncrementMode = state.currentTab == "Folder Items" and state.folderItemIncrementMode or state.incrementMode
            reaper.ImGui_Text(ctx, "Increment:")
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetCursorPosX(ctx, controlPosX)
            if reaper.ImGui_RadioButton(ctx, "Off", currentIncrementMode == "off") then
                if state.currentTab == "Folder Items" then
                    state.folderItemIncrementMode = "off"
                else
                    state.incrementMode = "off"
                end
                state.needsPreview = true
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_RadioButton(ctx, "Number", currentIncrementMode == "number") then
                if state.currentTab == "Folder Items" then
                    state.folderItemIncrementMode = "number"
                else
                    state.incrementMode = "number"
                end
                state.needsPreview = true
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_RadioButton(ctx, "Letter", currentIncrementMode == "letter") then
                if state.currentTab == "Folder Items" then
                    state.folderItemIncrementMode = "letter"
                else
                    state.incrementMode = "letter"
                end
                state.needsPreview = true
            end
            if reaper.ImGui_IsItemHovered(ctx) then
                reaper.ImGui_BeginTooltip(ctx)
                reaper.ImGui_Text(ctx, "Add suffix to duplicates: Off, Number (01, 02...), Letter (A, B... Z, AA...). Digits sets the number width.")
                reaper.ImGui_EndTooltip(ctx)
            end

            -- Digit count for the number increment suffix, on its own row below the radios
            -- (only relevant in "number" mode)
            if currentIncrementMode == "number" then
                reaper.ImGui_Text(ctx, "Digits:")
                reaper.ImGui_SameLine(ctx)
                reaper.ImGui_SetCursorPosX(ctx, controlPosX)
                reaper.ImGui_SetNextItemWidth(ctx, 90)
                local padChanged, newPad = reaper.ImGui_InputInt(ctx, "##incPadding", state.incrementPadding)
                if padChanged then
                    state.incrementPadding = math.max(1, math.min(6, math.floor(newPad)))
                    state.needsPreview = true
                end
                if reaper.ImGui_IsItemHovered(ctx) then
                    reaper.ImGui_BeginTooltip(ctx)
                    reaper.ImGui_Text(ctx, "Digits in the increment suffix (1-6). E.g. 2 -> _01, 3 -> _001")
                    reaper.ImGui_EndTooltip(ctx)
                end
            end
            
            -- Show pattern error if invalid
            if state.useLuaPatterns and not state.patternValid then
                reaper.ImGui_SetCursorPosX(ctx, controlPosX)
                reaper.ImGui_TextColored(ctx, 0xFF0000FF, "Pattern Error: " .. state.patternError)
            end
            
            -- Pattern testing area
            if state.useLuaPatterns then
                reaper.ImGui_Separator(ctx)
                reaper.ImGui_Text(ctx, "Test Pattern:")
                reaper.ImGui_SameLine(ctx)
                reaper.ImGui_SetCursorPosX(ctx, controlPosX)
                reaper.ImGui_SetNextItemWidth(ctx, 250)
                local testChanged, newTest = reaper.ImGui_InputText(ctx, "##TestPattern", state.testPatternText)
                if testChanged then
                    state.testPatternText = newTest
                end
                
                -- Show test result
                if state.testPatternText ~= "" and state.patternValid then
                    local testResult = Common.testPattern(state.testPatternText, state.findText, state.replaceText, true)
                    reaper.ImGui_Text(ctx, "Result:")
                    reaper.ImGui_SameLine(ctx)
                    reaper.ImGui_SetCursorPosX(ctx, controlPosX)
                    reaper.ImGui_TextColored(ctx, 0x00FF00FF, testResult)
                end
            end
            
            reaper.ImGui_Separator(ctx)
            
            -- Selection controls
            reaper.ImGui_Text(ctx, "Selection:")
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetCursorPosX(ctx, controlPosX)
            if reaper.ImGui_Button(ctx, "Select All") then
                for _, item in ipairs(state.currentList) do
                    item.checked = true
                end
            end
            
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Select None") then
                for _, item in ipairs(state.currentList) do
                    item.checked = false
                end
            end
            
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Select Changed") then
                local count = 0
                for _, item in ipairs(state.currentList) do
                    if item.changed then
                        item.checked = true
                        count = count + 1
                    else
                        item.checked = false
                    end
                end
            end
            
          end -- end if not showFolderItemOnboarding

            reaper.ImGui_EndChild(ctx)
        end

        -- RIGHT COLUMN (List with two-column table)
        reaper.ImGui_SameLine(ctx)
        local rightColumnWidth = windowWidth - leftColumnWidth - 10
        -- Adjust height to account for preset section above
        if reaper.ImGui_BeginChild(ctx, "RightColumn", rightColumnWidth, -30, reaper.ImGui_WindowFlags_None()) then
          if not showFolderItemOnboarding then
            -- Table display with full height
            local tableFlags = reaper.ImGui_TableFlags_Borders() |
                               reaper.ImGui_TableFlags_RowBg() |
                               reaper.ImGui_TableFlags_Resizable() |
                               reaper.ImGui_TableFlags_ScrollY() |
                               reaper.ImGui_TableFlags_ScrollX() |
                               reaper.ImGui_TableFlags_Sortable() |
                               reaper.ImGui_TableFlags_SortMulti() |
                               reaper.ImGui_TableFlags_SizingStretchSame()
            
            -- Adapt columns for different tabs
            local columnCount = 3  -- Default
            if state.currentTab == "Folder Items" then
                columnCount = 4
            elseif state.currentTab == "All" then
                columnCount = 5  -- Check, Type, Current, Target, Context
            end
            
            if reaper.ImGui_BeginTable(ctx, "ItemTable", columnCount, tableFlags, 0, 0) then
                -- Setup columns based on tab
                if state.currentTab == "All" then
                    reaper.ImGui_TableSetupColumn(ctx, "##Check", reaper.ImGui_TableColumnFlags_NoSort() | reaper.ImGui_TableColumnFlags_WidthFixed(), 30)
                    reaper.ImGui_TableSetupColumn(ctx, "Type", reaper.ImGui_TableColumnFlags_DefaultSort() | reaper.ImGui_TableColumnFlags_WidthFixed(), 100)
                    reaper.ImGui_TableSetupColumn(ctx, "Current Name", reaper.ImGui_TableColumnFlags_DefaultSort() | reaper.ImGui_TableColumnFlags_WidthStretch())
                    reaper.ImGui_TableSetupColumn(ctx, "Target Name", reaper.ImGui_TableColumnFlags_DefaultSort() | reaper.ImGui_TableColumnFlags_WidthStretch())
                    reaper.ImGui_TableSetupColumn(ctx, "Context", reaper.ImGui_TableColumnFlags_DefaultSort() | reaper.ImGui_TableColumnFlags_WidthFixed(), 200)
                elseif state.currentTab == "Folder Items" then
                    reaper.ImGui_TableSetupColumn(ctx, "##Check", reaper.ImGui_TableColumnFlags_NoSort() | reaper.ImGui_TableColumnFlags_WidthFixed(), 30)
                    reaper.ImGui_TableSetupColumn(ctx, "Current Name", reaper.ImGui_TableColumnFlags_DefaultSort() | reaper.ImGui_TableColumnFlags_WidthStretch())
                    reaper.ImGui_TableSetupColumn(ctx, "Target Name", reaper.ImGui_TableColumnFlags_DefaultSort() | reaper.ImGui_TableColumnFlags_WidthStretch())
                    reaper.ImGui_TableSetupColumn(ctx, "Context (Region/Track)", reaper.ImGui_TableColumnFlags_DefaultSort() | reaper.ImGui_TableColumnFlags_WidthStretch())
                else
                    reaper.ImGui_TableSetupColumn(ctx, "##Check", reaper.ImGui_TableColumnFlags_NoSort() | reaper.ImGui_TableColumnFlags_WidthFixed(), 30)
                    reaper.ImGui_TableSetupColumn(ctx, "Current Name", reaper.ImGui_TableColumnFlags_DefaultSort() | reaper.ImGui_TableColumnFlags_WidthStretch())
                    reaper.ImGui_TableSetupColumn(ctx, "Target Name", reaper.ImGui_TableColumnFlags_DefaultSort() | reaper.ImGui_TableColumnFlags_WidthStretch())
                end
                
                reaper.ImGui_TableSetupScrollFreeze(ctx, 0, 1) -- Freeze header row

                -- Manual column sorting implementation for ReaImGui
                -- Create custom header row with clickable headers
                if reaper.ImGui_TableNextRow(ctx, reaper.ImGui_TableRowFlags_Headers()) then
                    for col = 0, columnCount - 1 do
                        reaper.ImGui_TableSetColumnIndex(ctx, col)

                        local header_text = ""
                        local sortable = col > 0  -- Don't sort checkbox column

                        -- Get header text based on column and tab
                        if state.currentTab == "All" then
                            if col == 0 then header_text = ""
                            elseif col == 1 then header_text = "Type"
                            elseif col == 2 then header_text = "Current Name"
                            elseif col == 3 then header_text = "Target Name"
                            elseif col == 4 then header_text = "Context"
                            end
                        elseif state.currentTab == "Folder Items" then
                            if col == 0 then header_text = ""
                            elseif col == 1 then header_text = "Current Name"
                            elseif col == 2 then header_text = "Target Name"
                            elseif col == 3 then header_text = "Context"
                            end
                        else
                            if col == 0 then header_text = ""
                            elseif col == 1 then header_text = "Current Name"
                            elseif col == 2 then header_text = "Target Name"
                            end
                        end

                        if sortable and header_text ~= "" then
                            -- Add sort indicator
                            local displayText = header_text
                            if state.sortColumn == col then
                                displayText = displayText .. (state.sortDirection == "asc" and " ▲" or " ▼")
                            end

                            -- Make header clickable
                            if reaper.ImGui_Selectable(ctx, displayText .. "##h" .. col, false, reaper.ImGui_SelectableFlags_None()) then
                                -- Toggle sort
                                if state.sortColumn == col then
                                    state.sortDirection = state.sortDirection == "asc" and "desc" or "asc"
                                else
                                    state.sortColumn = col
                                    state.sortDirection = "asc"
                                end

                                -- Perform sort immediately
                                table.sort(state.currentList, function(a, b)
                                    local aVal, bVal

                                    if state.currentTab == "All" then
                                        if state.sortColumn == 1 then -- Type column
                                            aVal = a.type or ""
                                            bVal = b.type or ""
                                        elseif state.sortColumn == 2 then -- Current name
                                            aVal = a.name or a.notes or ""
                                            bVal = b.name or b.notes or ""
                                        elseif state.sortColumn == 3 then -- Target name
                                            aVal = a.preview or ""
                                            bVal = b.preview or ""
                                        elseif state.sortColumn == 4 then -- Context
                                            aVal = a.contextInfo or ""
                                            bVal = b.contextInfo or ""
                                        end
                                    else
                                        if state.sortColumn == 1 then -- Current name
                                            aVal = a.name or a.notes or ""
                                            bVal = b.name or b.notes or ""
                                        elseif state.sortColumn == 2 then -- Target name
                                            aVal = a.preview or ""
                                            bVal = b.preview or ""
                                        elseif state.sortColumn == 3 then -- Context
                                            aVal = a.contextInfo or ""
                                            bVal = b.contextInfo or ""
                                        end
                                    end

                                    -- Handle nil values
                                    if not aVal then aVal = "" end
                                    if not bVal then bVal = "" end

                                    -- Convert to string for comparison
                                    aVal = tostring(aVal):lower()
                                    bVal = tostring(bVal):lower()

                                    if state.sortDirection == "asc" then
                                        return aVal < bVal
                                    else
                                        return aVal > bVal
                                    end
                                end)
                            end
                        elseif col == 0 then
                            -- Checkbox header - empty
                            reaper.ImGui_Text(ctx, "")
                        end
                    end
                end

                local editInputActive = false
                for i, item in ipairs(state.currentList) do
                    reaper.ImGui_TableNextRow(ctx)
                    
                    -- Column 1: Checkbox
                    reaper.ImGui_TableSetColumnIndex(ctx, 0)
                    local changed, newChecked = reaper.ImGui_Checkbox(ctx, "##check" .. i, item.checked or false)
                    if changed then
                        item.checked = newChecked
                    end
                    
                    -- Column 2: Type (only for All tab)
                    if state.currentTab == "All" then
                        reaper.ImGui_TableSetColumnIndex(ctx, 1)
                        local typeColor = 0xFFFFFFFF
                        if item.type == "Media Item" then
                            typeColor = 0x00FF00FF
                        elseif item.type == "Folder Item" then
                            typeColor = 0xFF00FFFF
                        elseif item.type == "Region" then
                            typeColor = 0x00FFFFFF
                        elseif item.type == "Marker" then
                            typeColor = 0xFFFF00FF
                        elseif item.type == "Track" then
                            typeColor = 0xFF8800FF
                        end
                        reaper.ImGui_TextColored(ctx, typeColor, item.type or "")
                    end

                    -- Column 2 or 3: Current Name/Notes (depends on tab)
                    local nameColumnIndex = state.currentTab == "All" and 2 or 1
                    reaper.ImGui_TableSetColumnIndex(ctx, nameColumnIndex)
                    if state.currentTab == "Folder Items" then
                        -- For Folder Items, show editable notes
                        if state.editingIndex == i and state.editingColumn == "current" then
                            -- Edit mode for current notes
                            if state.needsFocus then
                                reaper.ImGui_SetKeyboardFocusHere(ctx)
                                state.needsFocus = false
                            end
                            
                            reaper.ImGui_SetNextItemWidth(ctx, -1) -- Use full column width
                            local changed, newText = reaper.ImGui_InputText(ctx, "##editCurrent" .. i, state.editingText)

                            if reaper.ImGui_IsItemActive(ctx) then
                                editInputActive = true
                            end

                            if changed then
                                state.editingText = newText
                            end

                            if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then
                                applyDirectEdit(i, state.editingText)
                                state.editingIndex = nil
                                state.editingText = ""
                                state.editingOriginal = ""
                                state.editingColumn = nil
                                state.needsFocus = false
                                state.selectedIndex = i
                            elseif reaper.ImGui_IsItemDeactivated(ctx) then
                                -- Cancelled
                                state.editingIndex = nil
                                state.editingText = ""
                                state.editingOriginal = ""
                                state.editingColumn = nil
                                state.needsFocus = false
                                state.selectedIndex = i
                            end
                        else
                            -- Normal mode: show clickable text
                            local displayText = item.name or ""
                            if displayText == "" then
                                displayText = "(empty)"
                            end
                            local is_selected = (state.selectedIndex == i)
                            local clicked = reaper.ImGui_Selectable(ctx, displayText .. "##current" .. i, is_selected, reaper.ImGui_SelectableFlags_SpanAllColumns())
                            
                            if clicked then
                                local currentTime = reaper.time_precise()
                                
                                -- Detect double-click
                                if state.lastClickIndex == i and (currentTime - state.lastClickTime) < 0.3 then
                                    -- Double-click: activate editing
                                    state.editingIndex = i
                                    state.editingColumn = "current"
                                    state.editingText = item.name or ""
                                    state.editingOriginal = item.name or ""
                                    state.needsFocus = true
                                    state.selectedIndex = nil
                                else
                                    -- Single click: select
                                    state.selectedIndex = i
                                    jumpToItemPosition(i)  -- Jump to position if enabled
                                end
                                
                                state.lastClickTime = currentTime
                                state.lastClickIndex = i
                            end
                        end
                    else
                        -- For other tabs, show editable name
                        if state.editingIndex == i and state.editingColumn == "current" then
                            -- Edit mode for current name
                            if state.needsFocus then
                                reaper.ImGui_SetKeyboardFocusHere(ctx)
                                state.needsFocus = false
                            end
                            
                            reaper.ImGui_SetNextItemWidth(ctx, -1) -- Use full column width
                            local changed, newText = reaper.ImGui_InputText(ctx, "##editCurrent" .. i, state.editingText)

                            if reaper.ImGui_IsItemActive(ctx) then
                                editInputActive = true
                            end

                            if changed then
                                state.editingText = newText
                            end

                            if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then
                                applyDirectEdit(i, state.editingText)
                                state.editingIndex = nil
                                state.editingText = ""
                                state.editingOriginal = ""
                                state.editingColumn = nil
                                state.needsFocus = false
                                state.selectedIndex = i
                            elseif reaper.ImGui_IsItemDeactivated(ctx) then
                                -- Cancelled
                                state.editingIndex = nil
                                state.editingText = ""
                                state.editingOriginal = ""
                                state.editingColumn = nil
                                state.needsFocus = false
                                state.selectedIndex = i
                            end
                        else
                            -- Normal mode: show clickable text
                            local is_selected = (state.selectedIndex == i)
                            local clicked = reaper.ImGui_Selectable(ctx, item.name .. "##current" .. i, is_selected, reaper.ImGui_SelectableFlags_SpanAllColumns())
                            
                            if clicked then
                                local currentTime = reaper.time_precise()
                                
                                -- Detect double-click
                                if state.lastClickIndex == i and (currentTime - state.lastClickTime) < 0.3 then
                                    -- Double-click: activate editing
                                    state.editingIndex = i
                                    state.editingColumn = "current"
                                    state.editingText = item.name or ""
                                    state.editingOriginal = item.name or ""
                                    state.needsFocus = true
                                    state.selectedIndex = nil
                                else
                                    -- Single click: select
                                    state.selectedIndex = i
                                    jumpToItemPosition(i)  -- Jump to position if enabled
                                end
                                
                                state.lastClickTime = currentTime
                                state.lastClickIndex = i
                            end
                        end
                    end
                    
                    -- Column 3 or 4: Target Name/Preview or Generated Name for Folder Items
                    local targetColumnIndex = state.currentTab == "All" and 3 or 2
                    reaper.ImGui_TableSetColumnIndex(ctx, targetColumnIndex)
                    if state.editingIndex ~= i then
                        local displayText = item.preview or item.name or ""
                        local textColor = 0xAAAAAAFF  -- Default gray
                        
                        if item.changed and item.preview then
                            textColor = 0x00FF00FF  -- Green for changed
                            displayText = item.preview
                        elseif item.checked and not item.changed then
                            textColor = 0xFFFF00FF  -- Yellow for no change
                            displayText = "(no change)"
                        elseif not item.preview or item.preview == "" then
                            -- Show the same name in gray if no preview
                            displayText = state.currentTab == "Folder Items" and "(empty)" or item.name or ""
                        end
                        
                        reaper.ImGui_TextColored(ctx, textColor, displayText)
                    end
                    
                    -- Column 4 or 5: Context info
                    if state.currentTab == "Folder Items" then
                        reaper.ImGui_TableSetColumnIndex(ctx, 3)
                        reaper.ImGui_Text(ctx, item.contextInfo or "")
                    elseif state.currentTab == "All" then
                        reaper.ImGui_TableSetColumnIndex(ctx, 4)
                        reaper.ImGui_Text(ctx, item.contextInfo or "")
                    end
                end
                
                -- Cancel editing if clicking elsewhere
                if state.editingIndex and reaper.ImGui_IsMouseClicked(ctx, 0) then
                    if not editInputActive then
                        if state.editingText ~= state.editingOriginal and state.editingText ~= "" then
                            applyDirectEdit(state.editingIndex, state.editingText)
                        end
                        state.editingIndex = nil
                        state.editingText = ""
                        state.editingOriginal = ""
                        state.editingColumn = nil
                        state.needsFocus = false
                    end
                end
                
                -- Keyboard shortcuts when an item is selected but not editing
                if state.selectedIndex and not state.editingIndex and #state.currentList > 0 then
                    if reaper.ImGui_IsWindowFocused(ctx) then
                        -- Use mouse wheel for navigation
                        local wheel = reaper.ImGui_GetMouseWheel(ctx)
                        if wheel > 0 then
                            state.selectedIndex = math.max(1, state.selectedIndex - 1)
                        elseif wheel < 0 then
                            state.selectedIndex = math.min(#state.currentList, state.selectedIndex + 1)
                        end
                        
                        -- Right-click to edit
                        if reaper.ImGui_IsMouseClicked(ctx, 1) then
                            state.editingIndex = state.selectedIndex
                            state.editingColumn = "current"
                            state.editingText = state.currentList[state.selectedIndex].name or ""
                            state.editingOriginal = state.currentList[state.selectedIndex].name or ""
                            state.needsFocus = true
                            state.selectedIndex = nil
                        end
                        
                        -- F2 key to edit
                        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F2()) then
                            state.editingIndex = state.selectedIndex
                            state.editingColumn = "current"
                            state.editingText = state.currentList[state.selectedIndex].name or ""
                            state.editingOriginal = state.currentList[state.selectedIndex].name or ""
                            state.needsFocus = true
                            state.selectedIndex = nil
                        end
                    end
                end
                
                reaper.ImGui_EndTable(ctx)
            end
          end -- end if not showFolderItemOnboarding (right column)
            reaper.ImGui_EndChild(ctx)
        end

        -- Removed pattern help window - no longer needed with operations
        
        -- Apply Changes button (full width at bottom)
      if not showFolderItemOnboarding then
        reaper.ImGui_Separator(ctx)

        -- Button and warning on same line
        if reaper.ImGui_Button(ctx, "Apply Changes") then
            applyChanges()
        end
      end

        -- Bottom bar: icons + version label (right-aligned)
        local versionText = "v" .. DM_RENAMER_VERSION
        local windowWidth = reaper.ImGui_GetWindowWidth(ctx)
        local textWidth = reaper.ImGui_CalcTextSize(ctx, versionText)
        local iconSize = 16
        local iconSpacing = 4
        local totalIconsWidth = (iconSize + iconSpacing) * 3 + 8 + textWidth + 15

        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_SetCursorPosX(ctx, windowWidth - totalIconsWidth)

        -- Transparent button style for icon buttons
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x00000000)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0xFFFFFF20)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0xFFFFFF40)
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 0, 0)

        -- Website icon
        if reaper.ImGui_ImageButton(ctx, "##WebsiteBtn", icon_website, iconSize, iconSize) then
            reaper.CF_ShellExecute(URL_WEBSITE)
        end
        if reaper.ImGui_IsItemHovered(ctx) then
            reaper.ImGui_BeginTooltip(ctx)
            reaper.ImGui_Text(ctx, "Visit demute.studio")
            reaper.ImGui_EndTooltip(ctx)
        end

        reaper.ImGui_SameLine(ctx, 0, iconSpacing)

        -- Discord icon
        if reaper.ImGui_ImageButton(ctx, "##DiscordBtn", icon_discord, iconSize, iconSize) then
            reaper.CF_ShellExecute(URL_DISCORD)
        end
        if reaper.ImGui_IsItemHovered(ctx) then
            reaper.ImGui_BeginTooltip(ctx)
            reaper.ImGui_Text(ctx, "Join our Discord")
            reaper.ImGui_EndTooltip(ctx)
        end

        reaper.ImGui_SameLine(ctx, 0, iconSpacing)

        -- Documentation icon
        if reaper.ImGui_ImageButton(ctx, "##DocsBtn", icon_docs, iconSize, iconSize) then
            reaper.CF_ShellExecute(URL_DOCS)
        end
        if reaper.ImGui_IsItemHovered(ctx) then
            reaper.ImGui_BeginTooltip(ctx)
            reaper.ImGui_Text(ctx, "View documentation on GitHub")
            reaper.ImGui_EndTooltip(ctx)
        end

        reaper.ImGui_PopStyleVar(ctx, 1)
        reaper.ImGui_PopStyleColor(ctx, 3)

        -- Version text
        reaper.ImGui_SameLine(ctx, 0, 8)
        reaper.ImGui_TextDisabled(ctx, versionText)

        reaper.ImGui_End(ctx)
    end
    
    -- Check for project state changes (auto-refresh)
    if hasProjectStateChanged() then
        state.needsRefresh = true
        state.needsPreview = true
    end
    
    -- Check for selection changes
    if hasSelectionChanged() then
        state.needsRefresh = true
        state.needsPreview = true
    end
    
    -- Process deferred updates
    if state.needsRefresh then
        refreshCurrentList()
        autoSelectAll()  -- Auto-select all after refresh
    end
    
    if state.needsPreview then
        updatePreview()
    end
    
    -- Pop all style colors and variables
    -- Pop base colors (9) plus any extra colors that were successfully pushed
    local totalColors = 9 + (state.extraColorsPushed or 0)
    reaper.ImGui_PopStyleColor(ctx, totalColors)
    reaper.ImGui_PopStyleVar(ctx, 5)    -- We pushed 5 style variables
    
    if open then
        reaper.defer(loop)
    end
end

-- Initialize region/marker names cache
local function initializeProjectCache()
    local retval, num_markers, num_regions = reaper.CountProjectMarkers(0)

    for i = 0, num_markers + num_regions - 1 do
        local _, isRegion, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers3(0, i)

        if isRegion then
            local key = tostring(markrgnindexnumber)
            state.lastRegionNames[key] = name .. "|" .. string.format("%.4f", pos) .. "|" .. string.format("%.4f", rgnend)
        else
            local key = tostring(markrgnindexnumber)
            state.lastMarkerNames[key] = name .. "|" .. string.format("%.4f", pos)
        end
    end
end

-- Start
-- Load initial list for the default tab
initializeProjectCache()
state.needsRefresh = true

reaper.defer(loop)