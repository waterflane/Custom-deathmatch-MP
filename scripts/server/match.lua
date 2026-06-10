local function resetScores()
	server.scores = {}
	for playerId in pairs(server.players or {}) do
		server.scores[playerId] = {kills = 0, deaths = 0}
	end
end

local function resetSettings()
	server.settings = {loadout = {}, lootWeights = {}, durationIdx = 2, headshotIdx = 3}
	for i = 1, #server.tools do
		local tool = server.tools[i]
		server.settings.loadout[tool.id] = {enabled = tool.startEnabled, ammo = tool.ammo or 0}
		server.settings.lootWeights[tool.id] = tool.canLoot and CDMP.Clamp(tool.lootWeight or 0, 0, 10) or 0
	end
end

local function sync()
	local hs = CDMP.HEADSHOT_OPTIONS[server.settings.headshotIdx] or 1.5
	if hs < 1.0 then hs = 1.0 end
	shared.multiplyheadshot = hs
	shared.cdmp = {
		version = CDMP.VERSION,
		state = server.state,
		timer = server.timer,
		settings = server.settings,
		tools = server.tools,
		players = server.players,
		ready = server.ready,
		scores = server.scores,
		durationOptions = CDMP.DURATION_OPTIONS,
		headshotOptions = CDMP.HEADSHOT_OPTIONS,
	}
end

local function settingsOpen()
	return server.state == "waiting" or server.state == "ended"
end

local function hostCanEdit(playerId)
	return settingsOpen() and IsPlayerHost(playerId)
end

local function playerIds()
	local ids = {}
	for playerId in pairs(server.players) do table.insert(ids, playerId) end
	return ids
end

local function disableAllTools(playerId)
	for i = 1, #server.allToolIds do
		SetToolEnabled(server.allToolIds[i], false, playerId)
		SetToolAmmo(server.allToolIds[i], 0, playerId)
	end
end

local function applyLoadout(playerId)
	disableAllTools(playerId)
	local firstTool = nil
	for i = 1, #server.tools do
		local tool = server.tools[i]
		local item = server.settings.loadout[tool.id]
		if item and item.enabled then
			SetToolEnabled(tool.id, true, playerId)
			if tool.usesAmmo then
				SetToolAmmo(tool.id, CDMP.Clamp(item.ammo or tool.ammo or 0, 0, 100), playerId)
			end
			if firstTool == nil then firstTool = tool.id end
		end
	end
	if firstTool then
		SetPlayerSpawnTool(firstTool, playerId)
		SetPlayerTool(firstTool, playerId)
	end
end

