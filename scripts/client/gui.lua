local CDMP_SETTING_PREFIX = "savegame.mod.cdmp."
local CDMP_SECTIONS = {"Match", "Starting tools", "Loot weights"}
local CDMP_AMMO_OPTIONS = nil
local CDMP_WEIGHT_OPTIONS = nil

local function key(name)
	return CDMP_SETTING_PREFIX .. name
end

local function option(label, value)
	return {label = label, value = tostring(value)}
end

local function intOptions(minValue, maxValue)
	local result = {}
	for i = minValue, maxValue do result[#result + 1] = option(tostring(i), i) end
	return result
end

local function ammoOptions()
	if not CDMP_AMMO_OPTIONS then CDMP_AMMO_OPTIONS = intOptions(0, 100) end
	return CDMP_AMMO_OPTIONS
end

local function weightOptions()
	if not CDMP_WEIGHT_OPTIONS then CDMP_WEIGHT_OPTIONS = intOptions(0, 10) end
	return CDMP_WEIGHT_OPTIONS
end

local function onOffOptions()
	return {option("Off", 0), option("On", 1)}
end

local function durationOptions(st)
	local result = {}
	local durations = st.durationOptions or CDMP.DURATION_OPTIONS
	for i = 1, #durations do result[#result + 1] = option(CDMP.FormatTime(durations[i]), i) end
	return result
end

local function headshotOptions(st)
	local result = {}
	local values = st.headshotOptions or CDMP.HEADSHOT_OPTIONS
	for i = 1, #values do result[#result + 1] = option("x" .. tostring(values[i]), i) end
	return result
end

local function optionIndex(options, value)
	local wanted = tostring(value)
	for i = 1, #options do
		if tostring(options[i].value) == wanted then return i end
	end
	return 1
end

local function ensureStepperValue(settingKey, options, defaultValue)
	if HasKey(settingKey) then return end
	local idx = optionIndex(options, defaultValue)
	SetInt(settingKey .. ".index", idx)
	SetString(settingKey, options[idx].value)
end

local function resetStepperValue(settingKey, options, defaultValue)
	local idx = optionIndex(options, defaultValue)
	SetInt(settingKey .. ".index", idx)
	SetString(settingKey, options[idx].value)
end

local function readNumber(settingKey, fallback)
	local value = tonumber(GetString(settingKey))
	if value == nil then return fallback end
	return value
end

local function toolLabel(tool)
	if tool.label and tool.label ~= "" then return tool.label end
	return tool.id
end

local function getLoadout(st, tool)
	local settings = st.settings or {}
	local loadout = settings.loadout or {}
	return loadout[tool.id] or {enabled = tool.startEnabled == true, ammo = tool.ammo or 0}
end

local function getLootWeight(st, tool)
	local settings = st.settings or {}
	local weights = settings.lootWeights or {}
	return weights[tool.id] or 0
end

local function makeMatchItems(st)
	return {
		{key = key("match.time"), label = "Time", info = "Match duration", options = durationOptions(st), default = (st.settings and st.settings.durationIdx) or 2},
		{key = key("match.headshot"), label = "Headshot", info = "Headshot damage multiplier", options = headshotOptions(st), default = (st.settings and st.settings.headshotIdx) or 3},
	}
end

local function makeLoadoutItems(st)
	local items = {}
	local tools = st.tools or {}
	for i = 1, #tools do
		local tool = tools[i]
		local loadout = getLoadout(st, tool)
		local enabledDefault = loadout.enabled and 1 or 0
		local ammoDefault = CDMP.Clamp(loadout.ammo or tool.ammo or 0, 0, 100)
		items[#items + 1] = {key = key("loadout." .. i .. ".enabled"), label = toolLabel(tool), info = "Start with this tool", options = onOffOptions(), default = enabledDefault, tool = tool}
		items[#items + 1] = {key = key("loadout." .. i .. ".ammo"), label = toolLabel(tool) .. " ammo", info = "Starting ammo, 0-100", options = ammoOptions(), default = ammoDefault, tool = tool}
	end
	return items
end

local function makeLootItems(st)
	local items = {}
	local tools = st.tools or {}
	for i = 1, #tools do
		local tool = tools[i]
		if tool.canLoot then
			local defaultWeight = CDMP.Clamp(getLootWeight(st, tool), 0, 10)
			items[#items + 1] = {key = key("loot." .. i), label = toolLabel(tool), info = "Loot crate spawn weight, 0-10", options = weightOptions(), default = defaultWeight, tool = tool}
		end
	end
	return items
end

local function makeSectionItems(st, section)
	if section == 1 then return makeMatchItems(st) end
	if section == 2 then return makeLoadoutItems(st) end
	return makeLootItems(st)
end

local function initializeAllSettings(st)
	local sections = {makeMatchItems(st), makeLoadoutItems(st), makeLootItems(st)}
	for i = 1, #sections do
		for j = 1, #sections[i] do
			local item = sections[i][j]
			ensureStepperValue(item.key, item.options, item.default)
		end
	end
end

local function resetItems(items)
	for i = 1, #items do
		local item = items[i]
		resetStepperValue(item.key, item.options, item.default)
	end
end

local function encodeLoadoutSettings(st)
	local parts = {}
	local tools = st.tools or {}
	for i = 1, #tools do
		local tool = tools[i]
		local loadout = getLoadout(st, tool)
		local enabled = readNumber(key("loadout." .. i .. ".enabled"), loadout.enabled and 1 or 0)
		local ammo = readNumber(key("loadout." .. i .. ".ammo"), loadout.ammo or tool.ammo or 0)
		parts[#parts + 1] = tool.id .. ":" .. tostring(CDMP.Clamp(enabled, 0, 1)) .. ":" .. tostring(CDMP.Clamp(ammo, 0, 100))
	end
	return table.concat(parts, ";")
end

local function encodeLootSettings(st)
	local parts = {}
	local tools = st.tools or {}
	for i = 1, #tools do
		local tool = tools[i]
		if tool.canLoot then
			local weight = readNumber(key("loot." .. i), getLootWeight(st, tool))
			parts[#parts + 1] = tool.id .. ":" .. tostring(CDMP.Clamp(weight, 0, 10))
		end
	end
	return table.concat(parts, ";")
end

local function applySettingsAndStart(st)
	local durationIdx = readNumber(key("match.time"), (st.settings and st.settings.durationIdx) or 2)
	local headshotIdx = readNumber(key("match.headshot"), (st.settings and st.settings.headshotIdx) or 3)
	ServerCall("server.settingsApplyAndStart", GetLocalPlayer(), durationIdx, headshotIdx, encodeLoadoutSettings(st), encodeLootSettings(st))
end

local function rowsFromState(st)
	local rows = {}
	for playerId, _info in pairs(st.players or {}) do
		local score = (st.scores and st.scores[playerId]) or {kills = 0, deaths = 0}
		rows[#rows + 1] = {player = playerId, columns = {score.kills or 0, score.deaths or 0}}
	end
	table.sort(rows, function(a, b)
		if a.columns[1] == b.columns[1] then return a.columns[2] < b.columns[2] end
		return a.columns[1] > b.columns[1]
	end)
	return rows
end

local function drawSectionButton(label, width, active)
	UiPush()
	local pressed = uiDrawSecondaryButton(label, width)
	if active then
		UiTranslate(-width / 2, 24)
		UiColor(COLOR_YELLOW)
		UiRect(width, 3)
	end
	UiPop()
	return pressed
end

local function drawSettingsPanel(st)
	if not client.cdmpSettingsVisible then return end

	local screenH = UiMiddle() * 2
	local width = 590
	local height = math.min(760, screenH - 60)
	local margin = 30
	local section = client.cdmpSettingsSection or 1
	local items = makeSectionItems(st, section)
	local contentWidth = width - margin * 2
	local rowHeight = 42
	local availableRows = math.floor((height - 230) / rowHeight)
	if availableRows < 4 then availableRows = 4 end
	local pageCount = math.max(1, math.ceil(#items / availableRows))
	client.cdmpSettingsPage = CDMP.Clamp(client.cdmpSettingsPage or 1, 1, pageCount)
	local page = client.cdmpSettingsPage
	local first = (page - 1) * availableRows + 1
	local last = math.min(#items, first + availableRows - 1)

	navigationBeginGroup("cdmpSettings")
	UiMakeInteractive()
	UiPush()
	UiTranslate(30, 30)
	UiAlign("left top")
	uiDrawPanel(width, height, 16)

	UiTranslate(margin, 34)
	UiColor(COLOR_WHITE)
	UiFont(FONT_BOLD, FONT_SIZE_30)
	UiText("Game mode settings")
	UiTranslate(0, 32)
	UiColor(0.53, 0.53, 0.53, 1)
	UiRect(contentWidth, 2)

	UiTranslate(0, 28)
	local tabWidth = (contentWidth - 20) / 3
	for i = 1, #CDMP_SECTIONS do
		UiPush()
		UiTranslate((i - 1) * (tabWidth + 10) + tabWidth / 2, 0)
		UiAlign("center middle")
		if drawSectionButton(CDMP_SECTIONS[i], tabWidth, section == i) then
			client.cdmpSettingsSection = i
			client.cdmpSettingsPage = 1
		end
		UiPop()
	end

	UiPush()
	UiTranslate(0, 52)
	for i = first, last do
		local item = items[i]
		ensureStepperValue(item.key, item.options, item.default)
		UiPush()
		UiAlign("left middle")
		_drawSettingsItemStepper(item.key, item.label, item.info, item.options, contentWidth, false)
		UiPop()
		UiTranslate(0, rowHeight)
	end
	UiPop()

	UiPush()
	UiTranslate(contentWidth / 2, height - 92 - margin - 34)
	UiAlign("center middle")
	local navWidth = 70
	UiPush()
	UiTranslate(-150, 0)
	if uiDrawSecondaryButton("<", navWidth, page <= 1) and page > 1 then client.cdmpSettingsPage = page - 1 end
	UiPop()
	UiPush()
	UiColor(COLOR_WHITE)
	UiFont(FONT_BOLD, FONT_SIZE_22)
	UiText("Page " .. tostring(page) .. "/" .. tostring(pageCount))
	UiPop()
	UiPush()
	UiTranslate(150, 0)
	if uiDrawSecondaryButton(">", navWidth, page >= pageCount) and page < pageCount then client.cdmpSettingsPage = page + 1 end
	UiPop()
	UiPop()

	UiPush()
	UiTranslate(contentWidth / 2, height - 45 - margin - 34)
	UiAlign("center middle")
	local buttonWidth = (contentWidth - 20) / 2
	UiPush()
	UiTranslate(-(buttonWidth + 20) / 2, 0)
	if uiDrawSecondaryButton("Reset", buttonWidth) then resetItems(items) end
	UiPop()
	UiPush()
	UiTranslate((buttonWidth + 20) / 2, 0)
	if uiDrawSecondaryButton("Close", buttonWidth) then client.cdmpSettingsVisible = false end
	UiPop()
	UiPop()

	UiPop()
	navigationEndGroup()
end

local function drawHostMenu(st)
	navigationBeginGroup("cdmpHostMenu")
	UiMakeInteractive()
	UiPush()
	UiTranslate(UiCenter(), UiMiddle() + 300)
	UiAlign("center top")
	local width = 330
	local height = 166
	uiDrawPanel(width, height, 16)
	UiTranslate(0, 14)
	UiColor(COLOR_WHITE)
	UiFont(FONT_BOLD, FONT_SIZE_30)
	UiText("loc@UI_TEXT_HOST_MENU")
	UiTranslate(0, 36)
	if uiDrawSecondaryButton("loc@UI_BUTTON_GAME_MODE_SETTINGS", 290) then
		client.cdmpSettingsVisible = not client.cdmpSettingsVisible
		client.cdmpSettingsPage = 1
	end
	UiTranslate(0, 50)
	if uiDrawPrimaryButton("loc@UI_BUTTON_START", 290) then
		applySettingsAndStart(st)
	end
	UiPop()
	navigationEndGroup()
end

local function drawWaitingForHost()
	UiPush()
	UiTranslate(UiCenter(), UiMiddle() + 300)
	uiDrawTextPanel("loc@UI_TEXT_WAITING_FOR_HOST", 1)
	UiPop()
end

local function drawSetup(st)
	SetBool("game.disablemap", true)
	initializeAllSettings(st)
	hudDrawTitle(client.cdmpDt or 0, "DEATHMATCH", true)
	hudDrawPlayerList()
	hudDrawGameModeHelpText("Deathmatch", "Eliminate opponents. Stay alive, score kills, and climb to the top.")
	if IsPlayerHost(GetLocalPlayer()) then
		drawHostMenu(st)
		drawSettingsPanel(st)
	else
		drawWaitingForHost()
	end
end

local function drawPlaying(st)
	hudDrawTimer(st.timer, 1.0)
	hudDrawDamageIndicators(client.cdmpDt or 0)
	hudDrawPlayerWorldMarkers(GetAllPlayers(), true, 40.0)

	local rows = rowsFromState(st)
	local groups = {{name = "Players", color = {0.52, 0.52, 0.52}, outline = false, rows = rows}}
	local columns = {{name = "Kills", align = "center"}, {name = "Deaths", align = "center"}}
	hudDrawScoreboard(hudIsScoreboardRequested(), "", columns, groups)
	hudDrawFade(client.cdmpDt or 0)
end

local function drawEnded(st)
	local rows = rowsFromState(st)
	local groups = {{name = "Players", color = {0.52, 0.52, 0.52}, outline = true, rows = rows}}
	local columns = {{name = "Kills", align = "center"}, {name = "Deaths", align = "center"}}
	local winner = "Match ended"
	if #rows > 0 then winner = GetPlayerName(rows[1].player) .. " wins" end
	hudDrawResults(winner, {0.0, 0.0, 0.0, 0.75}, "Results", columns, groups, nil, "")
end

function CDMP_GuiInit()
	client.cdmpDt = 0
	client.cdmpSettingsVisible = false
	client.cdmpSettingsSection = 1
	client.cdmpSettingsPage = 1
end

function CDMP_ClientTick(dt)
	client.cdmpDt = dt
	hudTick(dt)
	SetLowHealthBlurThreshold(0.25)
end

function CDMP_DrawGui()
	local st = shared.cdmp
	if not st then return end
	if st.state == "playing" then
		drawPlaying(st)
	else
		drawSetup(st)
	end
end