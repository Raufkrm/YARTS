class_name WorldState
extends Resource

const CellDataScript = preload("res://scripts/data/cell_data.gd")

const TERRAIN_TYPES := ["plains", "forest", "hills", "water"]

@export var seed := 0
@export var width := 5
@export var height := 5
@export var starting_cell_id := ""
@export var world_day := 1

var cells: Dictionary = {}
var factions := {
	"player": {
		"display_name": "Player Civilization",
		"color": "4f8cff",
	},
	"neutral": {
		"display_name": "Neutral",
		"color": "9aa0a6",
	},
	"bandits": {
		"display_name": "Bandits",
		"color": "d45b4f",
	},
}


func create_new(new_seed: int = 0, new_width: int = 24, new_height: int = 12) -> void:
	seed = new_seed if new_seed != 0 else int(Time.get_unix_time_from_system())
	width = new_width
	height = new_height
	world_day = 1
	cells.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var start_x := int(width / 2)
	var start_y := int(height / 2)

	for y_index in range(height):
		for x_index in range(width):
			var cell = CellDataScript.new()
			cell.x = x_index
			cell.y = y_index
			cell.id = "C%d_%d" % [x_index, y_index]
			cell.terrain = _terrain_for_cell(x_index, y_index, rng)
			cell.owner_id = "player" if x_index == start_x and y_index == start_y else _starting_owner_for_cell(rng)
			cell.threat_level = 0 if cell.owner_id == "player" else rng.randi_range(1, 3)
			cell.settlement_name = "Cradle" if cell.owner_id == "player" else ""
			cell.resources = _resources_for_terrain(cell.terrain)
			cells[cell.id] = cell

	starting_cell_id = "C%d_%d" % [start_x, start_y]


func get_cell(cell_id: String):
	return cells.get(cell_id)


func get_cells() -> Array:
	return cells.values()


func conquer_cell(cell_id: String, owner_id: String) -> void:
	var cell = get_cell(cell_id)
	if cell == null:
		return

	cell.owner_id = owner_id
	cell.threat_level = 0
	if cell.settlement_name.is_empty() and owner_id == "player":
		cell.settlement_name = "Outpost %s" % cell_id


func get_neighbors(cell_id: String) -> Array:
	var cell = get_cell(cell_id)
	if cell == null:
		return []

	var offsets := [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
	]
	var neighbors: Array = []
	for offset in offsets:
		var wrapped_x: int = posmod(int(cell.x) + offset.x, width)
		var wrapped_y: int = int(cell.y) + offset.y
		if wrapped_y < 0 or wrapped_y >= height:
			continue
		var neighbor_id := "C%d_%d" % [wrapped_x, wrapped_y]
		var neighbor = get_cell(neighbor_id)
		if neighbor != null:
			neighbors.append(neighbor)
	return neighbors


func cell_id_from_grid(x_index: int, y_index: int) -> String:
	return "C%d_%d" % [posmod(x_index, width), clamp(y_index, 0, height - 1)]


func get_cell_center_lat_lon(cell) -> Vector2:
	var lon: float = lerpf(-PI, PI, (float(cell.x) + 0.5) / float(width))
	var lat: float = lerpf(PI / 2.0, -PI / 2.0, (float(cell.y) + 0.5) / float(height))
	return Vector2(lat, lon)


func direction_to_cell_id(direction: Vector3) -> String:
	var normalized := direction.normalized()
	var lat := asin(clamp(normalized.y, -1.0, 1.0))
	var lon := atan2(normalized.x, normalized.z)
	var x_index := int(floor(((lon + PI) / TAU) * float(width)))
	var y_index := int(floor(((PI / 2.0 - lat) / PI) * float(height)))
	return cell_id_from_grid(x_index, y_index)


func to_dict() -> Dictionary:
	var serialized_cells := []
	for cell in cells.values():
		serialized_cells.append(cell.to_dict())

	return {
		"seed": seed,
		"width": width,
		"height": height,
		"starting_cell_id": starting_cell_id,
		"world_day": world_day,
		"factions": factions.duplicate(true),
		"cells": serialized_cells,
	}


func load_from_dict(data: Dictionary) -> void:
	seed = int(data.get("seed", 0))
	width = int(data.get("width", 5))
	height = int(data.get("height", 5))
	starting_cell_id = data.get("starting_cell_id", "")
	world_day = int(data.get("world_day", 1))
	factions = data.get("factions", factions).duplicate(true)
	cells.clear()

	for cell_data in data.get("cells", []):
		var cell = CellDataScript.new()
		cell.load_from_dict(cell_data)
		cells[cell.id] = cell


static func _starting_owner_for_cell(rng: RandomNumberGenerator) -> String:
	var roll := rng.randf()
	if roll < 0.18:
		return "bandits"
	return "neutral"


func _terrain_for_cell(x_index: int, y_index: int, rng: RandomNumberGenerator) -> String:
	var latitude_factor: float = abs(((float(y_index) + 0.5) / float(height)) - 0.5) * 2.0
	var wave: float = sin(float(x_index) * 1.37 + float(y_index) * 0.91 + float(seed % 1000) * 0.01)
	var roll: float = rng.randf() + wave * 0.18

	if latitude_factor > 0.82:
		if roll < 0.36:
			return "hills"
		return "plains"

	if roll < 0.22:
		return "water"
	if roll < 0.48:
		return "forest"
	if roll > 0.88:
		return "hills"
	return "plains"


static func _resources_for_terrain(terrain: String) -> Dictionary:
	var resource_map := {
		"food": 50,
		"wood": 50,
		"stone": 20,
		"metal": 0,
		"tools": 2,
		"weapons": 0,
		"supply": 25,
	}

	match terrain:
		"forest":
			resource_map["food"] = 80
			resource_map["wood"] = 160
		"hills":
			resource_map["stone"] = 110
			resource_map["metal"] = 25
		"water":
			resource_map["food"] = 120
			resource_map["wood"] = 20
			resource_map["supply"] = 15
		_:
			resource_map["food"] = 90
			resource_map["wood"] = 70

	return resource_map
