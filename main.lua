local api = require("api")

-- Raid Tool split out of Norrina-Hub 1.1.56.8 by Norrina, with local
-- changes by Ako/Defou1t: the whitelist lives in RaidFishTools/whitelist.txt
-- and is edited both in Notepad and in the window. The Fish Tracker moved to
-- Auction Income 1.10.0 (its Fish: On/Off button); the folder keeps its name
-- so updates and settings carry over.
local addon = {
    name = "Raid Tools",
    author = "Ako/Defou1t (from Norrina-Hub by Norrina)",
    desc = "Raid auto-invite, roles, give lead.",
    version = "1.4.0"
}

-- Kept at the Addon root, so replacing this folder never loses settings.
local DATA_FILE = "raidfish_data.lua"
local NORRINA_DATA_FILE = "norrina_craft_tracker_data.lua"
-- The first one found is used. The one in this addon's folder is the main
-- place; the two at the Addon root are read for older setups.
local WHITELIST_FILES = {"RaidFishTools/whitelist.txt", "raid_whitelist.lua", "norrina_whitelist.lua"}
-- The group's standard code word for passing raid lead.
local DEFAULT_LEAD_CODE = "gmlr"
-- Characters an edit box takes (~400 names of 10 letters).
local EDIT_MAX_CHARS = 5000

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
    pcall(function() api.Log:Info("[Raid Tools] " .. tostring(message)) end)
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
    "giveLeadProtection", "autoInviteX", "autoInviteY", "leadCodeStandard", "whitelistInFile",
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
    -- The client's default is short; name lists need room.
    pcall(function() edit:SetMaxTextLength(EDIT_MAX_CHARS) end)
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

-- Whitelist file RaidFishTools/whitelist.txt, a Lua table (the format
-- api.File:Read reads; Notepad edits it while the game runs):
--   { lead = { "Name1" }, invite = { "Name2", "Name3" }, Guild = { ... } }
-- Names under "lead" may receive raid lead with the code word; every name in
-- the file (lead included) is whitelisted for auto-invite. The window shows
-- the file: the Whitelist box holds every name outside "lead", the Give lead
-- box the "lead" names, and Save writes both back. Plain text is accepted too:
--   lead: Name1, Name2
--   Name3, Name4
local whitelistFile = {names = {}, lead = {}, count = 0, leadCount = 0, lists = 0, path = nil,
    inviteNames = {}, leadNames = {}, groupOf = {}}

