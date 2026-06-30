-- @noindex
-- DM RENAMER - Items Module
-- Handles all operations related to media items

local Items = {}

-- Load common functions
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
local Common = dofile(script_path .. "DM_RENAMER_Common.lua")
local FolderItems = dofile(script_path .. "DM_RENAMER_FolderItems.lua")

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

-- Structure for item data
local function createItemData(item, index)
    local take = reaper.GetActiveTake(item)
    local name = ""
    local takeName = ""
    
    if take then
        name = reaper.GetTakeName(take)
        takeName = name
    end
    
    local track = reaper.GetMediaItem_Track(item)
    local trackName = ""
    local trackNumber = 0
    
    if track then
        local _, tName = reaper.GetTrackName(track)
        trackName = tName
        trackNumber = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER"))
    end
    
    local position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local color = reaper.GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR")
    local selected = reaper.IsMediaItemSelected(item)
    local muted = reaper.GetMediaItemInfo_Value(item, "B_MUTE") == 1
    local locked = reaper.GetMediaItemInfo_Value(item, "C_LOCK") == 1
    
    return {
        item = item,
        take = take,
        index = index,
        name = name,
        takeName = takeName,
        trackName = trackName,
        trackNumber = trackNumber,
        position = position,
        length = length,
        color = color,
        selected = selected,
        muted = muted,
        locked = locked,
        
        -- For UI display
        checked = false,
        preview = "",
        status = ""
    }
end

-- Get all items in project
function Items.getItemList(selectedOnly, excludeTags)
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
                if item and not FolderItems.isEmptyItem(item) then
                    local itemData = createItemData(item, i)
                    -- Check if item should be excluded based on take name
                    if itemData and not isExcluded(itemData.name, excludeTags) then
                        table.insert(items, itemData)
                    end
                end
            end
        elseif hasTimeSelection then
            -- Filter by time selection
            local itemCount = reaper.CountMediaItems(0)
            for i = 0, itemCount - 1 do
                local item = reaper.GetMediaItem(0, i)
                if item and not FolderItems.isEmptyItem(item) then
                    local position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                    local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                    local itemEnd = position + length

                    -- Check if item overlaps with time selection
                    if position < end_time and itemEnd > start_time then
                        local itemData = createItemData(item, i)
                        -- Check if item should be excluded based on take name
                        if itemData and not isExcluded(itemData.name, excludeTags) then
                            table.insert(items, itemData)
                        end
                    end
                end
            end
        else
            -- No selection, return all non-folder items
            local itemCount = reaper.CountMediaItems(0)
            for i = 0, itemCount - 1 do
                local item = reaper.GetMediaItem(0, i)
                if item and not FolderItems.isEmptyItem(item) then
                    local itemData = createItemData(item, i)
                    -- Check if item should be excluded based on take name
                    if itemData and not isExcluded(itemData.name, excludeTags) then
                        table.insert(items, itemData)
                    end
                end
            end
        end
    else
        -- Return all non-folder items
        local itemCount = reaper.CountMediaItems(0)
        for i = 0, itemCount - 1 do
            local item = reaper.GetMediaItem(0, i)
            if item and not FolderItems.isEmptyItem(item) then
                table.insert(items, createItemData(item, i))
            end
        end
    end

    return items
end

