-- @noindex
-- DM RENAMER - Apply to Selected Folder Items
-- Standalone action: applies the running renamer's current settings to the
-- currently-selected folder items, reusing the tool's existing Apply path.
-- It never renames on its own and never launches the window; it only signals
-- the running window via the DM_RENAMER ExtState namespace.

local script_path = debug.getinfo(1, 'S').source:match[[^@?(.*[\/])[^\/]-$]]
local FolderItems = dofile(script_path .. "DM_RENAMER_FolderItems.lua")

-- Guard 1 (highest precedence): is at least one folder item selected?
-- Reuse FolderItems.isEmptyItem as the single source of truth for "folder item".
local hasFolderItemSelected = false
local selCount = reaper.CountSelectedMediaItems(0)
for i = 0, selCount - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    if item and FolderItems.isEmptyItem(item) then
        hasFolderItemSelected = true
        break
    end
end

-- Nothing applicable selected => true no-op (no rename, no signal, no console),
-- whether or not the tool is running.
if not hasFolderItemSelected then
    return
end

-- Guard 2: the Folder Items feature must be enabled. getFolderItemUser stores
-- "true" (enabled), "false" (hidden) or is unset/"undecided" (never onboarded).
-- Only proceed when explicitly enabled; otherwise tell the user how to enable it
-- rather than renaming behind a hidden/undecided tab.
if reaper.GetExtState("DM_RENAMER", "folderItemUser") ~= "true" then
    reaper.ShowConsoleMsg(
        "The Folder Items tab is not enabled.\n" ..
        "Enable it in DM Batch Renamer to use this action.\n")
    return
end

-- Something to act on: apply if the window is running, otherwise prompt to launch.
if reaper.GetExtState("DM_RENAMER", "Running") == "1" then
    -- One-shot apply signal; the running window consumes it on its next frame.
    reaper.SetExtState("DM_RENAMER", "ApplyFolderItems", "1", false)
else
    reaper.ShowConsoleMsg(
        "DM Batch Renamer is not running.\n" ..
        "Please launch DM Batch Renamer to apply folder item renaming.\n")
end
