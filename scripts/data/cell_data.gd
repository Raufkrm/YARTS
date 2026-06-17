class_name CellData
extends Resource

@export var id := ""
@export var x := 0
@export var y := 0
@export var owner_id := "neutral"
@export var terrain := "plains"
@export var settlement_name := ""
@export var threat_level := 1
@export var resources := {
	"food": 50,
	"wood": 50,
	"stone": 20,
	"metal": 0,
	"tools": 2,
	"weapons": 0,
	"supply": 25,
}


func is_player_owned() -> bool:
	return owner_id == "player"


func to_dict() -> Dictionary:
	return {
		"id": id,
		"x": x,
		"y": y,
		"owner_id": owner_id,
		"terrain": terrain,
		"settlement_name": settlement_name,
		"threat_level": threat_level,
		"resources": resources.duplicate(true),
	}


func load_from_dict(data: Dictionary) -> void:
	id = data.get("id", "")
	x = int(data.get("x", 0))
	y = int(data.get("y", 0))
	owner_id = data.get("owner_id", "neutral")
	terrain = data.get("terrain", "plains")
	settlement_name = data.get("settlement_name", "")
	threat_level = int(data.get("threat_level", 1))
	resources = data.get("resources", {}).duplicate(true)
