# Custom Deathmatch MP

A clean configurable multiplayer deathmatch game mode for Teardown.

The mod focuses on a small set of host-controlled match settings: match duration, starting tools, loot crate weights, and headshot damage multiplier. It uses the official Multiplayer Classics-style UI helpers and loot crate pickup flow.

## Features

- Multiplayer deathmatch game mode: `customdeathmatchmp`
- Host setup menu with separate sections:
  - Match
  - Starting tools
  - Loot weights
- Starting tools include vanilla and mod/workshop tools from `game.tool`
- Per-tool starting ammo from `0` to `100`
- Loot crate weights from `0` to `10`
- Official Multiplayer Classics-style loot crates and interact pickup behavior
- Configurable headshot damage multiplier (Thanks for the idea Exorsky(babon))
- Scoreboard with kills and deaths

## Installation

1. Copy this folder into your Teardown mods directory:

   ```text
   Documents/Teardown/mods/Custom Deathmatch MP
   ```

2. Enable the mod in Teardown.
3. Start a multiplayer session and select `Custom Deathmatch MP` from game modes.

## Repository Layout

```text
cdmp.lua              Main Teardown entrypoint
info.txt             Mod metadata
gamemodes.txt        Game mode registration
preview.jpg          Workshop/GitHub preview image
scripts/shared/      Shared config and tool catalog helpers
scripts/server/      Server-side match, settings, spawn, scoring, and damage logic
scripts/client/      Client-side HUD and host setup UI
mplib/               Multiplayer Classics UI and loot helper library
data/texts/          Localization data copied for official UI helpers
```

## Notes

- Do not commit `id.txt`; it links a local mod folder to a Steam Workshop item.
- The game mode is intended for multiplayer sessions.
- Loot spawning relies on `ammospawn` level locations when available. If a level does not provide them, the mod falls back to generated/fallback spawn positions.

## License

This project is licensed under the GNU General Public License v3.0. See LICENSE for details.