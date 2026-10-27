extends "res://scripts/tools/handgonne_human_drill.gd"
const Catalog = preload("res://scripts/tools/unit_animation_catalog.gd")
const PHASE_NAMES := ["Recover","Supplies","Powder","Shot","Draw rod","Ram","Return rod","Prime","Carry"]
var durations := {"Reload":27.0,"Carry":2.0,"Walk":1.0,"Jog":1.0,"Aim":2.0,"Fire":8.0,"Prime only":9.0,"Load barrel":24.0,"Combat loop":120.0,"Move":0.01,"Fit bayonet":0.01,"Remove bayonet":0.01}
var fire_start := 2.0
var release_time := 4.5
var bayonet := false
var gait_clips: Dictionary = {}
var rest_positions: Array[Vector3] = []
var state_text := ""
var shot_age := -1.0
var finished := false
var sequence_snapshot: Dictionary = {}
var move_origin: Dictionary = {}
func configure_attachment(_attached: bool): pass
func set_bayonet(_attached: bool): pass
func phase_starts() -> Array: return [0.0,2.0,2.8,6.0,9.0,12.0,17.0,20.0,23.0]
func _ready() -> void:
    super._ready()
    for mesh in human.find_children("*", "MeshInstance3D", true, false):
        mesh.material_override.albedo_color = Color("7d8980")
    for bone in range(skeleton.get_bone_count()): rest_positions.append(skeleton.get_bone_pose_position(bone))
    var source = load("res://assets/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb").instantiate()
    var player = Catalog.find_first_animation_player(source)
    var rig = Catalog.find_first_skeleton(source)
    for pair in [["Walk","Walk"],["Jog","Jog_Fwd"]]:
        var clip: Animation = Catalog.retarget_animation(player.get_animation(pair[1]), pair[1], rig, skeleton, get_path_to(skeleton))
        Catalog.Kneeling.preserve_vertical_motion(clip, player.get_animation(pair[1]), rig, skeleton, get_path_to(skeleton))
        gait_clips[pair[0]] = clip
        durations[pair[0]] = clip.length
    source.free()

func show_pose(mode: String, time: float) -> void:
    for bone in range(skeleton.get_bone_count()): skeleton.set_bone_pose_position(bone,rest_positions[bone])
    shot_age = -1.0
    finished = false
    if mode == "Combat loop":
        var sample := fposmod(time,35.0)
        show_pose("Reload" if sample < 27 else "Fire",sample if sample < 27 else sample-27)
        return
    if mode in ["Reload","Prime only","Load barrel"]:
        var state := Reload.new(100)
        state.start_reload(Reload.GOAL_PRIME if mode == "Prime only" else Reload.GOAL_LOAD if mode == "Load barrel" else Reload.GOAL_READY)
        state.advance(time)
        update_pose(state)
        current_phase = state.phase_label()
        state_text = "Loaded" if state.can_fire() else "Reloading / partial load"
        finished = not state.active
    elif mode in ["Aim","Fire"]:
        update_firing_pose(minf(time,2.0) if mode == "Aim" else time)
        var fire := Fire.new(); fire.elapsed = time
        current_phase = "Aim" if mode == "Aim" and time >= 2 else fire.phase_label()
        state_text = "Fired" if mode == "Fire" and time >= release_time else "Loaded preview"
        if mode == "Fire" and time >= release_time: shot_age = time-release_time
    else:
        update_pose(null)
        current_phase = mode; state_text = "Carry"
        finished = mode == "Move"
        if mode in ["Walk","Jog"]: _gait(mode,fposmod(time,float(durations[mode])))
func _gait(mode: String, time: float) -> void:
    var hand := skeleton.find_bone("hand_l")
    var before := skeleton.global_transform * skeleton.get_bone_global_pose(hand)
    var clip: Animation = gait_clips[mode]
    for track in range(clip.get_track_count()):
        var name := str(clip.track_get_path(track)).get_slice(":",1)
        var bone := skeleton.find_bone(name)
        if bone < 0: continue
        var leg := name.begins_with("thigh_") or name.begins_with("calf_") or name.begins_with("foot_") or name.begins_with("ball_")
        var torso := name in ["spine_01","spine_02","spine_03","neck_01","Head"]
        if not (leg or torso or name == "pelvis"): continue
        if clip.track_get_type(track) == Animation.TYPE_POSITION_3D:
            skeleton.set_bone_pose_position(bone,clip.position_track_interpolate(track,time))
        elif clip.track_get_type(track) == Animation.TYPE_ROTATION_3D:
            var q := clip.rotation_track_interpolate(track,time)
            if torso: q = _rest_rotations[bone].slerp(q,0.35 if mode == "Jog" else 0.55)
            skeleton.set_bone_pose_rotation(bone,q)
    skeleton.force_update_all_bone_transforms()
    # The shoulder carry stays rigidly in the supporting hand; no per-frame IK.
    var after := skeleton.global_transform * skeleton.get_bone_global_pose(hand)
    held_weapon.global_transform = after * before.affine_inverse() * held_weapon.global_transform
