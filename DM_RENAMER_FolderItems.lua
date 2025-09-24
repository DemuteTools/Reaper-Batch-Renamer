-- DM RENAMER - Folder Items Module
-- Handles detection and naming of empty items (folder items)

local FolderItems = {}

-- Load common functions
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
local Common = dofile(script_path .. "DM_RENAMER_Common.lua")

-- Module-level storage for current options
local currentOptions = {}

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

-- Set current options (can be called before getting list)
function FolderItems.setOptions(options)
    currentOptions = options or {}
end

-- Check if an item is empty (no audio or MIDI content)
function FolderItems.isEmptyItem(item)
    local takeCount = reaper.CountTakes(item)
    
    -- No takes = empty
    if takeCount == 0 then
        return true
    end
    
    -- Check each take
    for i = 0, takeCount - 1 do
        local take = reaper.GetMediaItemTake(item, i)
        if take then
            -- Check for audio source
            local source = reaper.GetMediaItemTake_Source(take)
            if source then
                local sourceType = reaper.GetMediaSourceType(source, "")
                -- If it has a real source (not EMPTY), it's not empty
                if sourceType and sourceType ~= "EMPTY" and sourceType ~= "" then
                    return false
                end
            end
            
            -- Check for MIDI
            if reaper.TakeIsMIDI(take) then
                local retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
                -- If it has any MIDI events, it's not empty
                if notecnt > 0 or ccevtcnt > 0 or textsyxevtcnt > 0 then
                    return false
                end
            end
        end
    end
    
    return true  -- No content found
end

-- Get regions at a specific position (returns ordered array by hierarchy)
function FolderItems.getRegionsAtPosition(position, length, excludeTag)
    local allRegions = {}
    local itemEnd = position + length

    -- Collect all regions that contain this position
    local i = 0
    repeat
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(i)
        if retval > 0 and isrgn then
            -- Check if the item is within this region
            -- Add 1ms tolerance for position check to handle floating point precision issues
            -- when folder items are positioned exactly at region start
            if position >= (pos - 0.001) and position < rgnend then
                -- Check if region should be excluded
                if not isExcluded(name, excludeTag) then
                    table.insert(allRegions, {
                        name = name,
                        pos = pos,
                        endPos = rgnend,
                        size = rgnend - pos
                    })
                end
            end
        end
        i = i + 1
    until retval == 0

    -- Sort regions by size (largest first = parent, then nested children)
    table.sort(allRegions, function(a, b) return a.size > b.size end)

    -- Return just the names in hierarchical order
    local regions = {}
    for j = 1, #allRegions do
        table.insert(regions, allRegions[j].name)
    end

    return regions
end

-- Get track hierarchy (returns ordered array by hierarchy)
function FolderItems.getTrackHierarchy(track, excludeTag)
    local trackPath = {}

    if not track then return trackPath end

    -- Get current track name
    local _, currentName = reaper.GetTrackName(track)

    -- Check if current track should be excluded
    if isExcluded(currentName, excludeTag) then
        -- Skip this track but continue to parent
        local parentTrack = reaper.GetParentTrack(track)
        if parentTrack then
            return FolderItems.getTrackHierarchy(parentTrack, excludeTag)
        else
            return trackPath  -- No valid track found
        end
    end

    -- Build hierarchy path from current track to top parent
    local currentTrack = track

    -- Add current track name if not excluded
    if not isExcluded(currentName, excludeTag) then
        table.insert(trackPath, currentName)
    end

    while currentTrack do
        local parentTrack = reaper.GetParentTrack(currentTrack)
        if parentTrack then
            local _, parentName = reaper.GetTrackName(parentTrack)
            -- Only add if not excluded
            if not isExcluded(parentName, excludeTag) then
                table.insert(trackPath, 1, parentName)  -- Insert at beginning (parent first)
            end
        end
        currentTrack = parentTrack
    end

    return trackPath
end

