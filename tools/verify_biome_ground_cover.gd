extends Node

const BattleSceneScript = preload("res://scripts/battle/battle_scene.gd")
const WorldStateScript = preload("res://scripts/data/world_state.gd")


func _ready() -> void:
	var battle = BattleSceneScript.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var inland_desert := {
		"terrain": "desert",
		"biome": "hot_desert",
		"elevation": WorldStateScript.SEA_LEVEL + 0.20,
		"river": 0.0,
		"ridge": 0.45,
		"raw_noise": 0.5,
	}
	assert(not battle._blocks_ground_cover_spawn(inland_desert))
	assert(battle._ground_cover_asset_for_sample(inland_desert, rng).get_file().begins_with("Cactus"))

	var beach_desert := inland_desert.duplicate()
	beach_desert["elevation"] = WorldStateScript.SEA_LEVEL + 0.02
	assert(battle._is_beach_sample(beach_desert))
	assert(battle._blocks_ground_cover_spawn(beach_desert))
	assert(battle._ground_cover_asset_for_sample(beach_desert, rng).is_empty())

	print("Biome ground-cover verification passed")
	battle.free()
	get_tree().quit()
