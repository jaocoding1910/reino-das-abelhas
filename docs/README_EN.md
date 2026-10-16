# Bee Kingdom (Reino das Abelhas) 🐝

A Roblox game written in Luau, developed in VS Code and synced to Roblox Studio with Rojo. You play as a bee in a giant kingdom: fly between huge flowers, collect nectar and honeycombs, build your hive cell by cell, survive predators at night and earn the title of Hive King or Queen.

> **Status:** a playable prototype. The full core loop runs end to end. Graphics use code-generated scenery plus a custom 3D model pack. It has not yet been tested on a published public server.

## Gameplay loop

Spawn at your hive → learn to fly → collect nectar and combs (3 rarities) → carry a limited load → deliver to your hive (honey and build points) → build and expand cells → buy upgrades → explore riskier regions → survive the night → deliver rare combs → complete the Queen's requests → become Hive King or Queen.

## Features

- **Flight:** smooth acceleration, banking, sprint with stamina, strafing, double-tap barrel roll, first/third-person camera.
- **Economy:** nectar → honey, comb rarities, carry weight that slows you down, passive honey from completed cells, hired workers, rebirths.
- **Progression:** chained quests, daily quests, achievements, a long-term crown goal tracked from saved data.
- **World:** day/night cycle, weather, hive trees with scaffolding, flower fields, a forest, a crystal cave, a dragonfly lake, cliffs with honey huts, a sky island race, a royal castle.
- **Danger:** spiders (webs), mantises (ambush) and dragonflies (dives) with state-machine AI and line of sight; a night boss.
- **Social:** clans with honey bonus and no friendly fire, a server and global leaderboard, friend bonus.
- **Presentation:** a first-person viewmodel (paws holding your cargo), floating numbers, combos, confetti, a cinematic tour mode (T).

## Architecture

| Layer | Folder | Responsibility |
|---|---|---|
| Shared | `src/shared` | Config (all balancing numbers), Types (save format and migrations), Remotes (the one list of network channels), Levels, Regions |
| Server | `src/server/Services` | 30+ single-responsibility services: data, world, resources, hive, health, predators, quests, clans, and more |
| Client | `src/client/Controllers` | Input, flight, camera, HUD, effects, audio, tour; display and input only |

**Key design decisions**

- **Server authority:** the client only *requests*; the server validates distance, timing, ownership, cost and rate limits, and decides every reward. No economic value is ever accepted from the client.
- **Two-phase boot:** a Loader requires every module, then runs `Init` on all of them, then `Start`, in a fixed order. Each phase is wrapped in `pcall`, so one failing system cannot take the game down.
- **No circular dependencies:** services report changes through a small `Notifier` (`Changed` / `Notify`). A single `StateService` builds the full HUD state and sends it to the client.
- **Safe persistence:** DataStore loads use `UpdateAsync` with a session lock, so two servers never overwrite the same profile. Saves are versioned and migrated (v6). Failed loads fall back to a clearly labeled test mode that never overwrites real data.
- **Exactly-once operations:** cargo is taken atomically on delivery and on defeat, and a death lock prevents double penalties. Nothing can be duplicated by disconnecting.
- **Streaming-aware client:** far landmarks are persistent models, and decorative scenery is built locally.

## Tooling

Rojo 7.7 · Rokit · StyLua · Selene · luau-lsp (type checking) · Git. Logic tests run in standalone Luau.

## Run it

```powershell
rokit install
rojo serve        # port 34872, then Connect in the Rojo Studio plugin
```

Then press F5 in Roblox Studio. Publishing steps are in `docs/PUBLICAR.md` (in Portuguese).

## Controls

WASD fly · Space up · Q/Ctrl down · Shift sprint · double-tap A/D barrel roll · V camera · G guide trail · H clean screen · T cinematic tour · P settings · 1/2/3 actions · hold E to interact.

---
Made by João Gabriel Lucena, with AI-assisted development.