-- Generate name based on pattern
function FolderItems.generateName(itemData, pattern, options)
    options = options or {}
    local separator = options.separator or "_"
    local name = ""

    if pattern == "simple" then
        -- Simple pattern: first region_first track
        local parts = {}
        if itemData.regions and #itemData.regions > 0 then
            table.insert(parts, itemData.regions[1])  -- First (parent) region
        end
        if itemData.trackName then
            table.insert(parts, itemData.trackName)
        end
        name = table.concat(parts, separator)

    elseif pattern == "hierarchical" then
        -- Hierarchical pattern: all levels
        local parts = {}

        -- Add all regions
        if itemData.regions then
            for _, region in ipairs(itemData.regions) do
                table.insert(parts, region)
            end
        end

        -- Add track hierarchy
        if itemData.tracks then
            for _, trackName in ipairs(itemData.tracks) do
                table.insert(parts, trackName)
            end
        end

        -- Use configured separator for hierarchical
        name = table.concat(parts, separator)

    elseif pattern == "custom" and options.customPattern then
        -- Custom pattern with $ variables
        name = options.customPattern

        -- Create a placeholder for empty values
        local EMPTY_PLACEHOLDER = "<<EMPTY>>"

        -- Replace numbered region variables
        name = name:gsub("%$region(%d+)", function(num)
            local index = tonumber(num)
            if itemData.regions and itemData.regions[index] then
                return itemData.regions[index]
            else
                return EMPTY_PLACEHOLDER
            end
        end)

        -- Replace numbered track variables
        name = name:gsub("%$track(%d+)", function(num)
            local index = tonumber(num)
            if itemData.tracks and itemData.tracks[index] then
                return itemData.tracks[index]
            else
                return EMPTY_PLACEHOLDER
            end
        end)

        -- Replace other variables
        name = name:gsub("%$position", Common.formatTime and Common.formatTime(itemData.position) or string.format("%.2f", itemData.position))
        name = name:gsub("%$index", tostring(itemData.index or 0))

        -- Clean up: remove empty placeholders and their adjacent separators
        -- Escape separator for pattern matching
        local sep_pattern = separator:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")

        -- Remove placeholder with separator before or after
        name = name:gsub(EMPTY_PLACEHOLDER .. sep_pattern, "")  -- Remove empty + separator
        name = name:gsub(sep_pattern .. EMPTY_PLACEHOLDER, "")  -- Remove separator + empty
        name = name:gsub(EMPTY_PLACEHOLDER, "")  -- Remove remaining empty

        -- Clean up multiple separators
        if separator ~= " " then  -- Don't clean multiple spaces yet, handled below
            name = name:gsub(sep_pattern .. "+", separator)  -- Replace multiple separators with one
        end

        -- Remove leading/trailing separators
        name = name:gsub("^" .. sep_pattern, "")  -- Remove leading separator
        name = name:gsub(sep_pattern .. "$", "")  -- Remove trailing separator
    end

    -- Clean up multiple spaces/separators
    name = name:gsub("%s+", " ")
    name = name:gsub("^%s*(.-)%s*$", "%1")  -- Trim

    return name
end

-- Create item data structure
local function createFolderItemData(item, index)
    local take = reaper.GetActiveTake(item)
    local name = ""
    local notes = ""
    
    -- Get current name (from take if exists)
    if take then
        name = reaper.GetTakeName(take)
    end
    
    -- Get notes from item
    local retval, notesStr = reaper.GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
    if retval then
        notes = notesStr
    end
    
    -- Exclude items with [JOIN] note
    if notes == "[JOIN]" then
        return nil
    end
    
    -- Get track info
    local track = reaper.GetMediaItem_Track(item)
    local trackName = ""
    local trackNumber = 0
    
    if track then
        local _, tName = reaper.GetTrackName(track)
        trackName = tName
        trackNumber = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER"))
    end
    
    -- Get position and length
    local position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local color = reaper.GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR")
    local selected = reaper.IsMediaItemSelected(item)
    
    -- Get regions at this position (with exclude tag from current options)
    local regions = FolderItems.getRegionsAtPosition(position, length, currentOptions.excludeTag)

    -- Get track hierarchy (with exclude tag from current options)
    local tracks = FolderItems.getTrackHierarchy(track, currentOptions.excludeTag)

    return {
        item = item,
        take = take,
        index = index,
        name = (name ~= "" and name) or notes,  -- Display name: prioritize take name, fallback to notes
        notes = notes,
        trackName = trackName,
        trackNumber = trackNumber,
        regions = regions,  -- Ordered array of regions
        tracks = tracks,    -- Ordered array of tracks
        position = position,
        length = length,
        color = color,
        selected = selected,

        -- For UI display
        checked = false,
        preview = "",
        changed = false,
        contextInfo = ""  -- Will show region/track info
    }
