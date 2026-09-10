extends SceneTree

const ICON_ROOT := "res://assets/sprites/ui/hud/"
const ICON_NAMES := [
	"population", "tech", "food", "owner", "threat", "sun",
	"units", "buildings", "entities", "full_models", "impostors",
	"health", "stamina", "morale", "armor", "damage", "speed",
	"equipment", "profession", "lead_unit", "carry",
	"resource_food", "resource_wood", "resource_stone", "resource_metal",
	"resource_tools", "resource_weapons", "resource_supply", "resource_flint",
	"resource_gold", "resource_none", "select", "add_selection", "move", "jog", "world",
]


func _init() -> void:
	for icon_name in ICON_NAMES:
		var icon_path := "%s%s.svg" % [ICON_ROOT, icon_name]
		assert(ResourceLoader.exists(icon_path), "Missing HUD icon: %s" % icon_path)
		var texture := load(icon_path) as Texture2D
		assert(texture != null, "HUD icon did not import as Texture2D: %s" % icon_path)
		assert(texture.get_size() == Vector2(24, 24), "Unexpected HUD icon size: %s" % icon_path)
	print("HUD icon verification passed: %d icons" % ICON_NAMES.size())
	quit()
