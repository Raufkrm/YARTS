extends HBoxContainer

const SCENES := [
	{"label": "Human Animations", "path": "res://scenes/tools/animation_tester.tscn"},
	{"label": "Camp & Transport", "path": "res://scenes/tools/camp_transport_preview.tscn"},
	{"label": "Hoes", "path": "res://scenes/tools/hoe_asset_preview.tscn"},
	{"label": "Wildlife", "path": "res://scenes/tools/wildlife_preview.tscn"},
	{"label": "Livestock", "path": "res://scenes/tools/livestock_preview.tscn"},
	{"label": "Ores", "path": "res://scenes/tools/ore_asset_preview.tscn"},
	{"label": "Wetlands", "path": "res://scenes/tools/wetland_preview.tscn"},
	{"label": "Firearms", "path": "res://scenes/tools/musket_preview.tscn"},
	{"label": "Crossbow", "path": "res://scenes/tools/crossbow_preview.tscn"},
]

var picker: OptionButton
var current_index := 0
var switching := false


func _ready() -> void:
	name = "PreviewSceneSelector"
	add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = "Scene"
	add_child(label)
	picker = OptionButton.new()
	picker.name = "ScenePicker"
	picker.custom_minimum_size.x = 220
	picker.tooltip_text = "Preview scene"
	add_child(picker)
	# During scene _ready, SceneTree.current_scene may still be unset.
	var scene_path := ""
	var ancestor := get_parent()
	while ancestor != null:
		if not ancestor.scene_file_path.is_empty():
			scene_path = ancestor.scene_file_path
			break
		ancestor = ancestor.get_parent()
	for index in range(SCENES.size()):
		picker.add_item(SCENES[index].label)
		picker.set_item_metadata(index, SCENES[index].path)
		if SCENES[index].path == scene_path:
			current_index = index
	picker.select(current_index)
	picker.item_selected.connect(_switch_scene)


func _switch_scene(index: int) -> void:
	if switching or index == current_index or index < 0 or index >= SCENES.size():
		return
	switching = true
	var error := get_tree().change_scene_to_file(SCENES[index].path)
	if error != OK:
		switching = false
		picker.select(current_index)
		push_error("Could not open preview scene: %s (%s)" % [SCENES[index].path, error_string(error)])


func _unhandled_key_input(event: InputEvent) -> void:
	if current_index != 0 and event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_switch_scene(0)
