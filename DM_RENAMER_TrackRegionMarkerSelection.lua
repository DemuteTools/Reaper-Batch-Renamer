-- DM RENAMER - Track Region/Marker Selection
-- This script tracks region/marker selection and stores in ExtState
-- Bind this to a toolbar button or mouse modifier for region/marker clicking

-- Get mouse position
local x, y = reaper.GetMousePosition()

-- Try to get what's under the mouse using SWS
if reaper.APIExists("BR_GetMouseCursorContext") then
    local window, segment, details = reaper.BR_GetMouseCursorContext()
    local mousePos = reaper.BR_GetMouseCursorContext_Position and reaper.BR_GetMouseCursorContext_Position() or reaper.GetCursorPosition()
    
    -- Get the marker/region at this position
    local markeridx, regionidx = reaper.GetLastMarkerAndCurRegion(0, mousePos)
    
    -- Check for Shift modifier
    local shiftState = reaper.JS_Mouse_GetState and reaper.JS_Mouse_GetState(0x0004) > 0 or false
    
    if regionidx >= 0 then
        -- Handle region selection
        local current = reaper.GetExtState("DM_RENAMER", "SelectedRegions") or ""
        
        if shiftState and current ~= "" then
            -- Multi-selection: toggle selection
            local newSelection = {}
            local found = false
            
            for index in string.gmatch(current, "([^,]+)") do
                local idx = tonumber(index)
                if idx == regionidx then
                    found = true
                    -- Don't add it (toggle off)
                else
                    table.insert(newSelection, index)
                end
            end
            
            if not found then
                -- Add to selection
                table.insert(newSelection, tostring(regionidx))
            end
            
            current = table.concat(newSelection, ",")
        else
            -- Single selection
            current = tostring(regionidx)
        end
        
        reaper.SetExtState("DM_RENAMER", "SelectedRegions", current, false)
        
        -- Clear marker selection
        if not shiftState then
            reaper.SetExtState("DM_RENAMER", "SelectedMarkers", "", false)
        end
        
    elseif markeridx >= 0 then
        -- Handle marker selection
        local current = reaper.GetExtState("DM_RENAMER", "SelectedMarkers") or ""
        
        if shiftState and current ~= "" then
            -- Multi-selection: toggle selection
            local newSelection = {}
            local found = false
            
            for index in string.gmatch(current, "([^,]+)") do
                local idx = tonumber(index)
                if idx == markeridx then
                    found = true
                    -- Don't add it (toggle off)
                else
                    table.insert(newSelection, index)
                end
            end
            
            if not found then
                -- Add to selection
                table.insert(newSelection, tostring(markeridx))
            end
            
            current = table.concat(newSelection, ",")
        else
            -- Single selection
            current = tostring(markeridx)
        end
        
        reaper.SetExtState("DM_RENAMER", "SelectedMarkers", current, false)
        
        -- Clear region selection
        if not shiftState then
            reaper.SetExtState("DM_RENAMER", "SelectedRegions", "", false)
        end
    else
        -- No region or marker found - clear selection if not shift
        if not shiftState then
            reaper.SetExtState("DM_RENAMER", "SelectedRegions", "", false)
            reaper.SetExtState("DM_RENAMER", "SelectedMarkers", "", false)
        end
    end
else
    -- Fallback without SWS - use cursor position
    local cursorPos = reaper.GetCursorPosition()
    local markeridx, regionidx = reaper.GetLastMarkerAndCurRegion(0, cursorPos)
    
    if regionidx >= 0 then
        reaper.SetExtState("DM_RENAMER", "SelectedRegions", tostring(regionidx), false)
        reaper.SetExtState("DM_RENAMER", "SelectedMarkers", "", false)
    elseif markeridx >= 0 then
        reaper.SetExtState("DM_RENAMER", "SelectedMarkers", tostring(markeridx), false)
        reaper.SetExtState("DM_RENAMER", "SelectedRegions", "", false)
    end
end

-- Optional: Show feedback
local selectedRegions = reaper.GetExtState("DM_RENAMER", "SelectedRegions") or ""
local selectedMarkers = reaper.GetExtState("DM_RENAMER", "SelectedMarkers") or ""

if selectedRegions ~= "" then
    reaper.ShowConsoleMsg("Selected regions: " .. selectedRegions .. "\n")
elseif selectedMarkers ~= "" then
    reaper.ShowConsoleMsg("Selected markers: " .. selectedMarkers .. "\n")
else
    reaper.ShowConsoleMsg("No regions/markers selected\n")
end