end

-- Get list of folder items
function FolderItems.getList()
    local items = {}
    local itemCount = reaper.CountMediaItems(0)
    
    for i = 0, itemCount - 1 do
        local item = reaper.GetMediaItem(0, i)
        if item and FolderItems.isEmptyItem(item) then
            local itemData = createFolderItemData(item, i)
            
            -- Skip if item was excluded (e.g., [JOIN] note)
            if itemData then
                -- Build context info string for display
                local contextParts = {}
                if itemData.regions and #itemData.regions > 0 then
                    table.insert(contextParts, "Regions: " .. table.concat(itemData.regions, " > "))
                end
                if itemData.tracks and #itemData.tracks > 0 then
                    table.insert(contextParts, "Tracks: " .. table.concat(itemData.tracks, " > "))
                end
                itemData.contextInfo = table.concat(contextParts, " | ")

                table.insert(items, itemData)
            end
        end
    end
    
    return items
end

-- Get list with selection filter
function FolderItems.getListWithSelection(selectedOnly)
    local items = {}

    -- Check what kind of selection we have
    local selectedItemCount = reaper.CountSelectedMediaItems(0)
    local start_time, end_time = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    local hasTimeSelection = (end_time - start_time) > 0

    if selectedOnly then
        -- Priority: item selection > time selection
        if selectedItemCount > 0 then
            -- Filter by selected items
            for i = 0, selectedItemCount - 1 do
                local item = reaper.GetSelectedMediaItem(0, i)
                if item and FolderItems.isEmptyItem(item) then
                    local itemData = createFolderItemData(item, i)
                    if itemData then
                        -- Build context info...
                        local contextParts = {}
                        if itemData.regions and #itemData.regions > 0 then
                            table.insert(contextParts, "Regions: " .. table.concat(itemData.regions, " > "))
                        end
                        if itemData.tracks and #itemData.tracks > 0 then
                            table.insert(contextParts, "Tracks: " .. table.concat(itemData.tracks, " > "))
                        end
                        itemData.contextInfo = table.concat(contextParts, " | ")
                        table.insert(items, itemData)
                    end
                end
            end
        elseif hasTimeSelection then
            -- Filter by time selection
            local itemCount = reaper.CountMediaItems(0)
            for i = 0, itemCount - 1 do
                local item = reaper.GetMediaItem(0, i)
                if item and FolderItems.isEmptyItem(item) then
                    local position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                    local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                    local itemEnd = position + length

                    -- Check if item overlaps with time selection
                    if position < end_time and itemEnd > start_time then
                        local itemData = createFolderItemData(item, i)
                        if itemData then
                            -- Build context info...
                            local contextParts = {}
                            if itemData.regions and #itemData.regions > 0 then
                                table.insert(contextParts, "Regions: " .. table.concat(itemData.regions, " > "))
                            end
                            if itemData.tracks and #itemData.tracks > 0 then
                                table.insert(contextParts, "Tracks: " .. table.concat(itemData.tracks, " > "))
                            end
                            itemData.contextInfo = table.concat(contextParts, " | ")
                            table.insert(items, itemData)
                        end
                    end
                end
            end
        else
            -- No selection, return all
            return FolderItems.getList()
        end
        return items
    else
        return FolderItems.getList()
    end
end

