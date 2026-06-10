#version 2
#include "script/include/common.lua"
#include "script/include/player.lua"
#include "scripts/shared/config.lua"
#include "scripts/shared/world.lua"
#include "mplib/util.lua"
#include "mplib/tools.lua"
#include "scripts/server/match.lua"
#include "mplib/hud.lua"
#include "scripts/client/gui.lua"

function server.init()
	CDMP_ServerInit()
end

function server.destroy()
	CDMP_ServerDestroy()
end

function server.tick(dt)
	CDMP_ServerTick(dt)
end

function server.settingsSetLoadoutTool(playerId, toolId, enabled, ammo)
	CDMP_SetLoadoutTool(playerId, toolId, enabled, ammo)
end

function server.settingsSetLootWeight(playerId, toolId, weight)
	CDMP_SetLootWeight(playerId, toolId, weight)
end

function server.settingsSetHeadshotMultiplier(playerId, idx)
	CDMP_SetHeadshotMultiplier(playerId, idx)
end

function server.settingsSetRoundDuration(playerId, idx)
	CDMP_SetRoundDuration(playerId, idx)
end

function server.settingsReady(playerId)
	CDMP_SetReady(playerId)
end

function server.settingsStartMatch(playerId)
	CDMP_StartFromGui(playerId)
end

function server.settingsReset(playerId)
	CDMP_ResetSettings(playerId)
end

function server.settingsApplyAndStart(playerId, durationIdx, headshotIdx, loadoutData, lootData)
	CDMP_ApplySettingsAndStart(playerId, durationIdx, headshotIdx, loadoutData, lootData)
end

function client.init()
	CDMP_GuiInit()
end

function client.tick(dt)
	CDMP_ClientTick(dt)
end

function client.draw()
	CDMP_DrawGui()
end