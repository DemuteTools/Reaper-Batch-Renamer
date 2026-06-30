-- @noindex
-- DM RENAMER - All Module
-- Combines all element types in a single view

local All = {}

-- Load modules
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
local Common = dofile(script_path .. "DM_RENAMER_Common.lua")
local Items = dofile(script_path .. "DM_RENAMER_Items.lua")
local Regions = dofile(script_path .. "DM_RENAMER_Regions.lua")
local Markers = dofile(script_path .. "DM_RENAMER_Markers.lua")
local Tracks = dofile(script_path .. "DM_RENAMER_Tracks.lua")
local FolderItems = dofile(script_path .. "DM_RENAMER_FolderItems.lua")

function All.getList(excludeTags)
    local allItems = {}

    -- Get all media items (excluding folder items)
    local items = Items.getList(excludeTags)
    for _, item in ipairs(items) do
        item.type = "Media Item"
        item.sortName = item.name
        item.contextInfo = item.trackName or ""
        table.insert(allItems, item)
    end

    -- Get all folder items
    local folderItems = FolderItems.getList(excludeTags)
    for _, item in ipairs(folderItems) do
        item.type = "Folder Item"
        item.sortName = item.name
        -- contextInfo already set by FolderItems module
        table.insert(allItems, item)
    end

    -- Get all regions
    local regions = Regions.getList(excludeTags)
    for _, region in ipairs(regions) do
        region.type = "Region"
        region.sortName = region.name
        region.contextInfo = string.format("%.2f - %.2f", region.startPos, region.endPos)
        table.insert(allItems, region)
    end

    -- Get all markers
    local markers = Markers.getList(excludeTags)
    for _, marker in ipairs(markers) do
        marker.type = "Marker"
        marker.sortName = marker.name
        marker.contextInfo = string.format("%.2f", marker.position)
        table.insert(allItems, marker)
    end

    -- Get all tracks
    local tracks = Tracks.getList(excludeTags)
    for _, track in ipairs(tracks) do
        track.type = "Track"
        track.sortName = track.name
        track.contextInfo = "Track " .. track.trackNumber
        table.insert(allItems, track)
    end

    return allItems
end

function All.getListWithSelection(selectedOnly, excludeTags)
    local allItems = {}

    -- Get media items with selection
    local items = Items.getListWithSelection(selectedOnly, excludeTags)
    for _, item in ipairs(items) do
        item.type = "Media Item"
        item.sortName = item.name
        item.contextInfo = item.trackName or ""
        table.insert(allItems, item)
    end

    -- Get folder items with selection
    local folderItems = FolderItems.getListWithSelection(selectedOnly, excludeTags)
    for _, item in ipairs(folderItems) do
        item.type = "Folder Item"
        item.sortName = item.name
        table.insert(allItems, item)
    end

    -- Get regions with selection
    local regions = Regions.getListWithSelection(selectedOnly, excludeTags)
    for _, region in ipairs(regions) do
        region.type = "Region"
        region.sortName = region.name
        region.contextInfo = string.format("%.2f - %.2f", region.startPos, region.endPos)
        table.insert(allItems, region)
    end

    -- Get markers with selection
    local markers = Markers.getListWithSelection(selectedOnly, excludeTags)
    for _, marker in ipairs(markers) do
        marker.type = "Marker"
        marker.sortName = marker.name
        marker.contextInfo = string.format("%.2f", marker.position)
        table.insert(allItems, marker)
    end

    -- Get tracks with selection
    local tracks = Tracks.getListWithSelection(selectedOnly, excludeTags)
    for _, track in ipairs(tracks) do
        track.type = "Track"
        track.sortName = track.name
        track.contextInfo = "Track " .. track.trackNumber
        table.insert(allItems, track)
    end

    return allItems
end

function All.updatePreview(list, findText, replaceText, options)
    -- Group items by type for efficient processing
    local itemsByType = {
        ["Media Item"] = {},
        ["Folder Item"] = {},
        ["Region"] = {},
        ["Marker"] = {},
        ["Track"] = {}
    }

    for _, item in ipairs(list) do
        if itemsByType[item.type] then
            table.insert(itemsByType[item.type], item)
        end
    end

    -- Update preview for each type
    if #itemsByType["Media Item"] > 0 then
        Items.updatePreview(itemsByType["Media Item"], findText, replaceText, options)
    end
    if #itemsByType["Folder Item"] > 0 then
        if options.folderItemPattern then
            FolderItems.updatePreview(itemsByType["Folder Item"], options.folderItemPattern, options)
        else
            -- Apply regular transformations to folder items
            for _, item in ipairs(itemsByType["Folder Item"]) do
                local preview = item.name or item.notes or ""
                preview = Common.applyTransformation(preview, findText, replaceText, options)
                
                -- Apply space replacement if configured
                if options.spaceReplacement and options.spaceReplacement ~= "" then
                    if options.spaceReplacement == "remove" then
                        preview = preview:gsub("%s+", "")
                    elseif options.spaceReplacement == "_" then
                        preview = preview:gsub("%s+", "_")
                    elseif options.spaceReplacement == "-" then
                        preview = preview:gsub("%s+", "-")
                    end
                end
                
                item.preview = preview
                item.changed = preview ~= (item.name or item.notes or "")
            end
        end
    end
    if #itemsByType["Region"] > 0 then
        Regions.updatePreview(itemsByType["Region"], findText, replaceText, options)
    end
    if #itemsByType["Marker"] > 0 then
        Markers.updatePreview(itemsByType["Marker"], findText, replaceText, options)
    end
    if #itemsByType["Track"] > 0 then
        Tracks.updatePreview(itemsByType["Track"], findText, replaceText, options)
    end

    -- Apply increment mode if not "off"
    if options.incrementMode and options.incrementMode ~= "off" then
        Common.handleDuplicateNames(list, options.incrementMode, nil, options.incrementPadding)
    end
end

function All.applyChanges(list)
    -- Group by type for batch processing
    local itemsByType = {
        ["Media Item"] = {},
        ["Folder Item"] = {},
        ["Region"] = {},
        ["Marker"] = {},
        ["Track"] = {}
    }

    for _, item in ipairs(list) do
        if item.checked and item.changed and itemsByType[item.type] then
            table.insert(itemsByType[item.type], item)
        end
    end

    -- Apply changes by type
    reaper.Undo_BeginBlock()

    if #itemsByType["Media Item"] > 0 then
        Items.applyChanges(itemsByType["Media Item"])
    end
    if #itemsByType["Folder Item"] > 0 then
        FolderItems.applyChanges(itemsByType["Folder Item"])
    end
    if #itemsByType["Region"] > 0 then
        Regions.applyChanges(itemsByType["Region"])
    end
    if #itemsByType["Marker"] > 0 then
        Markers.applyChanges(itemsByType["Marker"])
    end
    if #itemsByType["Track"] > 0 then
        Tracks.applyChanges(itemsByType["Track"])
    end

    reaper.Undo_EndBlock("DM Renamer - Apply All Changes", -1)
end

return All