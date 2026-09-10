class_name CellData
extends Resource

@export var id := ""
@export var x := 0
@export var y := 0
@export var x_span := 1
@export var owner_id := "neutral"
@export var terrain := "plains"
@export var biome := "grassland"
@export var climate := "temperate"
@export var elevation := 0.0
@export var moisture := 0.0
@export var temperature := 0.0
@export var settlement_name := ""
@export var status := "unsettled"
@export var threat_level := 1
@export var rts_state: Dictionary = {}
@export var resources := {
	"food": 0,
	"wood": 0,
	"stone": 0,
	"metal": 0,
	"tools": 0,
	"weapons": 0,
	"supply": 0,
}


func is_player_owned() -> bool:
	return owner_id == "player"


func to_dict() -> Dictionary:
	return {
		"id": id,
		"x": x,
		"y": y,
		"x_span": x_span,
		"owner_id": owner_id,
		"terrain": terrain,
		"biome": biome,
		"climate": climate,
		"elevation": elevation,
		"moisture": moisture,
		"temperature": temperature,
		"settlement_name": settlement_name,
		"status": status,
		"threat_level": threat_level,
		"rts_state": rts_state.duplicate(true),
		"resources": resources.duplicate(true),
	}


func load_from_dict(data: Dictionary) -> void:
	id = data.get("id", "")
	x = int(data.get("x", 0))
	y = int(data.get("y", 0))
	x_span = int(data.get("x_span", 1))
	owner_id = data.get("owner_id", "neutral")
	terrain = data.get("terrain", "plains")
	biome = data.get("biome", terrain)
	climate = data.get("climate", "temperate")
	elevation = float(data.get("elevation", 0.0))
	moisture = float(data.get("moisture", 0.0))
	temperature = float(data.get("temperature", 0.0))
	settlement_name = data.get("settlement_name", "")
	status = str(data.get("status", "settled" if not settlement_name.is_empty() or owner_id != "neutral" else "unsettled"))
	threat_level = int(data.get("threat_level", 1))
	rts_state = data.get("rts_state", {}).duplicate(true)
	resources = data.get("resources", {}).duplicate(true)
