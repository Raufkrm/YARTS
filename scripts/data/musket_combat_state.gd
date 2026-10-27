class_name MusketCombatState
extends RefCounted
## Simulation owns shots; shared cached animation only displays this timeline.
const Reload = preload("res://scripts/data/matchlock_reload_state.gd")
var reload := Reload.new()
var mode := "carry"
var elapsed := 0.0
var repeat_fire := false
var move_requested := false
var next_shot_id := 0
var shots: Array[int] = []

func start_combat(repeat: bool = true) -> void:
	repeat_fire = repeat
	move_requested = false
	reload.combat_reload = true
	if mode != "carry" and mode != "aim": return
	if mode == "aim":
		mode = "fire" if reload.ready_to_aim() else "lower"
	else:
		if mode == "carry": reload.recovered = false
		reload.start_reload()
		mode = "reload" if reload.active else "raise" if reload.ready_to_aim() else "carry"
	elapsed = 0

func request_move() -> void:
	repeat_fire = false
	move_requested = true
	if mode == "carry": return
	if mode == "reload":
		# Finish safe tool handling, then shoulder; never fire after a move order.
		reload.combat_reload = false
		return
	if mode == "raise":
		mode = "lower"
		elapsed = 2.0-elapsed
	elif mode not in ["return", "lower"]:
		mode = "lower"
		elapsed = 0

func advance(delta: float) -> void:
	var remaining := maxf(delta, 0)
	while remaining > 0.000001:
		if mode in ["carry", "aim"]: break
		if mode == "reload":
			if not reload.active:
				mode = "carry" if move_requested or not reload.ready_to_aim() else "raise"
				elapsed = 0
				continue
			var step := minf(remaining, reload.phase_duration()-reload.phase_elapsed)
			reload.advance(step)
			remaining -= step
			continue
		var duration := 4.0 if mode == "return" else 2.0
		var before := elapsed
		var step := minf(remaining, duration-elapsed)
		elapsed += step
		remaining -= step
		if mode == "fire" and before < 0.6 and elapsed >= 0.6:
			reload.cover_open = true
			if reload.commit_shot(next_shot_id):
				shots.append(next_shot_id)
				next_shot_id += 1
		if elapsed + 0.000001 < duration: continue
		elapsed = 0
		match mode:
			"raise": mode = "lower" if move_requested else "fire"
			"fire": mode = "lower" if repeat_fire or move_requested else "aim"
			"lower":
				if move_requested: mode = "return"
				else:
					reload.recovered = true
					reload.carry_recovered = false
					reload.combat_reload = true
					reload.start_reload()
					mode = "reload" if reload.active else "aim"
			"return":
				reload.interrupt_for_movement()
				mode = "carry"

func take_shots() -> Array[int]:
	var result := shots.duplicate()
	shots.clear()
	return result

func phase_label() -> String:
	if mode == "reload": return reload.phase_label()
	return {"carry":"Carry", "raise":"Raise to aim", "aim":"Aim", "fire":"Fire and recover", "lower":"Lower for movement" if move_requested else "Lower to reload", "return":"Shoulder"}.get(mode, mode)

func to_dict() -> Dictionary:
	return {"reload":reload.to_dict(), "mode":mode, "elapsed":elapsed, "repeat_fire":repeat_fire, "move_requested":move_requested, "next_shot_id":next_shot_id}

func load_from_dict(data: Dictionary) -> void:
	reload.load_from_dict(data.get("reload",{}))
	mode = str(data.get("mode","carry"))
	if mode not in ["carry","reload","raise","fire","lower","return","aim"]: mode = "carry"
	elapsed = clampf(float(data.get("elapsed",0)),0,4.0 if mode == "return" else 2.0)
	repeat_fire = bool(data.get("repeat_fire",false))
	move_requested = bool(data.get("move_requested",false))
	next_shot_id = maxi(reload.last_shot_id+1,int(data.get("next_shot_id",0)))
	shots.clear()
