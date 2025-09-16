-- DM RENAMER - Settings Module
-- Manages user preferences and persistent settings

local Settings = {}

-- Settings key for ExtState
local EXTSTATE_SECTION = "DM_RENAMER"

-- Default settings structure
function Settings.getDefaultSettings()
    return {
        -- Window settings
        window = {
            x = nil,  -- Will center on first run
            y = nil,
            width = 900,
            height = 600,
            docked = false
        },
        
        -- Current tab
        currentTab = "Items",
        
        -- Search options
        search = {
            caseSensitive = false,
            useRegex = false,
            wholeWord = false,
            autoPreview = true,
            searchInSelection = false
        },
        
        -- Replace options
        replace = {
            preserveCase = false,
            useVariables = true,
            confirmBatch = true
        },
        
        -- Display options
        display = {
            showPreview = true,
            showOnlyMatches = false,
            columnWidths = {
                checkbox = 30,
                current = 300,
                preview = 300,
                status = 100
            },
            fontSize = 14,
            theme = "dark"
        },
        
        -- History
        history = {
            maxRecentSearches = 20,
            maxRecentReplaces = 20,
            recentSearches = {},
            recentReplaces = {},
            lastUsedTemplates = {}
        },
        
        -- Numbering options
        numbering = {
            startNumber = 1,
            increment = 1,
            padding = 2,
            prefix = "",
            suffix = "",
            position = "suffix"  -- prefix, suffix, replace
        },
        
        -- Case change options
        caseChange = {
            type = "none"  -- none, upper, lower, title, camel, snake, kebab
        },
        
        -- Advanced options
        advanced = {
            maxUndoSteps = 100,
            backupBeforeApply = false,
            logOperations = false,
            showTooltips = true
        },
        
        -- Folder Items options
        folderItems = {
            pattern = "hierarchical",
            separator = "_",
            customPattern = "{region}_{track}",
            autoIncrement = true,
            excludeTag = "//"
        }
    }
end

-- Current settings instance
Settings.current = Settings.getDefaultSettings()

-- Serialize table to string
local function serializeTable(tbl, indent)
    indent = indent or 0
    local spaces = string.rep("  ", indent)
    local result = "{\n"
    
    for k, v in pairs(tbl) do
        result = result .. spaces .. "  "
        
        -- Handle key
        if type(k) == "string" then
            result = result .. '["' .. k .. '"] = '
        else
            result = result .. "[" .. tostring(k) .. "] = "
        end
        
        -- Handle value
        if type(v) == "table" then
            result = result .. serializeTable(v, indent + 1)
        elseif type(v) == "string" then
            result = result .. '"' .. v:gsub('"', '\\"') .. '"'
        elseif type(v) == "boolean" then
            result = result .. tostring(v)
        elseif type(v) == "number" then
            result = result .. tostring(v)
        else
            result = result .. "nil"
        end
        
        result = result .. ",\n"
    end
    
    result = result .. spaces .. "}"
    return result
end

-- Deserialize string to table
local function deserializeTable(str)
    if not str or str == "" then
        return nil
    end
    
    -- Create safe environment for loading
    local env = {}
    local fn, err = load("return " .. str, "settings", "t", env)
    
    if not fn then
        return nil, err
    end
    
    local success, result = pcall(fn)
    if success then
        return result
    else
        return nil, result
    end
end

-- Deep merge tables (b overwrites a)
local function deepMerge(a, b)
    if type(b) ~= "table" then return b end
    if type(a) ~= "table" then return b end
    
    local result = {}
    for k, v in pairs(a) do
        result[k] = v
    end
    
    for k, v in pairs(b) do
        if type(v) == "table" and type(result[k]) == "table" then
            result[k] = deepMerge(result[k], v)
        else
            result[k] = v
        end
    end
    
    return result
end

-- Save settings to ExtState
function Settings.save()
    local serialized = serializeTable(Settings.current)
    reaper.SetExtState(EXTSTATE_SECTION, "settings", serialized, true)
    
    -- Save individual frequently accessed values for quick access
    reaper.SetExtState(EXTSTATE_SECTION, "lastTab", Settings.current.currentTab, true)
    
    -- Save window position
    if Settings.current.window.x then
        reaper.SetExtState(EXTSTATE_SECTION, "windowPos", 
            string.format("%d,%d,%d,%d", 
                Settings.current.window.x,
                Settings.current.window.y,
                Settings.current.window.width,
                Settings.current.window.height), 
            true)
    end
end

