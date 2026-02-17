-- @noindex
-- DM RENAMER - Settings UI Module
-- Handles the user interface for settings configuration

local SettingsUI = {}

-- Module dependencies (will be set by init)
local Settings = nil
local ctx = nil
local reaper = reaper

-- Temporary variables for sliders (avoids constant saves)
local tempSettings = {}
local originalSettings = {}
local settingsWindowOpen = false

-- Initialize the module
function SettingsUI.init(settingsModule, imguiContext)
    Settings = settingsModule
    ctx = imguiContext
end

-- Initialize temporary settings if necessary
local function initTempSettings()
    if not tempSettings.initialized then
        -- Load current settings and create temp copies
        local appearance = Settings.getAppearanceSettings()
        
        -- Save original values
        originalSettings = {}
        for k, v in pairs(appearance) do
            originalSettings[k] = v
            tempSettings[k] = v
        end
        
        tempSettings.initialized = true
    end
end

-- Reset temporary settings
local function resetTempSettings()
    tempSettings = {}
    originalSettings = {}
end

-- Restore original settings (for Cancel)
local function restoreOriginalSettings()
    if originalSettings then
        for k, v in pairs(originalSettings) do
            Settings.setAppearanceOption(k, v)
        end
    end
end

-- Apply all temporary changes to the real settings
local function applyTempSettings()
    for k, v in pairs(tempSettings) do
        if k ~= "initialized" then
            Settings.setAppearanceOption(k, v)
        end
    end
    Settings.save()
end

-- Color picker helper
local function colorPicker(label, tempKey)
    local currentColor = tempSettings[tempKey]
    local rv, newColor = reaper.ImGui_ColorEdit4(ctx, label, currentColor, 
        reaper.ImGui_ColorEditFlags_AlphaBar() | 
        reaper.ImGui_ColorEditFlags_AlphaPreviewHalf())
    
    if rv then
        tempSettings[tempKey] = newColor
        -- Apply immediately for live preview
        Settings.setAppearanceOption(tempKey, newColor)
        
        -- If button color changed, update hover and highlight colors automatically
        if tempKey == "buttonColor" then
            tempSettings.buttonHoverColor = Settings.getHoverColor(newColor)
            tempSettings.highlightColor = Settings.getHighlightColor(newColor)
            Settings.setAppearanceOption("buttonHoverColor", tempSettings.buttonHoverColor)
            Settings.setAppearanceOption("highlightColor", tempSettings.highlightColor)
        end
        
        return true
    end
    return false
end

-- Show general settings section
local function showGeneralSettings()
    reaper.ImGui_TextColored(ctx, 0xFFAA00FF, "Exclude Tags")
    reaper.ImGui_Separator(ctx)
    
    reaper.ImGui_Text(ctx, "Tags to exclude from renaming:")
    reaper.ImGui_SetNextItemWidth(ctx, 400)
    
    -- Get the current exclude tags
    local excludeTags = Settings.current.excludeTags or ""
    local excludeChanged, newExclude = reaper.ImGui_InputText(ctx, "##ExcludeTags", excludeTags)
    if excludeChanged then
        Settings.current.excludeTags = newExclude
        Settings.save()
    end
    
    reaper.ImGui_Text(ctx, "Enter tags separated by spaces")
    reaper.ImGui_TextColored(ctx, 0xAAAA00FF, 
        "Items/Regions/Tracks starting with these tags will be excluded from renaming")
    reaper.ImGui_Text(ctx, "Example: // # temp_")
    
    reaper.ImGui_Separator(ctx)
end

