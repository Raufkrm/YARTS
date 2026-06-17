# YARTS Design Brief

This brief condenses `YARTS_revised.docx` into the first implementation targets for the Godot project.

## Core Direction

YARTS is a singleplayer-first roguelike RTS prototype inspired by Total War, Age of Empires, and Master of Command. The first build should prove one complete loop: start in a cell, gather resources, build a town center, equip units, defeat or negotiate with enemies, conquer the cell, move to another cell, and use older cells as support.

## Game Pillars

- Persistent conquest: conquered cells remain useful for future wars, supply, production, and expansion.
- Supply is king: food, equipment, roads, depots, and friendly territory determine army strength.
- Flexible population: equipment defines whether a person works, builds, or fights.
- World strategy and local battles: the world map controls large decisions; cell scenes provide RTS play.
- Growing civilizations: expansion, technology, production, diplomacy, and warfare build the nation over time.

## MVP Scope

Included:

- 3D spherical world map with a wrapped selectable cell grid.
- Random terrain generation on the sphere, with cell terrain feeding the local RTS map.
- One playable faction.
- Basic AI enemies.
- Simple resources and ownership.
- Town center and supply scaffolding.
- Unit equipment/profession scaffolding.
- Click-to-zoom world-to-cell transition.
- Large RTS work plane for the selected cell so unit control, building placement, gathering, and combat systems can be layered in.
- Basic save/load of world state.

Excluded from the first prototype:

- Multiplayer.
- Advanced diplomacy.
- Finished art, sound, and animation.
- Full technology tree.
- Complex AI personalities.
- Multiple planets.
- Naval combat.
- Late-game factories.

## First Architecture Boundaries

- `Game` autoload owns current campaign state, scene transitions, and debug events.
- `WorldState` stores cell ownership, terrain, resources, factions, and world time.
- `WorldManager` is the world-map system boundary for selection, ownership, neighbors, and world turns.
- `CellManager` is the battle-scene system boundary for generating a local encounter from a world cell.
- `UnitManager` owns professions, equipment, and basic stat implications.
- `EconomyManager` owns resource checks, costs, and production-chain scaffolding.
- `SupplyManager` owns supply radius and connected territory checks.
- `AIManager` owns simple defend/attack/rebuild behavior.
- `DiplomacyManager` owns peaceful outcomes and relationship data.
- `SaveManager` serializes the current campaign state.

## Traceability Targets

- Start a new campaign and load the world map.
- Click multiple cells and see unique ownership, terrain, resources, and actions.
- Enter a cell battle scene from the world map.
- Resolve the battle and update ownership.
- Save after conquering a cell, reload, and keep ownership.
- Use debug output for game start, cell selected, battle loaded, battle finished, ownership changed, resources updated, and save completed.
