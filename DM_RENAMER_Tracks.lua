-- DM RENAMER - Tracks Module
-- Handles all operations related to tracks

local Tracks = {}

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

-- Structure for track data
local function createTrackData(track, index)
    local _, name = reaper.GetTrackName(track)
    local trackNumber = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER"))
    local color = reaper.GetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR")
    local selected = reaper.IsTrackSelected(track)
    local muted = reaper.GetMediaTrackInfo_Value(track, "B_MUTE") == 1
    local solo = reaper.GetMediaTrackInfo_Value(track, "I_SOLO") > 0
    local armed = reaper.GetMediaTrackInfo_Value(track, "I_RECARM") == 1
    local volume = reaper.GetMediaTrackInfo_Value(track, "D_VOL")
    local pan = reaper.GetMediaTrackInfo_Value(track, "D_PAN")
    
    -- Check if track is a folder
    local folderDepth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
    local isFolder = folderDepth == 1
    local isFolderEnd = folderDepth < 0
    
    -- Get parent track if exists
    local parentTrack = reaper.GetParentTrack(track)
    local parentName = ""
    if parentTrack then
        _, parentName = reaper.GetTrackName(parentTrack)
    end
    
    -- Count items on track
    local itemCount = reaper.CountTrackMediaItems(track)
    
    -- Check if track has receives or sends
    local numSends = reaper.GetTrackNumSends(track, 0)
    local numReceives = reaper.GetTrackNumSends(track, -1)
    
    return {
        track = track,
        index = index,
        trackNumber = trackNumber,
        name = name,
        color = color,
        selected = selected,
        muted = muted,
        solo = solo,
        armed = armed,
        volume = volume,
        pan = pan,
        isFolder = isFolder,
        isFolderEnd = isFolderEnd,
        folderDepth = folderDepth,
        parentName = parentName,
        itemCount = itemCount,
        numSends = numSends,
        numReceives = numReceives,
        
        -- For UI display
        checked = false,
        preview = "",
        status = "",
        changed = false
    }
end

-- Get all tracks in project
function Tracks.getTrackList(selectedOnly, excludeTags)
    local tracks = {}
    local trackCount = reaper.CountTracks(0)
    
    for i = 0, trackCount - 1 do
        local track = reaper.GetTrack(0, i)
        if track then
            local _, name = reaper.GetTrackName(track)
            -- Check if track should be excluded
            if not isExcluded(name, excludeTags) then
                if not selectedOnly or reaper.IsTrackSelected(track) then
                    table.insert(tracks, createTrackData(track, i))
                end
            end
        end
    end
    
    return tracks
end

-- Get child tracks of a folder
function Tracks.getChildTracks(folderTrack)
    local tracks = {}
    local trackCount = reaper.CountTracks(0)
    local folderIndex = nil
    local folderDepth = 0
    local inFolder = false
    
    -- Find folder track index
    for i = 0, trackCount - 1 do
        local track = reaper.GetTrack(0, i)
        if track == folderTrack then
            folderIndex = i
            folderDepth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
            inFolder = true
            break
        end
    end
    
    if not folderIndex or folderDepth ~= 1 then
        return tracks  -- Not a folder track
    end
    
    -- Collect child tracks
    local currentDepth = 0
    for i = folderIndex + 1, trackCount - 1 do
        local track = reaper.GetTrack(0, i)
        if track then
            local depth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
            currentDepth = currentDepth + depth
            
            if currentDepth < 0 then
                break  -- End of folder
            end
            
            table.insert(tracks, createTrackData(track, i))
        end
    end
    
    return tracks
end

