-- @noindex
-- DM RENAMER - Clear Region/Marker Selection
-- Clears the region/marker selection stored in ExtState.

-- Clear both region and marker selections
reaper.SetExtState("DM_RENAMER", "SelectedRegions", "", false)
reaper.SetExtState("DM_RENAMER", "SelectedMarkers", "", false)

reaper.ShowConsoleMsg("Region/Marker selection cleared\n")