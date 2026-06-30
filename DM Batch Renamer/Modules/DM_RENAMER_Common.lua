-- @noindex
-- DM RENAMER - Common Functions Module
-- Shared utility functions for all renaming operations

local Common = {}

-- Escape special characters for pattern matching
function Common.escapePattern(str)
    if not str then return "" end
    local specialChars = "([%(%)%.%%%+%-%*%?%[%]%^%$])"
    return str:gsub(specialChars, "%%%1")
end


-- Apply operation to string (simplified - duplicates removed)
function Common.applyOperation(str, operation, context)
    if not str or operation == "none" then return str end
    
    if operation == "removeBrackets" then
        -- Remove brackets and their content
        return str:gsub("%[.-%]", "")
        
    elseif operation == "removeParens" then
        -- Remove parentheses and their content
        return str:gsub("%(.-%)" , "")
        
    elseif operation == "addTimestamp" then
        -- Add position timestamp (MM-SS-mmm format)
        if context and context.position then
            local pos = context.position
            local minutes = math.floor(pos / 60)
            local seconds = math.floor(pos % 60)
            local milliseconds = math.floor((pos % 1) * 1000)
            local timestamp = string.format("%02d-%02d-%03d", minutes, seconds, milliseconds)
            return str .. "_" .. timestamp
        elseif context and context.type == "track" then
            -- For tracks, use track number since they don't have timeline position
            local trackNum = context.trackNumber or context.index or 0
            local timestamp = string.format("Track%03d", trackNum)
            return str .. "_" .. timestamp
        else
            -- Fallback to system time if no position available
            local time = os.date("%H-%M-%S")
            return str .. "_" .. time
        end
        
    elseif operation == "addDate" then
        -- Add current date
        local date = os.date("%Y-%m-%d")
        return str .. "_" .. date
    end
    
    return str
end

-- Apply case transformation to string
function Common.applyCase(str, caseType)
    if not str then return "" end
    
    if caseType == "upper" then
        return str:upper()
        
    elseif caseType == "lower" then
        return str:lower()
        
    elseif caseType == "title" then
        -- Capitalize first letter of each word
        return str:gsub("(%a)([%w']*)", function(first, rest)
            return first:upper() .. rest:lower()
        end)
        
    elseif caseType == "sentence" then
        -- Capitalize only first letter of string
        local result = str:lower()
        return result:sub(1,1):upper() .. result:sub(2)
        
    elseif caseType == "camel" then
        -- camelCase: first word lowercase, rest title case
        local result = str:gsub("(%a)([%w']*)", function(first, rest)
            return first:upper() .. rest:lower()
        end)
        -- Remove spaces and special chars
        result = result:gsub("[%s%-_]+", "")
        -- Make first letter lowercase
        return result:sub(1,1):lower() .. result:sub(2)
        
    elseif caseType == "pascal" then
        -- PascalCase: all words title case, no spaces
        local result = str:gsub("(%a)([%w']*)", function(first, rest)
            return first:upper() .. rest:lower()
        end)
        -- Remove spaces and special chars
        return result:gsub("[%s%-_]+", "")
        
    elseif caseType == "snake" then
        -- snake_case: lowercase with underscores
        local result = str:lower()
        -- Replace spaces and dashes with underscores
        result = result:gsub("[%s%-]+", "_")
        -- Remove multiple underscores
        result = result:gsub("_+", "_")
        -- Remove leading/trailing underscores
        result = result:gsub("^_+", ""):gsub("_+$", "")
        return result
        
    elseif caseType == "kebab" then
        -- kebab-case: lowercase with dashes
        local result = str:lower()
        -- Replace spaces and underscores with dashes
        result = result:gsub("[%s_]+", "-")
        -- Remove multiple dashes
        result = result:gsub("%-+", "-")
        -- Remove leading/trailing dashes
        result = result:gsub("^%-+", ""):gsub("%-+$", "")
        return result
        
    elseif caseType == "constant" then
        -- CONSTANT_CASE: uppercase with underscores
        local result = str:upper()
        -- Replace spaces and dashes with underscores
        result = result:gsub("[%s%-]+", "_")
        -- Remove multiple underscores
        result = result:gsub("_+", "_")
        -- Remove leading/trailing underscores
        result = result:gsub("^_+", ""):gsub("_+$", "")
        return result
    end
    
    return str