-- Show appearance settings section
local function showAppearanceSettings()
    reaper.ImGui_TextColored(ctx, 0xFFAA00FF, "Color Settings")
    reaper.ImGui_Separator(ctx)
    
    -- Color pickers in two-column layout using manual positioning
    local itemWidth = 280  -- Width for each color picker
    
    -- Row 1
    reaper.ImGui_PushItemWidth(ctx, itemWidth)
    colorPicker("Button Color", "buttonColor")
    reaper.ImGui_SameLine(ctx, itemWidth + 50)
    colorPicker("Button Hover Color", "buttonHoverColor")
    reaper.ImGui_PopItemWidth(ctx)
    
    -- Row 2
    reaper.ImGui_PushItemWidth(ctx, itemWidth)
    colorPicker("Background Color", "backgroundColor")
    reaper.ImGui_SameLine(ctx, itemWidth + 50)
    colorPicker("Highlight Color", "highlightColor")
    reaper.ImGui_PopItemWidth(ctx)
    
    -- Row 3
    reaper.ImGui_PushItemWidth(ctx, itemWidth)
    colorPicker("Text Color", "textColor")
    reaper.ImGui_SameLine(ctx, itemWidth + 50)
    colorPicker("Header Color", "headerColor")
    reaper.ImGui_PopItemWidth(ctx)
    
    -- Row 4
    reaper.ImGui_PushItemWidth(ctx, itemWidth)
    colorPicker("Frame Color", "frameColor")
    reaper.ImGui_PopItemWidth(ctx)
    
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_TextColored(ctx, 0xFFAA00FF, "Style Settings")
    reaper.ImGui_Separator(ctx)
    
    -- Style Settings with proper alignment in two columns
    local sliderWidth = 280  -- Same width as color pickers
    
    -- First row
    reaper.ImGui_PushItemWidth(ctx, sliderWidth)
    local rv, newRounding = reaper.ImGui_SliderDouble(ctx, "UI Elements Rounding", 
        tempSettings.uiRounding, 0.0, 12.0, "%.1f")
    if rv and newRounding ~= tempSettings.uiRounding then
        tempSettings.uiRounding = newRounding
        Settings.setAppearanceOption("uiRounding", newRounding)
    end
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, 
            "Controls the roundness of UI elements like buttons, input fields, and sliders.\n" ..
            "Higher values create more rounded corners.")
    end
    
    reaper.ImGui_SameLine(ctx, sliderWidth + 50)
    local rv, newFrameRounding = reaper.ImGui_SliderDouble(ctx, "Window Rounding", 
        tempSettings.frameRounding, 0.0, 12.0, "%.1f")
    if rv and newFrameRounding ~= tempSettings.frameRounding then
        tempSettings.frameRounding = newFrameRounding
        Settings.setAppearanceOption("frameRounding", newFrameRounding)
    end
    reaper.ImGui_PopItemWidth(ctx)
    
    -- Second row
    reaper.ImGui_PushItemWidth(ctx, sliderWidth)
    local rv, newSpacing = reaper.ImGui_SliderDouble(ctx, "Item Spacing", 
        tempSettings.itemSpacing, 0, 20, "%.1f")
    if rv and newSpacing ~= tempSettings.itemSpacing then
        tempSettings.itemSpacing = newSpacing
        Settings.setAppearanceOption("itemSpacing", newSpacing)
    end
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "Controls the space between UI elements.")
    end
    
    reaper.ImGui_SameLine(ctx, sliderWidth + 50)
    local rv, newPadding = reaper.ImGui_SliderDouble(ctx, "Window Padding", 
        tempSettings.windowPadding, 0, 20, "%.1f")
    if rv and newPadding ~= tempSettings.windowPadding then
        tempSettings.windowPadding = newPadding
        Settings.setAppearanceOption("windowPadding", newPadding)
    end
    reaper.ImGui_PopItemWidth(ctx)
end

