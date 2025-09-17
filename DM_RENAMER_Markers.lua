-- DM RENAMER - Markers Module
-- Handles all operations related to markers

local Markers = {}

-- Load common functions
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
local Common = dofile(script_path .. "DM_RENAMER_Common.lua")

-- Structure for marker data
local function createMarkerData(idx, isRegion, pos, rgnend, name, markrgnindexnumber, color)
    if isRegion then
        return nil  -- Skip regions in this module
    end
    
    return {
        index = markrgnindexnumber,
        idx = idx,  -- Internal Reaper index
        name = name or "",
        position = pos,
        color = color,
        
        -- For UI display
        checked = false,
        preview = "",
        status = "",
        changed = false
    }
end

-- Get all markers in project
function Markers.getMarkerList()
    local markers = {}
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    
    for i = 0, num_markers + num_regions - 1 do
        local _, isRegion, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
        
        if not isRegion then
            local markerData = createMarkerData(i, isRegion, pos, rgnend, name, markrgnindexnumber, color)
            if markerData then
                table.insert(markers, markerData)
            end
        end
    end
    
    return markers
end

-- Get markers at cursor position
function Markers.getMarkersAtCursor()
    local cursorPos = reaper.GetCursorPosition()
    local tolerance = 0.1  -- 100ms tolerance for marker selection
    local markers = {}
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)

    for i = 0, num_markers + num_regions - 1 do
        local _, isRegion, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)

        if not isRegion then
            -- Check if cursor is near marker (with tolerance)
            if math.abs(cursorPos - pos) <= tolerance then
                local markerData = createMarkerData(i, isRegion, pos, rgnend, name, markrgnindexnumber, color)
                if markerData then
                    table.insert(markers, markerData)
                end
            end
        end
    end

    return markers
end

-- Get markers in time selection
function Markers.getMarkersInTimeSelection()
    local startTime, endTime = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    if startTime == endTime then
        return {}  -- No time selection
    end

    local markers = {}
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)

    for i = 0, num_markers + num_regions - 1 do
        local _, isRegion, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)

        if not isRegion then
            -- Check if marker is within time selection
            if pos >= startTime and pos <= endTime then
                local markerData = createMarkerData(i, isRegion, pos, rgnend, name, markrgnindexnumber, color)
                if markerData then
                    table.insert(markers, markerData)
                end
            end
        end
    end

    return markers
end

-- Filter markers by search pattern
function Markers.filterMarkers(markers, searchPattern, options)
    if not searchPattern or searchPattern == "" then
        return markers
    end
    
    local filtered = {}
    options = options or {}
    
    for _, markerData in ipairs(markers) do
        local matches = Common.matchPattern(
            markerData.name,
            searchPattern,
            options.caseSensitive,
            options.wholeWord
        )
        
        if matches then
            markerData.status = "Match found"
            table.insert(filtered, markerData)
        elseif options.showAll then
            markerData.status = ""
            table.insert(filtered, markerData)
        end
    end
    
    return filtered
end

