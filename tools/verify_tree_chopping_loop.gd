extends SceneTree

const ResourceNodeScript = preload("res://scripts/battle/rts_resource_node.gd")
const BuildingDataScript = preload("res://scripts/data/rts_building_data.gd")


func _init() -> void:
	var tree = ResourceNodeScript.new()
	tree.configure({
		"id": "tree_test",
		"resource_type": "wood",
		"stage": ResourceNodeScript.STAGE_STANDING_TREE,
		"amount_remaining": 5,
		"harvest_amount": 5,
		"work_required": 2.4,
		"chopped_down_threshold": 3.2,
		"show_ring": false,
	})

	assert(not tree.add_work(3.0))
	assert(tree.add_work(0.2))
	assert(is_equal_approx(tree.progress_ratio(), 1.0))
	tree.transition_to_felled_log(2.4)
	assert(tree.stage == ResourceNodeScript.STAGE_FELLED_LOG)
	assert(tree.show_ring)
	assert(tree.health == 100)
	assert(tree.max_health == 100)
	assert(tree.harvest_amount == 1)
	assert(is_zero_approx(tree.work_progress))
	assert(not tree.add_work(2.3))
	assert(tree.add_work(0.1))

	assert(tree.harvest(3) == 1)
	assert(tree.amount_remaining == 4)
	assert(tree.health == 80)
	assert(is_zero_approx(tree.work_progress))
	assert(not tree.depleted)
	assert(tree.harvest(20) == 0)
	for expected_remaining in [3, 2, 1, 0]:
		assert(tree.add_work(2.4))
		assert(tree.harvest(20) == 1)
		assert(tree.amount_remaining == expected_remaining)
	assert(tree.depleted)
	assert(tree.health == 0)

	var storage = BuildingDataScript.new()
	storage.apply_definition(BuildingDataScript.TYPE_SUPPLY_DEPOT)
	assert(storage.can_store_resources())
	assert(storage.store_resource("wood", 5))
	assert(int(storage.stored_resources.get("wood", 0)) == 5)

	print("Tree chopping loop verification passed")
	quit()
