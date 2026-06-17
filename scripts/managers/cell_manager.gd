class_name CellManager
extends Node

const TERRAIN_TO_BATTLE_TAG := {
	"plains": "open_field",
	"forest": "forest_battlefield",
	"hills": "high_ground",
	"water": "shoreline",
}


func build_battle_setup(cell) -> Dictionary:
	if cell == null:
		return {}

	return {
		"cell_id": cell.id,
		"terrain": cell.terrain,
		"battlefield_tag": TERRAIN_TO_BATTLE_TAG.get(cell.terrain, "open_field"),
		"enemy_owner": cell.owner_id,
		"threat_level": cell.threat_level,
		"local_resources": cell.resources.duplicate(true),
	}


func resolve_battle(cell, player_won: bool) -> Dictionary:
	return {
		"cell_id": cell.id if cell != null else "",
		"player_won": player_won,
		"loot": _basic_loot(cell) if player_won else {},
	}


func _basic_loot(cell) -> Dictionary:
	if cell == null:
		return {}

	return {
		"food": int(cell.resources.get("food", 0) * 0.15),
		"wood": int(cell.resources.get("wood", 0) * 0.15),
		"tools": max(0, int(cell.resources.get("tools", 0))),
		"weapons": max(0, int(cell.resources.get("weapons", 0))),
	}