-- Get items from selected tracks
function Items.getItemsFromSelectedTracks()
    local items = {}
    local trackCount = reaper.CountSelectedTracks(0)
    
    for t = 0, trackCount - 1 do
        local track = reaper.GetSelectedTrack(0, t)
        if track then
            local itemCount = reaper.CountTrackMediaItems(track)
            for i = 0, itemCount - 1 do
                local item = reaper.GetTrackMediaItem(track, i)
                if item then
                    -- Exclude folder items (empty items without audio or MIDI)
                    if not FolderItems.isEmptyItem(item) then
                        table.insert(items, createItemData(item, #items))
                    end
                end
            end
        end
    end
    
    return items
end

-- Filter items by search pattern
function Items.filterItems(items, searchPattern, options)
    if not searchPattern or searchPattern == "" then
        return items
    end
    
    local filtered = {}
    options = options or {}
    
    for _, itemData in ipairs(items) do
        local matches = Common.matchPattern(
            itemData.name,
            searchPattern,
            options.caseSensitive,
            options.wholeWord
        )
        
        if matches then
            itemData.status = "Match found"
            table.insert(filtered, itemData)
        elseif options.showAll then
            itemData.status = ""
            table.insert(filtered, itemData)
        end
    end
    
    return filtered
end

-- Preview rename for items
function Items.previewItemRename(items, findPattern, replacePattern, options)
    if not findPattern then return items end
    
    options = options or {}
    local previews = {}
    
    for i, itemData in ipairs(items) do
        local newName = itemData.name
        
        if options.useTemplate then
            -- Apply template with variables
            local vars = Common.generateVariables(i, itemData.name, {
                track = itemData.trackName,
                tracknum = itemData.trackNumber,
                position = Common.formatTime(itemData.position),
                length = Common.formatTime(itemData.length)
            })
            newName = Common.applyTemplate(replacePattern, vars)
        else
            -- Regular find and replace
            newName = Common.replacePattern(
                itemData.name,
                findPattern,
                replacePattern,
                options.caseSensitive,
                options.wholeWord
            )
        end
        
        -- Apply case transformation if specified
        if options.caseType and options.caseType ~= "none" then
            newName = Common.applyCase(newName, options.caseType)
        end
        
        -- Apply prefix/suffix
        if options.prefix then
            newName = options.prefix .. newName
        end
        if options.suffix then
            newName = newName .. options.suffix
        end
        
        -- Apply numbering
        if options.addNumbering then
            local number = Common.padNumber(
                options.startNumber + (i - 1) * options.increment,
                options.padding or 2
            )
            
            if options.numberPosition == "prefix" then
                newName = number .. options.numberSeparator .. newName
            elseif options.numberPosition == "suffix" then
                newName = newName .. options.numberSeparator .. number
            elseif options.numberPosition == "replace" then
                newName = number
            end
        end
        
        -- Truncate if needed
        if options.maxLength and options.maxLength > 0 then
            newName = Common.truncate(newName, options.maxLength, options.addEllipsis)
        end
        
        itemData.preview = newName
        itemData.changed = newName ~= itemData.name
        
        table.insert(previews, itemData)
    end
    
    return previews
end

-- Apply rename to items
function Items.applyItemRename(items, changes)
    if not items or #items == 0 then return false, "No items to rename" end
    
    Common.beginUndoBlock("Rename Items")
    
    local successCount = 0
    local errorCount = 0
    local errors = {}
    
    for _, itemData in ipairs(items) do
        if itemData.checked and itemData.changed and itemData.preview then
            if itemData.take then
                -- Rename take
                local success = reaper.GetSetMediaItemTakeInfo_String(
                    itemData.take,
                    "P_NAME",
                    itemData.preview,
                    true
                )
                
                if success then
                    successCount = successCount + 1
                    itemData.status = "Renamed"
                    itemData.name = itemData.preview
                else
                    errorCount = errorCount + 1
                    itemData.status = "Error"
                    table.insert(errors, "Failed to rename: " .. itemData.name)
                end
            else
                -- Item has no take, try to create one
                local take = reaper.AddTakeToMediaItem(itemData.item)
                if take then
                    local success = reaper.GetSetMediaItemTakeInfo_String(
                        take,
                        "P_NAME",
                        itemData.preview,
                        true
                    )
                    
                    if success then
                        successCount = successCount + 1
                        itemData.status = "Renamed"
                        itemData.name = itemData.preview
                        itemData.take = take
                    else
                        errorCount = errorCount + 1
                        itemData.status = "Error"
                        table.insert(errors, "Failed to rename: " .. itemData.name)
                    end
                else
                    errorCount = errorCount + 1
                    itemData.status = "No take"
                    table.insert(errors, "No take in item at position " .. Common.formatTime(itemData.position))
                end
            end
        end
    end
    
    Common.endUndoBlock("Rename Items")
    reaper.UpdateArrange()
    
    local message = string.format("Renamed %d items", successCount)
    if errorCount > 0 then
        message = message .. string.format(", %d errors", errorCount)
        if #errors > 0 then
            message = message .. "\n\n" .. table.concat(errors, "\n")
        end
    end
    
    return successCount > 0, message
end

-- Select items
function Items.selectItems(itemIndices, addToSelection)
    if not addToSelection then
        -- Clear current selection
        reaper.SelectAllMediaItems(0, false)
    end
    
    for _, index in ipairs(itemIndices) do
        local item = reaper.GetMediaItem(0, index)
        if item then
            reaper.SetMediaItemSelected(item, true)
        end
    end
    
    reaper.UpdateArrange()
end

-- Select items by data
function Items.selectItemsByData(items, selectChecked)
    reaper.SelectAllMediaItems(0, false)
    
    for _, itemData in ipairs(items) do
        if selectChecked and itemData.checked then
            reaper.SetMediaItemSelected(itemData.item, true)
        elseif not selectChecked and itemData.selected then
            reaper.SetMediaItemSelected(itemData.item, true)
        end
    end
    
    reaper.UpdateArrange()
end

-- Get item at time position
function Items.getItemAtPosition(position, track)
    if track then
        local itemCount = reaper.CountTrackMediaItems(track)
        for i = 0, itemCount - 1 do
            local item = reaper.GetTrackMediaItem(track, i)
            if item then
                local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                local itemLen = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                if position >= itemPos and position < itemPos + itemLen then
                    return item
                end
            end
        end
    else
        local itemCount = reaper.CountMediaItems(0)
        for i = 0, itemCount - 1 do
            local item = reaper.GetMediaItem(0, i)
            if item then
                local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                local itemLen = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                if position >= itemPos and position < itemPos + itemLen then
                    return item
                end
            end
        end
    end
    
    return nil
end

-- Check/uncheck all items
function Items.setAllChecked(items, checked)
    for _, itemData in ipairs(items) do
        itemData.checked = checked
    end
end

-- Check items by indices
function Items.checkItemsByIndices(items, indices)
    for _, idx in ipairs(indices) do
        if items[idx] then
            items[idx].checked = true
        end
    end
end

-- Toggle checked state
function Items.toggleChecked(items, index)
    if items[index] then
        items[index].checked = not items[index].checked
    end
end

-- Get checked items
function Items.getCheckedItems(items)
    local checked = {}
    for _, itemData in ipairs(items) do
        if itemData.checked then
            table.insert(checked, itemData)
        end
    end
    return checked
end

-- Sort items
function Items.sortItems(items, sortBy, ascending)
    ascending = ascending ~= false  -- Default to true
    
    table.sort(items, function(a, b)
        local aVal, bVal
        
        if sortBy == "name" then
            aVal = a.name:lower()
            bVal = b.name:lower()
        elseif sortBy == "track" then
            aVal = a.trackNumber
            bVal = b.trackNumber
        elseif sortBy == "position" then
            aVal = a.position
            bVal = b.position
        elseif sortBy == "length" then
            aVal = a.length
            bVal = b.length
        else
            return false
        end
        
        if ascending then
            return aVal < bVal
        else
            return aVal > bVal
        end
    end)
    
    return items
end

-- Export item names to file
function Items.exportToFile(items, filename, exportCheckedOnly)
    local file = io.open(filename, "w")
    if not file then
        return false, "Could not open file for writing"
    end
    
    for _, itemData in ipairs(items) do
        if not exportCheckedOnly or itemData.checked then
            file:write(itemData.name .. "\n")
        end
    end
    
    file:close()
    return true
end

-- Import names from file
function Items.importFromFile(items, filename)
    local file = io.open(filename, "r")
    if not file then
        return false, "Could not open file for reading"
    end
    
    local names = {}
    for line in file:lines() do
        table.insert(names, line)
    end
    file:close()
    
    -- Apply names to items
    for i, itemData in ipairs(items) do
        if names[i] then
            itemData.preview = names[i]
            itemData.changed = true
            itemData.checked = true
        end
    end
    
    return true
end

-- Wrapper functions for main interface compatibility
function Items.getList(excludeTags)
    return Items.getItemList(false, excludeTags)  -- Get all items
end

function Items.getListWithSelection(selectedOnly, excludeTags)
    return Items.getItemList(selectedOnly, excludeTags)
end

function Items.updatePreview(itemList, findText, replaceText, options)
    options = options or {
        operation = "none",      -- Default to no operation
        caseSensitive = false,
        wholeWord = false,
        useLuaPatterns = false,  -- Default to literal search
        transformCase = "none",   -- Default to no transformation
        -- Template and advanced options
        useTemplate = false,
        templateString = "",
        prefix = "",
        suffix = "",
        addNumbering = false,
        startNumber = 1,
        increment = 1,
        padding = 2,
        numberPosition = "suffix",
        numberSeparator = "_",
        maxLength = 0,
        addEllipsis = false
    }
    
    -- Update preview for each item
    for i, item in ipairs(itemList) do
        local newName = item.name
        
        -- Priority 1: Templates
        if options.useTemplate and options.templateString and options.templateString ~= "" then
            local vars = Common.generateVariables(i, item.name, {
                track = item.trackName,
                tracknum = item.trackNumber,
                position = Common.formatTime(item.position),
                length = Common.formatTime(item.length)
            })
            newName = Common.applyTemplate(options.templateString, vars)
        else
            -- Priority 2: Apply operation if specified
            if options.operation and options.operation ~= "none" then
                local ok, result = pcall(Common.applyOperation, newName, options.operation, {
                    position = item.position,
                    index = i,
                    type = "item"
                })
                if ok and result then newName = result end
            else
                -- Priority 3: Find/Replace (only if no operation)
                if findText and findText ~= "" then
                    newName = Common.replacePattern(
                        newName, 
                        findText,
                        replaceText,
                        options.caseSensitive,
                        options.wholeWord,
                        options.useLuaPatterns  -- Pass Lua patterns flag
                    )
                end
            end
        end
        
        -- Priority 3.5: Space replacement (independent of Find/Replace)
        if options.spaceReplacement and options.spaceReplacement ~= "" then
            if options.spaceReplacement == "remove" then
                newName = newName:gsub("%s+", "")
            elseif options.spaceReplacement == "_" then
                newName = newName:gsub("%s+", "_")
            elseif options.spaceReplacement == "-" then
                newName = newName:gsub("%s+", "-")
            end
        end
        
        -- Priority 3.7: Remove characters from start/end (before prefix/suffix)
        if (options.removeFromStart and options.removeFromStart > 0) or (options.removeFromEnd and options.removeFromEnd > 0) then
            newName = Common.removeChars(newName, options.removeFromStart, options.removeFromEnd)
        end

        -- Priority 4: Prefix/Suffix
        if options.prefix and options.prefix ~= "" then
            newName = options.prefix .. newName
        end
        if options.suffix and options.suffix ~= "" then
            newName = newName .. options.suffix
        end

        -- Priority 5: Numbering
        if options.addNumbering then
            local number = Common.padNumber(
                options.startNumber + (i - 1) * options.increment,
                options.padding
            )
            
            if options.numberPosition == "prefix" then
                newName = number .. options.numberSeparator .. newName
            elseif options.numberPosition == "suffix" then
                newName = newName .. options.numberSeparator .. number
            elseif options.numberPosition == "replace" then
                newName = number
            end
        end
        
        -- Priority 6: Case transformation
        if options.transformCase and options.transformCase ~= "none" then
            newName = Common.applyCase(newName, options.transformCase)
        end
        
        -- Priority 7: Truncation
        if options.maxLength and options.maxLength > 0 then
            newName = Common.truncate(newName, options.maxLength, options.addEllipsis)
        end
        
        item.preview = newName
        item.changed = (newName ~= item.name)
    end

    -- Apply increment mode for duplicates
    if options.incrementMode and options.incrementMode ~= "off" then
        Common.handleDuplicateNames(itemList, options.incrementMode, nil, options.incrementPadding)
    end
end

function Items.applyChanges(itemList)
    return Items.applyItemRename(itemList, itemList)
end

return Items