-- Load settings from ExtState
function Settings.load()
    local serialized = reaper.GetExtState(EXTSTATE_SECTION, "settings")
    
    if serialized and serialized ~= "" then
        local loaded = deserializeTable(serialized)
        if loaded then
            -- Merge with defaults to ensure all keys exist
            Settings.current = deepMerge(Settings.getDefaultSettings(), loaded)
        else
            Settings.current = Settings.getDefaultSettings()
        end
    else
        Settings.current = Settings.getDefaultSettings()
    end
    
    return Settings.current
end

-- Add to search history
function Settings.addSearchHistory(searchTerm)
    if not searchTerm or searchTerm == "" then return end
    
    local history = Settings.current.history.recentSearches
    
    -- Remove if already exists
    for i = #history, 1, -1 do
        if history[i] == searchTerm then
            table.remove(history, i)
        end
    end
    
    -- Add to beginning
    table.insert(history, 1, searchTerm)
    
    -- Limit size
    while #history > Settings.current.history.maxRecentSearches do
        table.remove(history)
    end
    
    Settings.save()
end

-- Add to replace history
function Settings.addReplaceHistory(replaceTerm)
    if not replaceTerm then return end  -- Allow empty string for clearing
    
    local history = Settings.current.history.recentReplaces
    
    -- Remove if already exists
    for i = #history, 1, -1 do
        if history[i] == replaceTerm then
            table.remove(history, i)
        end
    end
    
    -- Add to beginning
    table.insert(history, 1, replaceTerm)
    
    -- Limit size
    while #history > Settings.current.history.maxRecentReplaces do
        table.remove(history)
    end
    
    Settings.save()
end

-- Get search history
function Settings.getSearchHistory()
    return Settings.current.history.recentSearches or {}
end

-- Get replace history
function Settings.getReplaceHistory()
    return Settings.current.history.recentReplaces or {}
end

-- Clear history
function Settings.clearHistory(historyType)
    if historyType == "search" or historyType == "all" then
        Settings.current.history.recentSearches = {}
    end
    if historyType == "replace" or historyType == "all" then
        Settings.current.history.recentReplaces = {}
    end
    Settings.save()
end

-- Update window position
function Settings.updateWindowPosition(x, y, w, h)
    Settings.current.window.x = x
    Settings.current.window.y = y
    Settings.current.window.width = w
    Settings.current.window.height = h
    -- Don't save immediately, will be saved on window close
end

-- Get window position
function Settings.getWindowPosition()
    local w = Settings.current.window
    return w.x, w.y, w.width, w.height
end

-- Update search option
function Settings.setSearchOption(option, value)
    if Settings.current.search[option] ~= nil then
        Settings.current.search[option] = value
        Settings.save()
    end
end

-- Get search option
function Settings.getSearchOption(option)
    return Settings.current.search[option]
end

-- Update replace option
function Settings.setReplaceOption(option, value)
    if Settings.current.replace[option] ~= nil then
        Settings.current.replace[option] = value
        Settings.save()
    end
end

-- Get replace option
function Settings.getReplaceOption(option)
    return Settings.current.replace[option]
end

-- Set current tab
function Settings.setCurrentTab(tab)
    Settings.current.currentTab = tab
    Settings.save()
end

-- Get current tab
function Settings.getCurrentTab()
    return Settings.current.currentTab or "Items"
end

-- Update display option
function Settings.setDisplayOption(option, value)
    if Settings.current.display[option] ~= nil then
        Settings.current.display[option] = value
        Settings.save()
    end
end

-- Get display option
function Settings.getDisplayOption(option)
    return Settings.current.display[option]
end

-- Update column width
function Settings.setColumnWidth(column, width)
    if Settings.current.display.columnWidths[column] then
        Settings.current.display.columnWidths[column] = width
        -- Don't save immediately for performance
    end
end

-- Get column widths
function Settings.getColumnWidths()
    return Settings.current.display.columnWidths
end

-- Save column widths (call when done resizing)
function Settings.saveColumnWidths()
    Settings.save()
end

-- Reset settings to defaults
function Settings.reset()
    Settings.current = Settings.getDefaultSettings()
    Settings.save()
end

-- Export settings to file
function Settings.exportToFile(filename)
    local file = io.open(filename, "w")
    if not file then
        return false, "Could not open file for writing"
    end
    
    file:write(serializeTable(Settings.current))
    file:close()
    
    return true
end

-- Import settings from file
function Settings.importFromFile(filename)
    local file = io.open(filename, "r")
    if not file then
        return false, "Could not open file for reading"
    end
    
    local content = file:read("*all")
    file:close()
    
    local loaded = deserializeTable(content)
    if loaded then
        Settings.current = deepMerge(Settings.getDefaultSettings(), loaded)
        Settings.save()
        return true
    else
        return false, "Invalid settings file"
    end
end

-- Initialize settings on module load
Settings.load()

return Settings