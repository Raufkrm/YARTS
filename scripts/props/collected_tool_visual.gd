extends SkeletonModifier3D

# Presentation only: inventory remains the authority for collected item ownership.
# Runs after AnimationMixer; arm/body poses stay in the existing animation clips.
const MANIFEST := "res://assets/models/primitive_age_asset_manifest.json"
const HAND_CONTACT := Vector3(-0.046, 0.105, 0)
const HAND_BASIS := Basis(Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0))
const FAMILIES := {
	"flint_axe": ["primitive_stone_axe"],
	"building_tools": ["primitive_stone_axe_narrow", "primitive_antler_pick"],
	"spear": ["primitive_stone_spear"],
}
static var profiles: Dictionary = {}
var actor
var game_scale := 5.0
var detail := 1
var active_path := ""
var tool_grip := Vector3.ZERO
var held_tool: Node3D
var hand_attachment: BoneAttachment3D
var stow_attachment: BoneAttachment3D
var stowed := false
var _visual_key := ""
var _grip_bones: Array[int] = []
var _grip_rotations: Array[Quaternion] = []

func configure(owner_actor, visual_scale: float) -> void:
	actor = owner_actor
	game_scale = visual_scale
	var skeleton := get_skeleton()
	hand_attachment = BoneAttachment3D.new()
	hand_attachment.name = "CollectedToolHand"
	hand_attachment.bone_name = "hand_r"
	skeleton.add_child(hand_attachment)
	stow_attachment = BoneAttachment3D.new()
	stow_attachment.name = "CollectedToolHolster"
	stow_attachment.bone_name = "pelvis"
	skeleton.add_child(stow_attachment)
	# Joined-finger grip uses the approved hand bones; close around the thin haft.
	for entry in [["middle_01_r", 0.72], ["middle_02_r", 0.66], ["middle_03_r", 0.18], ["thumb_01_r", 0.44], ["thumb_02_r", 0.26]]:
		var bone := skeleton.find_bone(entry[0])
		if bone < 0: continue
		_grip_bones.append(bone)
		_grip_rotations.append(skeleton.get_bone_rest(bone).basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, float(entry[1]) * 1.20))
	refresh_inventory()

func refresh_inventory() -> void:
	if actor == null or actor.unit_data == null or hand_attachment == null: return
	if profiles.is_empty(): profiles = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST)).get("assets", {})
	var selected := ""
	var fallback := ""
	for item in actor.unit_data.collected_tools:
		var family: String = str(item.get("model", "")).get_file().trim_suffix("_lod0.glb").trim_suffix("_lod1.glb")
		if not profiles.has(family) or not FAMILIES.values().any(func(names): return family in names): continue
		if fallback.is_empty(): fallback = family
		if family in FAMILIES.get(actor.equipment_id, []):
			selected = family
			break
	if selected.is_empty(): selected = fallback
	var key := "%s:%d" % [selected, detail]
	if key != _visual_key:
		_visual_key = key
		if held_tool != null:
			held_tool.visible = false
			held_tool.queue_free()
			held_tool = null
		active_path = ""
		if not selected.is_empty():
			var profile: Dictionary = profiles[selected]
			active_path = "res://" + str(profile["lod%d" % detail].path)
			held_tool = (load(active_path) as PackedScene).instantiate() as Node3D
			held_tool.name = "HeldCollectedTool"
			hand_attachment.add_child(held_tool)
			var grip: Array = profile.attachment_points_blender.grip
			# GLB import converts Blender (X,Y,Z) to Godot (X,Z,-Y).
			tool_grip = Vector3(float(grip[0]), float(grip[2]), -float(grip[1]))
			# Carry the pick by bare wood just below its crosshead/lashings.
			if selected == "primitive_antler_pick": tool_grip = Vector3(0, 0.72, 0)
	# Empty inventories need no per-frame modifier; pickup explicitly refreshes it.
	active = held_tool != null
	if held_tool == null: return
	stowed = actor.carried_total() > 0 or (not actor.kneeling_context.is_empty() and not actor.kneeling_context.begins_with("build:"))
	var attachment := stow_attachment if stowed else hand_attachment
	if held_tool.get_parent() != attachment: held_tool.reparent(attachment, false)
	var inherited_scale := get_skeleton().global_basis.get_scale().x
	var scale_ratio := game_scale / inherited_scale
	var orientation := Basis(Vector3.BACK, -0.65) if stowed else HAND_BASIS
	# Axe cutting edge is authored on +X. Roll around the haft, keeping the
	# same grip and head position, so the bit faces down in the carry pose.
	if not stowed and selected.begins_with("primitive_stone_axe"):
		orientation = orientation * Basis(Vector3.UP, PI)
	var contact := Vector3(0, 0.02, -0.28) if stowed else HAND_CONTACT
	var basis := orientation.scaled(Vector3.ONE * scale_ratio)
	held_tool.transform = Transform3D(basis, contact - basis * tool_grip)
	held_tool.visible = actor.unit_data.is_alive()

func _process_modification_with_delta(_delta: float) -> void:
	refresh_inventory()
	if held_tool == null or not held_tool.visible or stowed: return
	var skeleton := get_skeleton()
	for index in range(_grip_bones.size()):
		skeleton.set_bone_pose_rotation(_grip_bones[index], _grip_rotations[index])