-- Show scale/zoom settings section
local function showScaleSettings()
    reaper.ImGui_TextColored(ctx, 0xFFAA00FF, "Scale / Zoom Settings")
    reaper.ImGui_Separator(ctx)
    
    -- UI Scale slider
    reaper.ImGui_PushItemWidth(ctx, 250)
    -- Display scale as percentage (multiply by 100 for display)
    local displayScale = tempSettings.uiScale * 100
    local rv, newDisplayScale = reaper.ImGui_SliderDouble(ctx, "UI Scale", 
        displayScale, 50, 200, "%.0f%%", 
        reaper.ImGui_SliderFlags_AlwaysClamp())
    
    if rv then
        local newScale = newDisplayScale / 100  -- Convert percentage back to decimal
        if newScale ~= tempSettings.uiScale then
            tempSettings.uiScale = newScale
            Settings.setAppearanceOption("uiScale", newScale)
        end
    end
    
    -- Quick scale buttons
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "50%") then
        tempSettings.uiScale = 0.5
        Settings.setAppearanceOption("uiScale", 0.5)
    end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "75%") then
        tempSettings.uiScale = 0.75
        Settings.setAppearanceOption("uiScale", 0.75)
    end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "100%") then
        tempSettings.uiScale = 1.0
        Settings.setAppearanceOption("uiScale", 1.0)
    end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "125%") then
        tempSettings.uiScale = 1.25
        Settings.setAppearanceOption("uiScale", 1.25)
    end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "150%") then
        tempSettings.uiScale = 1.5
        Settings.setAppearanceOption("uiScale", 1.5)
    end
    
    -- Font size slider
    local rv, newFontSize = reaper.ImGui_SliderInt(ctx, "Font Size", 
        tempSettings.fontSize, 10, 24, "%d px")
    if rv and newFontSize ~= tempSettings.fontSize then
        tempSettings.fontSize = newFontSize
        Settings.setAppearanceOption("fontSize", newFontSize)
    end
    
    reaper.ImGui_PopItemWidth(ctx)
    
    -- Note about font changes
    reaper.ImGui_TextColored(ctx, 0xAAAA00FF, 
        "Note: Font size changes require restarting the script to take effect.")
end

-- Show presets section
local function showPresetsSection()
    reaper.ImGui_TextColored(ctx, 0xFFAA00FF, "Appearance Presets")
    reaper.ImGui_Separator(ctx)
    
    -- Preset buttons
    if reaper.ImGui_Button(ctx, "Dark Theme", 120, 0) then
        local themeButtonColor = 0x0A7A62FF
        tempSettings.backgroundColor = 0x2E2E2EFF
        tempSettings.frameColor = 0x3A3A3AFF
        tempSettings.textColor = 0xD5D5D5FF
        tempSettings.buttonColor = themeButtonColor
        tempSettings.buttonHoverColor = Settings.getHoverColor(themeButtonColor)
        tempSettings.highlightColor = Settings.getHighlightColor(themeButtonColor)
        tempSettings.headerColor = 0x454545FF
        
        -- Apply immediately
        for k, v in pairs(tempSettings) do
            if k ~= "initialized" then
                Settings.setAppearanceOption(k, v)
            end
        end
    end
    
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "Light Theme", 120, 0) then
        local themeButtonColor = 0xD0D0D0FF
        tempSettings.backgroundColor = 0xF5F5F5FF
        tempSettings.frameColor = 0xE0E0E0FF
        tempSettings.textColor = 0x2A2A2AFF
        tempSettings.buttonColor = themeButtonColor
        tempSettings.buttonHoverColor = Settings.getHoverColor(themeButtonColor)
        tempSettings.highlightColor = Settings.getHighlightColor(themeButtonColor)
        tempSettings.headerColor = 0xE5E5E5FF
        
        -- Apply immediately
        for k, v in pairs(tempSettings) do
            if k ~= "initialized" then
                Settings.setAppearanceOption(k, v)
            end
        end
    end
    
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "High Contrast", 120, 0) then
        local themeButtonColor = 0x404040FF
        tempSettings.backgroundColor = 0x000000FF
        tempSettings.frameColor = 0x202020FF
        tempSettings.textColor = 0xFFFFFFFF
        tempSettings.buttonColor = themeButtonColor
        tempSettings.buttonHoverColor = Settings.getHoverColor(themeButtonColor)
        tempSettings.highlightColor = Settings.getHighlightColor(themeButtonColor)
        tempSettings.headerColor = 0x303030FF
        
        -- Apply immediately
        for k, v in pairs(tempSettings) do
            if k ~= "initialized" then
                Settings.setAppearanceOption(k, v)
            end
        end
    end
    
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "Blue Theme", 120, 0) then
        local themeButtonColor = 0x3A5F8AFF
        tempSettings.backgroundColor = 0x1E3A5FFF
        tempSettings.frameColor = 0x2A4E7CFF
        tempSettings.textColor = 0xE8F0FFFF
        tempSettings.buttonColor = themeButtonColor
        tempSettings.buttonHoverColor = Settings.getHoverColor(themeButtonColor)
        tempSettings.highlightColor = Settings.getHighlightColor(themeButtonColor)
        tempSettings.headerColor = 0x2D5080FF
        
        -- Apply immediately
        for k, v in pairs(tempSettings) do
            if k ~= "initialized" then
                Settings.setAppearanceOption(k, v)
            end
        end
    end