-- Preview rename for markers
function Markers.previewMarkerRename(markers, findPattern, replacePattern, options)
    if not findPattern and not (options and options.useTemplate) then 
        return markers 
    end
    
    options = options or {}
    local previews = {}
    
    for i, markerData in ipairs(markers) do
        local newName = markerData.name
        
        if options.useTemplate then
            -- Apply template with variables
            local vars = Common.generateVariables(i, markerData.name, {
                position = Common.formatTime(markerData.position),
                markernum = markerData.index
            })
            newName = Common.applyTemplate(replacePattern, vars)
        else
            -- Regular find and replace
            newName = Common.replacePattern(
                markerData.name,
                findPattern,
                replacePattern,
                options.caseSensitive,
                options.wholeWord,
                options.useLuaPatterns
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
        
        markerData.preview = newName
        markerData.changed = newName ~= markerData.name
        
        table.insert(previews, markerData)
    end
    
    return previews
end

-- Apply rename to markers
function Markers.applyMarkerRename(markers, changes)
    if not markers or #markers == 0 then return false, "No markers to rename" end
    
    Common.beginUndoBlock("Rename Markers")
    
    local successCount = 0
    local errorCount = 0
    local errors = {}
    
    for _, markerData in ipairs(markers) do
        if markerData.checked and markerData.changed and markerData.preview then
            -- Set marker name
            local success = reaper.SetProjectMarker3(
                0,
                markerData.index,  -- Use actual marker index number, not enumeration index
                false,  -- isRegion = false for markers
                markerData.position,
                markerData.position,  -- end position same as start for markers
                markerData.preview,
                markerData.color
            )
            
            if success then
                successCount = successCount + 1
                markerData.status = "Renamed"
                markerData.name = markerData.preview
            else
                errorCount = errorCount + 1
                markerData.status = "Error"
                table.insert(errors, "Failed to rename marker: " .. markerData.name)
            end
        end
    end
    
    Common.endUndoBlock("Rename Markers")
    reaper.UpdateArrange()
    
    local message = string.format("Renamed %d markers", successCount)
    if errorCount > 0 then
        message = message .. string.format(", %d errors", errorCount)
        if #errors > 0 then
            message = message .. "\n\n" .. table.concat(errors, "\n")
        end
    end
    
    return successCount > 0, message
end

-- Go to marker
function Markers.goToMarker(markerIndex)
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    
    for i = 0, num_markers + num_regions - 1 do
        local _, isRegion, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers3(0, i)
        
        if not isRegion and markrgnindexnumber == markerIndex then
            reaper.SetEditCurPos(pos, true, false)
            return true
        end
    end
    
    return false
end

-- Go to next marker
function Markers.goToNextMarker()
    local curPos = reaper.GetCursorPosition()
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    local nextPos = nil
    local nextDist = math.huge
    
    for i = 0, num_markers + num_regions - 1 do
        local _, isRegion, pos = reaper.EnumProjectMarkers3(0, i)
        
        if not isRegion and pos > curPos then
            local dist = pos - curPos
            if dist < nextDist then
                nextDist = dist
                nextPos = pos
            end
        end
    end
    
    if nextPos then
        reaper.SetEditCurPos(nextPos, true, false)
        return true
    end
    
    return false
end

-- Go to previous marker
function Markers.goToPreviousMarker()
    local curPos = reaper.GetCursorPosition()
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    local prevPos = nil
    local prevDist = math.huge
    
    for i = 0, num_markers + num_regions - 1 do
        local _, isRegion, pos = reaper.EnumProjectMarkers3(0, i)
        
        if not isRegion and pos < curPos then
            local dist = curPos - pos
            if dist < prevDist then
                prevDist = dist
                prevPos = pos
            end
        end
    end
    
    if prevPos then
        reaper.SetEditCurPos(prevPos, true, false)
        return true
    end
    
    return false
end

-- Check/uncheck all markers
function Markers.setAllChecked(markers, checked)
    for _, markerData in ipairs(markers) do
        markerData.checked = checked
    end
end

-- Toggle checked state
function Markers.toggleChecked(markers, index)
    if markers[index] then
        markers[index].checked = not markers[index].checked
    end
end

-- Get checked markers
function Markers.getCheckedMarkers(markers)
    local checked = {}
    for _, markerData in ipairs(markers) do
        if markerData.checked then
            table.insert(checked, markerData)
        end
    end
    return checked
end

-- Sort markers
function Markers.sortMarkers(markers, sortBy, ascending)
    ascending = ascending ~= false  -- Default to true
    
    table.sort(markers, function(a, b)
        local aVal, bVal
        
        if sortBy == "name" then
            aVal = a.name:lower()
            bVal = b.name:lower()
        elseif sortBy == "position" then
            aVal = a.position
            bVal = b.position
        elseif sortBy == "index" then
            aVal = a.index
            bVal = b.index
        else
            return false
        end
        
        if ascending then
            return aVal < bVal
        else
            return aVal > bVal
        end
    end)
    
    return markers
end

-- Delete markers
function Markers.deleteMarkers(markers)
    Common.beginUndoBlock("Delete Markers")
    
    local deletedCount = 0
    
    -- Delete from end to beginning to maintain indices
    local toDelete = {}
    for _, markerData in ipairs(markers) do
        if markerData.checked then
            table.insert(toDelete, markerData.idx)
        end
    end
    
    table.sort(toDelete, function(a, b) return a > b end)
    
    for _, idx in ipairs(toDelete) do
        reaper.DeleteProjectMarkerByIndex(0, idx)
        deletedCount = deletedCount + 1
    end
    
    Common.endUndoBlock("Delete Markers")
    reaper.UpdateArrange()
    
    return deletedCount
end

-- Create marker at position
function Markers.createMarkerAtPosition(position, name, color)
    position = position or reaper.GetCursorPosition()
    
    local index = reaper.AddProjectMarker2(0, false, position, 0, name or "", -1, color or 0)
    
    if index >= 0 then
        return true, "Marker created"
    else
        return false, "Failed to create marker"
    end
end

-- Create markers at item starts
function Markers.createMarkersAtItemStarts(nameTemplate)
    Common.beginUndoBlock("Create Markers at Item Starts")
    
    local createdCount = 0
    local itemCount = reaper.CountSelectedMediaItems(0)
    
    if itemCount == 0 then
        itemCount = reaper.CountMediaItems(0)
        
        for i = 0, itemCount - 1 do
            local item = reaper.GetMediaItem(0, i)
            if item then
                local position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                local take = reaper.GetActiveTake(item)
                local itemName = ""
                
                if take then
                    itemName = reaper.GetTakeName(take)
                end
                
                local markerName = nameTemplate or itemName
                local vars = Common.generateVariables(i + 1, itemName, {
                    itemname = itemName,
                    position = Common.formatTime(position)
                })
                markerName = Common.applyTemplate(markerName, vars)
                
                reaper.AddProjectMarker2(0, false, position, 0, markerName, -1, 0)
                createdCount = createdCount + 1
            end
        end
    else
        -- Only selected items
        for i = 0, itemCount - 1 do
            local item = reaper.GetSelectedMediaItem(0, i)
            if item then
                local position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                local take = reaper.GetActiveTake(item)
                local itemName = ""
                
                if take then
                    itemName = reaper.GetTakeName(take)
                end
                
                local markerName = nameTemplate or itemName
                local vars = Common.generateVariables(i + 1, itemName, {
                    itemname = itemName,
                    position = Common.formatTime(position)
                })
                markerName = Common.applyTemplate(markerName, vars)
                
                reaper.AddProjectMarker2(0, false, position, 0, markerName, -1, 0)
                createdCount = createdCount + 1
            end
        end
    end
    
    Common.endUndoBlock("Create Markers at Item Starts")
    reaper.UpdateArrange()
    
    return createdCount
end

-- Export marker names to file
function Markers.exportToFile(markers, filename, exportCheckedOnly)
    local file = io.open(filename, "w")
    if not file then
        return false, "Could not open file for writing"
    end
    
    -- Write header
    file:write("Index\tName\tPosition\n")
    
    for _, markerData in ipairs(markers) do
        if not exportCheckedOnly or markerData.checked then
            file:write(string.format("%d\t%s\t%s\n",
                markerData.index,
                markerData.name,
                Common.formatTime(markerData.position)
            ))
        end
    end
    
    file:close()
    return true
end

-- Import names from file
function Markers.importFromFile(markers, filename)
    local file = io.open(filename, "r")
    if not file then
        return false, "Could not open file for reading"
    end
    
    local names = {}
    local firstLine = true
    
    for line in file:lines() do
        if firstLine then
            firstLine = false  -- Skip header if present
            if not line:match("^%d+\t") then
                -- Not a data line, skip
                goto continue
            end
        end
        
        -- Try to parse tab-separated values
        local index, name = line:match("^(%d+)\t([^\t]*)")
        if index and name then
            names[tonumber(index)] = name
        else
            -- Try simple line as name
            table.insert(names, line)
        end
        
        ::continue::
    end
    file:close()
    
    -- Apply names to markers
    for i, markerData in ipairs(markers) do
        local newName = names[markerData.index] or names[i]
        if newName then
            markerData.preview = newName
            markerData.changed = true
            markerData.checked = true
        end
    end
    
    return true
end

-- Ripple edit markers (adjust positions)
function Markers.rippleEditMarkers(markers, timeDelta, fromPosition)
    Common.beginUndoBlock("Ripple Edit Markers")
    
    local editedCount = 0
    
    for _, markerData in ipairs(markers) do
        if markerData.position >= fromPosition then
            local newPos = markerData.position + timeDelta
            
            if newPos >= 0 then  -- Don't move before project start
                reaper.SetProjectMarker3(
                    0,
                    markerData.idx,
                    false,
                    newPos,
                    newPos,
                    markerData.name,
                    markerData.color
                )
                
                markerData.position = newPos
                editedCount = editedCount + 1
            end
        end
    end
    
    Common.endUndoBlock("Ripple Edit Markers")
    reaper.UpdateArrange()
    
    return editedCount
end

-- Renumber markers
function Markers.renumberMarkers(markers, startNumber, increment, prefix, suffix)
    Common.beginUndoBlock("Renumber Markers")
    
    startNumber = startNumber or 1
    increment = increment or 1
    prefix = prefix or ""
    suffix = suffix or ""
    
    local renumberedCount = 0
    local currentNumber = startNumber
    
    -- Sort by position first
    Markers.sortMarkers(markers, "position", true)
    
    for _, markerData in ipairs(markers) do
        if markerData.checked then
            local newName = prefix .. tostring(currentNumber) .. suffix
            
            reaper.SetProjectMarker3(
                0,
                markerData.idx,
                false,
                markerData.position,
                markerData.position,
                newName,
                markerData.color
            )
            
            markerData.name = newName
            currentNumber = currentNumber + increment
            renumberedCount = renumberedCount + 1
        end
    end
    
    Common.endUndoBlock("Renumber Markers")
    reaper.UpdateArrange()
    
    return renumberedCount
end


-- Wrapper functions for main interface compatibility
function Markers.getList()
    return Markers.getMarkerList()
end

function Markers.getListWithSelection(selectedOnly)
    if selectedOnly then
        -- First try time selection
        local start_time, end_time = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
        if end_time - start_time > 0 then
            return Markers.getMarkersInTimeSelection()
        end

        -- Then try cursor position
        local markers = Markers.getMarkersAtCursor()
        if #markers > 0 then
            return markers
        end
    end
    return Markers.getMarkerList()
end

function Markers.updatePreview(markerList, findText, replaceText, options)
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
    
    -- Update preview for each marker
    for i, marker in ipairs(markerList) do
        local newName = marker.name
        
        -- Priority 1: Templates
        if options.useTemplate and options.templateString and options.templateString ~= "" then
            local vars = Common.generateVariables(i, marker.name, {
                position = Common.formatTime(marker.position),
                markernum = marker.index
            })
            newName = Common.applyTemplate(options.templateString, vars)
        else
            -- Priority 2: Apply operation if specified
            if options.operation and options.operation ~= "none" then
                newName = Common.applyOperation(newName, options.operation, {
                    position = marker.position,
                    index = i,
                    type = "marker"
                })
            else
                -- Priority 3: Find/Replace (only if no operation)
                if findText and findText ~= "" then
                    newName = Common.replacePattern(
                        newName, 
                        findText,
                        replaceText,
                        options.caseSensitive,
                        options.wholeWord,
                        options.useLuaPatterns
                    )
                end
            end
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
        
        marker.preview = newName
        marker.changed = (newName ~= marker.name)
    end

    -- Apply auto-increment if enabled
    if options.autoIncrement then
        Common.handleDuplicateNames(markerList, true)
    end
end

function Markers.applyChanges(markerList)
    return Markers.applyMarkerRename(markerList, markerList)
end

return Markers