end

-- Pad number with zeros
function Common.padNumber(num, width)
    local numStr = tostring(num)
    local padding = width - #numStr
    if padding > 0 then
        return string.rep("0", padding) .. numStr
    end
    return numStr
end

-- Convert number to letter sequence (1=A, 2=B, ..., 26=Z, 27=AA, 28=AB, ...)
function Common.numberToLetters(num)
    if num < 1 then return "A" end

    local result = ""
    while num > 0 do
        num = num - 1  -- Adjust to 0-based for modulo
        local remainder = num % 26
        result = string.char(65 + remainder) .. result  -- 65 = 'A'
        num = math.floor(num / 26)
    end

    return result
end

-- Split string by delimiter
function Common.splitString(str, delimiter)
    if not str then return {} end
    delimiter = delimiter or " "
    local result = {}
    local pattern = string.format("([^%s]+)", delimiter)
    for match in str:gmatch(pattern) do
        table.insert(result, match)
    end
    return result
end

-- Validate Lua pattern syntax
function Common.validatePattern(pattern)
    if not pattern or pattern == "" then
        return true, ""  -- Empty pattern is valid
    end
    
    local success, err = pcall(function()
        string.match("test", pattern)
    end)
    
    if not success then
        -- Extract clean error message
        local errorMsg = err:match(".-:%d+: (.+)") or err
        return false, errorMsg
    end
    return true, ""
end

-- Test pattern on sample text
function Common.testPattern(text, findPattern, replacePattern, useLuaPattern)
    if not text or text == "" then return "" end
    
    if useLuaPattern then
        local success, result = pcall(function()
            local replaced, count = string.gsub(text, findPattern, replacePattern or "")
            return replaced
        end)
        
        if success then
            return result
        else
            return "Error: " .. tostring(result)
        end
    else
        return Common.replacePattern(text, findPattern, replacePattern, false, false, false)
    end
end

-- Simple text matching with options
function Common.matchPattern(str, pattern, caseSensitive, wholeWord, useLuaPattern)
    if not str or not pattern then return false end
    
    -- Mode Lua Pattern
    if useLuaPattern then
        local searchStr = caseSensitive and str or str:lower()
        local searchPattern = caseSensitive and pattern or pattern:lower()
        
        local success, result = pcall(function()
            return string.find(searchStr, searchPattern) ~= nil
        end)
        
        return success and result
    end
    
    -- Original literal mode
    -- Handle case sensitivity
    local searchStr = caseSensitive and str or str:lower()
    local searchPattern = caseSensitive and pattern or pattern:lower()
    
    -- Escape pattern for plain text search
    searchPattern = Common.escapePattern(searchPattern)
    
    -- Handle whole word matching
    if wholeWord then
        searchPattern = "%f[%w]" .. searchPattern .. "%f[%W]"
    end
    
    -- Find the pattern
    return string.find(searchStr, searchPattern) ~= nil
end

-- Simple text replacement
function Common.replacePattern(str, findPattern, replacePattern, caseSensitive, wholeWord, useLuaPattern)
    if not str or not findPattern then return str end
    replacePattern = replacePattern or ""
    
    -- Mode Lua Pattern with support for captures
    if useLuaPattern then
        if not caseSensitive then
            -- For case-insensitive patterns, we need a more complex approach
            -- This is a simplified version - true case-insensitive patterns would need more work
            local success, result = pcall(function()
                local replaced, count = string.gsub(str, findPattern, replacePattern)
                return replaced  -- Return ONLY the string, not the count
            end)
            return success and result or str
        else
            local success, result = pcall(function()
                local replaced, count = string.gsub(str, findPattern, replacePattern)
                return replaced  -- Return ONLY the string, not the count
            end)
            return success and result or str
        end
    end
    
    -- Original literal mode
    -- Handle case-insensitive replacement
    if not caseSensitive then
        -- For case-insensitive plain text replacement
        local lowerStr = str:lower()
        local lowerFind = findPattern:lower()
        local result = str
        local offset = 0
        
        while true do
            local startPos, endPos = string.find(lowerStr, Common.escapePattern(lowerFind), offset + 1, false)
            if not startPos then break end
            
            result = result:sub(1, startPos - 1) .. replacePattern .. result:sub(endPos + 1)
            lowerStr = result:lower()
            offset = startPos + #replacePattern - 1
        end
        
        return result
    end
    
    -- Escape pattern for plain text search
    local escapedFind = Common.escapePattern(findPattern)
    
    -- Handle whole word matching
    if wholeWord then
        escapedFind = "%f[%w]" .. escapedFind .. "%f[%W]"
    end
    
    -- Perform replacement
    return string.gsub(str, escapedFind, replacePattern)
