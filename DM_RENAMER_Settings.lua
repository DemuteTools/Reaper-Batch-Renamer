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
        },
        
        -- UI Appearance settings
        appearance = {
            -- Colors (in 0xRRGGBBAA format)
            buttonColor = 0x15856DFF,         -- Default blue-green buttons
            buttonHoverColor = 0x7D7D7DFF,   -- Auto-calculated from buttonColor
            backgroundColor = 0x2E2E2EFF,     -- Dark gray background
            frameColor = 0x3A3A3AFF,          -- Frame background color
            textColor = 0xD5D5D5FF,           -- Light gray text
            highlightColor = 0x4CAF50FF,      -- Auto-calculated from buttonColor
            headerColor = 0x454545FF,         -- Legacy - now uses dynamic selection color
            
            -- Style settings
            uiRounding = 3.0,                 -- UI elements rounding (buttons, inputs)
            frameRounding = 4.0,              -- Window rounding
            itemSpacing = 4.0,                -- Space between items
            windowPadding = 10.0,             -- Window padding
            
            -- Scale/Zoom settings
            uiScale = 1.0,                    -- Global UI scale (0.5-2.0)
            fontSize = 14,                    -- Base font size
            useCustomFont = false,            -- Enable custom font
            customFontPath = ""               -- Path to custom font file
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

-- Update appearance option
function Settings.setAppearanceOption(option, value)
    if Settings.current.appearance[option] ~= nil then
        Settings.current.appearance[option] = value
        Settings.save()
    end
end

-- Get appearance option
function Settings.getAppearanceOption(option)
    return Settings.current.appearance[option]
end

-- Get all appearance settings
function Settings.getAppearanceSettings()
    return Settings.current.appearance
end

-- Convert hex color (0xRRGGBBAA) to RGBA components (0-1 for ImGui)
function Settings.colorToRGBA(color)
    -- Convert string to number if necessary
    if type(color) == "string" then
        color = tonumber(color)
    end
    -- Check that the color is a number
    if type(color) ~= "number" then
        -- Default value in case of error (opaque white)
        return 1, 1, 1, 1
    end
    -- Extract components using bitwise operations
    local r = (color >> 24) & 0xFF
    local g = (color >> 16) & 0xFF
    local b = (color >> 8) & 0xFF
    local a = color & 0xFF
    return r/255, g/255, b/255, a/255
end

-- Convert RGBA components (0-1) to hex color (0xRRGGBBAA)
function Settings.rgbaToColor(r, g, b, a)
    r = math.floor(r * 255)
    g = math.floor(g * 255)
    b = math.floor(b * 255)
    a = math.floor((a or 1) * 255)
    return (r << 24) | (g << 16) | (b << 8) | a
end

-- Generate a lighter shade of a color
function Settings.generateLighterShade(baseColor, factor)
    factor = factor or 0.2  -- Default 20% lighter
    local r, g, b, a = Settings.colorToRGBA(baseColor)
    
    -- Increase lightness by moving towards white
    r = math.min(1, r + (1 - r) * factor)
    g = math.min(1, g + (1 - g) * factor)
    b = math.min(1, b + (1 - b) * factor)
    
    return Settings.rgbaToColor(r, g, b, a)
end

-- Generate a darker shade of a color
function Settings.generateDarkerShade(baseColor, factor)
    factor = factor or 0.2  -- Default 20% darker
    local r, g, b, a = Settings.colorToRGBA(baseColor)
    
    -- Decrease lightness by moving towards black
    r = math.max(0, r * (1 - factor))
    g = math.max(0, g * (1 - factor))
    b = math.max(0, b * (1 - factor))
    
    return Settings.rgbaToColor(r, g, b, a)
end

-- Generate a highlight shade (more saturated/lighter)
function Settings.generateHighlightShade(baseColor)
    local r, g, b, a = Settings.colorToRGBA(baseColor)
    
    -- Find the max and min components
    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    
    -- Increase saturation and brightness
    local saturationBoost = 0.3
    local brightnessBoost = 0.25
    
    -- Boost saturation by moving away from gray
    local gray = (r + g + b) / 3
    r = r + (r - gray) * saturationBoost
    g = g + (g - gray) * saturationBoost
    b = b + (b - gray) * saturationBoost
    
    -- Boost brightness
    r = math.min(1, r + brightnessBoost)
    g = math.min(1, g + brightnessBoost)
    b = math.min(1, b + brightnessBoost)
    
    return Settings.rgbaToColor(r, g, b, a)
end

-- Generate hover color from button color
function Settings.getHoverColor(buttonColor)
    return Settings.generateLighterShade(buttonColor, 0.2)
end

-- Generate highlight/active color from button color
function Settings.getHighlightColor(buttonColor)
    return Settings.generateHighlightShade(buttonColor)
end

-- Generate a subtle selection color from button color
function Settings.getSelectionColor(buttonColor)
    -- Create a very subtle tint of the button color for selected items
    local r, g, b, a = Settings.colorToRGBA(buttonColor)
    
    -- Get background color for mixing
    local bgColor = Settings.current.appearance.backgroundColor or 0x2E2E2EFF
    local bgR, bgG, bgB, bgA = Settings.colorToRGBA(bgColor)
    
    -- Mix colors: 30% button color, 70% background for subtlety
    r = bgR * 0.7 + r * 0.3
    g = bgG * 0.7 + g * 0.3
    b = bgB * 0.7 + b * 0.3
    
    return Settings.rgbaToColor(r, g, b, a)
end

-- Ensure appearance settings exist (for backwards compatibility)
function Settings.ensureAppearanceSettings()
    if not Settings.current.appearance then
        local defaultButtonColor = 0x15856DFF
        Settings.current.appearance = {
            -- Colors (in 0xRRGGBBAA format)
            buttonColor = defaultButtonColor,         -- Default blue-green buttons
            buttonHoverColor = Settings.getHoverColor(defaultButtonColor),   -- Auto-calculated
            backgroundColor = 0x2E2E2EFF,     -- Dark gray background
            frameColor = 0x3A3A3AFF,          -- Frame background color
            textColor = 0xD5D5D5FF,           -- Light gray text
            highlightColor = Settings.getHighlightColor(defaultButtonColor),      -- Auto-calculated
            headerColor = 0x454545FF,         -- Legacy - now uses dynamic selection color
            
            -- Style settings
            uiRounding = 3.0,                 -- UI elements rounding (buttons, inputs)
            frameRounding = 4.0,              -- Window rounding
            itemSpacing = 4.0,                -- Space between items
            windowPadding = 10.0,             -- Window padding
            
            -- Scale/Zoom settings
            uiScale = 1.0,                    -- Global UI scale (0.5-2.0)
            fontSize = 14,                    -- Base font size
            useCustomFont = false,            -- Enable custom font
            customFontPath = ""               -- Path to custom font file
        }
        Settings.save()
    else
        -- Ensure all fields exist
        local defaults = Settings.getDefaultSettings().appearance
        for k, v in pairs(defaults) do
            if Settings.current.appearance[k] == nil then
                Settings.current.appearance[k] = v
            end
        end
    end
end

-- Initialize settings on module load
Settings.load()
Settings.ensureAppearanceSettings()

return Settings