local function spawnPlayer(playerId)
	local index = GetRandomInt(1, #server.playerSpawns)
	RespawnPlayerAtTransform(CDMP.CopyTransform(server.playerSpawns[index]), playerId)
	SetPlayerHealth(1.0, playerId)
	SetPlayerWalkingSpeed(CDMP.DEFAULT_WALK_SPEED, playerId)
	applyLoadout(playerId)
	server.dead[playerId] = nil
end

local function stripLobbyPlayer(playerId)
	SetPlayerWalkingSpeed(0.0, playerId)
	disableAllTools(playerId)
end

local function addPlayer(playerId)
	server.players[playerId] = {name = GetPlayerName(playerId)}
	if server.ready[playerId] == nil then server.ready[playerId] = false end
	if server.scores[playerId] == nil then server.scores[playerId] = {kills = 0, deaths = 0} end
	if server.state == "playing" then
		server.ready[playerId] = true
		spawnPlayer(playerId)
	else
		stripLobbyPlayer(playerId)
	end
end

local function removePlayer(playerId)
	server.players[playerId] = nil
	server.ready[playerId] = nil
	server.dead[playerId] = nil
	server.scores[playerId] = nil
end

local function cleanupOfficialLoot()
	if toolsCleanup then toolsCleanup() end
end

local function appendTransforms(dst, src)
	if not src then return end
	for i = 1, #src do dst[#dst + 1] = src[i] end
end

local function loadOfficialLootSpawns()
	local spawns = {}
	if utilLoadLevelToolSpawns then
		appendTransforms(spawns, utilLoadLevelToolSpawns())
	end
	if #spawns == 0 and utilGenerateSpawnPointLists then
		local generated = utilGenerateSpawnPointLists({1.0})
		if generated and generated[1] then appendTransforms(spawns, generated[1]) end
	end
	if #spawns == 0 then
		for i = 1, #server.lootSlots do spawns[#spawns + 1] = server.lootSlots[i].transform end
	end
	return spawns
end

local function buildOfficialLootTable()
	local lootTable = {}
	for i = 1, #server.tools do
		local tool = server.tools[i]
		if tool.canLoot then
			local weight = CDMP.Clamp(server.settings.lootWeights[tool.id] or 0, 0, 10)
			if weight > 0 then
				local amount = GetToolAmmoPickupAmount(tool.id)
				if amount == nil or amount <= 0 then amount = tool.ammo or 20 end
				if amount <= 0 then amount = 20 end
				lootTable[#lootTable + 1] = {name = tool.id, weight = weight, amount = amount}
			end
		end
	end
	return lootTable
end

local function setupOfficialLoot()
	if not toolsAddLootTier then return end
	cleanupOfficialLoot()
	if toolsSetRespawnTime then toolsSetRespawnTime(CDMP.LOOT_RESPAWN_DELAY) end
	if toolsSetDropToolsOnDeath then toolsSetDropToolsOnDeath(true) end
	if toolsPreventToolDrop then toolsPreventToolDrop("sledge") end

	local spawns = loadOfficialLootSpawns()
	local lootTable = buildOfficialLootTable()
	if #spawns > 0 and #lootTable > 0 then
		toolsAddLootTier(spawns, lootTable)
	end
end

local function startMatch()
	server.state = "playing"
	server.timer = CDMP.DURATION_OPTIONS[server.settings.durationIdx] or CDMP.DURATION_OPTIONS[2]
	server.dead = {}
	resetScores()
	setupOfficialLoot()
	local ids = playerIds()
	for i = 1, #ids do
		server.ready[ids[i]] = true
		spawnPlayer(ids[i])
	end
	sync()
end

local function endMatch()
	server.state = "ended"
	cleanupOfficialLoot()
	local ids = playerIds()
	for i = 1, #ids do SetPlayerWalkingSpeed(0.0, ids[i]) end
	sync()
end

local function isKnownPlayer(playerId)
	return playerId ~= nil and server.players[playerId] ~= nil
end

local function isRealPlayerHit(playerId, attackerId, healthBefore, healthAfter, point)
	if not isKnownPlayer(playerId) then return false end
	if not isKnownPlayer(attackerId) then return false end
	if attackerId == playerId then return false end
	if point == nil then return false end
	return ((healthBefore or 0) - (healthAfter or 0)) > 0
end

local function getHeadshotBonusDamage(baseDamage)
	local multiplier = shared.multiplyheadshot or 1.5
	if multiplier < 1.0 then multiplier = 1.0 end
	local bonusPercent = multiplier - 1.0
	return baseDamage * bonusPercent
end

local function isHeadshot(playerId, point)
	local center = CDMP.GetHeadshotCenter(playerId)
	return VecLength(VecSub(point, center)) <= CDMP.HEAD_RADIUS
end

local function handleHeadshots()
	if server.ignoreHeadshotDamage then return end
	if (shared.multiplyheadshot or 1.0) <= 1.0 then return end
	for i = 1, GetEventCount("playerhurt") do
		local playerId, healthBefore, healthAfter, attackerId, point = GetEvent("playerhurt", i)
		if isRealPlayerHit(playerId, attackerId, healthBefore, healthAfter, point) and isHeadshot(playerId, point) then
			local baseDamage = (healthBefore or 0) - (healthAfter or 0)
			local bonusDamage = getHeadshotBonusDamage(baseDamage)
			if bonusDamage > 0 then
				server.ignoreHeadshotDamage = true
				ApplyPlayerDamage(playerId, bonusDamage, "headshot", attackerId)
				server.ignoreHeadshotDamage = false
			end
		end
	end
end

local function handleDeaths()
	for i = 1, GetEventCount("playerdied") do
		local playerId, attackerId = GetEvent("playerdied", i)
		if server.scores[playerId] then
			server.scores[playerId].deaths = (server.scores[playerId].deaths or 0) + 1
		end
		if attackerId ~= nil and attackerId ~= playerId and server.scores[attackerId] then
			server.scores[attackerId].kills = (server.scores[attackerId].kills or 0) + 1
		end
		if server.state == "playing" then server.dead[playerId] = CDMP.RESPAWN_DELAY end
	end
end

local function updatePlayerList()
	local added = GetAddedPlayers()
	for i = 1, #added do addPlayer(added[i]) end
	local removed = GetRemovedPlayers()
	for i = 1, #removed do removePlayer(removed[i]) end
end

function CDMP_ServerInit()
	if hudInit then hudInit(true) end
	if hudAddUnstuckButton then hudAddUnstuckButton() end
	if toolsInit then toolsInit() end
	if toolsSetRespawnTime then toolsSetRespawnTime(CDMP.LOOT_RESPAWN_DELAY) end
	if toolsSetDropToolsOnDeath then toolsSetDropToolsOnDeath(true) end
	if toolsPreventToolDrop then toolsPreventToolDrop("sledge") end

	server.state = "waiting"
	server.timer = 0
	server.tools, server.toolById, server.allToolIds = CDMP.CollectToolCatalog()
	server.players = {}
	server.ready = {}
	server.dead = {}
	server.scores = {}
	server.lootSlots = {}
	server.playerSpawns = CDMP.FindTransforms({"playerspawn", "spawn", "player"}, 12, 10.0, 3.0)
	local lootSpawns = CDMP.FindTransforms({"ammospawn", "toolspawn", "loot", "itemspawn", "spawn"}, 10, 7.0, 3.0)
	for i = 1, #lootSpawns do table.insert(server.lootSlots, {transform = lootSpawns[i], timer = 0}) end
	resetSettings()
	local count = GetPlayerCount()
	for playerId = 0, count - 1 do addPlayer(playerId) end
	sync()
end

function CDMP_ServerDestroy()
	cleanupOfficialLoot()
end

function CDMP_ServerTick(dt)
	updatePlayerList()
	handleHeadshots()
	handleDeaths()
	if server.state == "playing" then
		server.timer = server.timer - dt
		if server.timer <= 0 then
			endMatch()
		else
			if toolsTick then toolsTick(dt) end
			for playerId, delay in pairs(server.dead) do
				delay = delay - dt
				if delay <= 0 then spawnPlayer(playerId) else server.dead[playerId] = delay end
			end
		end
	else
		local ids = playerIds()
		for i = 1, #ids do SetPlayerWalkingSpeed(0.0, ids[i]) end
	end
	sync()
end

function CDMP_SetLoadoutTool(playerId, toolId, enabled, ammo)
	if not hostCanEdit(playerId) or not server.toolById[toolId] then return end
	server.settings.loadout[toolId] = server.settings.loadout[toolId] or {enabled = false, ammo = 0}
	server.settings.loadout[toolId].enabled = enabled == true
	server.settings.loadout[toolId].ammo = CDMP.Clamp(ammo or 0, 0, 100)
	sync()
end

function CDMP_SetLootWeight(playerId, toolId, weight)
	if not hostCanEdit(playerId) or not server.toolById[toolId] or not server.toolById[toolId].canLoot then return end
	server.settings.lootWeights[toolId] = CDMP.Clamp(weight or 0, 0, 10)
	sync()
end

function CDMP_SetHeadshotMultiplier(playerId, idx)
	if not hostCanEdit(playerId) then return end
	server.settings.headshotIdx = CDMP.Clamp(math.floor(tonumber(idx) or server.settings.headshotIdx), 1, #CDMP.HEADSHOT_OPTIONS)
	sync()
end

function CDMP_SetRoundDuration(playerId, idx)
	if not hostCanEdit(playerId) then return end
	server.settings.durationIdx = CDMP.Clamp(math.floor(tonumber(idx) or server.settings.durationIdx), 1, #CDMP.DURATION_OPTIONS)
	sync()
end

function CDMP_SetReady(playerId)
	if server.players[playerId] == nil then addPlayer(playerId) end
	server.ready[playerId] = true
	if server.state == "playing" then spawnPlayer(playerId) end
	sync()
end

function CDMP_StartFromGui(playerId)
	if not IsPlayerHost(playerId) then return end
	if server.state ~= "waiting" and server.state ~= "ended" then return end
	startMatch()
end

function CDMP_ResetSettings(playerId)
	if not hostCanEdit(playerId) then return end
	resetSettings()
	sync()
end

local function decodeSettingRecords(data)
	local records = {}
	data = data or ""
	for record in string.gmatch(data, "([^;]+)") do
		local a, b, c = string.match(record, "([^:]*):([^:]*):?([^:]*)")
		if a and a ~= "" then
			records[#records + 1] = {a, b, c}
		end
	end
	return records
end

function CDMP_ApplySettingsAndStart(playerId, durationIdx, headshotIdx, loadoutData, lootData)
	if not IsPlayerHost(playerId) then return end
	if server.state ~= "waiting" and server.state ~= "ended" then return end

	CDMP_SetRoundDuration(playerId, tonumber(durationIdx) or server.settings.durationIdx)
	CDMP_SetHeadshotMultiplier(playerId, tonumber(headshotIdx) or server.settings.headshotIdx)

	local loadoutRecords = decodeSettingRecords(loadoutData)
	for i = 1, #loadoutRecords do
		local record = loadoutRecords[i]
		local toolId = record[1]
		local enabled = tonumber(record[2]) == 1
		local ammo = tonumber(record[3]) or 0
		CDMP_SetLoadoutTool(playerId, toolId, enabled, ammo)
	end

	local lootRecords = decodeSettingRecords(lootData)
	for i = 1, #lootRecords do
		local record = lootRecords[i]
		local toolId = record[1]
		local weight = tonumber(record[2]) or 0
		CDMP_SetLootWeight(playerId, toolId, weight)
	end

	CDMP_StartFromGui(playerId)
end