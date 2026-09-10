extends SceneTree

const WorldStateScript = preload("res://scripts/data/world_state.gd")


func _init() -> void:
	for seed in [101, 202, 303, 404, 505, 606]:
		var world = WorldStateScript.new()
		world.create_new(seed, 24, 12)
		assert(world.starting_cell_id.is_empty())
		var starting_cell = null
		for candidate in world.get_cells():
			if world.get_cell_water_coverage(str(candidate.id)) <= 0.90:
				starting_cell = candidate
				break
		assert(starting_cell != null)
		assert(world.settle_starting_cell(str(starting_cell.id)))
		assert(world.starting_cell_id == str(starting_cell.id))
		assert(str(starting_cell.status) == "settled")
		assert(str(starting_cell.owner_id) == "player")
	print("Starting-cell settlement passed for all probe seeds.")
	quit()
