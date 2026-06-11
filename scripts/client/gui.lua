local CDMP_SETTING_PREFIX = "savegame.mod.cdmp."

function key(name)
	return CDMP_SETTING_PREFIX .. name
end

function option(label, value)
	return {label = label, value = tostring(value)}
end

function optionIndex(options, value)
	local wanted = tostring(value)
	for i = 1, #options do
		if tostring(options[i].value) == wanted then return i end
	end
	return 1
end

function ensureStepperValue(settingKey, options, defaultValue)
	if HasKey(settingKey) then return end
	local idx = optionIndex(options, defaultValue)
	SetInt(settingKey .. ".index", idx)
	SetString(settingKey, options[idx].value)
end

function resetStepperValue(settingKey, options, defaultValue)
	local idx = optionIndex(options, defaultValue)
	SetInt(settingKey .. ".index", idx)
	SetString(settingKey, options[idx].value)
end

function readNumber(settingKey, fallback)
	local value = tonumber(GetString(settingKey))
	if value == nil then return fallback end
	return value
end

function rowsFromState(st)
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

function playerName(playerId)
	if playerId == nil then return "Unknown" end
	local name = GetPlayerName(playerId)
	if name == nil or name == "" then return "Player " .. tostring(playerId) end
	return name
end
