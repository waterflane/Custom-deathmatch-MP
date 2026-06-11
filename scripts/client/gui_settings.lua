local CDMP_SECTIONS = {"Match", "Tools", "HUD"}
local CDMP_AMMO_OPTIONS = nil
local CDMP_WEIGHT_OPTIONS = nil

function intOptions(minValue, maxValue)
	local result = {}
	for i = minValue, maxValue do result[#result + 1] = option(tostring(i), i) end
	return result
end

function ammoOptions()
	if not CDMP_AMMO_OPTIONS then CDMP_AMMO_OPTIONS = intOptions(0, 100) end
	return CDMP_AMMO_OPTIONS
end

function weightOptions()
	if not CDMP_WEIGHT_OPTIONS then CDMP_WEIGHT_OPTIONS = intOptions(0, 10) end
	return CDMP_WEIGHT_OPTIONS
end

function onOffOptions()
	return {option("Off", 0), option("On", 1)}
end

function durationOptions(st)
	local result = {}
	local durations = st.durationOptions or CDMP.DURATION_OPTIONS
	for i = 1, #durations do result[#result + 1] = option(CDMP.FormatTime(durations[i]), i) end
	return result
end

function headshotOptions(st)
	local result = {}
	local values = st.headshotOptions or CDMP.HEADSHOT_OPTIONS
	for i = 1, #values do result[#result + 1] = option("x" .. tostring(values[i]), i) end
	return result
end

function toolLabel(tool)
	if tool.label and tool.label ~= "" then return tool.label end
	return tool.id
end

function toolSettingId(tool)
	return string.gsub(tool.id or "tool", "[^%w_]", "_")
end

function toolKey(tool, suffix)
	return key("tool." .. toolSettingId(tool) .. "." .. suffix)
end

function getLoadout(st, tool)
	local settings = st.settings or {}
	local loadout = settings.loadout or {}
	return loadout[tool.id] or {enabled = tool.startEnabled == true, ammo = tool.ammo or 0}
end

function getToolOptions(st, tool)
	local settings = st.settings or {}
	local options = settings.toolOptions or {}
	return options[tool.id] or {canLoot = tool.canLoot == true, pickupAmount = tool.pickupAmount or tool.ammo or 0}
end

function getLootWeight(st, tool)
	local settings = st.settings or {}
	local weights = settings.lootWeights or {}
	return weights[tool.id] or 0
end

function makeMatchItems(st)
	return {
		{key = key("match.time"), label = "Time", info = "Match duration", options = durationOptions(st), default = (st.settings and st.settings.durationIdx) or 2},
		{key = key("match.headshot"), label = "Headshot", info = "Headshot damage multiplier", options = headshotOptions(st), default = (st.settings and st.settings.headshotIdx) or 3},
	}
end

function makeHudItems()
	return {
		{key = key("hud.hitMarker"), label = "Hit marker", info = "Show feedback when you hit a player", options = onOffOptions(), default = 1},
		{key = key("hud.killMarker"), label = "Kill marker", info = "Show separate feedback when you kill a player", options = onOffOptions(), default = 1},
		{key = key("hud.damageNumbers"), label = "Damage numbers", info = "Show floating damage numbers near the crosshair", options = onOffOptions(), default = 1},
	}
end

function hudOptionEnabled(name)
	return readNumber(key("hud." .. name), 1) == 1
end

function makeToolItems(st, tool)
	local loadout = getLoadout(st, tool)
	local options = getToolOptions(st, tool)
	return {
		{key = toolKey(tool, "startEnabled"), label = "Starting tool", info = "Give this tool on spawn", options = onOffOptions(), default = loadout.enabled and 1 or 0},
		{key = toolKey(tool, "ammo"), label = "Starting ammo", info = "Ammo on spawn, 0-100", options = ammoOptions(), default = CDMP.Clamp(loadout.ammo or tool.ammo or 0, 0, 100)},
		{key = toolKey(tool, "canLoot"), label = "Spawn in loot", info = "Allow this tool in loot crates", options = onOffOptions(), default = options.canLoot and 1 or 0},
		{key = toolKey(tool, "lootWeight"), label = "Loot weight", info = "Spawn chance weight, 0-10", options = weightOptions(), default = CDMP.Clamp(getLootWeight(st, tool), 0, 10)},
		{key = toolKey(tool, "pickupAmount"), label = "Pickup amount", info = "Ammo received from a crate", options = ammoOptions(), default = CDMP.Clamp(options.pickupAmount or tool.pickupAmount or tool.ammo or 0, 0, 100)},
	}
end

function initializeAllSettings(st)
	local groups = {makeMatchItems(st), makeHudItems()}
	local tools = st.tools or {}
	for i = 1, #tools do groups[#groups + 1] = makeToolItems(st, tools[i]) end
	for i = 1, #groups do
		for j = 1, #groups[i] do
			local item = groups[i][j]
			if client.cdmpSettingsSeeded then
				ensureStepperValue(item.key, item.options, item.default)
			else
				resetStepperValue(item.key, item.options, item.default)
			end
		end
	end
	client.cdmpSettingsSeeded = true
end

function resetItems(items)
	for i = 1, #items do
		local item = items[i]
		resetStepperValue(item.key, item.options, item.default)
	end
end

function encodeLoadoutSettings(st)
	local parts = {}
	local tools = st.tools or {}
	for i = 1, #tools do
		local tool = tools[i]
		local loadout = getLoadout(st, tool)
		local enabled = readNumber(toolKey(tool, "startEnabled"), loadout.enabled and 1 or 0)
		local ammo = readNumber(toolKey(tool, "ammo"), loadout.ammo or tool.ammo or 0)
		parts[#parts + 1] = tool.id .. ":" .. tostring(CDMP.Clamp(enabled, 0, 1)) .. ":" .. tostring(CDMP.Clamp(ammo, 0, 100))
	end
	return table.concat(parts, ";")
end

function encodeLootSettings(st)
	local parts = {}
	local tools = st.tools or {}
	for i = 1, #tools do
		local tool = tools[i]
		local weight = readNumber(toolKey(tool, "lootWeight"), getLootWeight(st, tool))
		parts[#parts + 1] = tool.id .. ":" .. tostring(CDMP.Clamp(weight, 0, 10))
	end
	return table.concat(parts, ";")
end

function encodeToolOptions(st)
	local parts = {}
	local tools = st.tools or {}
	for i = 1, #tools do
		local tool = tools[i]
		local options = getToolOptions(st, tool)
		local canLoot = readNumber(toolKey(tool, "canLoot"), options.canLoot and 1 or 0)
		local pickupAmount = readNumber(toolKey(tool, "pickupAmount"), options.pickupAmount or tool.pickupAmount or tool.ammo or 0)
		parts[#parts + 1] = tool.id .. ":" .. tostring(CDMP.Clamp(canLoot, 0, 1)) .. ":" .. tostring(CDMP.Clamp(pickupAmount, 0, 100))
	end
	return table.concat(parts, ";")
end

function applySettingsAndStart(st)
	local durationIdx = readNumber(key("match.time"), (st.settings and st.settings.durationIdx) or 2)
	local headshotIdx = readNumber(key("match.headshot"), (st.settings and st.settings.headshotIdx) or 3)
	ServerCall("server.settingsApplyAndStart", GetLocalPlayer(), durationIdx, headshotIdx, encodeLoadoutSettings(st), encodeLootSettings(st), encodeToolOptions(st))
end

function drawSectionButton(label, width, active)
	UiPush()
	local pressed = uiDrawSecondaryButton(label, width)
	if active then
		UiTranslate(0, 24)
		UiAlign("center top")
		UiColor(COLOR_YELLOW)
		UiRect(width - 10, 3)
	end
	UiPop()
	return pressed
end

function drawStepperList(items, first, last, contentWidth, rowHeight)
	for i = first, last do
		local item = items[i]
		ensureStepperValue(item.key, item.options, item.default)
		UiPush()
		UiAlign("left middle")
		_drawSettingsItemStepper(item.key, item.label, item.info, item.options, contentWidth, false)
		UiPop()
		UiTranslate(0, rowHeight)
	end
end

function drawToolList(st, contentWidth, rowCount, page)
	local tools = st.tools or {}
	local first = (page - 1) * rowCount + 1
	local last = math.min(#tools, first + rowCount - 1)
	for i = first, last do
		local tool = tools[i]
		UiPush()
		UiTranslate(contentWidth / 2, 0)
		UiAlign("center middle")
		if uiDrawSecondaryButton(toolLabel(tool), contentWidth) then
			client.cdmpSelectedToolIndex = i
			client.cdmpSettingsPage = 1
		end
		UiPop()
		UiTranslate(0, 42)
	end
	return math.max(1, math.ceil(#tools / rowCount))
end

function drawSettingsPanel(st)
	if not client.cdmpSettingsVisible then return end

	local screenW = UiCenter() * 2
	local screenH = UiMiddle() * 2
	local width = math.min(760, screenW - 60)
	local height = math.min(780, screenH - 40)
	local panelX = 30
	local panelY = 20
	local margin = 30
	local section = client.cdmpSettingsSection or 1
	local contentWidth = width - margin * 2
	local rowHeight = 42
	local pageCount = 1
	local page = client.cdmpSettingsPage or 1

	navigationBeginGroup("cdmpSettings")
	UiMakeInteractive()
	UiPush()
	UiTranslate(panelX, panelY)
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
	local tabWidth = (contentWidth - 20) / #CDMP_SECTIONS
	for i = 1, #CDMP_SECTIONS do
		UiPush()
		UiTranslate((i - 1) * (tabWidth + 10) + tabWidth / 2, 0)
		UiAlign("center middle")
		if drawSectionButton(CDMP_SECTIONS[i], tabWidth, section == i) then
			client.cdmpSettingsSection = i
			client.cdmpSettingsPage = 1
			client.cdmpSelectedToolIndex = nil
		end
		UiPop()
	end

	local availableRows = math.floor((height - 280) / rowHeight)
	if availableRows < 4 then availableRows = 4 end
	UiPush()
	UiTranslate(0, 52)
	if section == 1 then
		local items = makeMatchItems(st)
		pageCount = 1
		drawStepperList(items, 1, #items, contentWidth, rowHeight)
	elseif section == 3 then
		local items = makeHudItems()
		pageCount = 1
		drawStepperList(items, 1, #items, contentWidth, rowHeight)
	elseif client.cdmpSelectedToolIndex then
		local tools = st.tools or {}
		local tool = tools[client.cdmpSelectedToolIndex]
		if tool then
			UiPush()
			UiTranslate(contentWidth / 2, 0)
			UiAlign("center middle")
			if uiDrawSecondaryButton("Back", contentWidth) then
				client.cdmpSelectedToolIndex = nil
				client.cdmpSettingsPage = 1
			end
			UiPop()
			UiTranslate(0, 48)
			local items = makeToolItems(st, tool)
			pageCount = 1
			drawStepperList(items, 1, #items, contentWidth, rowHeight)
		else
			client.cdmpSelectedToolIndex = nil
		end
	else
		pageCount = drawToolList(st, contentWidth, availableRows, page)
	end
	UiPop()

	page = CDMP.Clamp(client.cdmpSettingsPage or 1, 1, pageCount)
	client.cdmpSettingsPage = page
	UiPush()
	UiTranslate(contentWidth / 2, height - 220)
	UiAlign("center middle")
	local navWidth = 70
	local pageNavigationDisabled = pageCount <= 1 or client.cdmpSelectedToolIndex ~= nil
	UiPush()
	UiTranslate(-150, 0)
	if uiDrawSecondaryButton("<", navWidth, pageNavigationDisabled or page <= 1) and page > 1 and not pageNavigationDisabled then client.cdmpSettingsPage = page - 1 end
	UiPop()
	UiPush()
	UiColor(COLOR_WHITE)
	UiFont(FONT_BOLD, FONT_SIZE_22)
	UiText("Page " .. tostring(page) .. "/" .. tostring(pageCount))
	UiPop()
	UiPush()
	UiTranslate(150, 0)
	if uiDrawSecondaryButton(">", navWidth, pageNavigationDisabled or page >= pageCount) and page < pageCount and not pageNavigationDisabled then client.cdmpSettingsPage = page + 1 end
	UiPop()
	UiPop()

	UiPush()
	UiTranslate(contentWidth / 2, height - 172)
	UiAlign("center middle")
	local buttonWidth = (contentWidth - 20) / 2
	local resetItemsList = makeMatchItems(st)
	if section == 2 then
		resetItemsList = {}
		if client.cdmpSelectedToolIndex and (st.tools or {})[client.cdmpSelectedToolIndex] then
			resetItemsList = makeToolItems(st, (st.tools or {})[client.cdmpSelectedToolIndex])
		else
			local tools = st.tools or {}
			for i = 1, #tools do
				local toolItems = makeToolItems(st, tools[i])
				for j = 1, #toolItems do resetItemsList[#resetItemsList + 1] = toolItems[j] end
			end
		end
	elseif section == 3 then
		resetItemsList = makeHudItems()
	end
	UiPush()
	UiTranslate(-(buttonWidth + 20) / 2, 0)
	if uiDrawSecondaryButton("Reset", buttonWidth) then resetItems(resetItemsList) end
	UiPop()
	UiPush()
	UiTranslate((buttonWidth + 20) / 2, 0)
	if uiDrawSecondaryButton("Close", buttonWidth) then client.cdmpSettingsVisible = false end
	UiPop()
	UiPop()

	UiPop()
	navigationEndGroup()
end