end

-- Generate variables for replacement
function Common.generateVariables(index, name, context)
    local vars = {}
    
    -- Basic variables
    vars["$num"] = tostring(index)
    vars["$num2"] = Common.padNumber(index, 2)
    vars["$num3"] = Common.padNumber(index, 3)
    vars["$num4"] = Common.padNumber(index, 4)
    vars["$name"] = name or ""
    vars["$NAME"] = (name or ""):upper()
    vars["$Name"] = Common.applyCase(name or "", "title")
    
    -- Date and time variables
    local date = os.date("*t")
    vars["$date"] = string.format("%04d-%02d-%02d", date.year, date.month, date.day)
    vars["$time"] = string.format("%02d-%02d-%02d", date.hour, date.min, date.sec)
    vars["$year"] = tostring(date.year)
    vars["$month"] = Common.padNumber(date.month, 2)
    vars["$day"] = Common.padNumber(date.day, 2)
    
    -- Context-specific variables
    if context then
        for k, v in pairs(context) do
            vars["$" .. k] = tostring(v)
        end
    end
    
    return vars
end

-- Apply template with variables
function Common.applyTemplate(template, variables)
    if not template then return "" end
    
    local result = template
    for var, value in pairs(variables) do
        result = result:gsub(Common.escapePattern(var), value)
    end
    
    return result
end


