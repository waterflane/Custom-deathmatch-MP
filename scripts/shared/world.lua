function CDMP.ReadToolName(id, fallback)
	local name = GetString("game.tool." .. id .. ".name")
	if name == nil or name == "" then return fallback or id end
	return name
end

function CDMP.CollectToolCatalog()
	local list = {}
	local byId = {}
	local ids = {}
	local function add(tool)
		if not byId[tool.id] then
			byId[tool.id] = tool
			table.insert(list, tool)
			table.insert(ids, tool.id)
		end
	end
	for i = 1, #CDMP.VANILLA_TOOLS do
		local base = CDMP.VANILLA_TOOLS[i]
		add({id = base.id, label = CDMP.ReadToolName(base.id, base.label), ammo = base.ammo, usesAmmo = base.id ~= "sledge", canLoot = base.canLoot, startEnabled = base.startEnabled == true, vanilla = true})
	end
	local keys = ListKeys("game.tool")
	for i = 1, #keys do
		local id = keys[i]
		if id ~= "" and not byId[id] then
			add({id = id, label = CDMP.ReadToolName(id, id), ammo = 10, usesAmmo = true, canLoot = true, startEnabled = false, vanilla = false})
		end
	end
	return list, byId, ids
end

function CDMP.FindTransforms(tags, fallbackCount, radius, height)
	local result = {}
	for i = 1, #tags do
		local handles = FindLocations(tags[i], true)
		for j = 1, #handles do table.insert(result, GetLocationTransform(handles[j])) end
	end
	if #result == 0 then
		for i = 1, fallbackCount do
			local angle = (i / fallbackCount) * math.pi * 2.0
			local pos = Vec(math.cos(angle) * radius, height, math.sin(angle) * radius)
			table.insert(result, Transform(pos, QuatEuler(0, -angle * 180.0 / math.pi, 0)))
		end
	end
	return result
end

function CDMP.DeleteEntities(entities)
	if not entities then return end
	for i = 1, #entities do
		local entity = entities[i]
		if entity ~= 0 and IsHandleValid(entity) then Delete(entity) end
	end
end

function CDMP.HasLiveEntity(entities)
	if not entities then return false end
	for i = 1, #entities do
		local entity = entities[i]
		if entity ~= 0 and IsHandleValid(entity) then return true end
	end
	return false
end