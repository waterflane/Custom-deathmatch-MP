CDMP = CDMP or {}

CDMP.VERSION = 2
CDMP.DEFAULT_WALK_SPEED = 7.0
CDMP.RESPAWN_DELAY = 4.0
CDMP.LOOT_RESPAWN_DELAY = 18.0
CDMP.HEAD_RADIUS = 0.45

CDMP.DURATION_OPTIONS = {300, 600, 900, 1200, 1800}
CDMP.HEADSHOT_OPTIONS = {1.0, 1.25, 1.5, 2.0, 3.0}

CDMP.VANILLA_TOOLS = {
	{id = "sledge", label = "Sledge", ammo = 0, canLoot = false, startEnabled = true},
	{id = "gun", label = "Gun", ammo = 14, canLoot = true, startEnabled = true},
	{id = "shotgun", label = "Shotgun", ammo = 8, canLoot = true, startEnabled = false},
	{id = "rifle", label = "Rifle", ammo = 12, canLoot = true, startEnabled = false},
	{id = "rocket", label = "Rocket", ammo = 3, canLoot = true, startEnabled = false},
	{id = "bomb", label = "Bomb", ammo = 3, canLoot = true, startEnabled = false},
	{id = "pipebomb", label = "Pipebomb", ammo = 4, canLoot = true, startEnabled = false},
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