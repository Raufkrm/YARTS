extends "res://scripts/tools/matchlock_human_drill.gd"
## Viewer adapter: original musket handling clips, deterministic inspection clock.
const Catalog = preload("res://scripts/tools/unit_animation_catalog.gd")
const Combat = preload("res://scripts/data/musket_combat_state.gd")
const PHASE_NAMES := ["Recover", "Supplies", "Powder", "Shot", "Draw rod", "Ram", "Return rod", "Prime / cap", "Shoulder"]
const PHASE_STARTS := [0.0,4.0,6.0,9.5,12.0,15.0,19.0,22.0,24.5]
var durations := {"Reload":28.5,"Carry":2.0,"Walk":1.0,"Jog":1.0,"Aim":6.0,"Fire":10.0,"Fit bayonet":20.0,"Remove bayonet":20.0,"Combat loop":120.0,"Move":60.0}
var gait_clips: Dictionary = {}
var rest_positions: Array[Vector3] = []
var state_text := ""
var fire_start := 2.0
var release_time := 2.6
var bayonet := false
var move_origin: Dictionary = {}
var sequence_snapshot: Dictionary = {}
var finished := false
var shot_age := -1.0
static var _jog_brace_cache: Dictionary = {}
var _jog_brace: Animation

func jog_brace_contact() -> Vector3:
    return held_weapon.to_global(Vector3(0.12,-0.025,-0.035) * held_weapon.asset_scale())

func _prepare_jog_brace() -> void:
    var key := weapon_id + str(female) + str(held_weapon.asset_scale())
    if _jog_brace_cache.has(key):
        _jog_brace = _jog_brace_cache[key]
        return
    var clip := Animation.new()
    clip.length = durations.Jog; clip.loop_mode = Animation.LOOP_LINEAR
    var bones: Array[int] = []
    for bone in range(skeleton.get_bone_count()):
        var name := str(skeleton.get_bone_name(bone))
        if name.ends_with("_r") and (name.begins_with("upperarm") or name.begins_with("lowerarm") or name.begins_with("hand") or name.begins_with("middle") or name.begins_with("thumb")):
            bones.append(bone)
            var track := clip.add_track(Animation.TYPE_ROTATION_3D)
            clip.track_set_path(track,NodePath(name))
    var frames := ceili(clip.length*30.0)
    for frame in range(frames+1):
        var time := clip.length*frame/frames
        show_pose("Jog",0.0 if frame == frames else time)
        _grip_arm("r",to_local(jog_brace_contact()),held_weapon.global_basis.x,Vector3(-0.32,1.0,0.35))
        _curl_fingers("r",0.9)
        for track in range(bones.size()): clip.rotation_track_insert_key(track,time,skeleton.get_bone_pose_rotation(bones[track]))
    _jog_brace_cache[key] = clip
    _jog_brace = clip
    show_pose("Carry",0)


func configure_attachment(attached: bool) -> void:
    bayonet = attached
    set_bayonet(attached)
    durations.Reload = 38.1 if attached and weapon_id != "matchlock_arquebus" else 28.5
    durations["Fit bayonet"] = 20.0 if weapon_id == "matchlock_arquebus" else 0.01
    durations["Remove bayonet"] = durations["Fit bayonet"]

func reload_state():
    var state := MatchReload.new()
    state.socket_attached = bayonet and weapon_id != "matchlock_arquebus"
    state.set_plug_attached(bayonet and weapon_id == "matchlock_arquebus")
    return state

func phase_starts() -> Array:
    var starts := []
    var total := 0.0
    var state = reload_state()
    for phase in MatchReload.PHASES:
        starts.append(total)
        state.phase_id = phase
        total += state.phase_duration()
    return starts


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
    _prepare_jog_brace()

func show_pose(mode: String, time: float) -> void:
    for bone in range(skeleton.get_bone_count()): skeleton.set_bone_pose_position(bone, rest_positions[bone])
    finished = false
    shot_age = -1.0
    set_bayonet(bayonet)
    if mode in ["Fit bayonet", "Remove bayonet"]:
        if weapon_id == "matchlock_arquebus": update_bayonet_pose(mode == "Remove bayonet", time)
        else:
            update_pose(null)
            set_bayonet(mode == "Fit bayonet")
        current_phase = mode
        state_text = "Plug bayonet" if weapon_id == "matchlock_arquebus" else "Socket bayonet"
        return
    if mode in ["Combat loop", "Move"]:
        var sequence := Combat.new()
        if mode == "Move" and not move_origin.is_empty(): sequence.load_from_dict(move_origin)
        else:
            sequence.reload = reload_state()
            sequence.reload.available_ammo = 100000
            sequence.start_combat(true)
        # Reconstruct from zero for deterministic seeking, including the last shot age.
        var remaining := time
        var age := -1.0
        while remaining > 0.00001:
            var step := minf(remaining, 0.05)
            sequence.advance(step)
            if age >= 0: age += step
            if not sequence.take_shots().is_empty(): age = maxf(0,sequence.elapsed-0.6)
            remaining -= step
        update_combat_pose(sequence)
        sequence_snapshot = sequence.to_dict()
        current_phase = sequence.phase_label()
        state_text = "Loaded" if sequence.reload.ready_to_aim() else "Reloading / empty"
        shot_age = age
        finished = mode == "Move" and sequence.mode == "carry"
        return
    if mode == "Reload":
        var state = reload_state()
        state.start_reload(); state.advance(clampf(time,0,float(durations.Reload)))
        update_pose(state)
        current_phase = "Place cap" if weapon_id == "caplock_musket" and state.phase_id == "ML_R08" else state.phase_label()
        state_text = "Loaded" if state.ready_to_aim() else "Reloading"
    elif mode in ["Aim","Fire"]:
        var sequence := Combat.new()
        var sample := clampf(time,0,float(durations[mode]))
        sequence.mode = "raise" if sample < 2 else "aim"
        sequence.elapsed = sample
        if mode == "Aim":
            if sample < 4:
                var state = reload_state()
                state.phase_id = "ML_R00"; state.phase_elapsed = sample
                update_pose(state)
                current_phase = "Recover to aim"; state_text = "Loaded"
                return
            sequence.mode = "raise" if sample < 6 else "aim"
            sequence.elapsed = sample-4
        if mode == "Fire":
            if sample >= 6: sequence.mode = "return"; sequence.elapsed = sample-6
            elif sample >= 4: sequence.mode = "lower"; sequence.elapsed = sample-4
            elif sample >= 2: sequence.mode = "fire"; sequence.elapsed = sample-2
        update_combat_pose(sequence)
        if mode == "Fire" and sample >= 2.6: shot_age = sample-2.6
        current_phase = sequence.phase_label()
        state_text = "Fired" if mode == "Fire" and sample >= 2.6 else "Loaded preview"
    else:
        update_pose(null)
        current_phase = mode; state_text = "Shouldered carry"
        if mode in ["Walk","Jog"]: _gait(mode, fposmod(time,float(durations[mode])))

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
    if mode == "Jog" and _jog_brace != null:
        for track in range(_jog_brace.get_track_count()):
            var bone := skeleton.find_bone(str(_jog_brace.track_get_path(track)))
            skeleton.set_bone_pose_rotation(bone,_jog_brace.rotation_track_interpolate(track,time))
        skeleton.force_update_all_bone_transforms()
