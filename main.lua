local api = require("api")

-- Raid Tool and Fish Tracker split out of Norrina-Hub 1.1.56.8 by Norrina
-- (Fish Tracker there is based on Fish Track Reborn v2.2 by Wagasez,
-- inspired by Usb), with local changes by Ako/Defou1t:
--   * whitelist file Addon/raid_whitelist.lua for auto-invite
--   * Fish Tracker always on
--   * "Fish probe": tests reading buffs of a fish that is not the target
local addon = {
    name = "Raid & Fish Tools",
    author = "Ako/Defou1t (from Norrina-Hub by Norrina)",
    desc = "Raid auto-invite, roles, give lead; fish buff tracker.",
    version = "1.3.1"
}

-- Kept at the Addon root, so replacing this folder never loses settings.
local DATA_FILE = "raidfish_data.lua"
local NORRINA_DATA_FILE = "norrina_craft_tracker_data.lua"
-- The first one found is used. The one in this addon's folder is the main
-- place; the two at the Addon root are read for older setups.
local WHITELIST_FILES = {"RaidFishTools/whitelist.txt", "raid_whitelist.lua", "norrina_whitelist.lua"}
-- The group's standard code word for passing raid lead.
local DEFAULT_LEAD_CODE = "gmlr"

local state = {
    autoInviteEnabled = false,
    autoInviteTriggers = "",
    raidWhitelist = "",
    raidBlacklist = "",
    raidWhitelistOnly = false,
    raidRoles = {},
    giveLeadCode = DEFAULT_LEAD_CODE,
    giveLeadWhitelist = "",
    giveLeadProtection = true,
    buttonX = 40,
    buttonY = 380,
}

local idSuffix = ""
local autoInviteWin, floatingBtn
local autoInviteLastByName = {}

local function log(message)
    pcall(function() api.Log:Info("[Raid & Fish] " .. tostring(message)) end)
end

local function nowSeconds()
    return math.floor((tonumber(api.Time:GetUiMsec()) or 0) / 1000)
end

-- ============================================================
-- Storage
-- ============================================================

local SETTING_KEYS = {
    "autoInviteEnabled", "autoInviteTriggers", "raidWhitelist", "raidBlacklist",
    "raidWhitelistOnly", "raidRoles", "giveLeadCode", "giveLeadWhitelist",
    "giveLeadProtection", "autoInviteX", "autoInviteY", "leadCodeStandard",
}

local function save()
    local ok, err = pcall(api.File.Write, api.File, DATA_FILE, state)
    if not ok then log("Save failed: " .. tostring(err)) end
end

local function copySettings(from)
    for _, key in ipairs(SETTING_KEYS) do
        if from[key] ~= nil then state[key] = from[key] end
    end
end

local function load()
    local ok, loaded = pcall(api.File.Read, api.File, DATA_FILE)
    if ok and type(loaded) == "table" then
        copySettings(loaded)
        if tonumber(loaded.buttonX) then state.buttonX = tonumber(loaded.buttonX) end
        if tonumber(loaded.buttonY) then state.buttonY = tonumber(loaded.buttonY) end
    else
        -- First start: take over the Raid Tool settings from Norrina-Hub.
        local okN, norrina = pcall(api.File.Read, api.File, NORRINA_DATA_FILE)
        if okN and type(norrina) == "table" then
            copySettings(norrina)
            log("Raid Tool settings taken over from Norrina-Hub.")
        end
    end
    if type(state.raidRoles) ~= "table" then state.raidRoles = {} end
    for _, key in ipairs({"autoInviteTriggers", "raidWhitelist", "raidBlacklist", "giveLeadWhitelist"}) do
        if type(state[key]) ~= "string" then state[key] = "" end
    end
    if type(state.giveLeadCode) ~= "string" or state.giveLeadCode == "" then state.giveLeadCode = DEFAULT_LEAD_CODE end
    -- 1.3.0: everyone in the group switches to the standard code word once;
    -- it can still be changed in the window afterwards.
    if not state.leadCodeStandard then
        state.giveLeadCode = DEFAULT_LEAD_CODE
        state.leadCodeStandard = true
    end
    for _, key in ipairs({"autoInviteEnabled", "raidWhitelistOnly"}) do
        if type(state[key]) ~= "boolean" then state[key] = false end
    end
    if type(state.giveLeadProtection) ~= "boolean" then state.giveLeadProtection = true end
end

-- ============================================================
-- UI helpers (from Norrina-Hub)
-- ============================================================

local function makeLabel(parent, id, text, x, y, width, height, align)
    local label = parent:CreateChildWidget("label", id, 0, true)
    label:SetExtent(width, height)
    label:RemoveAllAnchors()
    label:AddAnchor("TOPLEFT", parent, x, y)
    label:SetText(text or "")
    if label.style then
        label.style:SetAlign(align or ALIGN.LEFT)
        label.style:SetFontSize(FONT_SIZE.MIDDLE or 16)
        label.style:SetColor(0.08, 0.035, 0.01, 1)
    end
    label:Show(true)
    return label
end

local function makeButton(parent, id, text, x, y, width, height, callback)
    local button = parent:CreateChildWidget("button", id, 0, true)
    if ApplyButtonSkin and BUTTON_BASIC then ApplyButtonSkin(button, BUTTON_BASIC.DEFAULT) end
    button:SetExtent(width, height)
    button:RemoveAllAnchors()
    button:AddAnchor("TOPLEFT", parent, x, y)
    button:SetText(text)
    function button:OnClick()
        local ok, err = pcall(callback)
        if not ok then log("Error: " .. tostring(err)) end
    end
    button:SetHandler("OnClick", button.OnClick)
    button:Show(true)
    return button
end