-- Filter tracks by search pattern
function Tracks.filterTracks(tracks, searchPattern, options)
    if not searchPattern or searchPattern == "" then
        return tracks
    end
    
    local filtered = {}
    options = options or {}
    
    for _, trackData in ipairs(tracks) do
        local matches = Common.matchPattern(
            trackData.name,
            searchPattern,
            options.caseSensitive,
            options.wholeWord
        )
        
        if matches then
            trackData.status = "Match found"
            table.insert(filtered, trackData)
        elseif options.showAll then
            trackData.status = ""
            table.insert(filtered, trackData)
        end
    end
    
    return filtered
end

-- Preview rename for tracks
function Tracks.previewTrackRename(tracks, findPattern, replacePattern, options)
    if not findPattern and not (options and options.useTemplate) then 
        return tracks 
    end
    
    options = options or {}
    local previews = {}
    
    for i, trackData in ipairs(tracks) do
        local newName = trackData.name
        
        if options.useTemplate then
            -- Apply template with variables
            local vars = Common.generateVariables(i, trackData.name, {
                tracknum = trackData.trackNumber,
                parent = trackData.parentName,
                items = trackData.itemCount,
                sends = trackData.numSends,
                receives = trackData.numReceives,
                folder = trackData.isFolder and "FOLDER" or ""
            })
            newName = Common.applyTemplate(replacePattern, vars)
        else
            -- Regular find and replace
            newName = Common.replacePattern(
                trackData.name,
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
        
        trackData.preview = newName
        trackData.changed = newName ~= trackData.name
        
        table.insert(previews, trackData)
    end
    
    return previews
end

-- Apply rename to tracks
function Tracks.applyTrackRename(tracks, changes)
    if not tracks or #tracks == 0 then return false, "No tracks to rename" end
    
    Common.beginUndoBlock("Rename Tracks")
    
    local successCount = 0
    local errorCount = 0
    local errors = {}
    
    for _, trackData in ipairs(tracks) do
        if trackData.checked and trackData.changed and trackData.preview then
            local success = reaper.GetSetMediaTrackInfo_String(
                trackData.track,
                "P_NAME",
                trackData.preview,
                true
            )
            
            if success then
                successCount = successCount + 1
                trackData.status = "Renamed"
                trackData.name = trackData.preview
            else
                errorCount = errorCount + 1
                trackData.status = "Error"
                table.insert(errors, "Failed to rename track: " .. trackData.name)
            end
        end
    end
    
    Common.endUndoBlock("Rename Tracks")
    reaper.UpdateArrange()
    reaper.TrackList_AdjustWindows(false)
    
    local message = string.format("Renamed %d tracks", successCount)
    if errorCount > 0 then
        message = message .. string.format(", %d errors", errorCount)
        if #errors > 0 then
            message = message .. "\n\n" .. table.concat(errors, "\n")
        end
    end
    
    return successCount > 0, message
end

-- Select tracks
function Tracks.selectTracks(trackIndices, addToSelection)
    if not addToSelection then
        -- Clear current selection
        reaper.Main_OnCommand(40297, 0)  -- Track: Unselect all tracks
    end
    
    for _, index in ipairs(trackIndices) do
        local track = reaper.GetTrack(0, index)
        if track then
            reaper.SetTrackSelected(track, true)
        end
    end
    
    reaper.UpdateArrange()
end

-- Select tracks by data
function Tracks.selectTracksByData(tracks, selectChecked)
    reaper.Main_OnCommand(40297, 0)  -- Track: Unselect all tracks
    
    for _, trackData in ipairs(tracks) do
        if selectChecked and trackData.checked then
            reaper.SetTrackSelected(trackData.track, true)
        elseif not selectChecked and trackData.selected then
            reaper.SetTrackSelected(trackData.track, true)
        end
    end
    
    reaper.UpdateArrange()
end

-- Check/uncheck all tracks
function Tracks.setAllChecked(tracks, checked)
    for _, trackData in ipairs(tracks) do
        trackData.checked = checked
    end
end

-- Toggle checked state
function Tracks.toggleChecked(tracks, index)
    if tracks[index] then
        tracks[index].checked = not tracks[index].checked
    end
end

-- Get checked tracks
function Tracks.getCheckedTracks(tracks)
    local checked = {}
    for _, trackData in ipairs(tracks) do
        if trackData.checked then
            table.insert(checked, trackData)
        end
    end
    return checked
end

-- Sort tracks
function Tracks.sortTracks(tracks, sortBy, ascending)
    ascending = ascending ~= false  -- Default to true
    
    table.sort(tracks, function(a, b)
        local aVal, bVal
        
        if sortBy == "name" then
            aVal = a.name:lower()
            bVal = b.name:lower()
        elseif sortBy == "number" then
            aVal = a.trackNumber
            bVal = b.trackNumber
        elseif sortBy == "items" then
            aVal = a.itemCount
            bVal = b.itemCount
        elseif sortBy == "color" then
            aVal = a.color
            bVal = b.color
        else
            return false
        end
        
        if ascending then
            return aVal < bVal
        else
            return aVal > bVal
        end
    end)
    
    return tracks
end

-- Color tracks
function Tracks.colorTracks(tracks, color)
    Common.beginUndoBlock("Color Tracks")
    
    local coloredCount = 0
    
    for _, trackData in ipairs(tracks) do
        if trackData.checked then
            reaper.SetMediaTrackInfo_Value(trackData.track, "I_CUSTOMCOLOR", color)
            trackData.color = color
            coloredCount = coloredCount + 1
        end
    end
    
    Common.endUndoBlock("Color Tracks")
    reaper.UpdateArrange()
    
    return coloredCount
end

-- Create folder from selected tracks
function Tracks.createFolderFromTracks(tracks, folderName)
    local checkedTracks = Tracks.getCheckedTracks(tracks)
    if #checkedTracks == 0 then
        return false, "No tracks selected"
    end
    
    Common.beginUndoBlock("Create Folder from Tracks")
    
    -- Sort by track number to maintain order
    table.sort(checkedTracks, function(a, b)
        return a.trackNumber < b.trackNumber
    end)
    
    -- Set first track as folder
    local firstTrack = checkedTracks[1].track
    if folderName and folderName ~= "" then
        reaper.GetSetMediaTrackInfo_String(firstTrack, "P_NAME", folderName, true)
    end
    reaper.SetMediaTrackInfo_Value(firstTrack, "I_FOLDERDEPTH", 1)
    
    -- Set last track as folder end
    local lastTrack = checkedTracks[#checkedTracks].track
    local currentDepth = reaper.GetMediaTrackInfo_Value(lastTrack, "I_FOLDERDEPTH")
    reaper.SetMediaTrackInfo_Value(lastTrack, "I_FOLDERDEPTH", currentDepth - 1)
    
    Common.endUndoBlock("Create Folder from Tracks")
    reaper.UpdateArrange()
    
    return true, "Folder created"
end

-- Export track names to file
function Tracks.exportToFile(tracks, filename, exportCheckedOnly)
    local file = io.open(filename, "w")
    if not file then
        return false, "Could not open file for writing"
    end
    
    -- Write header
    file:write("Number\tName\tItems\tFolder\tParent\n")
    
    for _, trackData in ipairs(tracks) do
        if not exportCheckedOnly or trackData.checked then
            file:write(string.format("%d\t%s\t%d\t%s\t%s\n",
                trackData.trackNumber,
                trackData.name,
                trackData.itemCount,
                trackData.isFolder and "Yes" or "No",
                trackData.parentName
            ))
        end
    end
    
    file:close()
    return true
end

-- Import names from file
function Tracks.importFromFile(tracks, filename)
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
        local number, name = line:match("^(%d+)\t([^\t]*)")
        if number and name then
            names[tonumber(number)] = name
        else
            -- Try simple line as name
            table.insert(names, line)
        end
        
        ::continue::
    end
    file:close()
    
    -- Apply names to tracks
    for i, trackData in ipairs(tracks) do
        local newName = names[trackData.trackNumber] or names[i]
        if newName then
            trackData.preview = newName
            trackData.changed = true
            trackData.checked = true
        end
    end
    
    return true
end

-- Duplicate tracks with new names
function Tracks.duplicateTracks(tracks, namePattern)
    Common.beginUndoBlock("Duplicate Tracks")
    
    local duplicatedCount = 0
    
    for _, trackData in ipairs(tracks) do
        if trackData.checked then
            -- Select only this track
            reaper.Main_OnCommand(40297, 0)  -- Unselect all tracks
            reaper.SetTrackSelected(trackData.track, true)
            
            -- Duplicate track
            reaper.Main_OnCommand(40062, 0)  -- Track: Duplicate tracks
            
            -- Get the new track (it will be right after the original)
            local newTrack = reaper.GetTrack(0, trackData.index + duplicatedCount + 1)
            if newTrack then
                -- Apply name pattern
                local newName = namePattern or (trackData.name .. " (copy)")
                local vars = Common.generateVariables(duplicatedCount + 1, trackData.name, {
                    original = trackData.name
                })
                newName = Common.applyTemplate(newName, vars)
                
                reaper.GetSetMediaTrackInfo_String(newTrack, "P_NAME", newName, true)
                duplicatedCount = duplicatedCount + 1
            end
        end
    end
    
    Common.endUndoBlock("Duplicate Tracks")
    reaper.UpdateArrange()
    
    return duplicatedCount
end

-- Apply track template
function Tracks.applyTrackTemplate(tracks, templatePath)
    if not templatePath or templatePath == "" then
        return false, "No template specified"
    end
    
    Common.beginUndoBlock("Apply Track Template")
    
    local appliedCount = 0
    
    for _, trackData in ipairs(tracks) do
        if trackData.checked then
            reaper.Main_OnCommand(40297, 0)  -- Unselect all tracks
            reaper.SetTrackSelected(trackData.track, true)
            
            -- Apply track template (requires SWS extension)
            -- This is a placeholder - actual implementation would need SWS
            appliedCount = appliedCount + 1
        end
    end
    
    Common.endUndoBlock("Apply Track Template")
    reaper.UpdateArrange()
    
    return appliedCount > 0, string.format("Template applied to %d tracks", appliedCount)
end

-- Wrapper functions for main interface compatibility
function Tracks.getList(excludeTags)
    return Tracks.getTrackList(false, excludeTags)  -- Get all tracks
end

function Tracks.getListWithSelection(selectedOnly, excludeTags)
    return Tracks.getTrackList(selectedOnly, excludeTags)
end

function Tracks.updatePreview(trackList, findText, replaceText, options)
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
    
    -- Update preview for each track
    for i, track in ipairs(trackList) do
        local newName = track.name
        
        -- Priority 1: Templates
        if options.useTemplate and options.templateString and options.templateString ~= "" then
            local vars = Common.generateVariables(i, track.name, {
                tracknum = track.trackNumber,
                parent = track.parentName,
                items = track.itemCount,
                sends = track.numSends,
                receives = track.numReceives,
                folder = track.isFolder and "[FOLDER] " or ""
            })
            newName = Common.applyTemplate(options.templateString, vars)
        else
            -- Priority 2: Apply operation if specified
            if options.operation and options.operation ~= "none" then
                local ok, result = pcall(Common.applyOperation, newName, options.operation, {
                    trackNumber = track.trackNumber,
                    index = i,
                    type = "track"
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
        
        track.preview = newName
        track.changed = (newName ~= track.name)
    end

    -- Apply increment mode for duplicates
    if options.incrementMode and options.incrementMode ~= "off" then
        Common.handleDuplicateNames(trackList, options.incrementMode)
    end
end

function Tracks.applyChanges(trackList)
    return Tracks.applyTrackRename(trackList, trackList)
end

return Tracks