-- Insert text at position
function Common.insertAtPosition(str, text, position)
    if not str then return text or "" end
    if not text then return str end
    
    position = math.max(0, math.min(position, #str))
    return str:sub(1, position) .. text .. str:sub(position + 1)
end

-- Remove characters from string
function Common.removeCharacters(str, startPos, endPos)
    if not str then return "" end
    
    startPos = math.max(1, startPos)
    endPos = math.min(#str, endPos)
    
    if startPos > endPos then return str end
    
    return str:sub(1, startPos - 1) .. str:sub(endPos + 1)
end

-- Remove prefix from string
function Common.removePrefix(str, prefix)
    if not str or not prefix then return str end
    
    if str:sub(1, #prefix) == prefix then
        return str:sub(#prefix + 1)
    end
    return str
end

-- Remove suffix from string
function Common.removeSuffix(str, suffix)
    if not str or not suffix then return str end
    
    if str:sub(-#suffix) == suffix then
        return str:sub(1, -#suffix - 1)
    end
    return str
end

-- Remove a fixed number of characters from the start and/or end of a string.
-- fromStart/fromEnd: char counts (coerced, floored, clamped to >= 0). Byte-based slicing,
-- consistent with truncate/removePrefix. Returns "" if the removals cover the whole string.
function Common.removeChars(str, fromStart, fromEnd)
    if not str then return str end
    fromStart = math.max(0, math.floor(tonumber(fromStart) or 0))
    fromEnd = math.max(0, math.floor(tonumber(fromEnd) or 0))
    if fromStart == 0 and fromEnd == 0 then return str end
    if fromStart + fromEnd >= #str then return "" end
    return str:sub(fromStart + 1, #str - fromEnd)
end

-- Truncate string to max length
function Common.truncate(str, maxLength, addEllipsis)
    if not str or #str <= maxLength then return str end
    
    if addEllipsis then
        return str:sub(1, maxLength - 3) .. "..."
    else
        return str:sub(1, maxLength)
    end
end

-- Extract text between delimiters
function Common.extractBetween(str, startDelim, endDelim)
    if not str then return "" end
    
    local startPos = str:find(Common.escapePattern(startDelim))
    if not startPos then return "" end
    
    startPos = startPos + #startDelim
    local endPos = str:find(Common.escapePattern(endDelim), startPos)
    if not endPos then return str:sub(startPos) end
    
    return str:sub(startPos, endPos - 1)
end

-- Get file extension
function Common.getExtension(filename)
    if not filename then return "" end
    local ext = filename:match("%.([^%.]+)$")
    return ext or ""
end

-- Get filename without extension
function Common.removeExtension(filename)
    if not filename then return "" end
    return filename:match("(.+)%.[^%.]+$") or filename
end

-- Create undo block
function Common.beginUndoBlock(description)
    reaper.Undo_BeginBlock2(0)
    return description or "Rename Operation"
end

-- End undo block
function Common.endUndoBlock(description)
    reaper.Undo_EndBlock2(0, description, -1)
end

-- Show message in console
function Common.msg(message)
    if reaper.ShowConsoleMsg then
        reaper.ShowConsoleMsg(tostring(message) .. "\n")
    end
end

-- Show error message
function Common.showError(title, message)
    reaper.MB(message, title or "Error", 0)
end

-- Show confirmation dialog
function Common.confirm(title, message)
    local result = reaper.MB(message, title or "Confirm", 4)
    return result == 6 -- 6 = Yes
end

-- Get current project
function Common.getProject()
    return reaper.EnumProjects(-1)
end

-- Format time as string
function Common.formatTime(time)
    local minutes = math.floor(time / 60)
    local seconds = time % 60
    return string.format("%d:%06.3f", minutes, seconds)
end

-- Parse time from string
function Common.parseTime(timeStr)
    local minutes, seconds = timeStr:match("(%d+):([%d%.]+)")
    if minutes and seconds then
        return tonumber(minutes) * 60 + tonumber(seconds)
    end
    return tonumber(timeStr) or 0
end

-- Handle duplicate names with auto-increment
-- incrementMode: "off", "number", or "letter"
-- separator: optional separator before suffix (default "_")
-- padding: digit count for "number" mode (default 2, clamped to >= 1; never truncates)
function Common.handleDuplicateNames(list, incrementMode, separator, padding)
    if not incrementMode or incrementMode == "off" then return end
    separator = separator or "_"
    padding = math.max(1, math.floor(tonumber(padding) or 2))

    -- Group items by preview name (include ALL items, not just changed ones,
    -- so increment-only usage works without requiring other transformations)
    local nameGroups = {}
    for _, item in ipairs(list) do
        if item.preview and item.preview ~= "" then
            if not nameGroups[item.preview] then
                nameGroups[item.preview] = {}
            end
            table.insert(nameGroups[item.preview], item)
        end
    end

    -- Add increment to duplicates
    for name, items in pairs(nameGroups) do
        if #items > 1 then
            -- Sort items by position/index for consistent numbering
            table.sort(items, function(a, b)
                if a.position and b.position then
                    return a.position < b.position
                elseif a.startPos and b.startPos then  -- For regions
                    return a.startPos < b.startPos
                elseif a.index and b.index then
                    return a.index < b.index
                elseif a.trackNumber and b.trackNumber then  -- For tracks
                    return a.trackNumber < b.trackNumber
                else
                    return false
                end
            end)

            -- Add suffix to ALL duplicates (including first) with zero-padded format
            for i = 1, #items do
                local suffix
                if incrementMode == "letter" then
                    suffix = Common.numberToLetters(i)
                else  -- "number" mode (default)
                    suffix = Common.padNumber(i, padding)
                end
                items[i].preview = name .. separator .. suffix
                items[i].changed = (items[i].preview ~= items[i].name)
            end
        end
    end
end

-- Apply transformation (wrapper for consistent API across modules)
function Common.applyTransformation(str, findText, replaceText, options)
    local result = str

    -- Apply find/replace
    if findText and findText ~= "" then
        result = Common.replacePattern(result, findText, replaceText,
                                      options.caseSensitive,
                                      options.wholeWord,
                                      options.useLuaPatterns)
    end

    -- Apply operations
    if options.operation and options.operation ~= "none" then
        result = Common.applyOperation(result, options.operation, options)
    end

    -- Apply case transformation
    if options.transformCase and options.transformCase ~= "none" then
        result = Common.applyCase(result, options.transformCase)
    end

    -- Apply prefix/suffix
    if options.prefix and options.prefix ~= "" then
        result = options.prefix .. result
    end
    if options.suffix and options.suffix ~= "" then
        result = result .. options.suffix
    end

    return result
end

return Common