class_name AIManager
extends Node

enum Intent {
	DEFEND,
	ATTACK_WEAK_NEIGHBOR,
	REBUILD,
}


func choose_cell_intent(world_state, cell) -> Intent:
	if world_state == null or cell == null:
		return Intent.DEFEND

	if cell.threat_level <= 0:
		return Intent.REBUILD

	for neighbor in world_state.get_neighbors(cell.id):
		if neighbor.owner_id == "player" and neighbor.threat_level <= cell.threat_level:
			return Intent.ATTACK_WEAK_NEIGHBOR

	return Intent.DEFEND


func describe_intent(intent: Intent) -> String:
	match intent:
		Intent.ATTACK_WEAK_NEIGHBOR:
			return "attack weak neighbor"
		Intent.REBUILD:
			return "rebuild"
		_:
			return "defend"