local function makeEdit(parent, id, x, y, width, height)
    local edit = W_CTRL and W_CTRL.CreateEdit and W_CTRL.CreateEdit(id, parent)
        or parent:CreateChildWidget("edit", id, 0, true)
    edit:SetExtent(width, height)
    edit:RemoveAllAnchors()
    edit:AddAnchor("TOPLEFT", parent, x, y)
    edit:Show(true)
    return edit
end

local function centerOnPhysicalScreen(window, width, height)
    local screenW = tonumber(api.Interface:GetScreenWidth()) or 1920
    local screenH = tonumber(api.Interface:GetScreenHeight()) or 1080
    window:RemoveAllAnchors()
    window:AddAnchor("TOPLEFT", "UIParent", math.floor((screenW - width) / 2), math.floor((screenH - height) / 2))
end

local function makeTrackedDraggable(window, xKey, yKey, width, height)
    if state[xKey] and state[yKey] then
        window:RemoveAllAnchors()
        window:AddAnchor("TOPLEFT", "UIParent", state[xKey], state[yKey])
    else
        centerOnPhysicalScreen(window, width, height)
    end
    local handle = window:CreateChildWidget("emptywidget", window:GetId() .. "_drag", 0, true)
    handle:SetExtent(width - 45, 38)
    handle:AddAnchor("TOPLEFT", window, 0, 0)
    function handle:OnDragStart()
        window:StartMoving()
        api.Cursor:ClearCursor()
        api.Cursor:SetCursorImage(CURSOR_PATH.MOVE, 0, 0)
    end
    handle:SetHandler("OnDragStart", handle.OnDragStart)
    function handle:OnDragStop()
        local x, y = window:GetEffectiveOffset()
        state[xKey], state[yKey] = x, y
        window:StopMovingOrSizing()
        api.Cursor:ClearCursor()
        save()
    end
    handle:SetHandler("OnDragStop", handle.OnDragStop)
    handle:EnableDrag(true)
    handle:Show(true)
end

local function createPaperWindow(id, title, width, height)
    local window = api.Interface:CreateEmptyWindow(id)
    window:SetExtent(width, height)
    local paper = window:CreateColorDrawable(0.93, 0.86, 0.69, 0.98, "background")
    paper:AddAnchor("TOPLEFT", window, 0, 0)
    paper:AddAnchor("BOTTOMRIGHT", window, 0, 0)
    local heading = makeLabel(window, id .. "_heading", title, 12, 10, width - 24, 30, ALIGN.CENTER)
    if heading.style then heading.style:SetFontSize(FONT_SIZE.LARGE or 20) end
    return window
end

-- ============================================================
-- RAID TOOL (from Norrina-Hub)
-- ============================================================

local function normaliseChatText(value)
    value = tostring(value or ""):lower()
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    local result = value:gsub("%s+", " ")
    return result
end

local function isAutoInviteTrigger(message)
    local wanted = normaliseChatText(message)
    if wanted == "" then return false end
    for trigger in tostring(state.autoInviteTriggers or ""):gmatch("[^,]+") do
        if wanted == normaliseChatText(trigger) then return true end
    end
    return false
end

local function nameInRaidList(name, list)
    local wanted = normaliseChatText(name)
    if wanted == "" then return false end
    for entry in tostring(list or ""):gmatch("[^,]+") do
        if wanted == normaliseChatText(entry) then return true end
    end
    return false
end

