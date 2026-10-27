class_name FirearmProp
extends Node3D
## Reusable visual prop. Human drill/combat state is owned by the future unit controller.

const MANIFEST_PATH := "res://assets/models/weapons/firearms/manifest.json"
const STOCKED_WEAPON_SCALE := 0.8
const LONG_MUSKET_SCALE := 0.75
static var manifest: Dictionary = {}

@export_enum("early_handgonne", "matchlock_arquebus", "flintlock_musket", "caplock_musket") var weapon_id := "flintlock_musket"
@export_range(0, 2) var detail_level := 0
@export var bayonet_attached := false
var scale_override := 0.0
var visual: Node3D
var animation_player: AnimationPlayer
var pose_name := ""
var pose_phase := 0.0


static func asset_manifest() -> Dictionary:
	if manifest.is_empty():
		manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	return manifest


func _ready() -> void:
	rebuild_visual()


func profile() -> Dictionary:
	return asset_manifest().assets.get(weapon_id, {})


func asset_scale() -> float:
	if weapon_id == "early_handgonne": return 1.0
	if scale_override > 0: return scale_override
	return STOCKED_WEAPON_SCALE if weapon_id == "matchlock_arquebus" else LONG_MUSKET_SCALE


func set_detail_level(level: int) -> void:
	level = clampi(level, 0, 2)
	if level == detail_level and visual != null: return
	detail_level = level
	rebuild_visual()


func set_bayonet_attached(attached: bool) -> void:
	attached = attached and bool(profile().get("bayonet_compatible", false))
	if attached == bayonet_attached and visual != null: return
	bayonet_attached = attached
	rebuild_visual()


func is_muzzle_blocked() -> bool:
	return bayonet_attached and not bool(profile().get("can_fire_with_bayonet", true))


func rebuild_visual() -> void:
	var data := profile()
	if data.is_empty():
		push_error("Unknown firearm model: " + weapon_id)
		return
	bayonet_attached = bayonet_attached and bool(data.bayonet_compatible)
	if visual != null:
		remove_child(visual)
		visual.queue_free()
	animation_player = null
	var lods: Array = data.bayonet_lods if bayonet_attached else data.lods
	var packed := load(str(lods[detail_level].mesh)) as PackedScene
	visual = packed.instantiate() as Node3D
	visual.name = "WeaponVisual"
	visual.scale = Vector3.ONE * asset_scale()
	add_child(visual)
	animation_player = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	# The mounted export merges the attachment into the same material surface.
	set_mechanism_pose(pose_name, pose_phase)


func set_mechanism_pose(animation_name: String, normalized_phase: float = 1.0) -> bool:
	pose_name = animation_name
	pose_phase = clampf(normalized_phase, 0.0, 1.0)
	if animation_player == null or animation_name.is_empty(): return false
	var resolved := ""
	for candidate in animation_player.get_animation_list():
		if candidate == animation_name or str(candidate).get_file() == animation_name:
			resolved = candidate
			break
	if resolved.is_empty(): return false
	animation_player.play(resolved)
	animation_player.seek(animation_player.get_animation(resolved).length * pose_phase, true)
	animation_player.pause()
	return true


func socket_position(socket_name: String) -> Vector3:
	var value: Array = profile().sockets.get(socket_name, [0, 0, 0])
	return Vector3(float(value[0]), float(value[1]), float(value[2])) * asset_scale()


func socket_world_position(socket_name: String) -> Vector3:
	return global_transform * socket_position(socket_name)


func current_report() -> Dictionary:
	var data := profile()
	return data.bayonet_lods[detail_level] if bayonet_attached else data.lods[detail_level]
