class_name RTSBuildingData
extends Resource

const Catalog = preload("res://scripts/data/building_catalog.gd")

const TYPE_TOWN_CENTER := "town_center"
const TYPE_SUPPLY_DEPOT := "supply_depot"
const TYPE_WORKSHOP := "workshop"
const TYPE_BARRACKS := "barracks"
const TYPE_HOUSE := "house"
const TYPE_TENT := "tent"
const TYPE_ROAD := "road"

const SHAPE_CUBE := "cube"
const SHAPE_TENT := "tent"
const SHAPE_FLAT := "flat"

const BUILDING_DEFINITIONS := {
	TYPE_TOWN_CENTER: {
		"display_name": "Town Center",
		"shape": SHAPE_CUBE,
		"size": Vector3(24.0, 12.0, 24.0),
		"max_health": 1500,
		"supply_radius": 100.0,
		"storage_capacity": 500,
		"can_train_population": true,
		"can_produce_equipment": false,
	},
	TYPE_SUPPLY_DEPOT: {
		"display_name": "Supply Depot",
		"shape": SHAPE_CUBE,
		"size": Vector3(14.0, 7.0, 14.0),
		"max_health": 800,
		"supply_radius": 70.0,
		"storage_capacity": 320,
		"can_train_population": false,
		"can_produce_equipment": false,
	},
	TYPE_WORKSHOP: {
		"display_name": "Workshop",
		"shape": SHAPE_CUBE,
		"size": Vector3(18.0, 8.0, 14.0),
		"max_health": 900,
		"supply_radius": 35.0,
		"storage_capacity": 180,
		"can_train_population": false,
		"can_produce_equipment": true,
	},
	TYPE_BARRACKS: {
		"display_name": "Barracks",
		"shape": SHAPE_CUBE,
		"size": Vector3(24.0, 8.0, 14.0),
		"max_health": 1000,
		"supply_radius": 35.0,
		"storage_capacity": 120,
		"can_train_population": false,
		"can_produce_equipment": false,
	},
	TYPE_HOUSE: {
		"display_name": "House",
		"shape": SHAPE_TENT,
		"size": Vector3(10.0, 8.0, 10.0),
		"max_health": 350,
		"supply_radius": 0.0,
		"storage_capacity": 40,
		"can_train_population": false,
		"can_produce_equipment": false,
	},
	TYPE_TENT: {
		"display_name": "Tent",
		"shape": SHAPE_TENT,
		"size": Vector3(8.0, 5.5, 8.0),
		"max_health": 180,
		"supply_radius": 0.0,
		"storage_capacity": 20,
		"can_train_population": false,
		"can_produce_equipment": false,
	},
	TYPE_ROAD: {
		"display_name": "Road",
		"shape": SHAPE_FLAT,
		"size": Vector3(32.0, 0.18, 8.0),
		"max_health": 999999,
		"supply_radius": 0.0,
		"storage_capacity": 0,
		"can_train_population": false,
		"can_produce_equipment": false,
	},
}

@export var id := ""
@export var type_id := TYPE_TENT
@export var display_name := "Tent"
@export var faction_id := "player"
@export var position := Vector3.ZERO
@export var rotation_y := 0.0
@export var size := Vector3(8.0, 5.5, 8.0)
@export var shape := SHAPE_TENT
@export var health := 180
@export var max_health := 180
@export var build_progress := 1.0
@export var completed := true
@export var supply_radius := 0.0
@export var storage_capacity := 0
@export var stored_resources := {}
@export var can_train_population := false
@export var can_produce_equipment := false
@export var production_queue: Array[String] = []
@export var work_required := 120.0
@export var housing := 0
@export var reserved_cost: Dictionary = {}
@export var founding_site := false


static func definition_for_type(building_type: String) -> Dictionary:
	return BUILDING_DEFINITIONS.get(building_type, BUILDING_DEFINITIONS[TYPE_TENT]).duplicate(true)


func apply_definition(building_type: String) -> void:
	type_id = building_type
	var definition := definition_for_type(building_type)
	display_name = str(definition.get("display_name", display_name))
	shape = str(definition.get("shape", shape))
	size = definition.get("size", size)
	max_health = int(definition.get("max_health", max_health))
	health = max_health
	supply_radius = float(definition.get("supply_radius", supply_radius))
	storage_capacity = int(definition.get("storage_capacity", storage_capacity))
	can_train_population = bool(definition.get("can_train_population", can_train_population))
	can_produce_equipment = bool(definition.get("can_produce_equipment", can_produce_equipment))
	if Catalog.DEFINITIONS.has(type_id):
		var entry: Dictionary = Catalog.DEFINITIONS[type_id]
		display_name = entry.name
		size = entry.size
		max_health = entry.health
		health = max_health
		storage_capacity = entry.storage
		supply_radius = entry.supply
		work_required = entry.work
		housing = entry.housing


