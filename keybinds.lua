script_name("keybinds")
script_author("akacross")
script_version("0.1.06")
script_url("https://akacross.net/")

local scriptPath = thisScript().path
local scriptName = thisScript().name
local scriptVersion = thisScript().version

-- Change Log
-- 0.1.07
-- Changed will go here for next update.
-- 0.1.06
-- Improved: Enhanced the ensureDefaults function to detect and remove blank tables.
-- Fixed: The editor now closes properly when changing keybinds if the keybind is not set.
-- Fixed: Added a nil check when opening the /keybinds menu to prevent system crashes.
-- Fixed: Resolved an issue where backspacing in the key textbox field would erase the entire input field.
-- Improved: The key input field now defaults to 0 if the input is erased, preventing the field from disappearing.
-- Improved: Added functionality to display wait time input next to action type and remove line buttons, starting from the second line.
-- Improved: The executeAction function now handles actions within a single Lua thread for better efficiency.
-- Improved: The keybinds condition now passes if both 'onFoot' and 'car' requirements are false.

-- Requirements
require 'lib.moonloader'
local ffi = require 'ffi'
local wm = require 'lib.windows.message'
local imgui = require 'mimgui'
local encoding = require 'encoding'
local fa = require 'fAwesome6'
local dlstatus = require 'moonloader'.download_status

-- Encoding
encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- Paths
local workingDir = getWorkingDirectory()
local configDir = workingDir .. '\\config\\'
local cfgFile = configDir .. 'keybinds.json'

-- URLs
local url = "https://raw.githubusercontent.com/akacross/keybinds/main/"
local scriptUrl = url .. "keybinds.lua"
local updateUrl = url .. "keybinds.txt"

-- Libs
local keybinds = {}
local keybinds_defaultSettings = {
    {name = "Hands up", keys = {VK_NUMPAD1}, type = {'KeyPressed'}, require = {chat = false, dialog = false, console = false, car = false, onFoot = true}, toggle = false, action = "sampSendChat('/s ARES! Drop your weapons and put your hands up ((/hu))')"},
    {name = "Tazer", keys = {VK_NUMPAD2}, type = {'KeyPressed'}, require = {chat = false, dialog = false, console = false, car = false, onFoot = true}, toggle = false, action = "sampSendChat('/tazer')"},
    {name = "Backup", keys = {VK_NUMPAD3}, type = {'KeyPressed'}, require = {chat = false, dialog = false, console = false, car = true, onFoot = true}, toggle = true, action = "sampSendChat(state and '/backup' or '/nobackup')"},
    {name = "Pullover", keys = {VK_NUMPAD4}, type = {'KeyPressed'}, require = {chat = false, dialog = false, console = false, car = true, onFoot = false}, toggle = false, action = "sampSendChat('/m This is ARES - Pullover your vehicle to the right side of the road.')"},
    {name = "Nos", keys = {VK_NUMPAD5}, type = {'KeyPressed'}, require = {chat = false, dialog = false, console = false, car = true, onFoot = false}, toggle = false, action = "sampSendChat('/nos')"},
    {name = "Badge", keys = {VK_NUMPAD6}, type = {'KeyPressed'}, require = {chat = false, dialog = false, console = false, car = true, onFoot = true}, toggle = false, action = "sampSendChat('/badge')"},
    {name = "Gate", keys = {VK_HOME}, type = {'KeyPressed'}, require = {chat = false, dialog = false, console = false, car = true, onFoot = true}, toggle = false, action = "sampSendChat('/gate')"},
    {name = "Vstorage", keys = {VK_END}, type = {'KeyPressed'}, require = {chat = false, dialog = false, console = false, car = true, onFoot = true}, toggle = false, action = "sampSendChat('/vst')"},
    {name = "PVLock", keys = {VK_DELETE}, type = {'KeyPressed'}, require = {chat = false, dialog = false, console = false, car = true, onFoot = true}, toggle = false, action = "sampSendChat('/pvlock')"},
    {name = "Reconnect", keys = {VK_SHIFT, VK_0}, type = {'KeyDown', 'KeyPressed'}, require = {chat = false, dialog = false, console = false, car = true, onFoot = true}, toggle = false, action = "local ip, port = sampGetCurrentServerAddress()\nsampConnectToServer(ip, port)"},
    {name = "Reload Scripts", keys = {VK_CONTROL, VK_R}, type = {'KeyDown', 'KeyPressed'}, require = {chat = false, dialog = false, console = false, car = true, onFoot = true}, toggle = false, action = "reloadScripts()"}
}

