-- DM RENAMER - Presets Module
-- Save and load renaming configurations

local Presets = {}

local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
local presets_path = script_path .. "DM_RENAMER_Presets.dat"

function Presets.save(name, state)
    -- Load existing presets
    local presets = Presets.load_all()

    -- Add/update preset
    presets[name] = {
        findText = state.findText,
        replaceText = state.replaceText,
        caseSensitive = state.caseSensitive,
        wholeWord = state.wholeWord,
        useLuaPatterns = state.useLuaPatterns,
        operation = state.operation,
        transformCase = state.transformCase,
        prefix = state.prefix,
        suffix = state.suffix,
        incrementMode = state.incrementMode,
        autoSelectChanged = state.autoSelectChanged,
        jumpToPosition = state.jumpToPosition,
        -- Add folder items specific settings
        folderItemPattern = state.folderItemPattern,
        folderItemSeparator = state.folderItemSeparator,
        folderItemCustomPattern = state.folderItemCustomPattern,
        folderItemIncrementMode = state.folderItemIncrementMode,
        -- Save global exclude tags
        excludeTags = state.excludeTags,
        -- Save space replacement setting
        spaceReplacement = state.spaceReplacement
    }

    -- Save to file
    local file = io.open(presets_path, "w")
    if file then
        file:write(Presets.serialize(presets))
        file:close()
        return true
    end
    return false
end

function Presets.load(name)
    local presets = Presets.load_all()
    local preset = presets[name]

    if preset then
        -- Handle backwards compatibility: convert old folderItemExcludeTag to excludeTags
        if preset.folderItemExcludeTag and not preset.excludeTags then
            preset.excludeTags = preset.folderItemExcludeTag
            preset.folderItemExcludeTag = nil
        end

        -- Handle backwards compatibility: convert old autoIncrement (boolean) to incrementMode (string)
        if preset.autoIncrement ~= nil and not preset.incrementMode then
            preset.incrementMode = preset.autoIncrement and "number" or "off"
            preset.autoIncrement = nil
        end

        -- Handle backwards compatibility: convert old folderItemAutoIncrement to folderItemIncrementMode
        if preset.folderItemAutoIncrement ~= nil and not preset.folderItemIncrementMode then
            preset.folderItemIncrementMode = preset.folderItemAutoIncrement and "number" or "off"
            preset.folderItemAutoIncrement = nil
        end
    end

    return preset
end

function Presets.load_all()
    local file = io.open(presets_path, "r")
    if file then
        local content = file:read("*a")
        file:close()
        return Presets.deserialize(content) or {}
    end
    return {}
end

function Presets.delete(name)
    local presets = Presets.load_all()
    presets[name] = nil

    local file = io.open(presets_path, "w")
    if file then
        file:write(Presets.serialize(presets))
        file:close()
        return true
    end
    return false
end

function Presets.list()
    local presets = Presets.load_all()
    local names = {}
    for name, _ in pairs(presets) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

function Presets.serialize(tbl)
    local result = "return {\n"
    for k, v in pairs(tbl) do
        result = result .. "[\"" .. k .. "\"] = {\n"
        for key, val in pairs(v) do
            local valStr
            if type(val) == "string" then
                -- Escape special characters in string
                valStr = "\"" .. val:gsub("\\", "\\\\"):gsub("\"", "\\\"") .. "\""
            elseif type(val) == "boolean" then
                valStr = tostring(val)
            elseif type(val) == "number" then
                valStr = tostring(val)
            elseif val == nil then
                valStr = "nil"
            else
                valStr = "\"" .. tostring(val) .. "\""
            end
            result = result .. "  " .. key .. " = " .. valStr .. ",\n"
        end
        result = result .. "},\n"
    end
    result = result .. "}"
    return result
end

function Presets.deserialize(str)
    if str and str ~= "" then
        local func = load(str, "presets", "t", {})
        if func then
            local success, result = pcall(func)
            if success then
                return result
            end
        end
    end
    return nil
end

return Presets