func is_supply_source() -> bool:
	return completed and supply_radius > 0.0


func can_store_resources() -> bool:
	return completed and storage_capacity > 0


func can_accept_resource(resource_name: String, amount: int) -> bool:
	if amount <= 0 or not can_store_resources():
		return false
	var stored_total := 0
	for value in stored_resources.values():
		stored_total += int(value)
	return stored_total + amount <= storage_capacity


func store_resource(resource_name: String, amount: int) -> bool:
	if not can_accept_resource(resource_name, amount):
		return false
	stored_resources[resource_name] = int(stored_resources.get(resource_name, 0)) + amount
	return true


func to_dict() -> Dictionary:
	return {
		"work_required": work_required,
		"housing": housing,
		"reserved_cost": reserved_cost.duplicate(true),
		"founding_site": founding_site,
		"id": id,
		"type_id": type_id,
		"display_name": display_name,
		"faction_id": faction_id,
		"position": {
			"x": position.x,
			"y": position.y,
			"z": position.z,
		},
		"rotation_y": rotation_y,
		"size": {
			"x": size.x,
			"y": size.y,
			"z": size.z,
		},
		"shape": shape,
		"health": health,
		"max_health": max_health,
		"build_progress": build_progress,
		"completed": completed,
		"supply_radius": supply_radius,
		"storage_capacity": storage_capacity,
		"stored_resources": stored_resources.duplicate(true),
		"can_train_population": can_train_population,
		"can_produce_equipment": can_produce_equipment,
		"production_queue": production_queue.duplicate(),
	}


func load_from_dict(data: Dictionary) -> void:
	id = str(data.get("id", ""))
	type_id = str(data.get("type_id", TYPE_TENT))
	apply_definition(type_id)
	work_required = float(data.get("work_required", work_required))
	housing = int(data.get("housing", housing))
	reserved_cost = data.get("reserved_cost", {}).duplicate(true)
	founding_site = bool(data.get("founding_site", false))
	display_name = str(data.get("display_name", "Tent"))
	faction_id = str(data.get("faction_id", "player"))
	var position_data: Dictionary = data.get("position", {})
	position = Vector3(
		float(position_data.get("x", 0.0)),
		float(position_data.get("y", 0.0)),
		float(position_data.get("z", 0.0))
	)
	rotation_y = float(data.get("rotation_y", 0.0))
	var size_data: Dictionary = data.get("size", {})
	size = Vector3(
		float(size_data.get("x", 8.0)),
		float(size_data.get("y", 5.5)),
		float(size_data.get("z", 8.0))
	)
	# Older saves store the Hall's previous bounds; match its current model scale.
	if type_id == TYPE_TOWN_CENTER: size = Catalog.DEFINITIONS.town_center.size
	shape = str(data.get("shape", SHAPE_TENT))
	health = int(data.get("health", 180))
	max_health = int(data.get("max_health", 180))
	build_progress = float(data.get("build_progress", 1.0))
	completed = bool(data.get("completed", true))
	supply_radius = float(data.get("supply_radius", 0.0))
	storage_capacity = int(data.get("storage_capacity", 0))
	stored_resources = data.get("stored_resources", {}).duplicate(true)
	can_train_population = bool(data.get("can_train_population", false))
	can_produce_equipment = bool(data.get("can_produce_equipment", false))
	production_queue.assign(data.get("production_queue", []))


func entrance_position() -> Vector3:
	return position + Vector3(0, 0, size.z * 0.5 + 6.0).rotated(Vector3.UP, rotation_y)


# Distances are measured from the rotated footprint, so a larger building has
# a larger interaction perimeter without allowing work farther from its walls.
func edge_distance(point: Vector3) -> float:
	var local := (point - position).rotated(Vector3.UP, -rotation_y)
	return Vector2(maxf(0.0, absf(local.x) - size.x * 0.5), maxf(0.0, absf(local.z) - size.z * 0.5)).length()

func perimeter_positions(near: Vector3, offset: float = 6.0, spacing: float = 5.0) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var local := (near - position).rotated(Vector3.UP, -rotation_y)
	var half := size * 0.5
	for axis in [0, 2]:
		var along := 2 if axis == 0 else 0
		for side in [-1.0, 1.0]:
			var point := Vector3.ZERO
			point[axis] = side * (half[axis] + offset)
			point[along] = clampf(local[along], -half[along], half[along])
			points.append(position + point.rotated(Vector3.UP, rotation_y))
			var steps := maxi(1, ceili(half[along] * 2.0 / spacing))
			for step in range(steps + 1):
				point[along] = lerpf(-half[along], half[along], float(step) / steps)
				points.append(position + point.rotated(Vector3.UP, rotation_y))
	points.sort_custom(func(a: Vector3, b: Vector3): return a.distance_squared_to(near) < b.distance_squared_to(near))
	return points