local ped, h = playerPed, playerHandle
local PressType = {KeyDown = isKeyDown, KeyPressed = wasKeyPressed}

local new, str, sizeof = imgui.new, ffi.string, ffi.sizeof
local menu = new.bool(false)
local runningActions = {}
local toggleStates = {}
local showEditor = false
local currentBindIndex = 1
local actionText = ""
local isSimpleAction = false
local actionLines = {}

local function executeAction(action, state)
    lua_thread.create(function()
        local func, err = loadstring("return function(state) " .. action .. " end")
        if func then
            func()(state)
        else
            print("Error loading action: " .. err)
        end
    end)
end

function main()
    createDirectory(configDir)
    keybinds = handleConfigFile(cfgFile, keybinds_defaultSettings, keybinds, {"name", "keys", "type", "require", "toggle", "action"})

    while not isSampAvailable() do wait(100) end
    sampRegisterChatCommand("keybinds", function()
        menu[0] = not menu[0]
    end)
    while true do wait(0)
        if not menu[0] then
            if showEditor then showEditor = false end
            for _, bind in ipairs(keybinds) do
                if keycheck(bind) then
                    local chatActive = sampIsChatInputActive()
                    local dialogActive = sampIsDialogActive()
                    local consoleActive = isSampfuncsConsoleActive()
                    local onFoot = isCharOnFoot(ped)
                    local inCar = isCharInAnyCar(ped)
                    if (bind.require.onFoot and onFoot) or (bind.require.car and inCar) or (not bind.require.onFoot and not bind.require.car) then
                        if (chatActive and not bind.require.chat) or
                           (dialogActive and not bind.require.dialog) or
                           (consoleActive and not bind.require.console) then
                        else
                            if bind.toggle then
                                if toggleStates[bind.name] == nil then
                                    toggleStates[bind.name] = false
                                end
                                toggleStates[bind.name] = not toggleStates[bind.name]
                                executeAction(bind.action, toggleStates[bind.name])
                            else
                                executeAction(bind.action, nil)
                            end
                        end
                    end
                end
            end
        end
    end
end

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    apply_custom_style()
end)

