-- DM RENAMER - Regions Module
-- Handles all operations related to regions

local Regions = {}

-- Load common functions
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
local Common = dofile(script_path .. "DM_RENAMER_Common.lua")

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

-- Structure for region data
local function createRegionData(idx, isRegion, pos, rgnend, name, markrgnindexnumber, color)
    if not isRegion then
        return nil  -- Skip markers in this module
    end
    
    return {
        index = markrgnindexnumber,
        idx = idx,  -- Internal Reaper index
        name = name or "",
        startPos = pos,
        endPos = rgnend,
        length = rgnend - pos,
        color = color,
        
        -- For UI display
        checked = false,
        preview = "",
        status = "",
        changed = false
    }
end

-- Get all regions in project
function Regions.getRegionList(excludeTags)
    local regions = {}
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    
    for i = 0, num_markers + num_regions - 1 do
        local _, isRegion, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
        
        if isRegion then
            -- Check if region should be excluded
            if not isExcluded(name, excludeTags) then
                local regionData = createRegionData(i, isRegion, pos, rgnend, name, markrgnindexnumber, color)
                if regionData then
                    table.insert(regions, regionData)
                end
            end
        end
    end
    
    return regions
end

-- Get regions at cursor position
function Regions.getRegionsAtCursor()
    local cursorPos = reaper.GetCursorPosition()
    local regions = {}
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)

    for i = 0, num_markers + num_regions - 1 do
        local _, isRegion, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)

        if isRegion then
            -- Check if cursor is within region
            if cursorPos >= pos and cursorPos <= rgnend then
                local regionData = createRegionData(i, isRegion, pos, rgnend, name, markrgnindexnumber, color)
                if regionData then
                    table.insert(regions, regionData)
                end
            end
        end
    end

    return regions
end

-- Get regions in time selection
function Regions.getRegionsInTimeSelection(excludeTags)
    local startTime, endTime = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    if startTime == endTime then
        return {}  -- No time selection
    end

    local regions = {}
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)

    for i = 0, num_markers + num_regions - 1 do
        local _, isRegion, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)

        if isRegion then
            -- Check if region overlaps with time selection
            if pos < endTime and rgnend > startTime then
                -- Check if region should be excluded
                if not isExcluded(name, excludeTags) then
                    local regionData = createRegionData(i, isRegion, pos, rgnend, name, markrgnindexnumber, color)
                    if regionData then
                        table.insert(regions, regionData)
                    end
                end
            end
        end
    end

    return regions
end

-- Get truly selected regions (using ExtState tracking and SWS if available)
function Regions.getSelectedRegionsList(excludeTags)
    local regions = {}
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    
    -- Method 1: Check ExtState for selected regions (set by our tracking)
    local selectedString = reaper.GetExtState("DM_RENAMER", "SelectedRegions") or ""
    local selectedIndices = {}
    
    -- Parse comma-separated indices
    for index in string.gmatch(selectedString, "([^,]+)") do
        selectedIndices[tonumber(index)] = true
    end
    
    -- Method 2: If SWS is available, check Region Manager selection
    local hasSWS = reaper.APIExists("BR_GetMouseCursorContext")
    if hasSWS and #selectedIndices == 0 then
        -- Try to get selection from Region Manager if open
        local hwnd = reaper.JS_Window_Find and reaper.JS_Window_Find("Region/Marker Manager", true)
        if hwnd then
            -- Region Manager is open, could potentially get selection from it
            -- This would require JS_ReaScriptAPI extension
        end
    end
    
    -- Collect selected regions
    for i = 0, num_markers + num_regions - 1 do
        local _, isRegion, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
        
        if isRegion and selectedIndices[markrgnindexnumber] then
            -- Check if region should be excluded
            if not isExcluded(name, excludeTags) then
                local regionData = createRegionData(i, isRegion, pos, rgnend, name, markrgnindexnumber, color)
                if regionData then
                    table.insert(regions, regionData)
                end
            end
        end
    end
    
    return regions
end

-- Track region selection (call this when regions are clicked)
function Regions.trackSelection()
    -- This function will be called from main loop to track selection changes
    if not reaper.APIExists("JS_Window_Find") then
        return  -- Need JS extension for full tracking
    end
    
    -- Get last touched region
    local markeridx, regionidx = reaper.GetLastMarkerAndCurRegion(0, reaper.GetCursorPosition())
    
    -- Store in ExtState
    if regionidx >= 0 then
        -- Check if Shift is held for multi-selection
        local shiftState = reaper.JS_Mouse_GetState and reaper.JS_Mouse_GetState(0x0004) > 0
        
        if shiftState then
            -- Add to selection
            local current = reaper.GetExtState("DM_RENAMER", "SelectedRegions") or ""
            if current == "" then
                current = tostring(regionidx)
            else
                -- Check if not already selected
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
            end
            reaper.SetExtState("DM_RENAMER", "SelectedRegions", current, false)
        else
            -- Single selection
            reaper.SetExtState("DM_RENAMER", "SelectedRegions", tostring(regionidx), false)
        end
    end
end