end

-- Main settings window function
function SettingsUI.showSettingsWindow(open)
    if not ctx then
        return false
    end
    
    -- Initialize temporary variables
    initTempSettings()
    
    local windowFlags = 0  -- No flags = resizable window
    
    reaper.ImGui_SetNextWindowSize(ctx, 750, 650, reaper.ImGui_Cond_FirstUseEver())
    
    local visible, open = reaper.ImGui_Begin(ctx, 'DM RENAMER Settings', open, windowFlags)
    
    if visible then
        -- Create tabs for different sections
        if reaper.ImGui_BeginTabBar(ctx, "SettingsTabs") then
            
            -- General Tab
            if reaper.ImGui_BeginTabItem(ctx, "General") then
                showGeneralSettings()
                reaper.ImGui_EndTabItem(ctx)
            end
            
            -- Appearance Tab
            if reaper.ImGui_BeginTabItem(ctx, "Appearance") then
                showAppearanceSettings()
                reaper.ImGui_EndTabItem(ctx)
            end
            
            -- Scale Tab
            if reaper.ImGui_BeginTabItem(ctx, "Scale / Zoom") then
                showScaleSettings()
                reaper.ImGui_EndTabItem(ctx)
            end
            
            -- Presets Tab
            if reaper.ImGui_BeginTabItem(ctx, "Presets") then
                showPresetsSection()
                reaper.ImGui_EndTabItem(ctx)
            end
            
            reaper.ImGui_EndTabBar(ctx)
        end
        
        reaper.ImGui_Separator(ctx)
        
        -- Control buttons at the bottom
        local buttonWidth = 120
        local totalWidth = buttonWidth * 4 + 10 * 3  -- 4 buttons with spacing
        local availWidth = reaper.ImGui_GetContentRegionAvail(ctx)
        local startX = (availWidth - totalWidth) / 2
        
        if startX > 0 then
            reaper.ImGui_Dummy(ctx, startX, 0)
            reaper.ImGui_SameLine(ctx)
        end
        
        if reaper.ImGui_Button(ctx, "Save & Close", buttonWidth, 0) then
            applyTempSettings()
            resetTempSettings()
            open = false
        end
        
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Apply", buttonWidth, 0) then
            applyTempSettings()
        end
        
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Cancel", buttonWidth, 0) then
            restoreOriginalSettings()
            resetTempSettings()
            open = false
        end
        
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Reset Defaults", buttonWidth, 0) then
            -- Reset to default values
            local defaultButtonColor = 0x15856DFF
            tempSettings.backgroundColor = 0x2E2E2EFF
            tempSettings.frameColor = 0x3A3A3AFF
            tempSettings.textColor = 0xD5D5D5FF
            tempSettings.buttonColor = defaultButtonColor
            tempSettings.buttonHoverColor = Settings.getHoverColor(defaultButtonColor)
            tempSettings.highlightColor = Settings.getHighlightColor(defaultButtonColor)
            tempSettings.headerColor = 0x454545FF
            tempSettings.uiRounding = 3.0
            tempSettings.frameRounding = 4.0
            tempSettings.itemSpacing = 4.0
            tempSettings.windowPadding = 10.0
            tempSettings.uiScale = 1.0
            tempSettings.fontSize = 14
            
            -- Apply immediately for preview
            for k, v in pairs(tempSettings) do
                if k ~= "initialized" then
                    Settings.setAppearanceOption(k, v)
                end
            end
        end
        
        reaper.ImGui_End(ctx)
    end
    
    return open
end

-- Check if settings window is open
function SettingsUI.isOpen()
    return settingsWindowOpen
end

-- Set settings window state
function SettingsUI.setOpen(open)
    settingsWindowOpen = open
end

return SettingsUI