-- Whitelist file: the whitelist edit boxes hold only so many characters, so
-- longer lists live in RaidFishTools/whitelist.txt. It is a Lua table (the
-- format api.File:Read is known to read; other addons' .txt files are too):
--   { lead = { "Name1" }, invite = { "Name2", "Name3" }, Guild = { ... } }
-- Names under "lead" may receive raid lead with the code word; every name in
-- the file (lead included) is whitelisted for auto-invite. Plain text is
-- accepted as well in case the client returns it as a string:
--   lead: Name1, Name2
--   Name3, Name4
local whitelistFile = {names = {}, lead = {}, count = 0, leadCount = 0, lists = 0, path = nil}

local function loadWhitelistFile()
    local names, lead, count, leadCount, lists = {}, {}, 0, 0, 0
    local data, path
    for _, candidate in ipairs(WHITELIST_FILES) do
        local ok, read = pcall(api.File.Read, api.File, candidate)
        -- api.File:Read returns plain text as a string and a Lua table as a table.
        if ok and (type(read) == "table" or (type(read) == "string" and read ~= "")) then
            data, path = read, candidate
            break
        end
    end
    local function add(value, isLead)
        for entry in tostring(value):gmatch("[^,;\r\n]+") do
            -- A raw read can keep quotes or a trailing escape around names.
            local key = normaliseChatText((entry:gsub("[\"'\\]", "")))
            if key ~= "" and key:sub(1, 1) ~= "#" and key:sub(1, 2) ~= "--" then
                if not names[key] then
                    names[key] = true
                    count = count + 1
                end
                if isLead and not lead[key] then
                    lead[key] = true
                    leadCount = leadCount + 1
                end
            end
        end
    end
    local function walk(value, depth, isLead)
        if type(value) == "string" then
            add(value, isLead)
        elseif type(value) == "table" and depth < 4 then
            for key, nested in pairs(value) do
                if type(nested) == "table" and depth == 0 then lists = lists + 1 end
                walk(nested, depth + 1, isLead or (depth == 0 and tostring(key):lower() == "lead"))
            end
        end
    end
    if not data then
        -- No list anywhere yet: create an empty one in the addon folder, in
        -- the format the game reads, ready to be filled in.
        pcall(api.File.Write, api.File, WHITELIST_FILES[1], {lead = {}, invite = {}})
    end
    if type(data) == "string" then
        for line in data:gmatch("[^\r\n]+") do
            local leadNames = line:match("^%s*[Ll][Ee][Aa][Dd]%s*[:=]%s*(.*)$")
            if leadNames then add(leadNames, true) else add(line, false) end
        end
    elseif data then
        walk(data, 0, false)
    end
    whitelistFile = {names = names, lead = lead, count = count, leadCount = leadCount, lists = lists, path = path}
end

local function inWhitelistFile(name)
    return whitelistFile.names[normaliseChatText(name)] == true
end

local function inLeadFile(name)
    return whitelistFile.lead[normaliseChatText(name)] == true
end

local RAID_ROLE_NAMES = {[1] = "Tank", [2] = "Healer", [3] = "DPS"}

local function currentRaidRoleKey()
    local name = ""
    pcall(function() name = api.Unit:GetUnitNameById(api.Unit:GetUnitId("player")) or "" end)
    name = normaliseChatText(name)
    return name ~= "" and name or "default"
end

local function savedRaidRole()
    local role = tonumber(state.raidRoles[currentRaidRoleKey()])
    return RAID_ROLE_NAMES[role] and role or nil
end

local function setRaidRole(role)
    role = tonumber(role)
    if not RAID_ROLE_NAMES[role] then return end
    state.raidRoles[currentRaidRoleKey()] = role
    save()
    if api.Team and api.Team.SetRole then pcall(api.Team.SetRole, api.Team, role) end
end

local rebuildAutoInvite, resetAutoInviteWindow

local function closeAutoInviteWindow()
    if not autoInviteWin then return end
    local window = autoInviteWin
    autoInviteWin = nil
    -- AAC keeps keyboard focus when a window with edit boxes is merely hidden.
    -- Free and rebuild it so movement/chat keys work immediately.
    pcall(function() window:Show(false) end)
    pcall(api.Interface.Free, api.Interface, window)
end

local function readEdits()
    state.autoInviteTriggers = tostring(autoInviteWin._edit:GetText() or "")
    state.raidWhitelist = tostring(autoInviteWin._whitelist:GetText() or "")
    state.raidBlacklist = tostring(autoInviteWin._blacklist:GetText() or "")
    state.giveLeadCode = tostring(autoInviteWin._leadCode:GetText() or "")
    state.giveLeadWhitelist = tostring(autoInviteWin._leadWhitelist:GetText() or "")
end

local function ensureAutoInviteWindow()
    if autoInviteWin then return end
    local w = createPaperWindow("raidfish_raid_tool" .. idSuffix, "Raid Tool - Recruiting", 520, 650)
    autoInviteWin = w
    makeTrackedDraggable(w, "autoInviteX", "autoInviteY", 520, 650)
    makeButton(w, "rf_close", "X", 520 - 34, 7, 27, 27, function() closeAutoInviteWindow() end)
    w._status = makeLabel(w, "rf_status", "", 18, 45, 484, 25, ALIGN.CENTER)
    makeLabel(w, "rf_explain", "Auto-invite recruiting messages from chat", 18, 72, 484, 22, ALIGN.CENTER)
    makeLabel(w, "rf_prompt", "Recruit phrases (comma-separated):", 18, 106, 300, 24, ALIGN.LEFT)
    w._edit = makeEdit(w, "rf_phrases", 18, 132, 484, 30)
    makeLabel(w, "rf_note", "Example: x serp, x cr, x gr  |  Raid leader required", 18, 169, 484, 24, ALIGN.CENTER)
    makeLabel(w, "rf_white_label", "Whitelist (comma-separated player names):", 18, 202, 330, 24, ALIGN.LEFT)
    w._whitelist = makeEdit(w, "rf_whitelist", 18, 228, 484, 30)
    makeLabel(w, "rf_black_label", "Blacklist (never invite these names):", 18, 268, 330, 24, ALIGN.LEFT)
    w._blacklist = makeEdit(w, "rf_blacklist", 18, 294, 484, 30)
    makeLabel(w, "rf_role_label", "Your raid role:", 18, 338, 140, 24, ALIGN.LEFT)
    w._roleStatus = makeLabel(w, "rf_role_status", "", 190, 338, 310, 24, ALIGN.LEFT)
    w._roleButtons = {}
    for role = 1, 3 do
        local capturedRole = role
        w._roleButtons[role] = makeButton(w, "rf_role_" .. role, RAID_ROLE_NAMES[role], 18 + (role - 1) * 121, 364, 113, 28, function()
            setRaidRole(capturedRole); resetAutoInviteWindow()
        end)
    end
    w._whitelistToggle = makeButton(w, "rf_whitelist_only", "", 18, 404, 190, 28, function()
        state.raidWhitelistOnly = not state.raidWhitelistOnly
        save(); resetAutoInviteWindow()
    end)
    w._fileStatus = makeLabel(w, "rf_file_status", "", 214, 406, 180, 24, ALIGN.LEFT)
    makeButton(w, "rf_file_reload", "Reload file", 400, 404, 102, 28, function()
        loadWhitelistFile()
        log(whitelistFile.path and ("Whitelist file Addon/" .. whitelistFile.path .. ": " .. whitelistFile.count
            .. " names, " .. whitelistFile.leadCount .. " may get lead")
            or "No whitelist file (Addon/RaidFishTools/whitelist.txt).")
        resetAutoInviteWindow()
    end)
    makeLabel(w, "rf_lead_code_label", "Give lead code word:", 18, 446, 180, 24, ALIGN.LEFT)
    w._leadCode = makeEdit(w, "rf_lead_code", 205, 442, 280, 30)
    makeLabel(w, "rf_lead_white_label", "Give lead whitelist (+ \"lead\" list in the file):", 18, 484, 484, 24, ALIGN.LEFT)
    w._leadWhitelist = makeEdit(w, "rf_lead_whitelist", 18, 510, 484, 30)
    w._leadToggle = makeButton(w, "rf_lead_protection", "", 18, 556, 210, 28, function()
        state.giveLeadProtection = not state.giveLeadProtection; save(); resetAutoInviteWindow()
    end)
    -- Fish Tracker has no settings: it shows itself above any fish you target.
    makeLabel(w, "rf_fish_note", "Fish Tracker: always on - target a fish", 18, 606, 290, 24, ALIGN.LEFT)
    makeButton(w, "rf_save", "Save", 315, 602, 85, 28, function()
        readEdits(); save(); resetAutoInviteWindow()
    end)
    w._toggle = makeButton(w, "rf_toggle", "", 408, 602, 94, 28, function()
        readEdits()
        state.autoInviteEnabled = not state.autoInviteEnabled
        save(); resetAutoInviteWindow()
    end)
    w:Show(false)
end

rebuildAutoInvite = function()
    ensureAutoInviteWindow()
    local w = autoInviteWin
    w._edit:SetText(tostring(state.autoInviteTriggers or ""))
    w._whitelist:SetText(tostring(state.raidWhitelist or ""))
    w._blacklist:SetText(tostring(state.raidBlacklist or ""))
    w._leadCode:SetText(tostring(state.giveLeadCode or DEFAULT_LEAD_CODE))
    w._leadWhitelist:SetText(tostring(state.giveLeadWhitelist or ""))
    w._status:SetText(state.autoInviteEnabled and "RECRUITING: ON" or "RECRUITING: OFF")
    if w._status.style then
        if state.autoInviteEnabled then w._status.style:SetColor(0.04, 0.42, 0.08, 1)
        else w._status.style:SetColor(0.72, 0.08, 0.05, 1) end
    end
    w._toggle:SetText(state.autoInviteEnabled and "Turn Off" or "Turn On")
    w._whitelistToggle:SetText(state.raidWhitelistOnly and "Whitelist Only: ON" or "Whitelist Only: OFF")
    w._fileStatus:SetText(whitelistFile.path and ("File: " .. whitelistFile.count .. ", lead " .. whitelistFile.leadCount) or "File: none")
    w._leadToggle:SetText(state.giveLeadProtection and "Lead Protection: ON" or "Lead Protection: OFF")
    local selectedRole = savedRaidRole()
    for role, button in ipairs(w._roleButtons or {}) do
        button:SetText((role == selectedRole and "[" or "") .. RAID_ROLE_NAMES[role] .. (role == selectedRole and "]" or ""))
        if button.style then
            if role == selectedRole then button.style:SetColor(0.04, 0.42, 0.08, 1)
            else button.style:SetColor(0.08, 0.035, 0.01, 1) end
        end
    end
    w._roleStatus:SetText(selectedRole and ("Selected: " .. RAID_ROLE_NAMES[selectedRole]) or "Selected: None")
    if w._roleStatus.style then w._roleStatus.style:SetColor(0.04, 0.42, 0.08, 1) end
end

resetAutoInviteWindow = function()
    local wasVisible = autoInviteWin and autoInviteWin:IsVisible()
    closeAutoInviteWindow()
    ensureAutoInviteWindow()
    rebuildAutoInvite()
    autoInviteWin:Show(wasVisible and true or false)
end

local function toggleAutoInvite()
    if autoInviteWin and autoInviteWin:IsVisible() then
        closeAutoInviteWindow()
    else
        ensureAutoInviteWindow()
        rebuildAutoInvite()
        autoInviteWin:Show(true)
    end
end

local function onChatMessage(channel, unit, isHostile, name, message)
    name = tostring(name or "")
    local code = normaliseChatText(state.giveLeadCode or DEFAULT_LEAD_CODE)
    -- Protection controls who may request lead; it must not disable the
    -- handoff itself. With protection OFF, any raid member using the code word
    -- may receive lead.
    if code ~= "" and normaliseChatText(message) == code
        and (channel == 5 or channel == -3 or channel == 7)
        and (not state.giveLeadProtection or nameInRaidList(name, state.giveLeadWhitelist) or inLeadFile(name)) then
        local index
        pcall(function() index = api.Team:GetMemberIndexByName(name) end)
        if index ~= nil then pcall(api.Team.MakeTeamOwner, api.Team, "team" .. tostring(index)) end
        return
    end
    if not state.autoInviteEnabled or not isAutoInviteTrigger(message) then return end
    if name == "" then return end
    if nameInRaidList(name, state.raidBlacklist) then return end
    if state.raidWhitelistOnly and not (nameInRaidList(name, state.raidWhitelist) or inWhitelistFile(name)) then return end

    local selfName
    local ok = pcall(function() selfName = api.Unit:GetUnitNameById(api.Unit:GetUnitId("player")) end)
    if ok and selfName and name == selfName then return end

    -- One invite per player per 30 seconds.
    local now = nowSeconds()
    local last = tonumber(autoInviteLastByName[name]) or -1000
    if now - last < 30 then return end
    autoInviteLastByName[name] = now

    local inviteOk, inviteErr = pcall(api.Team.InviteToTeam, api.Team, name, false)
    if inviteOk then
        log("Raid Tool: invited " .. name .. " for '" .. tostring(message) .. "'.")
    else
        log("Raid Tool invite failed for " .. name .. ": " .. tostring(inviteErr))
    end
end

-- ============================================================
-- FISH TRACKER (from Norrina-Hub; based on Fish Track Reborn v2.2 by
-- Wagasez, inspired by Usb). Always on.
-- ============================================================

local fishBuffIds = {
    [5715] = true, [5264] = true, [5265] = true, [5266] = true,
    [5267] = true, [5508] = true
}
local fishActionBuffs = {[5264] = true, [5265] = true, [5266] = true, [5267] = true, [5508] = true}
local fishNames = {
    ["Marlin"] = true, ["Blue Marlin"] = true, ["Tuna"] = true, ["Blue Tuna"] = true,
    ["Bluefin Tuna"] = true, ["Sunfish"] = true, ["Sailfish"] = true, ["Sturgeon"] = true,
    ["Pink Pufferfish"] = true, ["Carp"] = true, ["Arowana"] = true, ["Pufferfish"] = true,
    ["Eel"] = true, ["Pink Marlin"] = true, ["Treasure Mimic"] = true,
    ["철갑상어"] = true, ["청새치"] = true, ["참다랑어"] = true, ["돛새치"] = true, ["개복치"] = true,
    ["鲟鱼"] = true, ["枪鱼"] = true, ["蓝鳍金枪鱼"] = true, ["旗鱼"] = true, ["翻车鱼"] = true
}
local fish = {
    targetWin = nil, targetIcon = nil, actionTime = nil, strengthIcon = nil, strengthTime = nil,
    markerData = {}, markerUI = {}, boatData = nil, boatUI = nil, lastPosition = "",
}
local FISH_DEAD_TIME_MS, FISH_OWNERS_MARK_ID = 150000, 4867

local function fishHideAll()
    if fish.targetWin then fish.targetWin:Show(false) end
    if fish.watch then fish.watch.win:Show(false) end
    for _, ui in pairs(fish.markerUI) do if ui.window then ui.window:Show(false) end end
    if fish.boatUI and fish.boatUI.window then fish.boatUI.window:Show(false) end
end

-- Widgets are only touched when something changed. Up to 1.3.0 the icon
-- texture, texts and anchors were set again on every frame while a fish was
-- targeted; the client's renderer runs in its own thread, and from 2026-10-22
-- the game crashed there (CryRenderD3D10.dll, null read) several times a day.
-- Last visibility, text and texture per widget (separate: an icon is also shown/hidden).
local shown, texts, textures = {}, {}, {}

local function fishShow(widget, visible)
    if shown[widget] == visible then return end
    shown[widget] = visible
    widget:Show(visible)
end

local function fishText(label, text)
    if texts[label] == text then return end
    texts[label] = text
    label:SetText(text)
end

local buffIcons = {}   -- buff id -> icon path

local function fishSetIcon(icon, buffId, path)
    if not icon then return end
    local iconPath = path or buffIcons[buffId]
    if not iconPath then
        local ok, tooltip = pcall(api.Ability.GetBuffTooltip, api.Ability, buffId, 1)
        iconPath = ok and tooltip and tooltip.path or nil
        buffIcons[buffId] = iconPath
    end
    if not iconPath or textures[icon] == iconPath then return end
    textures[icon] = iconPath
    pcall(F_SLOT.SetIconBackGround, icon, iconPath)
end

local function fishCreateIcon(parent, id)
    local icon = CreateItemIconButton(id, parent)
    icon:Show(true)
    F_SLOT.ApplySlotSkin(icon, icon.back, SLOT_STYLE.DEFAULT)
    return icon
end

local function fishLabel(parent, id, text, x, y, r, g, b)
    local label = makeLabel(parent, id, text, x, y, 38, 20, ALIGN.CENTER)
    if label.style and r then label.style:SetColor(r, g, b, 1) end
    return label
end

-- One overlay (action + Strength Contest icons with timers) drawn above a
-- unit given by its token. "target" is the original; the second one follows
-- the client's watch / track target.
local function createFishOverlay(ids, tag)
    local s = idSuffix
    local o = {lastPosition = ""}
    o.win = api.Interface:CreateEmptyWindow(ids.win .. s)
    o.win:Show(false)
    o.icon = fishCreateIcon(o.win, ids.icon .. s)
    o.icon:AddAnchor("TOPLEFT", o.win, "TOPLEFT", 0, 0)
    o.actionTime = fishLabel(o.win, ids.icon .. "_time" .. s, "", 0, 38, 0, 1, 0)
    o.strengthIcon = fishCreateIcon(o.win, ids.strength .. s)
    o.strengthIcon:AddAnchor("LEFT", o.icon, "RIGHT", 5, 0)
    o.strengthIcon:Show(false)
    o.strengthTime = fishLabel(o.win, ids.strength .. "_time" .. s, "", 43, 38, 1, 1, 0)
    if tag then fishLabel(o.win, ids.win .. "_tag" .. s, tag, 21, -22, 0.4, 0.8, 1) end
    return o
end

local function initFishTracker()
    if fish.targetWin then return end
    local s = idSuffix
    fish.main = createFishOverlay({win = "raidfish_fish_target", icon = "raidfish_fish_action",
        strength = "raidfish_fish_strength"})
    fish.watch = createFishOverlay({win = "raidfish_fish_watch", icon = "raidfish_fish_watch_action",
        strength = "raidfish_fish_watch_strength"}, "W")
    fish.targetWin = fish.main.win

    for marker = 1, 9 do
        local window = api.Interface:CreateEmptyWindow("raidfish_fish_marker_" .. marker .. s)
        window:Show(false)
        local icon = fishCreateIcon(window, "raidfish_fish_marker_icon_" .. marker .. s)
        icon:AddAnchor("TOPLEFT", window, "TOPLEFT", 0, 0)
        local top = fishLabel(window, "raidfish_fish_marker_num_" .. marker .. s, tostring(marker), 0, -22)
        local time = fishLabel(window, "raidfish_fish_marker_time_" .. marker .. s, "", 0, 38, 1, 0.5, 0)
        fish.markerUI[marker] = {window = window, icon = icon, top = top, time = time}
    end
    local boat = api.Interface:CreateEmptyWindow("raidfish_fish_boat" .. s)
    boat:Show(false)
    local boatIcon = fishCreateIcon(boat, "raidfish_fish_boat_icon" .. s)
    boatIcon:AddAnchor("TOPLEFT", boat, "TOPLEFT", 0, 0)
    local boatTime = fishLabel(boat, "raidfish_fish_boat_time" .. s, "", 0, 38, 0.3, 0.6, 1)
    fish.boatUI = {window = boat, icon = boatIcon, time = boatTime}
end

-- The client's unit frames keep the token of the unit they show in
-- frame.target ("target" for the target frame, as Better ArcheAge reads it),
-- so the watch / track target frame tells which token to read.
local function watchToken()
    if fish.watchTokenCache then return fish.watchTokenCache end
    -- Asking the client for its frame is not free: once every 5 s at most.
    local nowMs = tonumber(api.Time:GetUiMsec()) or 0
    if fish.watchAskedMs and nowMs - fish.watchAskedMs < 5000 then return nil end
    fish.watchAskedMs = nowMs
    local ok, token = pcall(function()
        local frame = ADDON:GetContent(UIC.WATCH_TARGET_FRAME)
        return frame and frame.target
    end)
    if ok and type(token) == "string" and token ~= "" and token ~= "target" then
        fish.watchTokenCache = token
        return token
    end
    return nil
end

-- Fills overlay o for the unit behind token. Returns what the caller needs
-- (unit id, info, dead, Owner's Mark buff) or nil when it is not a fish.
local function updateFishOverlay(o, token, fallbackX, fallbackY)
    local unitId = token and api.Unit:GetUnitId(token)
    local info = unitId and api.Unit:GetUnitInfoById(unitId) or nil
    if not info or not fishNames[info.name] then fishShow(o.win, false); return nil end
    local okPos, x, y = pcall(function() return api.Unit:GetUnitScreenPosition(token) end)
    if not (okPos and x and y) and fallbackX then
        -- No screen position for this token: a fixed spot instead.
        x, y = fallbackX, fallbackY
    end
    x, y = tonumber(x), tonumber(y)
    if x and y then
        -- Re-anchored only when it moved by 2 pixels or more.
        if not o.lastX or math.abs(x - o.lastX) >= 2 or math.abs(y - o.lastY) >= 2 then
            o.win:RemoveAllAnchors()
            o.win:AddAnchor("TOP", "UIParent", "TOPLEFT", math.floor(x - 42), math.floor(y + 5))
            o.lastX, o.lastY = x, y
        end
    end
    local health = api.Unit:UnitHealth(token)
    if health and health <= 0 then
        fishShow(o.strengthIcon, false); fishText(o.strengthTime, "")
        fishSetIcon(o.icon, 4832); fishText(o.actionTime, "")
        fishShow(o.win, true)
        return {id = unitId, info = info, dead = true}
    end
    local count = api.Unit:UnitBuffCount(token) or 0
    local action, contest, owner
    for index = 1, count do
        local buff = api.Unit:UnitBuff(token, index)
        if buff then
            if buff.buff_id == FISH_OWNERS_MARK_ID then owner = buff
            elseif fishBuffIds[buff.buff_id] then
                if fishActionBuffs[buff.buff_id] then action = buff else contest = buff end
            end
        end
    end
    if action then
        fishSetIcon(o.icon, action.buff_id, action.path)
        fishText(o.actionTime, string.format("%.1fs", (tonumber(action.timeLeft) or 0) / 1000))
    else
        fishSetIcon(o.icon, 3710)
        fishText(o.actionTime, "Waiting")
    end
    if contest then
        fishSetIcon(o.strengthIcon, 5715)
        fishText(o.strengthTime, string.format("%.1fs", (tonumber(contest.timeLeft) or 0) / 1000))
        fishShow(o.strengthIcon, true)
    else
        fishShow(o.strengthIcon, false); fishText(o.strengthTime, "")
    end
    fishShow(o.win, true)
    return {id = unitId, info = info, owner = owner}
end

local function updateFishTracker()
    if not fish.targetWin then return end
    local now = tonumber(api.Time:GetUiMsec()) or 0
    local active = 0
    for marker = 1, 9 do
        local id = api.Unit:GetOverHeadMarkerUnitId(marker)
        local info = id and api.Unit:GetUnitInfoById(id) or nil
        if info and fishNames[info.name] then
            fish.markerData[marker] = fish.markerData[marker] or {id = id}
            if fish.markerData[marker].id ~= id then fish.markerData[marker] = {id = id} end
        elseif fish.markerData[marker] then
            fish.markerData[marker] = nil
            fishShow(fish.markerUI[marker].window, false)
        end
        local data, ui = fish.markerData[marker], fish.markerUI[marker]
        if data and data.deathAt then
            local remaining = FISH_DEAD_TIME_MS - (now - data.deathAt)
            if remaining > 0 then
                if ui.slot ~= active then
                    ui.window:RemoveAllAnchors()
                    ui.window:AddAnchor("TOP", "UIParent", "CENTER", active * 50 - 125, 200)
                    ui.slot = active
                end
                fishSetIcon(ui.icon, 4832)
                fishText(ui.time, string.format("%.0fs", remaining / 1000))
                fishShow(ui.window, true)
                active = active + 1
            else
                data.deathAt = nil
                fishShow(ui.window, false)
            end
        end
    end
    if fish.boatData then
        local remaining = fish.boatData.expiresAt - now
        if remaining > 0 then
            if fish.boatUI.slot ~= active then
                fish.boatUI.window:RemoveAllAnchors()
                fish.boatUI.window:AddAnchor("TOP", "UIParent", "CENTER", active * 50 - 125, 200)
                fish.boatUI.slot = active
            end
            fishText(fish.boatUI.time, string.format("%.0fs", remaining / 1000))
            fishShow(fish.boatUI.window, true)
        else
            fish.boatData = nil
            fishShow(fish.boatUI.window, false)
        end
    end

    local main = updateFishOverlay(fish.main, "target")
    -- The watched fish, unless it is the same fish as the target.
    local token = watchToken()
    local watchId = token and api.Unit:GetUnitId(token)
    if token and watchId and not (main and main.id == watchId) then
        local screenW = tonumber(api.Interface:GetScreenWidth()) or 1920
        updateFishOverlay(fish.watch, token, math.floor(screenW / 2) + 100, 150)
    else
        fishShow(fish.watch.win, false)
    end

    if not main then return end
    if main.dead then
        for marker = 1, 9 do
            local data = fish.markerData[marker]
            if data and data.id == main.id and not data.deathAt then data.deathAt = now end
        end
        return
    end
    if main.owner then
        local player = api.Unit:GetUnitInfoById(api.Unit:GetUnitId("player"))
        if player and main.info.owner_name == player.name then
            fish.boatData = {expiresAt = now + (tonumber(main.owner.timeLeft) or 0)}
            fishSetIcon(fish.boatUI.icon, FISH_OWNERS_MARK_ID)
        end
    end
end
-- Experiment: can buffs of a fish that is NOT the target be read? The addon
-- API takes unit tokens (player, target, targettarget, team1-50, playerpet);
-- a fish with an overhead marker gives only a unit id. This tries
-- UnitBuffCount with that id and with the undocumented "watchtarget" token,
-- and reports each distinct result once in chat.
local probe = {seen = {}, lastMs = 0, lines = {}}
local PROBE_FILE = "RaidFishTools/probe_log.txt"

-- Each new finding goes to chat and to PROBE_FILE (last 200 lines), so it
-- can be read back without a screenshot of the chat.
local function probeReport(key, text)
    if probe.seen[key] == text then return end
    probe.seen[key] = text
    log("Fish probe: " .. text)
    local stamp = ""
    pcall(function()
        local t = api.Time:TimeToDate(api.Time:GetLocalTime())
        stamp = string.format("%02d:%02d:%02d ", tonumber(t.hour) or 0, tonumber(t.minute or t.min) or 0, tonumber(t.second or t.sec) or 0)
    end)
    table.insert(probe.lines, stamp .. (tostring(text):gsub('[%c"\\]', "'")))
    while #probe.lines > 200 do table.remove(probe.lines, 1) end
    pcall(api.File.Write, api.File, PROBE_FILE, {lines = probe.lines})
end

-- Step by step: what the watch frame holds and what the game answers for it.
local function probeWatchFrame()
    local okFrame, frame = pcall(function() return ADDON:GetContent(UIC.WATCH_TARGET_FRAME) end)
    if not okFrame or not frame then
        probeReport("wf", "watch frame: " .. (okFrame and "nil" or ("error " .. tostring(frame))))
        return
    end
    local fields = {}
    pcall(function()
        for key, value in pairs(frame) do
            local kind = type(value)
            if kind == "string" or kind == "number" or kind == "boolean" then
                fields[#fields + 1] = tostring(key) .. "=" .. tostring(value)
            end
            if #fields >= 40 then break end
        end
    end)
    local okVis, visible = pcall(function() return frame:IsVisible() end)
    probeReport("wf", "watch frame visible=" .. tostring(okVis and visible) .. " fields: " .. table.concat(fields, ", "))
    local okT, token = pcall(function() return frame.target end)
    if not (okT and type(token) == "string") then return end
    local function ask(label, fn)
        local ok, a, b = pcall(fn)
        return label .. "=" .. (ok and (tostring(a) .. (b ~= nil and ("," .. tostring(b)) or "")) or ("error " .. tostring(a)))
    end
    probeReport("wf:" .. token, "token '" .. token .. "': "
        .. ask("id", function() return api.Unit:GetUnitId(token) end) .. "; "
        .. ask("name", function() return api.Unit:UnitName(token) end) .. "; "
        .. ask("hp", function() return api.Unit:UnitHealth(token) end) .. "; "
        .. ask("buffs", function() return api.Unit:UnitBuffCount(token) end) .. "; "
        .. ask("screen", function() return api.Unit:GetUnitScreenPosition(token) end) .. "; "
        .. ask("distance", function() return api.Unit:UnitDistance(token) end))
end

local function fishProbeOthers()
    local now = tonumber(api.Time:GetUiMsec()) or 0
    if now - probe.lastMs < 3000 then return end
    probe.lastMs = now
    local targetId = api.Unit:GetUnitId("target")
    for marker = 1, 9 do
        local data = fish.markerData[marker]
        if data and data.id and data.id ~= targetId then
            local ok, count = pcall(function() return api.Unit:UnitBuffCount(data.id) end)
            local buffs = ""
            if ok and tonumber(count) and tonumber(count) > 0 then
                local okBuff, buff = pcall(function() return api.Unit:UnitBuff(data.id, 1) end)
                buffs = okBuff and type(buff) == "table" and (" first buff id " .. tostring(buff.buff_id)) or ""
            end
            probeReport("marker" .. marker, "marked fish " .. marker .. " (not target): buffs by id -> "
                .. (ok and tostring(count) or ("error " .. tostring(count))) .. buffs)
            -- What the game tells about it by id (health? its target?).
            local okInfo, info = pcall(function() return api.Unit:GetUnitInfoById(data.id) end)
            if okInfo and type(info) == "table" then
                local fields = {}
                for key, value in pairs(info) do
                    if type(value) ~= "table" and type(value) ~= "function" then
                        fields[#fields + 1] = tostring(key) .. "=" .. tostring(value)
                    end
                    if #fields >= 25 then break end
                end
                probeReport("info" .. marker, "marked fish " .. marker .. " info: " .. table.concat(fields, ", "))
            end
            local okPos, x, y = pcall(function() return api.Unit:GetUnitScreenPosition(data.id) end)
            probeReport("pos" .. marker, "marked fish " .. marker .. " screen position by id -> "
                .. (okPos and (tostring(x) .. ", " .. tostring(y)) or ("error " .. tostring(x))))
        end
    end
    -- The client's watch / track target (WATCH_TARGET_FRAME) has no documented
    -- unit token, so a few likely names are tried; whichever answers is reported.
    probeReport("watchframe", "watch frame unit token = " .. tostring(watchToken()))
    probeWatchFrame()
    for _, token in ipairs({watchToken() or "watchtarget", "watchtarget", "tracktarget", "focus"}) do
        local okId, watchId = pcall(function() return api.Unit:GetUnitId(token) end)
        if okId and watchId and watchId ~= targetId then
            local info = api.Unit:GetUnitInfoById(watchId)
            local ok, count = pcall(function() return api.Unit:UnitBuffCount(token) end)
            local okPos, x, y = pcall(function() return api.Unit:GetUnitScreenPosition(token) end)
            probeReport("watch:" .. token, "'" .. token .. "' = " .. tostring(info and info.name)
                .. ", buffs -> " .. (ok and tostring(count) or ("error " .. tostring(count)))
                .. ", screen -> " .. (okPos and (tostring(x) .. ", " .. tostring(y)) or "error"))
        end
    end
end

-- ============================================================
-- Button and lifecycle
-- ============================================================

local function createFloatingButton()
    floatingBtn = api.Interface:CreateEmptyWindow("raidfish_floating" .. idSuffix, "UIParent")
    floatingBtn:SetExtent(130, 40)
    floatingBtn:RemoveAllAnchors()
    floatingBtn:AddAnchor("TOPLEFT", "UIParent", state.buttonX, state.buttonY)
    local background = floatingBtn:CreateNinePartDrawable(TEXTURE_PATH.HUD, "background")
    background:SetTextureInfo("bg_quest")
    background:SetColor(0, 0, 0, 0.6)
    background:AddAnchor("TOPLEFT", floatingBtn, 0, 0)
    background:AddAnchor("BOTTOMRIGHT", floatingBtn, 0, 0)
    local button = api.Interface:CreateWidget("button", "raidfish_button" .. idSuffix, floatingBtn)
    api.Interface:ApplyButtonSkin(button, BUTTON_BASIC.DEFAULT)
    button:SetExtent(120, 28)
    button:AddAnchor("TOPLEFT", floatingBtn, 5, 6)
    button:SetText("Raid Tool")
    button:SetHandler("OnClick", function()
        local ok, err = pcall(toggleAutoInvite)
        if not ok then log("Error: " .. tostring(err)) end
    end)
    button:Show(true)
    function floatingBtn:OnDragStart()
        if api.Input:IsShiftKeyDown() then
            floatingBtn:StartMoving()
            api.Cursor:ClearCursor()
            api.Cursor:SetCursorImage(CURSOR_PATH.MOVE, 0, 0)
        end
    end
    floatingBtn:SetHandler("OnDragStart", floatingBtn.OnDragStart)
    function floatingBtn:OnDragStop()
        local x, y = floatingBtn:GetEffectiveOffset()
        state.buttonX, state.buttonY = x, y
        floatingBtn:StopMovingOrSizing()
        api.Cursor:ClearCursor()
        save()
    end
    floatingBtn:SetHandler("OnDragStop", floatingBtn.OnDragStop)
    floatingBtn:EnableDrag(true)
    floatingBtn:Show(true)
end

local lastFishUpdateMs = -100000

local function OnUpdate()
    -- 10 times a second is enough for timers shown to 0.1 s.
    local nowMs = tonumber(api.Time:GetUiMsec()) or 0
    if nowMs - lastFishUpdateMs < 100 then return end
    lastFishUpdateMs = nowMs
    local ok, err = pcall(updateFishTracker)
    if not ok then log("Fish Tracker error: " .. tostring(err)) end
    -- The probe (fishProbeOthers) answered everything it could, so it no
    -- longer runs: verified 2026-10-23 that the addon API returns nothing for
    -- a fish by marker id (only name/level) or by the "watchtarget" token.
end

local function OnLoad()
    -- Windows of a previous load survive an addon reload; new names avoid clashes.
    idSuffix = "_" .. string.format("%.0f", tonumber(api.Time:GetUiMsec()) or 0)
    local ok, err = pcall(load)
    if not ok then log("Settings load failed: " .. tostring(err)) end
    ok, err = pcall(loadWhitelistFile)
    if not ok then log("Whitelist file failed: " .. tostring(err)) end
    save()
    ok, err = pcall(initFishTracker)
    if not ok then log("Fish Tracker failed to start: " .. tostring(err)) end
    api:DoIn(200, function()
        local success, buttonErr = pcall(createFloatingButton)
        if not success then log("Button failed: " .. tostring(buttonErr)) end
    end)
    api.On("CHAT_MESSAGE", function(...)
        local success, chatErr = pcall(onChatMessage, ...)
        if not success then log("Raid Tool error: " .. tostring(chatErr)) end
    end)
    api.On("UPDATE", OnUpdate)
    log("Loaded. 'Raid Tool' button opens recruiting; Fish Tracker is on. Shift-drag moves the button.")
end

local function OnUnload()
    api.On("UPDATE", function() end)
    api.On("CHAT_MESSAGE", function() end)
    closeAutoInviteWindow()
    fishHideAll()
    if floatingBtn then floatingBtn:Show(false) end
    save()
end

addon.OnLoad = OnLoad
addon.OnUnload = OnUnload

return addon
