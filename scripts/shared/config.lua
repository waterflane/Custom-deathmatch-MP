CDMP = CDMP or {}

CDMP.VERSION = 3
CDMP.DEFAULT_WALK_SPEED = 7.0
CDMP.RESPAWN_DELAY = 4.0
CDMP.COUNTDOWN_TIME = 5.0
CDMP.HITMARKER_TIME = 0.35
CDMP.KILLMARKER_TIME = 0.65
CDMP.DAMAGE_NUMBER_TIME = 0.85
CDMP.RESULTS_SCOREBOARD_DELAY = 2.0
CDMP.RESULTS_SCOREBOARD_FADE = 0.35
CDMP.KILLFEED_MAX = 6
CDMP.LOOT_RESPAWN_DELAY = 18.0
CDMP.HEAD_RADIUS = 0.45
CDMP.HEAD_OFFSET = Vec(0, 0.18, 0)

CDMP.DURATION_OPTIONS = {300, 600, 900, 1200, 1800}
CDMP.HEADSHOT_OPTIONS = {1.0, 1.15, 1.25, 1.3, 1.5, 2.0, 2.5, 3.0}

CDMP.DEFAULT_UNLISTED_TOOL_AMMO = 10
CDMP.DEFAULT_UNLISTED_TOOL_PICKUP_AMOUNT = 10
CDMP.DEFAULT_UNLISTED_TOOL_CAN_LOOT = true
CDMP.DEFAULT_UNLISTED_TOOL_LOOT_WEIGHT = 0
CDMP.DEFAULT_UNLISTED_TOOL_START_ENABLED = false

CDMP.VANILLA_TOOLS = {
	{id = "sledge", label = "Sledge", ammo = 0, pickupAmount = 0, canLoot = false, lootWeight = 0, startEnabled = true},
	{id = "spraycan", label = "Spraycan", ammo = 0, pickupAmount = 0, canLoot = false, lootWeight = 0, startEnabled = true},
	{id = "extinguisher", label = "Extinguisher", ammo = 0, pickupAmount = 0, canLoot = false, lootWeight = 0, startEnabled = true},

	{id = "leafblower", label = "Leafblower", ammo = 0, pickupAmount = 0, canLoot = false, lootWeight = 0, startEnabled = false},
	{id = "blowtorch", label = "Blowtorch", ammo = 10, pickupAmount = 20, canLoot = true, lootWeight = 0, startEnabled = false},

	{id = "cable", label = "Cable", ammo = 6, pickupAmount = 4, canLoot = true, lootWeight = 0, startEnabled = false},
	{id = "plank", label = "Plank", ammo = 6, pickupAmount = 5, canLoot = true, lootWeight = 1, startEnabled = false},

	{id = "gun", label = "Gun", ammo = 14, pickupAmount = 12, canLoot = true, lootWeight = 4, startEnabled = true},
	{id = "shotgun", label = "Shotgun", ammo = 8, pickupAmount = 8, canLoot = true, lootWeight = 4, startEnabled = false},
	{id = "rifle", label = "Rifle", ammo = 12, pickupAmount = 8, canLoot = true, lootWeight = 2, startEnabled = false},
	{id = "rocket", label = "Rocket", ammo = 3, pickupAmount = 4, canLoot = true, lootWeight = 1, startEnabled = false},

	{id = "bomb", label = "Bomb", ammo = 3, pickupAmount = 4, canLoot = true, lootWeight = 3, startEnabled = false},
	{id = "pipebomb", label = "Pipebomb", ammo = 4, pickupAmount = 6, canLoot = true, lootWeight = 3, startEnabled = false},
	{id = "explosive", label = "Explosive", ammo = 3, pickupAmount = 6, canLoot = true, lootWeight = 2, startEnabled = false},

	{id = "booster", label = "Booster", ammo = 6, pickupAmount = 4, canLoot = true, lootWeight = 0, startEnabled = false},
	{id = "transport_booster", label = "Transport Booster", ammo = 6, pickupAmount = 4, canLoot = true, lootWeight = 0, startEnabled = false},
	{id = "steroid", label = "Steroid", ammo = 4, pickupAmount = 2, canLoot = true, lootWeight = 1, startEnabled = false},
}

function CDMP.Clamp(value, minValue, maxValue)
	value = tonumber(value) or minValue
	if value < minValue then return minValue end
	if value > maxValue then return maxValue end
	return value
end

function CDMP.FormatTime(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	local minutes = math.floor(seconds / 60)
	local secs = seconds - minutes * 60
	if secs < 10 then return tostring(minutes) .. ":0" .. tostring(secs) end
	return tostring(minutes) .. ":" .. tostring(secs)
end

function CDMP.CopyTransform(t)
	return Transform(Vec(t.pos[1], t.pos[2], t.pos[3]), Quat(t.rot[1], t.rot[2], t.rot[3], t.rot[4]))
end

function CDMP.GetHeadshotCenter(playerId)
	local eye = GetPlayerEyeTransform(playerId)
	return TransformToParentPoint(eye, CDMP.HEAD_OFFSET)
end