imgui.OnFrame(function() return menu[0] end,
function()
    local io = imgui.GetIO()
    local center = imgui.ImVec2(io.DisplaySize.x / 2, io.DisplaySize.y / 2)
    imgui.SetNextWindowPos(center, imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(500, 400), imgui.Cond.Always)
    if imgui.Begin(string.format("Keybind Editor - Version: %s", scriptVersion), menu, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse) then
        if not showEditor then
            imgui.Text('Keybinds:')
            if #keybinds == 0 then
                if imgui.Button('Add Keybind') then
                    table.insert(keybinds, {
                        name = "New Keybind",
                        keys = {VK_NUMPAD1},
                        type = {'KeyPressed'},
                        require = {chat = false, dialog = false, console = false, onFoot = true, car = false},
                        toggle = false,
                        action = "sampSendChat('/Command')\nsampSendChat('Message here')"
                    })
                    openEditor(#keybinds)
                end
            else
                for i, bind in ipairs(keybinds) do
                    if bind.name ~= nil then
                        if imgui.Button(bind.name .. '##' .. i) then
                            openEditor(i)
                        end
                        imgui.SameLine()
                        if imgui.Button('Remove##' .. i) then
                            table.remove(keybinds, i)
                        end
                    end
                end
                if imgui.Button('Add Keybind') then
                    table.insert(keybinds, {
                        name = "New Keybind",
                        keys = {VK_NUMPAD1},
                        type = {'KeyPressed'},
                        require = {chat = false, dialog = false, console = false, onFoot = true, car = false},
                        toggle = false,
                        action = "sampSendChat('/Command')\nsampSendChat('Message here')"
                    })
                    openEditor(#keybinds)
                end
            end
        else
            imgui.Text('Edit Action for Keybind ' .. currentBindIndex)
            
            imgui.Text('Nickname:')
            imgui.PushItemWidth(475)
            local nickBuffer = ffi.new("char[?]", 128, keybinds[currentBindIndex].name)
            if imgui.InputText('##nickname', nickBuffer, sizeof(nickBuffer)) then
                keybinds[currentBindIndex].name = str(nickBuffer)
            end
            imgui.PopItemWidth()

            if imgui.Checkbox('Simple Action', new.bool(isSimpleAction)) then
                isSimpleAction = not isSimpleAction
                if isSimpleAction then
                    actionLines = {}
                    local previousLine = nil
                    for line in actionText:gmatch("[^\r\n]+") do
                        local isSendChat = line:match("sampSendChat%(%s*['\"](.-)['\"]%s*%)")
                        local isProcessChatInput = line:match("sampProcessChatInput%(%s*['\"](.-)['\"]%s*%)")
                        local isWait = line:match("^wait%((%d+)%)$")

                        print("Line:", line)
                        print("isSendChat:", isSendChat)
                        print("isProcessChatInput:", isProcessChatInput)
                        print("isWait:", isWait)

                        if isSendChat then
                            table.insert(actionLines, {type = "sampSendChat", text = isSendChat})
                            previousLine = actionLines[#actionLines]
                        elseif isProcessChatInput then
                            table.insert(actionLines, {type = "sampProcessChatInput", text = isProcessChatInput})
                            previousLine = actionLines[#actionLines]
                        elseif isWait then
                            if previousLine then
                                previousLine.waitTime = tonumber(isWait)
                            end
                        else
                            table.insert(actionLines, {type = "code", text = line})
                            previousLine = actionLines[#actionLines]
                        end
                    end
                else
                    actionText = ""
                    for _, line in ipairs(actionLines) do
                        if line.type == "sampSendChat" or line.type == "sampProcessChatInput" then
                            actionText = actionText .. line.type .. "('" .. line.text .. "')\n"
                        else
                            actionText = actionText .. line.text .. "\n"
                        end
                        if line.waitTime then
                            actionText = actionText .. "wait(" .. line.waitTime .. ")\n"
                        end
                    end
                end
            end

            if isSimpleAction then
                for i, line in ipairs(actionLines) do
                    local actionTypes = {"sampSendChat", "sampProcessChatInput"}
                    local currentIndex = (line.type == "sampSendChat") and 1 or 2
            
                    imgui.PushItemWidth(155)
                    if imgui.BeginCombo("Action Type " .. i, actionTypes[currentIndex]) then
                        for j = 1, #actionTypes do
                            local actionType = actionTypes[j]
                            if imgui.Selectable(actionType, actionTypes[currentIndex] == actionType) then
                                line.type = actionType
                            end
                        end
                        imgui.EndCombo()
                    end
                    imgui.PopItemWidth()
            
                    imgui.PushItemWidth(475)
                    local actionBuffer = ffi.new("char[?]", 128, line.text)
                    if imgui.InputText('##action' .. i, actionBuffer, sizeof(actionBuffer)) then
                        line.text = str(actionBuffer)
                    end
                    imgui.PopItemWidth()
            
                    if i > 1 then
                        local waitTime = actionLines[i-1].waitTime or 0
                        local waitBuffer = ffi.new("char[?]", 128, tostring(waitTime / 1000))
                        if imgui.InputText('Wait (s)##' .. i, waitBuffer, sizeof(waitBuffer)) then
                            local waitTimeInSeconds = tonumber(str(waitBuffer))
                            if waitTimeInSeconds then
                                actionLines[i-1].waitTime = waitTimeInSeconds * 1000
                            else
                                actionLines[i-1].waitTime = 0
                            end
                        end
                    end
                    imgui.SameLine()
                    if imgui.Button('Remove Line##' .. i) then
                        table.remove(actionLines, i)
                    end
                end
            
                if imgui.Button('Add Line') then
                    table.insert(actionLines, {type = "sampSendChat", text = ""})
                end
            else
                imgui.PushItemWidth(500)
                local actionBuffer = ffi.new("char[?]", 1024, actionText)
                if imgui.InputTextMultiline('##action', actionBuffer, sizeof(actionBuffer)) then
                    actionText = str(actionBuffer)
                end
                imgui.PopItemWidth()
            end

            imgui.Text('Requirements:')
            local require = keybinds[currentBindIndex].require
            if imgui.Checkbox('On Foot', new.bool(require.onFoot)) then
                require.onFoot = not require.onFoot
            end
            if imgui.Checkbox('Car', new.bool(require.car)) then
                require.car = not require.car
            end
            if imgui.Checkbox('Toggle', new.bool(keybinds[currentBindIndex].toggle)) then
                keybinds[currentBindIndex].toggle = not keybinds[currentBindIndex].toggle
            end
            imgui.Text('Optional Requirements:')
            if imgui.Checkbox('Chat', new.bool(require.chat)) then
                require.chat = not require.chat
            end
            if imgui.Checkbox('Dialog', new.bool(require.dialog)) then
                require.dialog = not require.dialog
            end
            if imgui.Checkbox('Console', new.bool(require.console)) then
                require.console = not require.console
            end

            imgui.Text('Keys:')
            for i = 1, #keybinds[currentBindIndex].keys do
                imgui.PushItemWidth(40)
                local keyBuffer = ffi.new("char[?]", 128, tostring(keybinds[currentBindIndex].keys[i]))
                if imgui.InputText('##key' .. i, keyBuffer, sizeof(keyBuffer)) then
                    local keyStr = str(keyBuffer)
                    if keyStr == "" then
                        keybinds[currentBindIndex].keys[i] = 0
                    else
                        keybinds[currentBindIndex].keys[i] = tonumber(keyStr)
                    end
                end
                imgui.PopItemWidth()
                imgui.SameLine()
                imgui.PushItemWidth(95)
                local typeOptions = {"KeyPressed", "KeyDown"}
                local currentTypeIndex = (keybinds[currentBindIndex].type[i] == "KeyPressed") and 1 or 2
                if imgui.BeginCombo('##type' .. i, typeOptions[currentTypeIndex]) then
                    for j = 1, #typeOptions do
                        if imgui.Selectable(typeOptions[j], currentTypeIndex == j) then
                            keybinds[currentBindIndex].type[i] = typeOptions[j]
                        end
                    end
                    imgui.EndCombo()
                end
                imgui.PopItemWidth()

                if #keybinds[currentBindIndex].keys > 1 then
                    imgui.SameLine()
                    if imgui.Button('Remove##' .. i) then
                        table.remove(keybinds[currentBindIndex].keys, i)
                        table.remove(keybinds[currentBindIndex].type, i)
                    end
                end
            end

            if #keybinds[currentBindIndex].keys < 3 then
                if imgui.Button('Add Key') then
                    table.insert(keybinds[currentBindIndex].keys, 0)
                    table.insert(keybinds[currentBindIndex].type, "KeyPressed")
                end
            end

            if imgui.Button('Save') then
                if isSimpleAction then
                    actionText = ""
                    for i, line in ipairs(actionLines) do
                        if line.type == "sampSendChat" or line.type == "sampProcessChatInput" then
                            actionText = actionText .. line.type .. "('" .. line.text .. "')\n"
                        else
                            actionText = actionText .. line.text .. "\n"
                        end
                        if line.waitTime and i < #actionLines then
                            actionText = actionText .. "wait(" .. line.waitTime .. ")\n"
                        end
                    end
                end
                keybinds[currentBindIndex].action = actionText
                saveConfigWithErrorHandling(cfgFile, keybinds)
                showEditor = false
            end
            imgui.SameLine()
            if imgui.Button('Cancel') then
                showEditor = false
            end
        end
        imgui.End()
    end
end)

function openEditor(index)
    currentBindIndex = index
    if keybinds[index] and keybinds[index].action then
        actionText = keybinds[index].action
        local isSendChat = actionText:match("sampSendChat%(%s*['\"](.-)['\"]%s*%)") ~= nil
        local isProcessChatInput = actionText:match("sampProcessChatInput%(%s*['\"](.-)['\"]%s*%)") ~= nil
        isSimpleAction = isSendChat or isProcessChatInput
        if isSimpleAction then
            actionLines = {}
            local previousLine = nil
            for line in actionText:gmatch("[^\r\n]+") do
                local isSendChat = line:match("sampSendChat%(%s*['\"](.-)['\"]%s*%)")
                local isProcessChatInput = line:match("sampProcessChatInput%(%s*['\"](.-)['\"]%s*%)")
                local isWait = line:match("^wait%((%d+)%)$")
                if isSendChat then
                    table.insert(actionLines, {type = "sampSendChat", text = isSendChat})
                    previousLine = actionLines[#actionLines]
                elseif isProcessChatInput then
                    table.insert(actionLines, {type = "sampProcessChatInput", text = isProcessChatInput})
                    previousLine = actionLines[#actionLines]
                elseif isWait then
                    if previousLine then
                        previousLine.waitTime = tonumber(isWait)
                    end
                else
                    table.insert(actionLines, {type = "code", text = line})
                    previousLine = actionLines[#actionLines]
                end
            end
        else
            actionLines = {}
            for line in actionText:gmatch("[^\r\n]+") do
                table.insert(actionLines, {type = "code", text = line})
            end
        end
        showEditor = true
    else
        print("Invalid keybind index or action is nil")
    end
end

function keycheck(bind)
    local r = true
    if not bind.keys then
        return false
    end
    for i = 1, #bind.keys do
        r = r and PressType[bind.type[i]](bind.keys[i])
    end
    return r
end

function saveConfigWithErrorHandling(path, config)
    local success, err = saveConfig(path, config)
    if not success then
        print("Error saving config to " .. path .. ": " .. err)
    end
    return success
end

function handleConfigFile(path, defaults, configVar, ignoreKeys)
    ignoreKeys = ignoreKeys or {}
    if doesFileExist(path) then
        local config, err = loadConfig(path)
        if not config then
            print("Error loading config from " .. path .. ": " .. err)

            local newpath = path:gsub("%.[^%.]+$", ".bak")
            local success, err2 = os.rename(path, newpath)
            if not success then
                print("Error renaming config: " .. err2)
                os.remove(path)
            end
            handleConfigFile(path, defaults, configVar)
        else
            local result = ensureDefaults(config, defaults, false, ignoreKeys)
            if result then
                local success, err3 = saveConfig(path, config)
                if not success then
                    print("Error saving config: " .. err3)
                end
            end
            return config
        end
    else
        local result = ensureDefaults(configVar, defaults, true)
        if result then
            local success, err = saveConfig(path, configVar)
            if not success then
                print("Error saving config: " .. err)
            end
        end
    end
    return configVar
end

function loadConfig(filePath)
    local file = io.open(filePath, "r")
    if not file then
        return nil, "Could not open file."
    end

    local content = file:read("*a")
    file:close()

    if not content or content == "" then
        return nil, "Config file is empty."
    end

    local success, decoded = pcall(decodeJson, content)
    if success then
        if next(decoded) == nil then
            return nil, "JSON format is empty."
        else
            return decoded, nil
        end
    else
        return nil, "Failed to decode JSON: " .. decoded
    end
end

function saveConfig(filePath, config)
    local file = io.open(filePath, "w")
    if not file then
        return false, "Could not save file."
    end
    file:write(encodeJson(config, false))
    file:close()
    return true
end

function ensureDefaults(config, defaults, reset, ignoreKeys)
    ignoreKeys = ignoreKeys or {}
    local status = false

    local function isIgnored(key)
        for _, ignoreKey in ipairs(ignoreKeys) do
            if key == ignoreKey then
                return true
            end
        end
        return false
    end

    local function isEmptyTable(t)
        return next(t) == nil
    end

    local function cleanupConfig(conf, def)
        local localStatus = false
        for k, v in pairs(conf) do
            if isIgnored(k) then
                return
            elseif def[k] == nil then
                conf[k] = nil
                localStatus = true
            elseif type(conf[k]) == "table" and type(def[k]) == "table" then
                localStatus = cleanupConfig(conf[k], def[k]) or localStatus
                if isEmptyTable(conf[k]) then
                    conf[k] = nil
                    localStatus = true
                end
            end
        end
        return localStatus
    end

    local function applyDefaults(conf, def)
        local localStatus = false
        for k, v in pairs(def) do
            if isIgnored(k) then
                return
            elseif conf[k] == nil or reset then
                if type(v) == "table" then
                    conf[k] = {}
                    localStatus = applyDefaults(conf[k], v) or localStatus
                else
                    conf[k] = v
                    localStatus = true
                end
            elseif type(v) == "table" and type(conf[k]) == "table" then
                localStatus = applyDefaults(conf[k], v) or localStatus
            end
        end
        return localStatus
    end

    setmetatable(config, {__index = function(t, k)
        if type(defaults[k]) == "table" then
            t[k] = {}
            applyDefaults(t[k], defaults[k])
            return t[k]
        end
    end})

    status = applyDefaults(config, defaults)
    status = cleanupConfig(config, defaults) or status
    return status
end

function loadFontAwesome6Icons(iconList, fontSize)
    local config = imgui.ImFontConfig()
    config.MergeMode = true
    config.PixelSnapH = true
    config.GlyphMinAdvanceX = 14
    local builder = imgui.ImFontGlyphRangesBuilder()
    
    for _, icon in ipairs(iconList) do
        builder:AddText(fa(icon))
    end
    
    local glyphRanges = imgui.ImVector_ImWchar()
    builder:BuildRanges(glyphRanges)
    imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(fa.get_font_data_base85("solid"), fontSize, config, glyphRanges[0].Data)
end

function apply_custom_style()
    imgui.SwitchContext()
    local ImVec4 = imgui.ImVec4
    local ImVec2 = imgui.ImVec2
    local style = imgui.GetStyle()
    style.WindowRounding = 0
    style.WindowPadding = ImVec2(8, 8)
    style.WindowTitleAlign = ImVec2(0.5, 0.5)
    style.FrameRounding = 0
    style.ItemSpacing = ImVec2(8, 4)
    style.ScrollbarSize = 10
    style.ScrollbarRounding = 3
    style.GrabMinSize = 10
    style.GrabRounding = 0
    style.Alpha = 1
    style.FramePadding = ImVec2(4, 3)
    style.ItemInnerSpacing = ImVec2(4, 4)
    style.TouchExtraPadding = ImVec2(0, 0)
    style.IndentSpacing = 21
    style.ColumnsMinSpacing = 6
    style.ButtonTextAlign = ImVec2(0.5, 0.5)
    style.DisplayWindowPadding = ImVec2(22, 22)
    style.DisplaySafeAreaPadding = ImVec2(4, 4)
    style.AntiAliasedLines = true
    style.CurveTessellationTol = 1.25
    local colors = style.Colors
    local clr = imgui.Col
    colors[clr.FrameBg]                = ImVec4(0.48, 0.16, 0.16, 0.54)
    colors[clr.FrameBgHovered]         = ImVec4(0.98, 0.26, 0.26, 0.40)
    colors[clr.FrameBgActive]          = ImVec4(0.98, 0.26, 0.26, 0.67)
    colors[clr.TitleBg]                = ImVec4(0.04, 0.04, 0.04, 1.00)
    colors[clr.TitleBgActive]          = ImVec4(0.48, 0.16, 0.16, 1.00)
    colors[clr.TitleBgCollapsed]       = ImVec4(0.00, 0.00, 0.00, 0.51)
    colors[clr.CheckMark]              = ImVec4(0.98, 0.26, 0.26, 1.00)
    colors[clr.SliderGrab]             = ImVec4(0.88, 0.26, 0.24, 1.00)
    colors[clr.SliderGrabActive]       = ImVec4(0.98, 0.26, 0.26, 1.00)
    colors[clr.Button]                 = ImVec4(0.98, 0.26, 0.26, 0.40)
    colors[clr.ButtonHovered]          = ImVec4(0.98, 0.26, 0.26, 1.00)
    colors[clr.ButtonActive]           = ImVec4(0.98, 0.06, 0.06, 1.00)
    colors[clr.Header]                 = ImVec4(0.98, 0.26, 0.26, 0.31)
    colors[clr.HeaderHovered]          = ImVec4(0.98, 0.26, 0.26, 0.80)
    colors[clr.HeaderActive]           = ImVec4(0.98, 0.26, 0.26, 1.00)
    colors[clr.Separator]              = colors[clr.Border]
    colors[clr.SeparatorHovered]       = ImVec4(0.75, 0.10, 0.10, 0.78)
    colors[clr.SeparatorActive]        = ImVec4(0.75, 0.10, 0.10, 1.00)
    colors[clr.ResizeGrip]             = ImVec4(0.98, 0.26, 0.26, 0.25)
    colors[clr.ResizeGripHovered]      = ImVec4(0.98, 0.26, 0.26, 0.67)
    colors[clr.ResizeGripActive]       = ImVec4(0.98, 0.26, 0.26, 0.95)
    colors[clr.TextSelectedBg]         = ImVec4(0.98, 0.26, 0.26, 0.35)
    colors[clr.Text]                   = ImVec4(1.00, 1.00, 1.00, 1.00)
    colors[clr.TextDisabled]           = ImVec4(0.50, 0.50, 0.50, 1.00)
    colors[clr.WindowBg]               = ImVec4(0.06, 0.06, 0.06, 0.94)
    colors[clr.PopupBg]                = ImVec4(0.08, 0.08, 0.08, 0.94)
    colors[clr.Border]                 = ImVec4(0.43, 0.43, 0.50, 0.50)
    colors[clr.BorderShadow]           = ImVec4(0.00, 0.00, 0.00, 0.00)
    colors[clr.MenuBarBg]              = ImVec4(0.14, 0.14, 0.14, 1.00)
    colors[clr.ScrollbarBg]            = ImVec4(0.02, 0.02, 0.02, 0.53)
    colors[clr.ScrollbarGrab]          = ImVec4(0.31, 0.31, 0.31, 1.00)
    colors[clr.ScrollbarGrabHovered]   = ImVec4(0.41, 0.41, 0.41, 1.00)
    colors[clr.ScrollbarGrabActive]    = ImVec4(0.51, 0.51, 0.51, 1.00)
    colors[clr.PlotLines]              = ImVec4(0.61, 0.61, 0.61, 1.00)
    colors[clr.PlotLinesHovered]       = ImVec4(1.00, 0.43, 0.35, 1.00)
    colors[clr.PlotHistogram]          = ImVec4(0.90, 0.70, 0.00, 1.00)
    colors[clr.PlotHistogramHovered]   = ImVec4(1.00, 0.60, 0.00, 1.00)
end