-- Filter regions by search pattern
function Regions.filterRegions(regions, searchPattern, options)
    if not searchPattern or searchPattern == "" then
        return regions
    end
    
    local filtered = {}
    options = options or {}
    
    for _, regionData in ipairs(regions) do
        local matches = Common.matchPattern(
            regionData.name,
            searchPattern,
            options.caseSensitive,
            options.wholeWord
        )
        
        if matches then
            regionData.status = "Match found"
            table.insert(filtered, regionData)
        elseif options.showAll then
            regionData.status = ""
            table.insert(filtered, regionData)
        end
    end
    
    return filtered
end

-- Preview rename for regions
function Regions.previewRegionRename(regions, findPattern, replacePattern, options)
    if not findPattern and not (options and options.useTemplate) then 
        return regions 
    end
    
    options = options or {}
    local previews = {}
    
    for i, regionData in ipairs(regions) do
        local newName = regionData.name
        
        if options.useTemplate then
            -- Apply template with variables
            local vars = Common.generateVariables(i, regionData.name, {
                start = Common.formatTime(regionData.startPos),
                ending = Common.formatTime(regionData.endPos),
                length = Common.formatTime(regionData.length),
                regionnum = regionData.index
            })
            newName = Common.applyTemplate(replacePattern, vars)
        else
            -- Regular find and replace
            newName = Common.replacePattern(
                regionData.name,
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
        
        regionData.preview = newName
        regionData.changed = newName ~= regionData.name
        
        table.insert(previews, regionData)
    end
    
    return previews
end

-- Apply rename to regions
function Regions.applyRegionRename(regions, changes)
    if not regions or #regions == 0 then return false, "No regions to rename" end
    
    Common.beginUndoBlock("Rename Regions")
    
    local successCount = 0
    local errorCount = 0
    local errors = {}
    
    for _, regionData in ipairs(regions) do
        if regionData.checked and regionData.changed and regionData.preview then
            -- Set region name
            local success = reaper.SetProjectMarker3(
                0,
                regionData.index,  -- Use actual region index number, not enumeration index
                true,  -- isRegion
                regionData.startPos,
                regionData.endPos,
                regionData.preview,
                regionData.color
            )
            
            if success then
                successCount = successCount + 1
                regionData.status = "Renamed"
                regionData.name = regionData.preview
            else
                errorCount = errorCount + 1
                regionData.status = "Error"
                table.insert(errors, "Failed to rename region: " .. regionData.name)
            end
        end
    end
    
    Common.endUndoBlock("Rename Regions")
    reaper.UpdateArrange()
    
    local message = string.format("Renamed %d regions", successCount)
    if errorCount > 0 then
        message = message .. string.format(", %d errors", errorCount)
        if #errors > 0 then
            message = message .. "\n\n" .. table.concat(errors, "\n")
        end
    end
    
    return successCount > 0, message
end

-- Select regions (set edit cursor to region start)
function Regions.selectRegions(regionIndices)
    if #regionIndices > 0 then
        -- Get first region's position
        local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
        
        for i = 0, num_markers + num_regions - 1 do
            local _, isRegion, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers3(0, i)
            
            if isRegion then
                for _, idx in ipairs(regionIndices) do
                    if markrgnindexnumber == idx then
                        reaper.SetEditCurPos(pos, true, false)
                        return
                    end
                end
            end
        end
    end
end

-- Go to region by index
function Regions.goToRegion(regionIndex)
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    
    for i = 0, num_markers + num_regions - 1 do
        local _, isRegion, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers3(0, i)
        
        if isRegion and markrgnindexnumber == regionIndex then
            reaper.SetEditCurPos(pos, true, false)
            -- Optionally set time selection to region
            reaper.GetSet_LoopTimeRange(true, false, pos, rgnend, false)
            return true
        end
    end
    
    return false
end

-- Set time selection to regions
function Regions.setTimeSelectionToRegions(regions)
    if not regions or #regions == 0 then return end
    
    local minStart = math.huge
    local maxEnd = -math.huge
    
    for _, regionData in ipairs(regions) do
        if regionData.checked then
            minStart = math.min(minStart, regionData.startPos)
            maxEnd = math.max(maxEnd, regionData.endPos)
        end
    end
    
    if minStart < math.huge and maxEnd > -math.huge then
        reaper.GetSet_LoopTimeRange(true, false, minStart, maxEnd, false)
    end
end

-- Check/uncheck all regions
function Regions.setAllChecked(regions, checked)
    for _, regionData in ipairs(regions) do
        regionData.checked = checked
    end
end

-- Toggle checked state
function Regions.toggleChecked(regions, index)
    if regions[index] then
        regions[index].checked = not regions[index].checked
    end
end

-- Get checked regions
function Regions.getCheckedRegions(regions)
    local checked = {}
    for _, regionData in ipairs(regions) do
        if regionData.checked then
            table.insert(checked, regionData)
        end
    end
    return checked
end

-- Sort regions
function Regions.sortRegions(regions, sortBy, ascending)
    ascending = ascending ~= false  -- Default to true
    
    table.sort(regions, function(a, b)
        local aVal, bVal
        
        if sortBy == "name" then
            aVal = a.name:lower()
            bVal = b.name:lower()
        elseif sortBy == "position" then
            aVal = a.startPos
            bVal = b.startPos
        elseif sortBy == "length" then
            aVal = a.length
            bVal = b.length
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
    
    return regions
end

-- Delete regions
function Regions.deleteRegions(regions)
    Common.beginUndoBlock("Delete Regions")
    
    local deletedCount = 0
    
    -- Delete from end to beginning to maintain indices
    local toDelete = {}
    for _, regionData in ipairs(regions) do
        if regionData.checked then
            table.insert(toDelete, regionData.idx)
        end
    end
    
    table.sort(toDelete, function(a, b) return a > b end)
    
    for _, idx in ipairs(toDelete) do
        reaper.DeleteProjectMarkerByIndex(0, idx)
        deletedCount = deletedCount + 1
    end
    
    Common.endUndoBlock("Delete Regions")
    reaper.UpdateArrange()
    
    return deletedCount
end

-- Create region from time selection
function Regions.createRegionFromTimeSelection(name, color)
    local startTime, endTime = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    
    if startTime == endTime then
        return false, "No time selection"
    end
    
    local index = reaper.AddProjectMarker2(0, true, startTime, endTime, name or "", -1, color or 0)
    
    if index >= 0 then
        return true, "Region created"
    else
        return false, "Failed to create region"
    end
end

-- Export region names to file
function Regions.exportToFile(regions, filename, exportCheckedOnly)
    local file = io.open(filename, "w")
    if not file then
        return false, "Could not open file for writing"
    end
    
    -- Write header
    file:write("Index\tName\tStart\tEnd\tLength\n")
    
    for _, regionData in ipairs(regions) do
        if not exportCheckedOnly or regionData.checked then
            file:write(string.format("%d\t%s\t%s\t%s\t%s\n",
                regionData.index,
                regionData.name,
                Common.formatTime(regionData.startPos),
                Common.formatTime(regionData.endPos),
                Common.formatTime(regionData.length)
            ))
        end
    end
    
    file:close()
    return true
end

-- Import names from file
function Regions.importFromFile(regions, filename)
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
    
    -- Apply names to regions
    for i, regionData in ipairs(regions) do
        local newName = names[regionData.index] or names[i]
        if newName then
            regionData.preview = newName
            regionData.changed = true
            regionData.checked = true
        end
    end
    
    return true
end

-- Ripple edit regions (adjust positions)
function Regions.rippleEditRegions(regions, timeDelta, fromPosition)
    Common.beginUndoBlock("Ripple Edit Regions")
    
    local editedCount = 0
    
    for _, regionData in ipairs(regions) do
        if regionData.startPos >= fromPosition then
            local newStart = regionData.startPos + timeDelta
            local newEnd = regionData.endPos + timeDelta
            
            if newStart >= 0 then  -- Don't move before project start
                reaper.SetProjectMarker3(
                    0,
                    regionData.idx,
                    true,
                    newStart,
                    newEnd,
                    regionData.name,
                    regionData.color
                )
                
                regionData.startPos = newStart
                regionData.endPos = newEnd
                editedCount = editedCount + 1
            end
        end
    end
    
    Common.endUndoBlock("Ripple Edit Regions")
    reaper.UpdateArrange()
    
    return editedCount
end


-- Wrapper functions for main interface compatibility
function Regions.getList(excludeTags)
    return Regions.getRegionList(excludeTags)
end

function Regions.getListWithSelection(selectedOnly, excludeTags)
    if selectedOnly then
        -- Check for selected regions via ExtState (will be set by selection tracking)
        local selectedRegions = Regions.getSelectedRegionsList(excludeTags)  -- NEW function
        if #selectedRegions > 0 then
            return selectedRegions
        end
        
        -- Fallback to time selection only (NOT cursor position)
        local start_time, end_time = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
        if end_time - start_time > 0 then
            return Regions.getRegionsInTimeSelection(excludeTags)
        end
    end
    return Regions.getRegionList(excludeTags)
end

function Regions.updatePreview(regionList, findText, replaceText, options)
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
    
    -- Update preview for each region
    for i, region in ipairs(regionList) do
        local newName = region.name
        
        -- Priority 1: Templates
        if options.useTemplate and options.templateString and options.templateString ~= "" then
            local vars = Common.generateVariables(i, region.name, {
                start = Common.formatTime(region.startPos),
                ending = Common.formatTime(region.endPos),
                length = Common.formatTime(region.length),
                regionnum = region.index
            })
            newName = Common.applyTemplate(options.templateString, vars)
        else
            -- Priority 2: Apply operation if specified
            if options.operation and options.operation ~= "none" then
                newName = Common.applyOperation(newName, options.operation, {
                    position = region.startPos,
                    index = i,
                    type = "region"
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
        
        region.preview = newName
        region.changed = (newName ~= region.name)
    end

    -- Apply increment mode if not "off"
    if options.incrementMode and options.incrementMode ~= "off" then
        Common.handleDuplicateNames(regionList, options.incrementMode)
    end
end

function Regions.applyChanges(regionList)
    return Regions.applyRegionRename(regionList, regionList)
end

return Regions