-- Appends the names in text (as written) to into, skipping those in seen.
local function splitNames(text, into, seen)
    for entry in tostring(text or ""):gmatch("[^,;\r\n]+") do
        -- A raw read can keep quotes or a trailing escape around names.
        local name = (entry:gsub("[\"'\\]", "")):gsub("^%s+", ""):gsub("%s+$", "")
        local key = normaliseChatText(name)
        if key ~= "" and key:sub(1, 1) ~= "#" and key:sub(1, 2) ~= "--" and not seen[key] then
            seen[key] = true
            into[#into + 1] = name
        end
    end
    return into
end

local GROUP_RANK = {lead = 1, invite = 2}

local function loadWhitelistFile()
    local data, path
    for _, candidate in ipairs(WHITELIST_FILES) do
        local ok, read = pcall(api.File.Read, api.File, candidate)
        -- api.File:Read returns plain text as a string and a Lua table as a table.
        if ok and (type(read) == "table" or (type(read) == "string" and read ~= "")) then
            data, path = read, candidate
            break
        end
    end
    if not data then
        -- No list anywhere yet: create an empty one in the addon folder, in
        -- the format the game reads, ready to be filled in.
        pcall(api.File.Write, api.File, WHITELIST_FILES[1], {lead = {}, invite = {}})
    end
    -- Group name -> its names as text; "lead" first, then "invite", then the rest.
    local groups, order = {}, {}
    local function addGroup(group, value)
        if not groups[group] then groups[group] = {}; order[#order + 1] = group end
        local list = groups[group]
        local function walk(nested, depth)
            if type(nested) == "string" then
                list[#list + 1] = nested
            elseif type(nested) == "table" and depth < 3 then
                for _, inner in ipairs(nested) do walk(inner, depth + 1) end
                for key, inner in pairs(nested) do
                    if type(key) ~= "number" then walk(inner, depth + 1) end
                end
            end
        end
        walk(value, 0)
    end
    if type(data) == "string" then
        for line in data:gmatch("[^\r\n]+") do
            local leadNames = line:match("^%s*[Ll][Ee][Aa][Dd]%s*[:=]%s*(.*)$")
            if leadNames then addGroup("lead", leadNames) else addGroup("invite", line) end
        end
    elseif type(data) == "table" then
        local keys = {}
        for key in pairs(data) do if type(key) ~= "number" then keys[#keys + 1] = tostring(key) end end
        table.sort(keys, function(x, y)
            local rx, ry = GROUP_RANK[x:lower()] or 3, GROUP_RANK[y:lower()] or 3
            if rx ~= ry then return rx < ry end
            return x < y
        end)
        for _, key in ipairs(keys) do addGroup(key:lower() == "lead" and "lead" or key, data[key]) end
        -- Names right in the table, outside any group, count as invite.
        for _, value in ipairs(data) do addGroup("invite", value) end
    end
    local names, lead, groupOf = {}, {}, {}
    local count, leadCount = 0, 0
    local leadNames, inviteNames, inviteSeen = {}, {}, {}
    for _, group in ipairs(order) do
        local isLead = group == "lead"
        for _, name in ipairs(splitNames(table.concat(groups[group], ","), {}, {})) do
            local key = normaliseChatText(name)
            if not names[key] then names[key] = true; count = count + 1 end
            if isLead then
                if not lead[key] then lead[key] = true; leadCount = leadCount + 1; leadNames[#leadNames + 1] = name end
            elseif not inviteSeen[key] then
                inviteSeen[key] = true
                inviteNames[#inviteNames + 1] = name
                groupOf[key] = group
            end
        end
    end
    whitelistFile = {names = names, lead = lead, count = count, leadCount = leadCount, lists = #order, path = path,
        inviteNames = inviteNames, leadNames = leadNames, groupOf = groupOf}
end

-- Writes the two name lists to RaidFishTools/whitelist.txt; names keep the
-- group they had in the file, new ones go to "invite".
local function writeWhitelistFile(inviteText, leadText)
    local file = {lead = splitNames(leadText, {}, {}), invite = {}}
    for _, name in ipairs(splitNames(inviteText, {}, {})) do
        local group = whitelistFile.groupOf[normaliseChatText(name)] or "invite"
        file[group] = file[group] or {}
        table.insert(file[group], name)
    end
    local ok, err = pcall(api.File.Write, api.File, WHITELIST_FILES[1], file)
    if not ok then log("Whitelist file not written: " .. tostring(err)) end
    loadWhitelistFile()
end

-- 1.4.0: names typed in the window up to 1.3.x lived in the settings; they
-- move into the file once, so the file holds the whole list.
local function moveWindowListsToFile()
    if state.whitelistInFile then return end
    state.whitelistInFile = true
    if state.raidWhitelist ~= "" or state.giveLeadWhitelist ~= "" then
        writeWhitelistFile(table.concat(whitelistFile.inviteNames, ",") .. "," .. state.raidWhitelist,
            table.concat(whitelistFile.leadNames, ",") .. "," .. state.giveLeadWhitelist)
        log("Whitelist names from the window moved into Addon/" .. WHITELIST_FILES[1] .. ".")
    end
    state.raidWhitelist, state.giveLeadWhitelist = "", ""
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
    state.raidBlacklist = tostring(autoInviteWin._blacklist:GetText() or "")
    state.giveLeadCode = tostring(autoInviteWin._leadCode:GetText() or "")
    -- The two name lists are the file's. A list the box could not hold
    -- whole is left as it is in the file, so a cut list never drops names.
    local fileInvite = table.concat(whitelistFile.inviteNames, ", ")
    local fileLead = table.concat(whitelistFile.leadNames, ", ")
    local invite = autoInviteWin._inviteFits and tostring(autoInviteWin._whitelist:GetText() or "") or fileInvite
    local lead = autoInviteWin._leadFits and tostring(autoInviteWin._leadWhitelist:GetText() or "") or fileLead
    if invite ~= fileInvite or lead ~= fileLead then
        writeWhitelistFile(invite, lead)
    end
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
    makeLabel(w, "rf_white_label", "Whitelist (names, comma-separated) = whitelist.txt:", 18, 202, 484, 24, ALIGN.LEFT)
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
    makeLabel(w, "rf_lead_white_label", "Give lead whitelist = \"lead\" in whitelist.txt:", 18, 484, 484, 24, ALIGN.LEFT)
    w._leadWhitelist = makeEdit(w, "rf_lead_whitelist", 18, 510, 484, 30)
    w._leadToggle = makeButton(w, "rf_lead_protection", "", 18, 556, 210, 28, function()
        state.giveLeadProtection = not state.giveLeadProtection; save(); resetAutoInviteWindow()
    end)
    makeLabel(w, "rf_save_note", "Save also writes whitelist.txt", 18, 606, 290, 24, ALIGN.LEFT)
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
    local invite = table.concat(whitelistFile.inviteNames, ", ")
    w._whitelist:SetText(invite)
    w._inviteFits = w._whitelist:GetText() == invite
    if not w._inviteFits then log("Whitelist too long for the box: edit Addon/" .. WHITELIST_FILES[1] .. " in Notepad.") end
    w._blacklist:SetText(tostring(state.raidBlacklist or ""))
    w._leadCode:SetText(tostring(state.giveLeadCode or DEFAULT_LEAD_CODE))
    local lead = table.concat(whitelistFile.leadNames, ", ")
    w._leadWhitelist:SetText(lead)
    w._leadFits = w._leadWhitelist:GetText() == lead
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
        -- Names added in Notepad meanwhile show up at once.
        loadWhitelistFile()
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

local function OnLoad()
    -- Windows of a previous load survive an addon reload; new names avoid clashes.
    idSuffix = "_" .. string.format("%.0f", tonumber(api.Time:GetUiMsec()) or 0)
    local ok, err = pcall(load)
    if not ok then log("Settings load failed: " .. tostring(err)) end
    ok, err = pcall(loadWhitelistFile)
    if not ok then log("Whitelist file failed: " .. tostring(err)) end
    ok, err = pcall(moveWindowListsToFile)
    if not ok then log("Whitelist move failed: " .. tostring(err)) end
    save()
    api:DoIn(200, function()
        local success, buttonErr = pcall(createFloatingButton)
        if not success then log("Button failed: " .. tostring(buttonErr)) end
    end)
    api.On("CHAT_MESSAGE", function(...)
        local success, chatErr = pcall(onChatMessage, ...)
        if not success then log("Raid Tool error: " .. tostring(chatErr)) end
    end)
    log("Loaded. 'Raid Tool' button opens recruiting; Shift-drag moves the button. Fish Tracker: Auction Income.")
end

local function OnUnload()
    api.On("CHAT_MESSAGE", function() end)
    closeAutoInviteWindow()
    if floatingBtn then floatingBtn:Show(false) end
    save()
end

addon.OnLoad = OnLoad
addon.OnUnload = OnUnload

return addon