-- Update preview with generated names
function FolderItems.updatePreview(itemList, pattern, options)
    -- Store options for use in other functions
    currentOptions = options or {}
    
    -- First pass: generate base names with all transformations
    local nameCount = {}
    for i, item in ipairs(itemList) do
        local generatedName = FolderItems.generateName(item, pattern, options)
        
        -- Apply additional transformations (for full pattern system)
        -- 1. Operations
        if options.operation and options.operation ~= "none" then
            generatedName = Common.applyOperation(generatedName, options.operation, {
                position = item.position,
                index = i,
                type = "folderitem"
            })
        end
        
        -- 2. Find/Replace with Lua patterns
        if options.findText and options.findText ~= "" then
            generatedName = Common.replacePattern(
                generatedName,
                options.findText,
                options.replaceText,
                options.caseSensitive,
                options.wholeWord,
                options.useLuaPatterns
            )
        end
        
        -- 2.5. Space replacement (independent of Find/Replace)
        if options.spaceReplacement and options.spaceReplacement ~= "" then
            if options.spaceReplacement == "remove" then
                generatedName = generatedName:gsub("%s+", "")
            elseif options.spaceReplacement == "_" then
                generatedName = generatedName:gsub("%s+", "_")
            elseif options.spaceReplacement == "-" then
                generatedName = generatedName:gsub("%s+", "-")
            end
        end
        
        -- 3. Prefix/Suffix
        if options.prefix and options.prefix ~= "" then
            generatedName = options.prefix .. generatedName
        end
        if options.suffix and options.suffix ~= "" then
            generatedName = generatedName .. options.suffix
        end
        
        -- 4. Case transformation
        if options.transformCase and options.transformCase ~= "none" then
            generatedName = Common.applyCase(generatedName, options.transformCase)
        end
        
        item.basePreview = generatedName
        
        -- Count occurrences only if auto-increment is enabled
        if options.autoIncrement ~= false then  -- Default true if not specified
            nameCount[generatedName] = (nameCount[generatedName] or 0) + 1
        end
    end
    
    -- Second pass: add numbers to duplicates (only if auto-increment enabled)
    local nameIndex = {}
    for _, item in ipairs(itemList) do
        local baseName = item.basePreview
        
        if options.autoIncrement ~= false and nameCount[baseName] and nameCount[baseName] > 1 then
            -- This name has duplicates, add number
            nameIndex[baseName] = (nameIndex[baseName] or 0) + 1
            local separator = options.separator or "_"
            local number = string.format("%02d", nameIndex[baseName])
            item.preview = baseName .. separator .. number
        else
            -- Unique name or auto-increment disabled
            item.preview = baseName
        end
        
        -- Ensure preview is never empty
        if item.preview == "" or item.preview == nil then
            item.preview = "(empty)"
        end
        
        -- Changed if different from either notes OR name
        item.changed = (item.preview ~= item.notes) or (item.preview ~= item.name)
    end
end

-- Apply changes to items
function FolderItems.applyChanges(itemList)
    Common.beginUndoBlock("Apply Folder Item Names")
    
    local successCount = 0
    local errorCount = 0
    
    for _, itemData in ipairs(itemList) do
        if itemData.checked and itemData.changed and itemData.preview then
            -- ALWAYS write to both Notes AND Take name for NVK compatibility
            
            -- 1. Write to item notes
            local successNotes = reaper.GetSetMediaItemInfo_String(
                itemData.item,
                "P_NOTES",
                itemData.preview,
                true
            )
            
            -- 2. Write to take name (create take if needed)
            local successTake = false
            if not itemData.take then
                -- Create a take if none exists
                itemData.take = reaper.AddTakeToMediaItem(itemData.item)
            end
            
            if itemData.take then
                successTake = reaper.GetSetMediaItemTakeInfo_String(
                    itemData.take,
                    "P_NAME",
                    itemData.preview,
                    true
                )
            end
            
            -- Success if both worked
            if successNotes and successTake then
                successCount = successCount + 1
                -- Update local data to reflect the changes
                itemData.notes = itemData.preview
                itemData.name = itemData.preview
                itemData.changed = false
            else
                errorCount = errorCount + 1
            end
        end
    end
    
    Common.endUndoBlock("Apply Folder Item Names")
    reaper.UpdateArrange()
    
    return successCount > 0, string.format("Updated %d items, %d errors", successCount, errorCount)
end

return FolderItems