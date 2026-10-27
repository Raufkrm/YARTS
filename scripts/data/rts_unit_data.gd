class_name RTSUnitData
extends Resource

const MusketCombat = preload("res://scripts/data/musket_combat_state.gd")
var musket_combat: MusketCombat
const HandgonneReload = preload("res://scripts/data/handgonne_reload_state.gd")

# Created only for units using this weapon; ordinary units keep no reload state.
var handgonne_reload: HandgonneReload

@export var id := ""
@export var display_name := "Person"
@export var faction_id := "player"
@export var equipment_id := "flint_axe"
@export var position := Vector3.ZERO
@export var health := 100
@export var max_health := 100
@export var stamina := 100
@export var morale := 50
@export var fatigue := 0
@export var armor := 0
@export var damage := 4
@export var movement_speed := 4.0
@export var experience := 0
@export var equipment_quality := 1
@export var supply := 100
@export var ground_tools_initialized := false
@export var ground_tools_position := Vector3.ZERO
@export var ground_tools_equipment_id := ""
@export var ground_tools_collected: Array[int] = []
@export var collected_tools: Array[Dictionary] = []


func apply_stats(stats: Dictionary) -> void:
	health = int(stats.get("health", health))
	max_health = max(max_health, health)
	morale = int(stats.get("morale", morale))
	fatigue = int(stats.get("fatigue", fatigue))
	armor = int(stats.get("armor", armor))
	damage = int(stats.get("damage", damage))
	movement_speed = float(stats.get("movement_speed", movement_speed))
	equipment_quality = int(stats.get("equipment_quality", equipment_quality))
	experience = int(stats.get("experience", experience))


func can_gather() -> bool:
	return is_alive()


func can_construct() -> bool:
	return is_alive()


func can_fight() -> bool:
	return damage > 0


func is_alive() -> bool:
	return health > 0


func get_musket_combat_state() -> MusketCombat:
	if musket_combat == null: musket_combat = MusketCombat.new()
	return musket_combat


func get_handgonne_reload_state() -> HandgonneReload:
	if handgonne_reload == null:
		handgonne_reload = HandgonneReload.new()
	return handgonne_reload


func to_dict() -> Dictionary:
	var data := {
		"id": id,
		"display_name": display_name,
		"faction_id": faction_id,
		"equipment_id": equipment_id,
		"position": {
			"x": position.x,
			"y": position.y,
			"z": position.z,
		},
		"health": health,
		"max_health": max_health,
		"stamina": stamina,
		"morale": morale,
		"fatigue": fatigue,
		"armor": armor,
		"damage": damage,
		"movement_speed": movement_speed,
		"experience": experience,
		"equipment_quality": equipment_quality,
		"supply": supply,
		"ground_tools_initialized": ground_tools_initialized,
		"ground_tools_position": {"x": ground_tools_position.x, "y": ground_tools_position.y, "z": ground_tools_position.z},
		"ground_tools_equipment_id": ground_tools_equipment_id,
		"ground_tools_collected": ground_tools_collected.duplicate(),
		"collected_tools": collected_tools.duplicate(true),
	}
	if musket_combat != null: data["musket_combat"] = musket_combat.to_dict()
	if handgonne_reload != null:
		data["handgonne_reload"] = handgonne_reload.to_dict()
	return data


func load_from_dict(data: Dictionary) -> void:
	id = str(data.get("id", ""))
	display_name = str(data.get("display_name", "Person"))
	# Migrate old automatic role labels; preserve player-authored names and IDs.
	if display_name in ["Worker", "Builder", "Spearman"]: display_name = "Person"
	faction_id = str(data.get("faction_id", "player"))
	equipment_id = str(data.get("equipment_id", "flint_axe"))
	var position_data: Dictionary = data.get("position", {})
	position = Vector3(
		float(position_data.get("x", 0.0)),
		float(position_data.get("y", 0.0)),
		float(position_data.get("z", 0.0))
	)
	health = int(data.get("health", 100))
	max_health = int(data.get("max_health", 100))
	stamina = int(data.get("stamina", 100))
	morale = int(data.get("morale", 50))
	fatigue = int(data.get("fatigue", 0))
	armor = int(data.get("armor", 0))
	damage = int(data.get("damage", 4))
	movement_speed = float(data.get("movement_speed", 4.0))
	experience = int(data.get("experience", 0))
	equipment_quality = int(data.get("equipment_quality", 1))
	supply = int(data.get("supply", 100))
	ground_tools_initialized = bool(data.get("ground_tools_initialized", false))
	ground_tools_equipment_id = str(data.get("ground_tools_equipment_id", equipment_id))
	ground_tools_collected.clear()
	for index in data.get("ground_tools_collected", []): ground_tools_collected.append(int(index))
	collected_tools.clear()
	for item in data.get("collected_tools", []):
		if item is Dictionary: collected_tools.append(item.duplicate(true))
	var tool_position: Dictionary = data.get("ground_tools_position", {})
	ground_tools_position = Vector3(float(tool_position.get("x", 0)), float(tool_position.get("y", 0)), float(tool_position.get("z", 0)))
	handgonne_reload = null
	var reload_data = data.get("handgonne_reload")
	if reload_data is Dictionary:
		get_handgonne_reload_state().load_from_dict(reload_data)

	musket_combat = null
	if data.get("musket_combat") is Dictionary:
		get_musket_combat_state().load_from_dict(data.musket_combat)
