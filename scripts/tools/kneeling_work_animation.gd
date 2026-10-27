extends RefCounted

# UAL1 Fixing_Kneeling: settle by frame 30, start rising at frame 123 (30 Hz).
const ENTER_END := 1.0
const EXIT_START := 4.1
const LOOP_BLEND := 0.18

static func preserve_vertical_motion(clip: Animation, source: Animation, source_skeleton: Skeleton3D, target: Skeleton3D, path: NodePath) -> void:
	var source_bone := source_skeleton.find_bone("pelvis")
	if source_bone < 0: source_bone = source_skeleton.find_bone("mixamorig_Hips")
	var target_bone := target.find_bone("pelvis")
	if target_bone < 0 or source_bone < 0: return
	var source_track := -1
	for track in range(source.get_track_count()):
		if source.track_get_type(track) == Animation.TYPE_POSITION_3D and str(source.track_get_path(track)).get_slice(":", 1) == str(source_skeleton.get_bone_name(source_bone)):
			source_track = track
	if source_track < 0: return
	var source_parent := source_skeleton.get_bone_parent(source_bone)
	var target_parent := target.get_bone_parent(target_bone)
	var source_basis := source_skeleton.get_bone_global_rest(source_parent).basis if source_parent >= 0 else Basis.IDENTITY
	var target_basis := target.get_bone_global_rest(target_parent).basis if target_parent >= 0 else Basis.IDENTITY
	var source_rest := source_skeleton.get_bone_rest(source_bone).origin
	var target_rest := target.get_bone_rest(target_bone).origin
	var source_height := source_skeleton.get_bone_global_rest(source_bone).origin.y
	var target_height := target.get_bone_global_rest(target_bone).origin.y
	var scale := target_height / maxf(0.001, source_height)
	var track := clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(track, NodePath("%s:pelvis" % path))
	for frame in range(ceili(clip.length * 30.0) + 1):
		var time := minf(frame / 30.0, clip.length)
		var delta := source_basis * (source.position_track_interpolate(source_track, time) - source_rest)
		# Keep height changes, but never import horizontal root travel into an RTS actor.
		clip.position_track_insert_key(track, time, target_rest + target_basis.inverse() * Vector3(0, delta.y * scale, 0))

static func add_phases(library: AnimationLibrary, names: Array) -> void:
	if not library.has_animation("Fixing_Kneeling"): return
	var source := library.get_animation("Fixing_Kneeling")
	var phases := {
		"Kneel_Enter": slice(source, 0.0, ENTER_END),
		"Kneel_Work": slice(source, ENTER_END, EXIT_START, true),
		"Kneel_Exit": slice(source, EXIT_START, source.length),
		# A single ground reach followed by standing, available in the preview.
		"Kneel_Pickup": join(slice(source, 0.0, 1.6), slice(source, EXIT_START, source.length)),
	}
	for name in phases:
		library.add_animation(name, phases[name])
		names.append(name)

static func slice(source: Animation, start: float, end: float, looping: bool = false) -> Animation:
	var clip := Animation.new()
	clip.length = end - start
	clip.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
	for source_track in range(source.get_track_count()):
		var type := source.track_get_type(source_track)
		if type not in [Animation.TYPE_ROTATION_3D, Animation.TYPE_POSITION_3D]: continue
		var track := clip.add_track(type)
		clip.track_set_path(track, source.track_get_path(source_track))
		for frame in range(ceili(clip.length * 30.0) + 1):
			var time := minf(frame / 30.0, clip.length)
			var weight := clampf((time - (clip.length - LOOP_BLEND)) / LOOP_BLEND, 0, 1) if looping else 0.0
			if type == Animation.TYPE_ROTATION_3D:
				var value := source.rotation_track_interpolate(source_track, start + time)
				value = value.slerp(source.rotation_track_interpolate(source_track, start), weight)
				clip.rotation_track_insert_key(track, time, value)
			else:
				var value := source.position_track_interpolate(source_track, start + time)
				value = value.lerp(source.position_track_interpolate(source_track, start), weight)
				clip.position_track_insert_key(track, time, value)
	return clip

static func join(first: Animation, second: Animation) -> Animation:
	var clip := first.duplicate(true) as Animation
	clip.length = first.length + second.length
	for track in range(second.get_track_count()):
		for frame in range(ceili(second.length * 30.0) + 1):
			var time := minf(frame / 30.0, second.length)
			var weight := smoothstep(0.0, LOOP_BLEND, time)
			if second.track_get_type(track) == Animation.TYPE_ROTATION_3D:
				var value := first.rotation_track_interpolate(track, first.length).slerp(second.rotation_track_interpolate(track, time), weight)
				clip.rotation_track_insert_key(track, first.length + time, value)
			else:
				var value := first.position_track_interpolate(track, first.length).lerp(second.position_track_interpolate(track, time), weight)
				clip.position_track_insert_key(track, first.length + time, value)
	return clip
