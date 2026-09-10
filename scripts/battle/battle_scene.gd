extends Node3D

class HudMapPreview:
	extends Control

	var preview_mode := "minimap"
	var map_texture: Texture2D
	var camera_map_position := Vector2(0.5, 0.5)
	var camera_forward := Vector2(0.0, -1.0)
	var camera_fov_degrees := 50.0
	var camera_view_distance_ratio := 0.26
	var friendly_points := PackedVector2Array()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		if preview_mode == "world":
			_draw_world_preview(rect)
		else:
			_draw_minimap_preview(rect)

	func _draw_world_preview(rect: Rect2) -> void:
		var center := rect.size * 0.5
		var radius: float = min(rect.size.x, rect.size.y) * 0.36
		draw_circle(center, radius, Color(0.04, 0.07, 0.09, 0.92))
		draw_arc(center, radius, 0.0, TAU, 64, Color(0.65, 0.82, 0.92, 0.95), 2.0)
		for index in range(1, 4):
			var offset: float = lerpf(-radius * 0.62, radius * 0.62, float(index) / 4.0)
			var half_width: float = sqrt(max(radius * radius - offset * offset, 0.0))
			draw_line(center + Vector2(-half_width, offset), center + Vector2(half_width, offset), Color(0.35, 0.55, 0.66, 0.70), 1.0)
			draw_line(center + Vector2(offset, -half_width), center + Vector2(offset, half_width), Color(0.35, 0.55, 0.66, 0.70), 1.0)
		var land_color := Color(0.18, 0.48, 0.25, 0.95)
		var coast_color := Color(0.73, 0.64, 0.39, 0.95)
		draw_polyline(PackedVector2Array([
			center + Vector2(-radius * 0.55, -radius * 0.10),
			center + Vector2(-radius * 0.28, -radius * 0.32),
			center + Vector2(radius * 0.06, -radius * 0.22),
			center + Vector2(radius * 0.22, radius * 0.03),
			center + Vector2(-radius * 0.02, radius * 0.24),
			center + Vector2(-radius * 0.46, radius * 0.22),
			center + Vector2(-radius * 0.55, -radius * 0.10),
		]), land_color, 8.0, true)
		draw_polyline(PackedVector2Array([
			center + Vector2(radius * 0.20, -radius * 0.38),
			center + Vector2(radius * 0.55, -radius * 0.18),
			center + Vector2(radius * 0.48, radius * 0.18),
			center + Vector2(radius * 0.18, radius * 0.34),
		]), coast_color, 6.0, true)

	func _draw_minimap_preview(rect: Rect2) -> void:
		var map_rect := _minimap_map_rect(rect)
		draw_rect(rect, Color(0.012, 0.018, 0.020, 0.88), true)
		if map_texture != null:
			draw_texture_rect(map_texture, map_rect, false)
		else:
			draw_rect(map_rect, Color(0.025, 0.040, 0.045, 0.88), true)
		_draw_minimap_grid(map_rect)
		_draw_camera_cone(map_rect)
		_draw_friendly_units(map_rect)
		draw_rect(map_rect, Color(0.85, 0.93, 1.0, 0.42), false, 1.0)

	func _minimap_map_rect(rect: Rect2) -> Rect2:
		var side: float = min(rect.size.x, rect.size.y)
		var top_left := rect.position + (rect.size - Vector2(side, side)) * 0.5
		return Rect2(top_left, Vector2(side, side))

	func _draw_minimap_grid(map_rect: Rect2) -> void:
		var grid_color := Color(0.88, 0.94, 0.86, 0.14)
		for index in range(1, 5):
			var t: float = float(index) / 5.0
			var x: float = lerpf(map_rect.position.x, map_rect.end.x, t)
			var y: float = lerpf(map_rect.position.y, map_rect.end.y, t)
			draw_line(Vector2(x, map_rect.position.y), Vector2(x, map_rect.end.y), grid_color, 1.0)
			draw_line(Vector2(map_rect.position.x, y), Vector2(map_rect.end.x, y), grid_color, 1.0)

	func _draw_camera_cone(map_rect: Rect2) -> void:
		var origin := _map_to_draw_position(camera_map_position, map_rect)
		var forward := camera_forward
		if forward.length_squared() <= 0.001:
			forward = Vector2(0.0, -1.0)
		forward = forward.normalized()
		var distance: float = map_rect.size.x * clamp(camera_view_distance_ratio, 0.10, 0.54)
		var half_angle: float = deg_to_rad(camera_fov_degrees * 0.5)
		var left := origin + forward.rotated(-half_angle) * distance
		var right := origin + forward.rotated(half_angle) * distance
		var cone := PackedVector2Array([origin, left, right])
		draw_colored_polygon(cone, Color(1.0, 0.95, 0.42, 0.18))
		draw_polyline(PackedVector2Array([origin, left, right, origin]), Color(1.0, 0.94, 0.48, 0.56), 1.0, true)
		draw_circle(origin, 3.0, Color(1.0, 0.96, 0.52, 0.95))

	func _draw_friendly_units(map_rect: Rect2) -> void:
		for point in friendly_points:
			var draw_position := _map_to_draw_position(point, map_rect)
			draw_circle(draw_position, 2.6, Color(0.58, 0.92, 1.0, 0.95))
			draw_circle(draw_position, 4.2, Color(0.25, 0.68, 1.0, 0.18))

	func _map_to_draw_position(normalized_position: Vector2, map_rect: Rect2) -> Vector2:
		return Vector2(
			lerpf(map_rect.position.x, map_rect.end.x, clamp(normalized_position.x, 0.0, 1.0)),
			lerpf(map_rect.position.y, map_rect.end.y, clamp(normalized_position.y, 0.0, 1.0))
		)

class DragSelectionOverlay:
	extends Control

	var dragging := false
	var start_position := Vector2.ZERO
	var end_position := Vector2.ZERO

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if not dragging:
			return

		var rect := _rect_from_points(start_position, end_position)
		if rect.size.x < 4.0 or rect.size.y < 4.0:
			return

		draw_rect(rect, Color(0.30, 0.66, 1.0, 0.12), true)
		draw_rect(rect, Color(0.62, 0.88, 1.0, 0.88), false, 2.0)

	func _rect_from_points(a: Vector2, b: Vector2) -> Rect2:
		var top_left := Vector2(min(a.x, b.x), min(a.y, b.y))
		var bottom_right := Vector2(max(a.x, b.x), max(a.y, b.y))
		return Rect2(top_left, bottom_right - top_left)

class HudStatText:
	extends RichTextLabel

	signal stat_hover_started(stat_key: String)
	signal stat_hover_ended

	func _ready() -> void:
		bbcode_enabled = true
		fit_content = true
		scroll_active = false
		meta_underlined = false
		add_theme_color_override("font_link_color", Color.WHITE)
		add_theme_color_override("font_hovered_color", Color(0.80, 1.0, 0.84))
		meta_hover_started.connect(_on_meta_hover_started)
		meta_hover_ended.connect(_on_meta_hover_ended)

	func _on_meta_hover_started(meta) -> void:
		var value := str(meta)
		if value.begins_with("stat:"):
			stat_hover_started.emit(value.trim_prefix("stat:"))

	func _on_meta_hover_ended(_meta) -> void:
		stat_hover_ended.emit()

const MAP_SIZE := 4000.0
const GRID_STEP := 100.0
const TERRAIN_STEPS := 192
const RTS_CACHE_VERSION := 52
const MINIMAP_TEXTURE_SIZE := 160
const WORLD_GLOBE_VIEWPORT_SIZE := Vector2i(208, 138)
const WORLD_GLOBE_TEXTURE_SIZE := Vector2i(256, 128)
const WORLD_GLOBE_UPDATE_INTERVAL := 0.35
const WORLD_GLOBE_TEXTURE_VERSION := 1
const WORLD_GLOBE_RADIUS := 1.0
const WORLD_GLOBE_GRID_RADIUS := 1.006
const WORLD_GLOBE_OUTLINE_RADIUS := 1.014
const WORLD_GLOBE_CAMERA_DISTANCE := 2.45
const WORLD_GLOBE_LONGITUDE_SEGMENTS := 48
const WORLD_GLOBE_LATITUDE_SEGMENTS := 24
const MOON_LIGHT_COLOR := Color(0.43, 0.56, 0.84)
const MOON_LIGHT_MAX_ENERGY := 0.75
const TREE_SAMPLE_COUNT := 96000
const DETAIL_PROP_SAMPLE_COUNT := 1800
const OPEN_GROUND_PROP_SAMPLE_COUNT := 14000
const PROP_EDGE_INSET := 12.0
const WATER_PLANE_STEPS := TERRAIN_STEPS * 2
const RIVER_SURFACE_STEPS := TERRAIN_STEPS * 3
const RIVER_MESH_EDGE_ALPHA := 0.08
const RIVER_MASK_STEPS := TERRAIN_STEPS * 2
const RIVER_SMOOTH_RADIUS := 3
const UNIT_HEIGHT := 1.65
const UNIT_VISUAL_SCALE := 5.0
const UNIT_VISUAL_HEIGHT := UNIT_HEIGHT * UNIT_VISUAL_SCALE
const UNIT_BODY_HEIGHT := 1.35
const UNIT_HEAD_RADIUS := 0.15
const UNIT_MODEL_MALE := "res://assets/reference_models/base_low_poly_male_reference_ual_rigged.glb"
const UNIT_MODEL_FEMALE := "res://assets/reference_models/base_low_poly_female_reference_ual_rigged.glb"
const UNIT_ANIMATION_REFERENCE_MODEL := UNIT_MODEL_MALE
const UNIT_ANIMATION_PACKS := [
	{
		"label": "UAL1",
		"path": "res://assets/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb",
	},
	{
		"label": "UAL2",
		"path": "res://assets/Universal Animation Library 2[Standard]/Unreal-Godot/UAL2_Standard.glb",
	},
	{
		"label": "Mixamo Carry Idle",
		"path": "res://assets/animations/mixamo/carrying/Carrying.fbx",
		"animation_name": "Mixamo_Carry_Idle",
		"loop": true,
	},
	{
		"label": "Mixamo Carry Walk",
		"path": "res://assets/animations/mixamo/carrying/Walking.fbx",
		"animation_name": "Mixamo_Carry_Walk",
		"loop": true,
	},
	{
		"label": "Mixamo Carry Run",
		"path": "res://assets/animations/mixamo/carrying/Running.fbx",
		"animation_name": "Mixamo_Carry_Run",
		"loop": true,
	},
	{
		"label": "Mixamo Carry Stop",
		"path": "res://assets/animations/mixamo/carrying/Walk To Stop.fbx",
		"animation_name": "Mixamo_Carry_Stop",
		"loop": false,
		"trim_tail": 1.25,
	},
	{
		"label": "Mixamo Swimming",
		"path": "res://assets/animations/mixamo/swimming/Swimming.fbx",
		"animation_name": "Mixamo_Swimming",
		"loop": true,
	},
	{
		"label": "Mixamo Treading Water",
		"path": "res://assets/animations/mixamo/swimming/Treading Water.fbx",
		"animation_name": "Mixamo_Treading_Water",
		"loop": true,
	},
]
const UNIT_DEFAULT_ANIMATION := "Idle"
const HUD_MISSING_ICON := "■"
const HUD_ICON_ROOT := "res://assets/sprites/ui/hud/"
const HUD_INLINE_ICON_SIZE := 14
const HUD_TOOLTIP_EXPAND_SECONDS := 4.0
const UnitManagerScript = preload("res://scripts/managers/unit_manager.gd")
const RTSUnitMoveOrderScript = preload("res://scripts/battle/rts_unit_move_order.gd")
const RTSUnitActorScript = preload("res://scripts/battle/rts_unit_actor.gd")
const RTSUnitGatherActionScript = preload("res://scripts/battle/rts_unit_gather_action.gd")
const RTSUnitDeliveryActionScript = preload("res://scripts/battle/rts_unit_delivery_action.gd")
const RTSResourceNodeScript = preload("res://scripts/battle/rts_resource_node.gd")
const RTSBuildingDataScript = preload("res://scripts/data/rts_building_data.gd")
const UnitAnimationCatalogScript = preload("res://scripts/tools/unit_animation_catalog.gd")
const UNIT_ANIMATION_BONE_MAP := {
	"pelvis": "Hips",
	"spine_01": "Spine",
	"spine_02": "Spine",
	"spine_03": "Chest",
	"neck_01": "Neck",
	"Head": "Head",
	"clavicle_l": "Shoulder.L",
	"upperarm_l": "UpperArm.L",
	"lowerarm_l": "LowerArm.L",
	"hand_l": "Hand.L",
	"thumb_01_l": "Thumb.L",
	"clavicle_r": "Shoulder.R",
	"upperarm_r": "UpperArm.R",
	"lowerarm_r": "LowerArm.R",
	"hand_r": "Hand.R",
	"thumb_01_r": "Thumb.R",
	"thigh_l": "UpperLeg.L",
	"calf_l": "LowerLeg.L",
	"foot_l": "Foot.L",
	"thigh_r": "UpperLeg.R",
	"calf_r": "LowerLeg.R",
	"foot_r": "Foot.R",
	"mixamorig_Hips": "pelvis",
	"mixamorig_Spine": "spine_01",
	"mixamorig_Spine1": "spine_02",
	"mixamorig_Spine2": "spine_03",
	"mixamorig_Neck": "neck_01",
	"mixamorig_Head": "Head",
	"mixamorig_LeftShoulder": "clavicle_l",
	"mixamorig_LeftArm": "upperarm_l",
	"mixamorig_LeftForeArm": "lowerarm_l",
	"mixamorig_LeftHand": "hand_l",
	"mixamorig_LeftHandThumb1": "thumb_01_l",
	"mixamorig_LeftHandThumb2": "thumb_02_l",
	"mixamorig_LeftHandThumb3": "thumb_03_l",
	"mixamorig_LeftHandThumb4": "thumb_04_leaf_l",
	"mixamorig_LeftHandIndex1": "index_01_l",
	"mixamorig_LeftHandIndex2": "index_02_l",
	"mixamorig_LeftHandIndex3": "index_03_l",
	"mixamorig_LeftHandIndex4": "index_04_leaf_l",
	"mixamorig_LeftHandMiddle1": "middle_01_l",
	"mixamorig_LeftHandMiddle2": "middle_02_l",
	"mixamorig_LeftHandMiddle3": "middle_03_l",
	"mixamorig_LeftHandMiddle4": "middle_04_leaf_l",
	"mixamorig_LeftHandRing1": "ring_01_l",
	"mixamorig_LeftHandRing2": "ring_02_l",
	"mixamorig_LeftHandRing3": "ring_03_l",
	"mixamorig_LeftHandRing4": "ring_04_leaf_l",
	"mixamorig_LeftHandPinky1": "pinky_01_l",
	"mixamorig_LeftHandPinky2": "pinky_02_l",
	"mixamorig_LeftHandPinky3": "pinky_03_l",
	"mixamorig_LeftHandPinky4": "pinky_04_leaf_l",
	"mixamorig_RightShoulder": "clavicle_r",
	"mixamorig_RightArm": "upperarm_r",
	"mixamorig_RightForeArm": "lowerarm_r",
	"mixamorig_RightHand": "hand_r",
	"mixamorig_RightHandThumb1": "thumb_01_r",
	"mixamorig_RightHandThumb2": "thumb_02_r",
	"mixamorig_RightHandThumb3": "thumb_03_r",
	"mixamorig_RightHandThumb4": "thumb_04_leaf_r",
	"mixamorig_RightHandIndex1": "index_01_r",
	"mixamorig_RightHandIndex2": "index_02_r",
	"mixamorig_RightHandIndex3": "index_03_r",
	"mixamorig_RightHandIndex4": "index_04_leaf_r",
	"mixamorig_RightHandMiddle1": "middle_01_r",
	"mixamorig_RightHandMiddle2": "middle_02_r",
	"mixamorig_RightHandMiddle3": "middle_03_r",
	"mixamorig_RightHandMiddle4": "middle_04_leaf_r",
	"mixamorig_RightHandRing1": "ring_01_r",
	"mixamorig_RightHandRing2": "ring_02_r",
	"mixamorig_RightHandRing3": "ring_03_r",
	"mixamorig_RightHandRing4": "ring_04_leaf_r",
	"mixamorig_RightHandPinky1": "pinky_01_r",
	"mixamorig_RightHandPinky2": "pinky_02_r",
	"mixamorig_RightHandPinky3": "pinky_03_r",
	"mixamorig_RightHandPinky4": "pinky_04_leaf_r",
	"mixamorig_LeftUpLeg": "thigh_l",
	"mixamorig_LeftLeg": "calf_l",
	"mixamorig_LeftFoot": "foot_l",
	"mixamorig_LeftToeBase": "ball_l",
	"mixamorig_LeftToe_End": "ball_leaf_l",
	"mixamorig_RightUpLeg": "thigh_r",
	"mixamorig_RightLeg": "calf_r",
	"mixamorig_RightFoot": "foot_r",
	"mixamorig_RightToeBase": "ball_r",
	"mixamorig_RightToe_End": "ball_leaf_r",
}
const UNIT_ANIMATION_BONE_STRENGTH := {
	"Shoulder.L": 0.35,
	"Shoulder.R": 0.35,
	"UpperArm.L": 0.25,
	"UpperArm.R": 0.25,
	"LowerArm.L": 0.55,
	"LowerArm.R": 0.55,
	"Hand.L": 0.42,
	"Hand.R": 0.42,
	"Thumb.L": 0.18,
	"Thumb.R": 0.18,
}
const UNIT_ANIMATION_RELAXED_ARM_BONES := {
	"Shoulder.L": true,
	"Shoulder.R": true,
	"UpperArm.L": true,
	"UpperArm.R": true,
	"LowerArm.L": true,
	"LowerArm.R": true,
	"Hand.L": true,
	"Hand.R": true,
	"Thumb.L": true,
	"Thumb.R": true,
}
const UNIT_UPPER_ARM_RELAX_X := -1.256637
const UNIT_LOWER_ARM_RELAX_X := -0.174533
const UNIT_HAND_RELAX_X := 0.05236
const UNIT_ARM_SWING_WALK := 0.105
const UNIT_ARM_SWING_JOG := 0.14
const UNIT_ARM_SWING_SPRINT := 0.175
const UNIT_ARM_SWING_CROUCH := 0.07
const UNIT_ARM_SWING_KEYS := 8
const MIN_TREE_TO_HUMAN_HEIGHT_RATIO := 10.0
const MAX_TREE_TO_HUMAN_HEIGHT_RATIO := 25.0
const TERRAIN_HEIGHT_SCALE := 38.0
const TERRAIN_SMOOTH_PASSES := 2
const TERRAIN_SMOOTH_BLEND := 0.55
const TERRAIN_BASE_HEIGHT := -1.5
const WATER_SURFACE_HEIGHT := 0.08
const WATER_SHORE_DROOP_DEPTH := 1.10
const WATER_RIVER_MASK_THRESHOLD := 0.10
const RIVER_SURFACE_OFFSET := 0.0
const RIVER_RENDER_EDGE := 0.22
const RIVER_RENDER_FULL := 0.68
const TREE_SHORE_HEIGHT_BUFFER := 0.75
const TREE_RIVER_NO_SPAWN_THRESHOLD := 0.045
const TREE_RIVER_BANK_BUFFER_METERS := 150.0
const TREE_RIVER_NEARBY_THRESHOLD := 0.025
const TREE_SPACING_BUCKET_SIZE := 24.0
const TREE_SPACING_RADIUS_RATIO := 0.15
const TREE_SPACING_RADIUS_MIN := 3.8
const TREE_SPACING_RADIUS_MAX := 9.5
const TREE_SPACING_TOUCH_ALLOWANCE := 0.88
const TREE_FULL_MODEL_MAX := 2200
const TREE_FULL_MODEL_NEAR_RADIUS := 430.0
const TREE_FULL_MODEL_GRID_BUCKET := 95.0
const TREE_IMPOSTORS_ENABLED := false
const TREE_IMPOSTOR_VIEW_MODE := "angle45"
const TREE_IMPOSTOR_SURFACE_OFFSET := 0.08
const TREE_IMPOSTOR_WIDTH_RATIO := 0.95
const TREE_IMPOSTOR_HEIGHT_SCALE := 1.45
const TREE_IMPOSTOR_FULL_LOD_MAX := 2400
const TREE_IMPOSTOR_FULL_LOD_DISABLE_ZOOM := 0.94
const TREE_IMPOSTOR_FULL_LOD_FADE_START_ZOOM := 0.78
const TREE_IMPOSTOR_FULL_LOD_SCREEN_MARGIN := 180.0
const TREE_IMPOSTOR_FULL_LOD_DEPTH_WEIGHT := 0.00025
const TREE_IMPOSTOR_LOD_UPDATE_INTERVAL := 0.28
const DEAD_TREE_FREQUENCY := 25
const TREE_SHADOW_MAX_DISTANCE := 1600.0
const TREE_SHADOW_OPACITY := 0.56
const TREE_SHADOW_BLUR := 2.8
const TREE_SHADOW_BIAS := 0.08
const TREE_SHADOW_NORMAL_BIAS := 1.6
const TREE_GROUND_SHADOW_SURFACE_OFFSET := 0.075
const TREE_GROUND_SHADOW_ALPHA := 0.32
const GRID_SURFACE_OFFSET := 0.16
const CAMERA_PAN_SPEED := 420.0
const CAMERA_FAST_MULTIPLIER := 2.2
const CAMERA_ZOOM_STEP := 70.0
const CAMERA_MIN_HEIGHT := 90.0
const CAMERA_MAX_HEIGHT := 1200.0
const CAMERA_MIN_Z := 120.0
const CAMERA_MAX_Z := 1450.0
const FREE_ROAM_SPEED := 95.0
const FREE_ROAM_FAST_MULTIPLIER := 3.0
const FREE_ROAM_MOUSE_SENSITIVITY := 0.0025
const FREE_ROAM_MIN_PITCH := -1.5
const FREE_ROAM_MAX_PITCH := 1.5
const RTS_MOUSE_YAW_SPEED := 0.006
const UNIT_SELECTION_CLICK_RADIUS := 34.0
const UNIT_SELECTION_DRAG_THRESHOLD := 8.0
const UNIT_SELECTION_RING_RADIUS := 5.8
const UNIT_VISIBILITY_RING_RADIUS := 4.6
const UNIT_MOVE_ARRIVAL_RADIUS := 0.25
const UNIT_MOVE_FORMATION_SPACING := 14.0
const UNIT_MOVE_ORDER_LINE_SAMPLE_STEP := 35.0
const UNIT_MOVE_ORDER_LINE_MAX_SEGMENTS := 72
const UNIT_MOVE_ORDER_LINE_SURFACE_OFFSET := 0.22
const UNIT_MOVE_ORDER_CONE_HEIGHT := 5.2
const UNIT_MOVE_ORDER_CONE_RADIUS := 1.9
const UNIT_MOVE_DOUBLE_CLICK_MAX_MS := 900
const UNIT_MOVE_DOUBLE_CLICK_MAX_DISTANCE := 56.0
const UNIT_SWIM_SUBMERGENCE_RATIO := 0.56
const UNIT_TREAD_WATER_SUBMERGENCE_RATIO := 0.70
const UNIT_WALK_SPEED_MULTIPLIER := 1.5
const UNIT_WALK_ANIMATION_SPEED := 1.5
const UNIT_JOG_SPEED_MULTIPLIER := 3.5
const UNIT_WALK_ANIMATION_CANDIDATES := [
	"Walk",
	"Walk_Fwd",
	"Walking",
]
const UNIT_JOG_ANIMATION_CANDIDATES := [
	"Jog_Fwd",
	"Jog",
	"Run",
	"Sprint",
]
const UNIT_IDLE_ANIMATION_CANDIDATES := [
	"Idle",
	"A_TPose",
]
const UNIT_CHOP_ANIMATION_CANDIDATES := [
	"Chop",
	"Axe",
	"Woodcut",
	"Gather",
	"Attack_1H",
	"Attack",
	"Melee",
]
const UNIT_PICKUP_ANIMATION_CANDIDATES := [
	"Pick_Up",
	"Pickup",
	"PickUp",
	"Interact",
	"Gather",
]
const UNIT_CARRY_IDLE_ANIMATION_CANDIDATES := [
	"Mixamo_Carry_Idle",
	"Carry",
	"Carrying",
	"Carry_Idle",
]
const UNIT_CARRY_WALK_ANIMATION_CANDIDATES := [
	"Mixamo_Carry_Walk",
	"Carry_Fwd",
	"Walk_Carry",
	"Walk",
]
const UNIT_CARRY_RUN_ANIMATION_CANDIDATES := [
	"Mixamo_Carry_Run",
	"Run_Carry",
	"Carry_Run",
]
const UNIT_CARRY_STOP_ANIMATION_CANDIDATES := [
	"Mixamo_Carry_Stop",
	"Carry_Stop",
]
const UNIT_SWIM_ANIMATION_CANDIDATES := ["Mixamo_Swimming", "Swimming", "Swim"]
const UNIT_TREAD_WATER_ANIMATION_CANDIDATES := ["Mixamo_Treading_Water", "Treading_Water", "Treading Water"]
const RESOURCE_SELECTION_CLICK_RADIUS := 46.0
const RESOURCE_RING_SURFACE_OFFSET := 0.18
const TREE_CHOP_RANGE := 11.0
const TREE_CHOPPED_DOWN_THRESHOLD := 3.2
const FELLED_LOG_PROCESS_SECONDS := 2.4
const TREE_FALL_DURATION := 2.15
const TREE_IMPACT_BOUNCE_DURATION := 0.55
const TREE_IMPACT_REBOUND_RADIANS := 0.105
const SPLIT_WOOD_PIECE_COUNT := 5
const TREE_CHOP_YIELD := 5
const TREE_CHOP_WORK_RATE := 1.0
const STORAGE_DELIVERY_RANGE := 10.0
const ROCK_GATHER_RANGE := 9.0
const ROCK_GATHER_WORK_SECONDS := 2.0
const ROCK_GATHER_YIELD := 3
const FLINT_GATHER_YIELD := 1
const STONE_DEPOSIT_AMOUNT := 240
const FLINT_DEPOSIT_AMOUNT := 160
const FOOD_DEPOSIT_AMOUNT := 180
const FISH_DEPOSIT_AMOUNT := 300
const SHALLOW_FISH_DEPOSIT_AMOUNT := 90
const WHALE_OIL_DEPOSIT_AMOUNT := 240
const MINERAL_DEPOSIT_SAMPLE_COUNT := 180
const FISH_DEPOSIT_SAMPLE_COUNT := 260
const SHALLOW_FISH_DEPOSIT_SAMPLE_COUNT := 300
const WHALE_OIL_DEPOSIT_SAMPLE_COUNT := 180
const RESOURCE_DEPOSIT_SIZES := ["small", "medium", "large"]
const RESOURCE_RING_SEGMENTS := 40
const RESOURCE_RING_BASE_RADIUS := 1.0
const NATURE_PACK_OBJ_ROOT := "res://assets/Ultimate Nature Pack by Quaternius/OBJ/"
const STUMP_ASSETS := [
	NATURE_PACK_OBJ_ROOT + "TreeStump.obj",
	NATURE_PACK_OBJ_ROOT + "TreeStump_Moss.obj",
	NATURE_PACK_OBJ_ROOT + "TreeStump_Snow.obj",
]
const LEAF_TREE_ASSETS := [
	NATURE_PACK_OBJ_ROOT + "CommonTree_1.obj",
	NATURE_PACK_OBJ_ROOT + "BirchTree_2.obj",
	NATURE_PACK_OBJ_ROOT + "CommonTree_3.obj",
]
const CONIFER_TREE_ASSETS := [
	NATURE_PACK_OBJ_ROOT + "PineTree_1.obj",
	NATURE_PACK_OBJ_ROOT + "PineTree_2.obj",
	NATURE_PACK_OBJ_ROOT + "PineTree_3.obj",
]
const SNOW_CONIFER_TREE_ASSETS := [
	NATURE_PACK_OBJ_ROOT + "PineTree_Snow_1.obj",
	NATURE_PACK_OBJ_ROOT + "PineTree_Snow_2.obj",
	NATURE_PACK_OBJ_ROOT + "PineTree_Snow_3.obj",
]
const PALM_TREE_ASSETS := [
	NATURE_PACK_OBJ_ROOT + "PalmTree_1.obj",
	NATURE_PACK_OBJ_ROOT + "PalmTree_2.obj",
	NATURE_PACK_OBJ_ROOT + "PalmTree_3.obj",
]
const DEAD_TREE_ASSETS := [
	NATURE_PACK_OBJ_ROOT + "CommonTree_Dead_1.obj",
	NATURE_PACK_OBJ_ROOT + "BirchTree_Dead_2.obj",
	NATURE_PACK_OBJ_ROOT + "CommonTree_Dead_3.obj",
]
const SNOW_DEAD_TREE_ASSETS := [
	NATURE_PACK_OBJ_ROOT + "CommonTree_Dead_Snow_1.obj",
	NATURE_PACK_OBJ_ROOT + "BirchTree_Dead_Snow_2.obj",
	NATURE_PACK_OBJ_ROOT + "CommonTree_Dead_Snow_3.obj",
]
const BROKEN_TREE_ASSETS := [
	NATURE_PACK_OBJ_ROOT + "WoodLog.obj",
	NATURE_PACK_OBJ_ROOT + "WoodLog_Moss.obj",
	NATURE_PACK_OBJ_ROOT + "WoodLog_Snow.obj",
]
const ROCK_ASSETS := [
	NATURE_PACK_OBJ_ROOT + "Rock_1.obj",
	NATURE_PACK_OBJ_ROOT + "Rock_2.obj",
	NATURE_PACK_OBJ_ROOT + "Rock_3.obj",
]
const BUSH_ASSETS := [
	NATURE_PACK_OBJ_ROOT + "Bush_1.obj",
	NATURE_PACK_OBJ_ROOT + "Bush_2.obj",
	NATURE_PACK_OBJ_ROOT + "BushBerries_1.obj",
	NATURE_PACK_OBJ_ROOT + "BushBerries_2.obj",
]
const SNOW_BUSH_ASSETS := [
	NATURE_PACK_OBJ_ROOT + "Bush_Snow_1.obj",
	NATURE_PACK_OBJ_ROOT + "Bush_Snow_2.obj",
]
const SMALL_TREE_ASSETS := [
	NATURE_PACK_OBJ_ROOT + "CommonTree_4.obj",
	NATURE_PACK_OBJ_ROOT + "BirchTree_4.obj",
	NATURE_PACK_OBJ_ROOT + "PineTree_4.obj",
]
const SMALL_SNOW_TREE_ASSETS := [
	NATURE_PACK_OBJ_ROOT + "PineTree_Snow_4.obj",
	NATURE_PACK_OBJ_ROOT + "PineTree_Snow_5.obj",
]
const FIELD_PLANT_ASSETS := [
	NATURE_PACK_OBJ_ROOT + "Plant_1.obj",
	NATURE_PACK_OBJ_ROOT + "Plant_2.obj",
	NATURE_PACK_OBJ_ROOT + "Plant_3.obj",
	NATURE_PACK_OBJ_ROOT + "Plant_4.obj",
	NATURE_PACK_OBJ_ROOT + "Plant_5.obj",
]
const CACTUS_ASSETS := [
	NATURE_PACK_OBJ_ROOT + "Cactus_1.obj",
	NATURE_PACK_OBJ_ROOT + "Cactus_2.obj",
	NATURE_PACK_OBJ_ROOT + "Cactus_3.obj",
	NATURE_PACK_OBJ_ROOT + "Cactus_4.obj",
	NATURE_PACK_OBJ_ROOT + "Cactus_5.obj",
	NATURE_PACK_OBJ_ROOT + "CactusFlower_1.obj",
	NATURE_PACK_OBJ_ROOT + "CactusFlowers_2.obj",
	NATURE_PACK_OBJ_ROOT + "CactusFlowers_3.obj",
	NATURE_PACK_OBJ_ROOT + "CactusFlowers_4.obj",
	NATURE_PACK_OBJ_ROOT + "CactusFlowers_5.obj",
]
const BONE_PILE_ASSETS := [
	"res://assets/models/details/bone_pile_01.glb",
]
const CARCASS_ASSETS := [
	"res://assets/models/details/dead_carcass_01.glb",
]
const FLINT_STONE_ASSETS := [
	"res://assets/models/details/flint_stone_01.glb",
]
const ORE_DEPOSIT_ASSETS := {
	"coal": "res://assets/models/resources/ore_coal.glb",
	"copper": "res://assets/models/resources/ore_copper.glb",
	"tin": "res://assets/models/resources/ore_tin.glb",
	"iron": "res://assets/models/resources/ore_iron.glb",
	"silver": "res://assets/models/resources/ore_silver.glb",
	"gold_ore": "res://assets/models/resources/ore_gold.glb",
	"uranium": "res://assets/models/resources/ore_uranium.glb",
}
const FISH_DEPOSIT_ASSETS := [
	"res://assets/models/fish/quaternius_animated_fish_pack/fish_1.fbx",
	"res://assets/models/fish/quaternius_animated_fish_pack/fish_2.fbx",
	"res://assets/models/fish/quaternius_animated_fish_pack/fish_3.fbx",
]
const WHALE_ASSET := "res://assets/models/fish/quaternius_animated_fish_pack/whale.fbx"
const DOLPHIN_ASSET := "res://assets/models/fish/quaternius_animated_fish_pack/dolphin.fbx"
const MANTA_RAY_ASSET := "res://assets/models/fish/quaternius_animated_fish_pack/manta_ray.fbx"
const SHARK_ASSET := "res://assets/models/fish/quaternius_animated_fish_pack/shark.fbx"
const WHALE_OIL_DEPOSIT_ASSETS := [
	WHALE_ASSET,
	WHALE_ASSET,
	DOLPHIN_ASSET,
	FISH_DEPOSIT_ASSETS[0],
	FISH_DEPOSIT_ASSETS[1],
	MANTA_RAY_ASSET,
	FISH_DEPOSIT_ASSETS[2],
	SHARK_ASSET,
]
const WHALE_OIL_MEMBER_SCALE_MULTIPLIERS := {
	WHALE_ASSET: 1.30,
	DOLPHIN_ASSET: 0.72,
	MANTA_RAY_ASSET: 0.62,
	SHARK_ASSET: 0.74,
	"res://assets/models/fish/quaternius_animated_fish_pack/fish_1.fbx": 0.42,
	"res://assets/models/fish/quaternius_animated_fish_pack/fish_2.fbx": 0.38,
	"res://assets/models/fish/quaternius_animated_fish_pack/fish_3.fbx": 0.42,
}
const ORDER_CURSOR_ICON_PATHS := {
	"move": "res://assets/sprites/ui/yarts_thing_selected_cursor.svg",
	"build": "res://assets/sprites/ui/yarts_build_cursor.svg",
	"attack": "res://assets/sprites/ui/yarts_attack_cursor.svg",
	"interact": "res://assets/sprites/ui/yarts_interact_cursor.svg",
	"auto_move": "res://assets/sprites/ui/yarts_auto_move_cursor.svg",
	"repair": "res://assets/sprites/ui/yarts_repair_cursor.svg",
	"scavenge": "res://assets/sprites/ui/yarts_scavenge_cursor.svg",
}
const ORDER_CURSOR_TOOLTIPS := {
	"move": "Move order",
	"build": "Build order",
	"attack": "Attack order",
	"interact": "Interact / gather order",
	"auto_move": "Automated movement order",
	"repair": "Repair order",
	"scavenge": "Scavenge order",
}
const CARRIED_WOOD_MODEL := NATURE_PACK_OBJ_ROOT + "WoodLog.obj"
const CARRIED_WOOD_VISUAL_LENGTH := 2.4

var cell
var camera: Camera3D
var sun_light: DirectionalLight3D
var night_fill_light: DirectionalLight3D
var battle_environment: Environment
var sky_material: ShaderMaterial
var summary_label: HudStatText
var resource_rail_panel: PanelContainer
var settlement_strip_panel: PanelContainer
var region_header_panel: PanelContainer
var region_name_label: Label
var resource_list_container: VBoxContainer
var context_panel: PanelContainer
var context_title_label: Label
var context_stats_label: HudStatText
var context_carry_panel: PanelContainer
var context_carry_label: HudStatText
var context_animation_picker: OptionButton
var context_animation_picker_updating := false
var order_sidebar_panel: PanelContainer
var order_buttons_by_mode: Dictionary = {}
var active_order_mode := "move"
var event_log_label: RichTextLabel
var loading_layer: CanvasLayer
var loading_label: Label
var loading_bar: ProgressBar
var world_view_panel: PanelContainer
var world_view_toggle_button: Button
var world_globe_viewport: SubViewport
var world_globe_root: Node3D
var world_globe_scene_root: Node3D
var world_globe_planet: MeshInstance3D
var world_globe_grid: MeshInstance3D
var world_globe_cell_outline: MeshInstance3D
var world_globe_camera: Camera3D
var world_globe_sun_light: DirectionalLight3D
var world_globe_update_elapsed := WORLD_GLOBE_UPDATE_INTERVAL
var minimap_panel: PanelContainer
var minimap_toggle_button: Button
var minimap_preview: HudMapPreview
var drag_selection_overlay: DragSelectionOverlay
var terrain_root: Node3D
var battle_entity_root: Node3D
var battle_units: Array = []
var battle_buildings: Array = []
var unit_nodes_by_id: Dictionary = {}
var unit_actors_by_id: Dictionary = {}
var unit_animation_players_by_id: Dictionary = {}
var unit_animation_library: AnimationLibrary
var unit_animation_names: Array = []
var unit_animation_status := ""
var selected_unit_ids: Array = []
var selected_unit_id := ""
var selected_unit_data = null
var selected_unit_node: Node3D
var unit_selection_marker_mesh: ArrayMesh
var unit_visibility_marker_mesh: ArrayMesh
var unit_move_order_cone_mesh: Mesh
var unit_move_order_line_material: StandardMaterial3D
var unit_move_order_cone_material: StandardMaterial3D
var selected_unit_markers_by_id: Dictionary = {}
var unit_visibility_markers_by_id: Dictionary = {}
var unit_move_order_line_markers_by_id: Dictionary = {}
var unit_move_order_cones_by_id: Dictionary = {}
var resource_nodes_by_id: Dictionary = {}
var resource_node_sequence := 0
var falling_tree_animations: Array = []
var fish_school_members: Array = []
var fish_school_elapsed := 0.0
var resource_ring_mesh: ArrayMesh
var resource_ring_batches_by_type: Dictionary = {}
var resource_hover_ring: MeshInstance3D
var hovered_resource = null
var resource_hover_cursor_active := false
var carried_resource_visuals_by_unit_id: Dictionary = {}
var last_move_order_click_msec := -1000000
var last_move_order_click_position := Vector2(-1000000.0, -1000000.0)
var unit_selection_dragging := false
var unit_selection_drag_start := Vector2.ZERO
var unit_selection_drag_end := Vector2.ZERO
var free_roam_enabled := false
var free_roam_yaw := 0.0
var free_roam_pitch := 0.0
var displayed_sun_label := ""
var hud_stat_tooltip_panel: PanelContainer
var hud_stat_tooltip_label: Label
var hud_hovered_stat := ""
var hud_hover_elapsed := 0.0
var hud_tooltip_expanded := false
var hud_icon_texture_cache: Dictionary = {}
var rts_yaw_dragging := false
var grid_visible := false
var world_view_collapsed := false
var minimap_collapsed := false
var minimap_update_elapsed := 0.0
var smoothed_river_map := PackedFloat32Array()
var smoothed_river_map_size := 0
var terrain_surface_heights := PackedFloat32Array()
var terrain_surface_row_length := 0
var tree_scene_cache: Dictionary = {}
var tree_mesh_part_cache: Dictionary = {}
var battle_prop_material_cache: Dictionary = {}
var tree_shadow_mesh: ArrayMesh
var tree_shadow_material: ShaderMaterial
var tree_impostor_texture_cache: Dictionary = {}
var tree_impostor_material_cache: Dictionary = {}
var tree_impostor_quad_mesh: QuadMesh
var tree_impostor_lod_entries: Array = []
var active_tree_impostor_full_nodes: Dictionary = {}
var tree_impostor_lod_root: Node3D
var tree_impostor_lod_elapsed := 0.0
var loaded_entity_count := 0
var full_model_entity_count := 0
var impostor_entity_count := 0
var rts_state_ready := false


func _ready() -> void:
	Game.set_thing_selected_cursor_active(false)
	cell = Game.get_current_cell()
	_build_scene()
	_build_overlay()
	_refresh_overlay()
	_build_loading_overlay()
	call_deferred("_load_rts_cell")


func _process(delta: float) -> void:
	Game.advance_battle_sun(delta)
	_sync_sun_lighting()
	if free_roam_enabled:
		_update_free_roam_camera(delta)
	else:
		_update_rts_camera(delta)
	if TREE_IMPOSTORS_ENABLED:
		_update_tree_impostor_lod(delta)
	_update_unit_movement(delta)
	_update_unit_gather_actions(delta)
	_update_unit_delivery_actions()
	_update_falling_trees(delta)
	_update_unit_actor_animation_queues(delta)
	_update_carried_unit_animation_state()
	_update_fish_school_motion(delta)
	_update_unit_selection_marker()
	_update_world_globe_preview(delta)
	_update_minimap_preview(delta)
	_update_hud_stat_tooltip(delta)
	_update_hovered_resource_visual()


func _input(event: InputEvent) -> void:
	if camera == null:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G:
			_toggle_grid_visibility()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_P:
			_toggle_free_roam()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE and free_roam_enabled:
			_set_free_roam_enabled(false)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion and free_roam_enabled:
		_clear_resource_hover()
		free_roam_yaw -= event.relative.x * FREE_ROAM_MOUSE_SENSITIVITY
		free_roam_pitch = clamp(free_roam_pitch - event.relative.y * FREE_ROAM_MOUSE_SENSITIVITY, FREE_ROAM_MIN_PITCH, FREE_ROAM_MAX_PITCH)
		camera.rotation = Vector3(free_roam_pitch, free_roam_yaw, 0.0)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and not free_roam_enabled:
		_update_resource_hover(event.position)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not free_roam_enabled:
		if event.pressed:
			if not _is_screen_point_in_hud(event.position):
				_begin_unit_selection_drag(event.position)
				get_viewport().set_input_as_handled()
				return
		elif unit_selection_dragging:
			_finish_unit_selection_drag(event.position)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not free_roam_enabled:
		var jog_order := _is_jog_move_order_click(event.position)
		var resource_hit = _resource_at_screen(event.position)
		if not _is_screen_point_in_hud(event.position) and resource_hit != null and _issue_gather_order_to_selected_units(resource_hit):
			_remember_move_order_click(event.position)
			get_viewport().set_input_as_handled()
			return
		if not _is_screen_point_in_hud(event.position) and _issue_move_order_to_selected_units(event.position, jog_order):
			_remember_move_order_click(event.position)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion and unit_selection_dragging and not free_roam_enabled:
		_update_unit_selection_drag(event.position)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed:
			_cancel_unit_selection_drag()
		rts_yaw_dragging = event.pressed and not free_roam_enabled
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and rts_yaw_dragging and not free_roam_enabled:
		camera.rotation.y -= event.relative.x * RTS_MOUSE_YAW_SPEED
		get_viewport().set_input_as_handled()
		return


func _unhandled_input(event: InputEvent) -> void:
	if camera == null:
		return

	if event is InputEventMouseButton and event.pressed:
		if free_roam_enabled:
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(-CAMERA_ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(CAMERA_ZOOM_STEP)


func _exit_tree() -> void:
	_snapshot_current_cell_state()
	_clear_resource_hover()
	Game.reset_order_cursor()
	Game.set_thing_selected_cursor_active(false)
	if free_roam_enabled:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_cancel_unit_selection_drag()
	rts_yaw_dragging = false


func _build_scene() -> void:
	terrain_root = Node3D.new()
	terrain_root.name = "DetailedRTSCell"
	add_child(terrain_root)
	_create_unit_selection_marker()

	sun_light = DirectionalLight3D.new()
	sun_light.name = "BattleSun"
	sun_light.shadow_enabled = true
	add_child(sun_light)
	_configure_tree_shadow_quality()

	night_fill_light = DirectionalLight3D.new()
	night_fill_light.name = "BattleMoon"
	night_fill_light.shadow_enabled = false
	night_fill_light.light_color = MOON_LIGHT_COLOR
	night_fill_light.light_energy = 0.0
	night_fill_light.light_specular = 0.25
	add_child(night_fill_light)

	var world_environment := WorldEnvironment.new()
	battle_environment = Environment.new()
	battle_environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_material = ShaderMaterial.new()
	sky_material.shader = load("res://shaders/sky_sorta_cell.gdshader")
	sky.sky_material = sky_material
	battle_environment.sky = sky
	battle_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_environment.environment = battle_environment
	add_child(world_environment)

	_sync_sun_lighting()

	camera = Camera3D.new()
	camera.name = "RTSCamera"
	camera.position = Vector3(0.0, 420.0, 420.0)
	camera.rotation_degrees = Vector3(-52.0, 0.0, 0.0)
	camera.fov = 50.0
	camera.current = true
	add_child(camera)


func _configure_tree_shadow_quality() -> void:
	if sun_light == null:
		return

	sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun_light.directional_shadow_max_distance = TREE_SHADOW_MAX_DISTANCE
	sun_light.directional_shadow_fade_start = 0.72
	sun_light.directional_shadow_pancake_size = 20.0
	sun_light.directional_shadow_blend_splits = false
	sun_light.shadow_opacity = TREE_SHADOW_OPACITY
	sun_light.shadow_blur = TREE_SHADOW_BLUR
	sun_light.shadow_bias = TREE_SHADOW_BIAS
	sun_light.shadow_normal_bias = TREE_SHADOW_NORMAL_BIAS


func _build_terrain_grid_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var minor_alpha := 0.025
	var major_alpha := 0.055
	var minor_color := Color(0.94, 0.95, 0.86, minor_alpha)
	var major_color := Color(1.0, 0.96, 0.70, major_alpha)
	var line_count := int(MAP_SIZE / GRID_STEP)
	var half_size := MAP_SIZE * 0.5
	var segments_per_line := TERRAIN_STEPS

	for index in range(line_count + 1):
		var offset: float = -half_size + float(index) * GRID_STEP
		var color := major_color if index % 4 == 0 else minor_color
		for segment_index in range(segments_per_line):
			var t0: float = float(segment_index) / float(segments_per_line)
			var t1: float = float(segment_index + 1) / float(segments_per_line)
			var z0: float = lerpf(-half_size, half_size, t0)
			var z1: float = lerpf(-half_size, half_size, t1)
			var x0: float = lerpf(-half_size, half_size, t0)
			var x1: float = lerpf(-half_size, half_size, t1)
			vertices.append(_grid_vertex_at(offset, z0))
			vertices.append(_grid_vertex_at(offset, z1))
			vertices.append(_grid_vertex_at(x0, offset))
			vertices.append(_grid_vertex_at(x1, offset))
			for color_index in range(4):
				colors.append(color)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.surface_set_material(0, material)
	return mesh


func _toggle_grid_visibility() -> void:
	grid_visible = not grid_visible
	_refresh_grid_mesh()


func _refresh_grid_mesh() -> void:
	if terrain_root == null:
		return

	var grid := terrain_root.get_node_or_null("ScaleGrid10m") as MeshInstance3D
	if grid == null:
		return
	grid.visible = grid_visible


func _grid_vertex_at(x: float, z: float) -> Vector3:
	var u := inverse_lerp(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, x)
	var v := inverse_lerp(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, z)
	var sample := _sample_cell_uv(u, v)
	var surface_height := _height_from_sample(sample)
	if str(sample["terrain"]) == "water":
		surface_height = max(surface_height, WATER_SURFACE_HEIGHT)
	elif float(sample.get("river", 0.0)) > 0.42:
		surface_height = max(surface_height, WATER_SURFACE_HEIGHT)
	return Vector3(x, surface_height + GRID_SURFACE_OFFSET, z)


func _spawn_starter_battle_entities() -> void:
	battle_units.clear()
	battle_buildings.clear()
	unit_nodes_by_id.clear()
	unit_actors_by_id.clear()
	unit_animation_players_by_id.clear()
	_clear_unit_selection()
	battle_entity_root = Node3D.new()
	battle_entity_root.name = "BattleEntities"
	terrain_root.add_child(battle_entity_root)

	var unit_manager = UnitManagerScript.new()
	if cell != null and cell.rts_state is Dictionary:
		for building_state_value in cell.rts_state.get("buildings", []):
			if not building_state_value is Dictionary:
				continue
			var building = RTSBuildingDataScript.new()
			building.load_from_dict(building_state_value)
			battle_buildings.append(building)
	var saved_units: Array = []
	if cell != null and cell.rts_state is Dictionary:
		saved_units = cell.rts_state.get("units", [])
	if not saved_units.is_empty():
		for unit_state_value in saved_units:
			if unit_state_value is Dictionary:
				battle_units.append(unit_manager.unit_from_dict(unit_state_value))
	else:
		var spawn_center := _find_initial_dry_spawn_center()
		battle_units.append(unit_manager.create_unit(
			"player_worker_01",
			"player",
			"flint_axe",
			_find_dry_spawn_near(spawn_center + Vector3(-32.0, 0.0, 0.0)),
			0
		))
		battle_units.append(unit_manager.create_unit(
			"player_builder_01",
			"player",
			"building_tools",
			_find_dry_spawn_near(spawn_center + Vector3(32.0, 0.0, 6.0)),
			0
		))

	for unit in battle_units:
		_spawn_unit_from_data(unit)
	_restore_unit_runtime_state()

	loaded_entity_count += battle_units.size() + battle_buildings.size()
	full_model_entity_count += battle_units.size() + battle_buildings.size()


func _find_initial_dry_spawn_center() -> Vector3:
	var half_size := MAP_SIZE * 0.5 - 80.0
	var step := 48.0
	var z := 0.0
	while z <= half_size:
		if _is_dry_spawn_location(0.0, z):
			return _ground_position_for_local(0.0, z)
		z += step
	for radius in range(1, 24):
		var distance := float(radius) * 72.0
		for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			var candidate: Vector2 = direction * distance
			if _is_dry_spawn_location(candidate.x, candidate.y):
				return _ground_position_for_local(candidate.x, candidate.y)
	return _ground_position_for_local(0.0, 0.0)


func _find_dry_spawn_near(preferred: Vector3) -> Vector3:
	if _is_dry_spawn_location(preferred.x, preferred.z):
		return _ground_position_for_local(preferred.x, preferred.z)
	for radius in range(1, 18):
		var distance := float(radius) * 18.0
		for angle_index in range(12):
			var angle := TAU * float(angle_index) / 12.0
			var x := preferred.x + cos(angle) * distance
			var z := preferred.z + sin(angle) * distance
			if _is_dry_spawn_location(x, z):
				return _ground_position_for_local(x, z)
	return _ground_position_for_local(preferred.x, preferred.z)


func _is_dry_spawn_location(x: float, z: float) -> bool:
	var half_size := MAP_SIZE * 0.5 - 20.0
	if abs(x) > half_size or abs(z) > half_size:
		return false
	var u := inverse_lerp(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, x)
	var v := inverse_lerp(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, z)
	var sample := _sample_cell_uv(u, v)
	return str(sample.get("terrain", "water")) != "water" and float(sample.get("river", 0.0)) < 0.18


func _restore_unit_runtime_state() -> void:
	if cell == null or not cell.rts_state is Dictionary:
		return
	var runtime_by_id: Dictionary = cell.rts_state.get("unit_runtime", {})
	for unit_id_value in runtime_by_id.keys():
		var actor = unit_actors_by_id.get(str(unit_id_value))
		var runtime = runtime_by_id.get(unit_id_value)
		if actor == null or not runtime is Dictionary:
			continue
		actor.carried_resources = runtime.get("carried_resources", {}).duplicate(true)
		_sync_actor_carried_resource_visual(actor)


func _spawn_unit_from_data(unit_data) -> void:
	if battle_entity_root == null:
		return

	var unit = RTSUnitActorScript.new()
	unit.configure(unit_data)
	battle_entity_root.add_child(unit)
	unit_nodes_by_id[str(unit_data.id)] = unit
	unit_actors_by_id[str(unit_data.id)] = unit

	var unit_resource := load(_unit_model_path(str(unit_data.id)))
	if unit_resource is PackedScene:
		var model := (unit_resource as PackedScene).instantiate()
		if model is Node3D:
			var model_3d := model as Node3D
			model_3d.name = "TposeUnit_%s" % str(unit_data.profession)
			unit.add_child(model_3d)
			_fit_model_to_height(model_3d, UNIT_VISUAL_HEIGHT)
			_apply_unit_faction_color(model_3d, str(unit_data.faction_id))
			_set_shadow_casting(model_3d, true)
			_attach_unit_animation_player(str(unit_data.id), model_3d)
			return
		model.queue_free()

	_spawn_placeholder_scale_unit(unit)


func _unit_model_path(unit_id: String) -> String:
	# Keep the visual stable across scene reloads without adding a save-data field yet.
	return UNIT_MODEL_FEMALE if (unit_id.hash() & 1) == 1 else UNIT_MODEL_MALE


func _apply_unit_faction_color(node: Node, faction_id: String) -> void:
	var faction_color := Game.get_faction_color(faction_id)
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			var tinted_mesh := mesh_instance.mesh.duplicate() as Mesh
			for surface_index in range(tinted_mesh.get_surface_count()):
				var source_material := mesh_instance.mesh.surface_get_material(surface_index)
				var tinted_material := _unit_faction_material(source_material, faction_color)
				if tinted_material != null:
					tinted_mesh.surface_set_material(surface_index, tinted_material)
			mesh_instance.mesh = tinted_mesh
		if mesh_instance.material_override != null:
			mesh_instance.material_override = _unit_faction_material(mesh_instance.material_override, faction_color)
	for child in node.get_children():
		_apply_unit_faction_color(child, faction_id)


func _unit_faction_material(source_material: Material, faction_color: Color) -> Material:
	if source_material == null:
		return null
	var material := source_material.duplicate() as Material
	if material is BaseMaterial3D:
		var base := material as BaseMaterial3D
		var source_color := base.albedo_color
		var tinted := source_color.lerp(faction_color, 0.58)
		tinted.a = source_color.a
		base.albedo_color = tinted
	return material


func _attach_unit_animation_player(unit_id: String, model_root: Node3D) -> void:
	var library := _get_unit_animation_library()
	if library == null or unit_animation_names.is_empty():
		return

	var player := AnimationPlayer.new()
	player.name = "UnitAnimationPlayer"
	player.root_node = NodePath("..")
	player.add_animation_library("", library)
	model_root.add_child(player)
	unit_animation_players_by_id[unit_id] = player
	var actor = unit_actors_by_id.get(unit_id)
	if actor != null:
		actor.set_animation_player(player)
	if player.has_animation(UNIT_DEFAULT_ANIMATION):
		if actor != null:
			actor.play_animation(UNIT_DEFAULT_ANIMATION)
		else:
			player.play(UNIT_DEFAULT_ANIMATION)


func _get_unit_animation_library() -> AnimationLibrary:
	if unit_animation_library != null:
		return unit_animation_library

	unit_animation_names.clear()
	unit_animation_status = ""

	var target_scene = load(UNIT_ANIMATION_REFERENCE_MODEL)
	if not target_scene is PackedScene:
		unit_animation_status = "YARTS unit model is not available."
		return null
	var target_root := (target_scene as PackedScene).instantiate()
	var target_skeleton := _find_first_skeleton(target_root)
	if target_skeleton == null:
		unit_animation_status = "YARTS unit model has no Skeleton3D."
		target_root.queue_free()
		return null
	var target_skeleton_path := target_root.get_path_to(target_skeleton)

	var library := AnimationLibrary.new()
	var loaded_pack_count := 0
	var direct_pack_count := 0
	var skipped_packs: Array[String] = []

	for pack in UNIT_ANIMATION_PACKS:
		var pack_label := str(pack.get("label", "Animations"))
		var pack_path := str(pack.get("path", ""))
		var preferred_animation_name := str(pack.get("animation_name", ""))
		var source_scene = load(pack_path)
		if not source_scene is PackedScene:
			skipped_packs.append("%s missing" % pack_label)
			continue

		var source_root := (source_scene as PackedScene).instantiate()
		var source_player := _find_first_animation_player(source_root)
		if source_player == null:
			skipped_packs.append("%s has no AnimationPlayer" % pack_label)
			source_root.queue_free()
			continue
		var source_skeleton := _find_first_skeleton(source_root)
		if source_skeleton == null:
			skipped_packs.append("%s has no Skeleton3D" % pack_label)
			source_root.queue_free()
			continue

		var direct_animation_tracks := _unit_skeleton_matches_source(source_skeleton, target_skeleton)
		if direct_animation_tracks:
			direct_pack_count += 1
		loaded_pack_count += 1

		for source_library_name in source_player.get_animation_library_list():
			var source_library := source_player.get_animation_library(source_library_name)
			if source_library == null:
				continue
			for animation_name_value in source_library.get_animation_list():
				var source_animation_name := str(animation_name_value)
				var animation_name := preferred_animation_name if not preferred_animation_name.is_empty() else source_animation_name
				var source_animation := source_library.get_animation(animation_name_value)
				var remapped_animation := (
					_copy_direct_unit_animation(source_animation, animation_name)
					if direct_animation_tracks
					else _remap_unit_animation(source_animation, animation_name, source_skeleton, target_skeleton, target_skeleton_path)
				)
				if remapped_animation == null or remapped_animation.get_track_count() <= 0:
					continue
				var trim_tail := float(pack.get("trim_tail", 0.0))
				if trim_tail > 0.0 and remapped_animation.length > trim_tail:
					remapped_animation = _trim_unit_animation_tail(remapped_animation, trim_tail)
				if pack.has("loop"):
					remapped_animation.loop_mode = Animation.LOOP_LINEAR if bool(pack["loop"]) else Animation.LOOP_NONE
				var library_animation_name := _unique_unit_animation_name(library, animation_name, pack_label)
				library.add_animation(library_animation_name, remapped_animation)
				unit_animation_names.append(library_animation_name)

		source_root.queue_free()
	target_root.queue_free()
	if unit_animation_names.is_empty():
		unit_animation_status = "No compatible animation tracks found."
		if not skipped_packs.is_empty():
			unit_animation_status += " %s." % ", ".join(skipped_packs)
		return null

	unit_animation_names.sort()
	unit_animation_library = library
	unit_animation_status = "%d animations ready from %d packs%s." % [
		unit_animation_names.size(),
		loaded_pack_count,
		" on source rig" if loaded_pack_count > 0 and direct_pack_count == loaded_pack_count else "",
	]
	if not skipped_packs.is_empty():
		unit_animation_status += " Skipped: %s." % ", ".join(skipped_packs)
	return unit_animation_library


func _unique_unit_animation_name(library: AnimationLibrary, animation_name: String, pack_label: String) -> String:
	if not library.has_animation(animation_name):
		return animation_name
	var packed_name := "%s - %s" % [pack_label, animation_name]
	if not library.has_animation(packed_name):
		return packed_name
	var suffix := 2
	while library.has_animation("%s %d - %s" % [pack_label, suffix, animation_name]):
		suffix += 1
	return "%s %d - %s" % [pack_label, suffix, animation_name]


func _unit_skeleton_matches_source(source_skeleton: Skeleton3D, target_skeleton: Skeleton3D) -> bool:
	if source_skeleton == null or target_skeleton == null:
		return false
	if source_skeleton.get_bone_count() != target_skeleton.get_bone_count():
		return false
	for bone_index in range(source_skeleton.get_bone_count()):
		if source_skeleton.get_bone_name(bone_index) != target_skeleton.get_bone_name(bone_index):
			return false
	return target_skeleton.name == "Skeleton3D" and target_skeleton.get_parent() != null and target_skeleton.get_parent().name == "Armature"


func _copy_direct_unit_animation(source_animation: Animation, animation_name: String) -> Animation:
	if source_animation == null:
		return null
	var direct_animation := source_animation.duplicate(true) as Animation
	_remove_unit_animation_position_tracks(direct_animation)
	if direct_animation.loop_mode == Animation.LOOP_NONE and _unit_animation_name_is_loop(animation_name):
		direct_animation.loop_mode = Animation.LOOP_LINEAR
	return direct_animation


func _remove_unit_animation_position_tracks(animation: Animation) -> void:
	if animation == null:
		return
	# RTS actors own world movement. Imported root motion must not move the mesh
	# independently or convert source forward motion into target-rig height.
	for track_index in range(animation.get_track_count() - 1, -1, -1):
		if animation.track_get_type(track_index) == Animation.TYPE_POSITION_3D:
			animation.remove_track(track_index)


func _trim_unit_animation_tail(source_animation: Animation, tail_duration: float) -> Animation:
	var duration: float = clamp(tail_duration, 0.05, source_animation.length)
	var start_time: float = max(0.0, source_animation.length - duration)
	var trimmed := Animation.new()
	trimmed.length = duration
	trimmed.loop_mode = Animation.LOOP_NONE
	for source_track_index in range(source_animation.get_track_count()):
		var key_count := source_animation.track_get_key_count(source_track_index)
		if key_count <= 0:
			continue
		var track_index := trimmed.add_track(source_animation.track_get_type(source_track_index))
		trimmed.track_set_path(track_index, source_animation.track_get_path(source_track_index))
		trimmed.track_set_interpolation_type(track_index, source_animation.track_get_interpolation_type(source_track_index))
		var initial_value = source_animation.track_get_key_value(source_track_index, 0)
		var initial_transition := 1.0
		for key_index in range(key_count):
			var key_time := source_animation.track_get_key_time(source_track_index, key_index)
			if key_time <= start_time:
				initial_value = source_animation.track_get_key_value(source_track_index, key_index)
				initial_transition = source_animation.track_get_key_transition(source_track_index, key_index)
				continue
			trimmed.track_insert_key(
				track_index,
				key_time - start_time,
				source_animation.track_get_key_value(source_track_index, key_index),
				source_animation.track_get_key_transition(source_track_index, key_index)
			)
		trimmed.track_insert_key(track_index, 0.0, initial_value, initial_transition)
	return trimmed


func _find_first_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_first_animation_player(child)
		if found != null:
			return found
	return null


func _find_first_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_first_skeleton(child)
		if found != null:
			return found
	return null


func _remap_unit_animation(source_animation: Animation, animation_name: String, source_skeleton: Skeleton3D, target_skeleton: Skeleton3D, target_skeleton_path: NodePath) -> Animation:
	if source_animation == null:
		return null
	if source_skeleton.find_bone("mixamorig_Hips") >= 0:
		return UnitAnimationCatalogScript.retarget_animation(
			source_animation,
			animation_name,
			source_skeleton,
			target_skeleton,
			target_skeleton_path
		)

	var remapped := Animation.new()
	remapped.length = source_animation.length
	remapped.loop_mode = source_animation.loop_mode
	if remapped.loop_mode == Animation.LOOP_NONE and _unit_animation_name_is_loop(animation_name):
		remapped.loop_mode = Animation.LOOP_LINEAR

	var used_paths := {}
	for source_track_index in range(source_animation.get_track_count()):
		var track_type := source_animation.track_get_type(source_track_index)
		if track_type != Animation.TYPE_ROTATION_3D:
			continue

		var source_bone := _source_bone_name_from_track_path(source_animation.track_get_path(source_track_index))
		if source_bone.is_empty() or not UNIT_ANIMATION_BONE_MAP.has(source_bone):
			continue

		var target_bone: String = UNIT_ANIMATION_BONE_MAP[source_bone]
		if _unit_animation_uses_relaxed_arm_pose(animation_name) and UNIT_ANIMATION_RELAXED_ARM_BONES.has(target_bone):
			continue

		var source_bone_index := source_skeleton.find_bone(source_bone)
		var target_bone_index := target_skeleton.find_bone(target_bone)
		if source_bone_index < 0 or target_bone_index < 0:
			continue

		var source_rest_rotation := source_skeleton.get_bone_rest(source_bone_index).basis.get_rotation_quaternion()
		var target_rest_rotation := target_skeleton.get_bone_rest(target_bone_index).basis.get_rotation_quaternion()
		var target_path := NodePath("%s:%s" % [str(target_skeleton_path), target_bone])
		if used_paths.has(str(target_path)):
			continue
		used_paths[str(target_path)] = true

		var target_track_index := remapped.add_track(track_type)
		remapped.track_set_path(target_track_index, target_path)
		remapped.track_set_interpolation_type(target_track_index, source_animation.track_get_interpolation_type(source_track_index))
		for key_index in range(source_animation.track_get_key_count(source_track_index)):
			var source_key_value = source_animation.track_get_key_value(source_track_index, key_index)
			if not source_key_value is Quaternion:
				continue
			var source_rotation := source_key_value as Quaternion
			var source_delta := source_rest_rotation.inverse() * source_rotation
			var delta_strength := _unit_animation_bone_strength(animation_name, target_bone)
			if delta_strength < 1.0:
				source_delta = Quaternion(0.0, 0.0, 0.0, 1.0).slerp(source_delta.normalized(), delta_strength)
			var target_rotation := (target_rest_rotation * source_delta).normalized()
			remapped.track_insert_key(
				target_track_index,
				source_animation.track_get_key_time(source_track_index, key_index),
				target_rotation,
				source_animation.track_get_key_transition(source_track_index, key_index)
			)

	if _unit_animation_uses_relaxed_arm_pose(animation_name):
		_add_relaxed_unit_arm_tracks(remapped, animation_name, target_skeleton, target_skeleton_path, used_paths)

	return remapped


func _unit_animation_uses_relaxed_arm_pose(animation_name: String) -> bool:
	var lower_name := animation_name.to_lower()
	return (
		lower_name == "idle"
		or lower_name == "walk"
		or lower_name == "walk_formal"
		or lower_name == "jog_fwd"
		or lower_name == "sprint"
		or lower_name == "crouch_idle"
		or lower_name == "crouch_fwd"
	)


func _unit_animation_bone_strength(animation_name: String, target_bone: String) -> float:
	var lower_name := animation_name.to_lower()
	if _unit_animation_is_arm_action(lower_name):
		match target_bone:
			"Shoulder.L", "Shoulder.R":
				return 0.65
			"UpperArm.L", "UpperArm.R":
				return 0.88
			"LowerArm.L", "LowerArm.R":
				return 0.82
			"Hand.L", "Hand.R":
				return 0.74
			"Thumb.L", "Thumb.R":
				return 0.24
	if not _unit_animation_uses_relaxed_arm_pose(animation_name) and UNIT_ANIMATION_RELAXED_ARM_BONES.has(target_bone):
		match target_bone:
			"Shoulder.L", "Shoulder.R":
				return 0.55
			"UpperArm.L", "UpperArm.R":
				return 0.68
			"LowerArm.L", "LowerArm.R":
				return 0.72
			"Hand.L", "Hand.R":
				return 0.62
			"Thumb.L", "Thumb.R":
				return 0.22
	return float(UNIT_ANIMATION_BONE_STRENGTH.get(target_bone, 1.0))


func _unit_animation_is_arm_action(lower_name: String) -> bool:
	return (
		lower_name.find("pistol") >= 0
		or lower_name.find("punch") >= 0
		or lower_name.find("sword") >= 0
		or lower_name.find("spell") >= 0
		or lower_name.find("interact") >= 0
		or lower_name.find("pickup") >= 0
		or lower_name.find("talking") >= 0
		or lower_name.find("torch") >= 0
		or lower_name.find("fixing") >= 0
		or lower_name.find("hit") >= 0
		or lower_name.find("carry") >= 0
	)


func _add_relaxed_unit_arm_tracks(remapped: Animation, animation_name: String, target_skeleton: Skeleton3D, target_skeleton_path: NodePath, used_paths: Dictionary) -> void:
	var swing_amount := _unit_animation_arm_swing_amount(animation_name)
	_add_static_unit_arm_track(remapped, target_skeleton, target_skeleton_path, used_paths, "Shoulder.L", Quaternion.IDENTITY)
	_add_static_unit_arm_track(remapped, target_skeleton, target_skeleton_path, used_paths, "Shoulder.R", Quaternion.IDENTITY)
	_add_upper_unit_arm_track(remapped, target_skeleton, target_skeleton_path, used_paths, "UpperArm.L", 1.0, swing_amount)
	_add_upper_unit_arm_track(remapped, target_skeleton, target_skeleton_path, used_paths, "UpperArm.R", -1.0, swing_amount)
	_add_static_unit_arm_track(remapped, target_skeleton, target_skeleton_path, used_paths, "LowerArm.L", Quaternion(Vector3.RIGHT, UNIT_LOWER_ARM_RELAX_X))
	_add_static_unit_arm_track(remapped, target_skeleton, target_skeleton_path, used_paths, "LowerArm.R", Quaternion(Vector3.RIGHT, UNIT_LOWER_ARM_RELAX_X))
	_add_static_unit_arm_track(remapped, target_skeleton, target_skeleton_path, used_paths, "Hand.L", Quaternion(Vector3.RIGHT, UNIT_HAND_RELAX_X))
	_add_static_unit_arm_track(remapped, target_skeleton, target_skeleton_path, used_paths, "Hand.R", Quaternion(Vector3.RIGHT, UNIT_HAND_RELAX_X))
	_add_static_unit_arm_track(remapped, target_skeleton, target_skeleton_path, used_paths, "Thumb.L", Quaternion.IDENTITY)
	_add_static_unit_arm_track(remapped, target_skeleton, target_skeleton_path, used_paths, "Thumb.R", Quaternion.IDENTITY)


func _add_static_unit_arm_track(remapped: Animation, target_skeleton: Skeleton3D, target_skeleton_path: NodePath, used_paths: Dictionary, target_bone: String, correction: Quaternion) -> void:
	var target_bone_index := target_skeleton.find_bone(target_bone)
	if target_bone_index < 0:
		return

	var target_path := NodePath("%s:%s" % [str(target_skeleton_path), target_bone])
	if used_paths.has(str(target_path)):
		return
	used_paths[str(target_path)] = true

	var target_rest_rotation := target_skeleton.get_bone_rest(target_bone_index).basis.get_rotation_quaternion()
	var target_rotation := (target_rest_rotation * correction).normalized()
	var target_track_index := remapped.add_track(Animation.TYPE_ROTATION_3D)
	remapped.track_set_path(target_track_index, target_path)
	remapped.track_set_interpolation_type(target_track_index, Animation.INTERPOLATION_LINEAR)
	remapped.track_insert_key(target_track_index, 0.0, target_rotation)
	if remapped.length > 0.0:
		remapped.track_insert_key(target_track_index, remapped.length, target_rotation)


func _add_upper_unit_arm_track(remapped: Animation, target_skeleton: Skeleton3D, target_skeleton_path: NodePath, used_paths: Dictionary, target_bone: String, side_sign: float, swing_amount: float) -> void:
	var target_bone_index := target_skeleton.find_bone(target_bone)
	if target_bone_index < 0:
		return

	var target_path := NodePath("%s:%s" % [str(target_skeleton_path), target_bone])
	if used_paths.has(str(target_path)):
		return
	used_paths[str(target_path)] = true

	var target_rest_rotation := target_skeleton.get_bone_rest(target_bone_index).basis.get_rotation_quaternion()
	var target_track_index := remapped.add_track(Animation.TYPE_ROTATION_3D)
	remapped.track_set_path(target_track_index, target_path)
	remapped.track_set_interpolation_type(target_track_index, Animation.INTERPOLATION_LINEAR)

	if remapped.length <= 0.0 or swing_amount <= 0.0:
		var correction := Quaternion(Vector3.RIGHT, UNIT_UPPER_ARM_RELAX_X)
		remapped.track_insert_key(target_track_index, 0.0, (target_rest_rotation * correction).normalized())
		if remapped.length > 0.0:
			remapped.track_insert_key(target_track_index, remapped.length, (target_rest_rotation * correction).normalized())
		return

	for key_index in range(UNIT_ARM_SWING_KEYS + 1):
		var key_time := remapped.length * float(key_index) / float(UNIT_ARM_SWING_KEYS)
		var cycle := TAU * float(key_index) / float(UNIT_ARM_SWING_KEYS)
		var swing := sin(cycle) * swing_amount * side_sign
		var correction := Quaternion(Vector3.RIGHT, UNIT_UPPER_ARM_RELAX_X) * Quaternion(Vector3(0.0, 0.0, 1.0), swing)
		remapped.track_insert_key(target_track_index, key_time, (target_rest_rotation * correction).normalized())


func _unit_animation_arm_swing_amount(animation_name: String) -> float:
	var lower_name := animation_name.to_lower()
	if lower_name.find("sprint") >= 0:
		return UNIT_ARM_SWING_SPRINT
	if lower_name.find("jog") >= 0:
		return UNIT_ARM_SWING_JOG
	if lower_name.find("walk") >= 0:
		return UNIT_ARM_SWING_WALK
	if lower_name.find("crouch") >= 0:
		return UNIT_ARM_SWING_CROUCH
	return 0.0


func _source_bone_name_from_track_path(track_path: NodePath) -> String:
	var path_text := str(track_path)
	var separator_index := path_text.rfind(":")
	if separator_index < 0:
		return ""
	return path_text.substr(separator_index + 1)


func _unit_animation_name_is_loop(animation_name: String) -> bool:
	var lower_name := animation_name.to_lower()
	return (
		lower_name.find("idle") >= 0
		or lower_name.find("walk") >= 0
		or lower_name.find("jog") >= 0
		or lower_name.find("sprint") >= 0
		or lower_name.find("crouch") >= 0
		or lower_name.find("dance") >= 0
		or lower_name.find("swim") >= 0
		or lower_name.find("push") >= 0
		or lower_name.find("driving") >= 0
	)


func _play_animation_on_selected_units(animation_name: String) -> void:
	for unit_id_value in selected_unit_ids:
		_play_unit_animation(str(unit_id_value), animation_name)
	_refresh_animation_picker()


func _play_unit_animation(unit_id: String, animation_name: String, playback_speed: float = 1.0) -> void:
	var actor = unit_actors_by_id.get(unit_id)
	if actor != null and is_instance_valid(actor):
		actor.play_animation(animation_name, 0.18, playback_speed)
		return

	var player := unit_animation_players_by_id.get(unit_id) as AnimationPlayer
	if player == null or not is_instance_valid(player):
		return
	if not player.has_animation(animation_name):
		return

	var unit_node := unit_nodes_by_id.get(unit_id) as Node3D
	var clamped_playback_speed: float = max(0.05, playback_speed)
	if (
		unit_node != null
		and unit_node.has_meta("current_animation")
		and str(unit_node.get_meta("current_animation")) == animation_name
		and is_equal_approx(float(unit_node.get_meta("current_animation_speed", 1.0)), clamped_playback_speed)
		and player.is_playing()
	):
		return

	player.play(animation_name, 0.18, clamped_playback_speed)
	if unit_node != null:
		unit_node.set_meta("current_animation", animation_name)
		unit_node.set_meta("current_animation_speed", clamped_playback_speed)


func _current_selection_animation_name() -> String:
	if selected_unit_ids.is_empty():
		return ""
	var unit_node := unit_nodes_by_id.get(str(selected_unit_ids[0])) as Node3D
	if unit_node == null or not unit_node.has_meta("current_animation"):
		return ""
	return str(unit_node.get_meta("current_animation"))


func _create_unit_selection_marker() -> void:
	if terrain_root == null:
		return

	selected_unit_markers_by_id.clear()
	unit_visibility_markers_by_id.clear()
	unit_move_order_line_markers_by_id.clear()
	unit_move_order_cones_by_id.clear()
	if unit_selection_marker_mesh == null:
		unit_selection_marker_mesh = _build_unit_selection_marker_mesh()
	if unit_visibility_marker_mesh == null:
		unit_visibility_marker_mesh = _build_unit_visibility_marker_mesh()
	if unit_move_order_cone_mesh == null:
		unit_move_order_cone_mesh = _build_unit_move_order_cone_mesh()
	if unit_move_order_line_material == null:
		unit_move_order_line_material = _transparent_unshaded_material(Color(0.40, 0.90, 1.0, 0.68), true)
	if unit_move_order_cone_material == null:
		unit_move_order_cone_material = _transparent_unshaded_material(Color(0.38, 0.86, 1.0, 0.62))


func _build_unit_selection_marker_mesh() -> ArrayMesh:
	return _build_ring_marker_mesh(UNIT_SELECTION_RING_RADIUS, Color(0.48, 0.88, 1.0, 0.92))


func _build_unit_visibility_marker_mesh() -> ArrayMesh:
	return _build_ring_marker_mesh(UNIT_VISIBILITY_RING_RADIUS, Color(0.52, 0.84, 1.0, 0.24))


func _build_ring_marker_mesh(radius: float, ring_color: Color) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var segments := 64
	for segment in range(segments):
		var angle_a: float = TAU * float(segment) / float(segments)
		var angle_b: float = TAU * float(segment + 1) / float(segments)
		vertices.append(Vector3(cos(angle_a) * radius, 0.0, sin(angle_a) * radius))
		vertices.append(Vector3(cos(angle_b) * radius, 0.0, sin(angle_b) * radius))
		colors.append(ring_color)
		colors.append(ring_color)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.surface_set_material(0, material)
	return mesh


func _build_unit_move_order_cone_mesh() -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = UNIT_MOVE_ORDER_CONE_RADIUS
	mesh.height = UNIT_MOVE_ORDER_CONE_HEIGHT
	mesh.radial_segments = 16
	return mesh


func _unit_at_screen(screen_position: Vector2) -> Dictionary:
	if camera == null:
		return {}

	var best_unit_id := ""
	var best_unit_data = null
	var best_unit_node: Node3D = null
	var best_distance_sq := UNIT_SELECTION_CLICK_RADIUS * UNIT_SELECTION_CLICK_RADIUS
	for unit_data in battle_units:
		var unit_id := str(unit_data.id)
		var unit_node := unit_nodes_by_id.get(unit_id) as Node3D
		if unit_node == null:
			continue

		var world_center := unit_node.global_position + Vector3(0.0, UNIT_VISUAL_HEIGHT * 0.48, 0.0)
		var world_feet := unit_node.global_position + Vector3(0.0, 0.35, 0.0)
		if camera.is_position_behind(world_center) and camera.is_position_behind(world_feet):
			continue

		var center_screen := camera.unproject_position(world_center)
		var feet_screen := camera.unproject_position(world_feet)
		var distance_sq: float = min(screen_position.distance_squared_to(center_screen), screen_position.distance_squared_to(feet_screen))
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best_unit_id = unit_id
			best_unit_data = unit_data
			best_unit_node = unit_node

	if best_unit_id.is_empty():
		return {}
	return {
		"id": best_unit_id,
		"data": best_unit_data,
		"node": best_unit_node,
	}


func _resource_at_screen(screen_position: Vector2):
	if camera == null or resource_nodes_by_id.is_empty():
		return null

	var best_resource = null
	var best_distance_sq := RESOURCE_SELECTION_CLICK_RADIUS * RESOURCE_SELECTION_CLICK_RADIUS
	for resource_value in resource_nodes_by_id.values():
		var resource = resource_value
		if resource == null or not resource.is_available():
			continue

		var base_position: Vector3 = resource.world_position + Vector3(0.0, 0.35, 0.0)
		var upper_position: Vector3 = resource.world_position + Vector3(0.0, max(0.75, float(resource.selection_height)), 0.0)
		if camera.is_position_behind(base_position) and camera.is_position_behind(upper_position):
			continue

		var base_screen := camera.unproject_position(base_position)
		var upper_screen := camera.unproject_position(upper_position)
		var distance_sq: float = min(screen_position.distance_squared_to(base_screen), screen_position.distance_squared_to(upper_screen))
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best_resource = resource

	return best_resource


func _update_resource_hover(screen_position: Vector2) -> void:
	if _is_screen_point_in_hud(screen_position):
		_clear_resource_hover()
		return
	var resource = _resource_at_screen(screen_position)
	if resource == hovered_resource:
		return
	hovered_resource = resource
	if hovered_resource == null:
		_clear_resource_hover()
		return
	_ensure_resource_hover_ring()
	_sync_unit_selection_cursor()
	_update_hovered_resource_visual()


func _update_hovered_resource_visual() -> void:
	if hovered_resource != null and (not hovered_resource.is_available() or free_roam_enabled):
		_clear_resource_hover()
		return
	if hovered_resource == null:
		if resource_hover_ring != null:
			resource_hover_ring.visible = false
		return
	_ensure_resource_hover_ring()
	var radius: float = clamp(float(hovered_resource.visual_radius), 1.2, 7.5) * 1.08
	resource_hover_ring.position = hovered_resource.world_position + Vector3(0.0, RESOURCE_RING_SURFACE_OFFSET + 0.04, 0.0)
	resource_hover_ring.scale = Vector3(radius, 1.0, radius)
	resource_hover_ring.visible = true


func _ensure_resource_hover_ring() -> void:
	if resource_hover_ring != null or terrain_root == null:
		return
	resource_hover_ring = MeshInstance3D.new()
	resource_hover_ring.name = "HoveredResourceRing"
	resource_hover_ring.mesh = _resource_ring_mesh()
	resource_hover_ring.material_override = _resource_hover_ring_material()
	resource_hover_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	resource_hover_ring.visible = false
	terrain_root.add_child(resource_hover_ring)


func _resource_hover_ring_material() -> StandardMaterial3D:
	var material := _transparent_unshaded_material(Color(0.54, 1.0, 0.72, 0.82))
	material.no_depth_test = false
	return material


func _clear_resource_hover() -> void:
	hovered_resource = null
	if resource_hover_ring != null:
		resource_hover_ring.visible = false
	if resource_hover_cursor_active:
		resource_hover_cursor_active = false
		_apply_active_order_cursor()


func _select_unit_from_screen(screen_position: Vector2, additive: bool = false) -> void:
	var hit := _unit_at_screen(screen_position)
	if hit.is_empty():
		if not additive:
			_clear_unit_selection()
		_refresh_overlay()
		return

	var unit_id := str(hit.get("id", ""))
	if additive:
		_toggle_unit_selection(unit_id)
	else:
		_set_selected_unit(unit_id, hit.get("data"), hit.get("node") as Node3D)
	_refresh_overlay()


func _begin_unit_selection_drag(screen_position: Vector2) -> void:
	unit_selection_dragging = true
	unit_selection_drag_start = screen_position
	unit_selection_drag_end = screen_position
	_update_drag_selection_overlay(false)


func _update_unit_selection_drag(screen_position: Vector2) -> void:
	unit_selection_drag_end = screen_position
	var draw_box := unit_selection_drag_start.distance_to(unit_selection_drag_end) >= UNIT_SELECTION_DRAG_THRESHOLD
	_update_drag_selection_overlay(draw_box)


func _finish_unit_selection_drag(screen_position: Vector2) -> void:
	var start_position := unit_selection_drag_start
	var end_position := screen_position
	var drag_distance := start_position.distance_to(end_position)
	var additive := Input.is_key_pressed(KEY_SHIFT)
	_cancel_unit_selection_drag()

	if drag_distance < UNIT_SELECTION_DRAG_THRESHOLD:
		_select_unit_from_screen(end_position, additive)
	else:
		_select_units_in_screen_rect(start_position, end_position, additive)


func _cancel_unit_selection_drag() -> void:
	unit_selection_dragging = false
	unit_selection_drag_start = Vector2.ZERO
	unit_selection_drag_end = Vector2.ZERO
	_update_drag_selection_overlay(false)


func _update_drag_selection_overlay(visible: bool) -> void:
	if drag_selection_overlay == null:
		return

	drag_selection_overlay.dragging = visible
	drag_selection_overlay.start_position = unit_selection_drag_start
	drag_selection_overlay.end_position = unit_selection_drag_end
	drag_selection_overlay.queue_redraw()


func _select_units_in_screen_rect(start_position: Vector2, end_position: Vector2, additive: bool = false) -> void:
	if camera == null:
		return

	var selection_rect := _screen_rect_from_points(start_position, end_position)
	var unit_ids: Array = []
	for unit_data in battle_units:
		var unit_id := str(unit_data.id)
		var unit_node := unit_nodes_by_id.get(unit_id) as Node3D
		if unit_node == null:
			continue

		var world_center := unit_node.global_position + Vector3(0.0, UNIT_VISUAL_HEIGHT * 0.48, 0.0)
		var world_feet := unit_node.global_position + Vector3(0.0, 0.35, 0.0)
		if camera.is_position_behind(world_center) and camera.is_position_behind(world_feet):
			continue

		var center_screen := camera.unproject_position(world_center)
		var feet_screen := camera.unproject_position(world_feet)
		if selection_rect.has_point(center_screen) or selection_rect.has_point(feet_screen):
			unit_ids.append(unit_id)

	if additive:
		_add_selected_units(unit_ids)
	else:
		_set_selected_units(unit_ids)
	_refresh_overlay()


func _screen_rect_from_points(a: Vector2, b: Vector2) -> Rect2:
	var top_left := Vector2(min(a.x, b.x), min(a.y, b.y))
	var bottom_right := Vector2(max(a.x, b.x), max(a.y, b.y))
	return Rect2(top_left, bottom_right - top_left)


func _unit_data_by_id(unit_id: String):
	for unit_data in battle_units:
		if str(unit_data.id) == unit_id:
			return unit_data
	return null


func _set_selected_unit(unit_id: String, unit_data, unit_node: Node3D) -> void:
	selected_unit_ids.clear()
	selected_unit_ids.append(unit_id)
	selected_unit_id = unit_id
	selected_unit_data = unit_data
	selected_unit_node = unit_node
	_update_unit_selection_marker()
	_sync_unit_selection_cursor()


func _set_selected_units(unit_ids: Array) -> void:
	if unit_ids.is_empty():
		_clear_unit_selection()
		return

	selected_unit_ids.clear()
	for unit_id in unit_ids:
		var id_text := str(unit_id)
		if not selected_unit_ids.has(id_text):
			selected_unit_ids.append(id_text)

	selected_unit_id = str(selected_unit_ids[0])
	selected_unit_data = _unit_data_by_id(selected_unit_id)
	selected_unit_node = unit_nodes_by_id.get(selected_unit_id) as Node3D
	_update_unit_selection_marker()
	_sync_unit_selection_cursor()


func _add_selected_units(unit_ids: Array) -> void:
	for unit_id in unit_ids:
		var id_text := str(unit_id)
		if id_text.is_empty() or selected_unit_ids.has(id_text):
			continue
		selected_unit_ids.append(id_text)

	if selected_unit_ids.is_empty():
		_clear_unit_selection()
		return

	selected_unit_id = str(selected_unit_ids[0])
	selected_unit_data = _unit_data_by_id(selected_unit_id)
	selected_unit_node = unit_nodes_by_id.get(selected_unit_id) as Node3D
	_update_unit_selection_marker()
	_sync_unit_selection_cursor()


func _toggle_unit_selection(unit_id: String) -> void:
	if unit_id.is_empty():
		return

	if selected_unit_ids.has(unit_id):
		selected_unit_ids.erase(unit_id)
	else:
		selected_unit_ids.append(unit_id)

	if selected_unit_ids.is_empty():
		_clear_unit_selection()
		return

	selected_unit_id = str(selected_unit_ids[0])
	selected_unit_data = _unit_data_by_id(selected_unit_id)
	selected_unit_node = unit_nodes_by_id.get(selected_unit_id) as Node3D
	_update_unit_selection_marker()
	_sync_unit_selection_cursor()


func _clear_unit_selection() -> void:
	selected_unit_ids.clear()
	selected_unit_id = ""
	selected_unit_data = null
	selected_unit_node = null
	_clear_selection_markers()
	_sync_unit_selection_cursor()


func _sync_unit_selection_cursor() -> void:
	var has_selected_human := not _valid_selected_unit_ids().is_empty()
	Game.set_thing_selected_cursor_active(has_selected_human)
	if hovered_resource == null:
		return
	if has_selected_human:
		resource_hover_cursor_active = true
		Game.set_interact_order_cursor_active(true)
	elif resource_hover_cursor_active:
		resource_hover_cursor_active = false
		_apply_active_order_cursor()


func _update_unit_selection_marker() -> void:
	if terrain_root == null:
		return

	var active_ids := {}
	for unit_id_value in selected_unit_ids:
		var unit_id := str(unit_id_value)
		var unit_node := unit_nodes_by_id.get(unit_id) as Node3D
		if unit_node == null or not is_instance_valid(unit_node):
			continue

		var marker := _selection_marker_for_unit_id(unit_id)
		marker.visible = true
		marker.global_position = unit_node.global_position + Vector3(0.0, 0.10, 0.0)
		active_ids[unit_id] = true

	for marker_id_value in selected_unit_markers_by_id.keys():
		var marker_id := str(marker_id_value)
		if active_ids.has(marker_id):
			continue
		var marker := selected_unit_markers_by_id.get(marker_id) as MeshInstance3D
		if marker != null and is_instance_valid(marker):
			marker.queue_free()
		selected_unit_markers_by_id.erase(marker_id)

	_update_unit_visibility_markers()
	_update_move_order_markers()


func _selection_marker_for_unit_id(unit_id: String) -> MeshInstance3D:
	var existing_marker := selected_unit_markers_by_id.get(unit_id) as MeshInstance3D
	if existing_marker != null and is_instance_valid(existing_marker):
		return existing_marker

	if unit_selection_marker_mesh == null:
		unit_selection_marker_mesh = _build_unit_selection_marker_mesh()

	var marker := MeshInstance3D.new()
	marker.name = "SelectedUnitMarker_%s" % unit_id
	marker.mesh = unit_selection_marker_mesh
	marker.visible = false
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	terrain_root.add_child(marker)
	selected_unit_markers_by_id[unit_id] = marker
	return marker


func _update_unit_visibility_markers() -> void:
	if terrain_root == null:
		return

	var active_ids := {}
	if selected_unit_ids.is_empty():
		for unit_data in battle_units:
			var unit_id := str(unit_data.id)
			var unit_node := unit_nodes_by_id.get(unit_id) as Node3D
			if unit_node == null or not is_instance_valid(unit_node):
				continue

			var marker := _visibility_marker_for_unit_id(unit_id)
			marker.visible = true
			marker.global_position = unit_node.global_position + Vector3(0.0, 0.08, 0.0)
			active_ids[unit_id] = true

	for marker_id_value in unit_visibility_markers_by_id.keys():
		var marker_id := str(marker_id_value)
		if active_ids.has(marker_id):
			continue
		var marker := unit_visibility_markers_by_id.get(marker_id) as MeshInstance3D
		if marker != null and is_instance_valid(marker):
			marker.queue_free()
		unit_visibility_markers_by_id.erase(marker_id)


func _visibility_marker_for_unit_id(unit_id: String) -> MeshInstance3D:
	var existing_marker := unit_visibility_markers_by_id.get(unit_id) as MeshInstance3D
	if existing_marker != null and is_instance_valid(existing_marker):
		return existing_marker

	if unit_visibility_marker_mesh == null:
		unit_visibility_marker_mesh = _build_unit_visibility_marker_mesh()

	var marker := MeshInstance3D.new()
	marker.name = "UnitVisibilityMarker_%s" % unit_id
	marker.mesh = unit_visibility_marker_mesh
	marker.visible = false
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	terrain_root.add_child(marker)
	unit_visibility_markers_by_id[unit_id] = marker
	return marker


func _update_move_order_markers() -> void:
	if terrain_root == null:
		return

	var active_ids := {}
	for unit_id_value in selected_unit_ids:
		var unit_id := str(unit_id_value)
		var actor = unit_actors_by_id.get(unit_id)
		if actor == null or not is_instance_valid(actor) or not actor.has_move_order():
			continue

		var unit_node := unit_nodes_by_id.get(unit_id) as Node3D
		if unit_node == null or not is_instance_valid(unit_node):
			continue

		var target: Vector3 = actor.move_order_target()
		var line_marker := _move_order_line_marker_for_unit_id(unit_id)
		line_marker.visible = true
		line_marker.mesh = _build_move_order_line_mesh(unit_node.global_position, target)

		var cone_marker := _move_order_cone_for_unit_id(unit_id)
		cone_marker.visible = true
		cone_marker.global_position = target + Vector3(0.0, UNIT_MOVE_ORDER_CONE_HEIGHT * 0.5 + 0.35, 0.0)
		active_ids[unit_id] = true

	_clear_inactive_move_order_markers(active_ids)


func _move_order_line_marker_for_unit_id(unit_id: String) -> MeshInstance3D:
	var existing_marker := unit_move_order_line_markers_by_id.get(unit_id) as MeshInstance3D
	if existing_marker != null and is_instance_valid(existing_marker):
		return existing_marker

	var marker := MeshInstance3D.new()
	marker.name = "MoveOrderLine_%s" % unit_id
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	terrain_root.add_child(marker)
	unit_move_order_line_markers_by_id[unit_id] = marker
	return marker


func _move_order_cone_for_unit_id(unit_id: String) -> MeshInstance3D:
	var existing_marker := unit_move_order_cones_by_id.get(unit_id) as MeshInstance3D
	if existing_marker != null and is_instance_valid(existing_marker):
		return existing_marker

	if unit_move_order_cone_mesh == null:
		unit_move_order_cone_mesh = _build_unit_move_order_cone_mesh()
	if unit_move_order_cone_material == null:
		unit_move_order_cone_material = _transparent_unshaded_material(Color(0.38, 0.86, 1.0, 0.62))

	var marker := MeshInstance3D.new()
	marker.name = "MoveOrderCone_%s" % unit_id
	marker.mesh = unit_move_order_cone_mesh
	marker.material_override = unit_move_order_cone_material
	marker.visible = false
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	terrain_root.add_child(marker)
	unit_move_order_cones_by_id[unit_id] = marker
	return marker


func _clear_inactive_move_order_markers(active_ids: Dictionary) -> void:
	for marker_id_value in unit_move_order_line_markers_by_id.keys():
		var marker_id := str(marker_id_value)
		if active_ids.has(marker_id):
			continue
		var marker := unit_move_order_line_markers_by_id.get(marker_id) as MeshInstance3D
		if marker != null and is_instance_valid(marker):
			marker.queue_free()
		unit_move_order_line_markers_by_id.erase(marker_id)

	for marker_id_value in unit_move_order_cones_by_id.keys():
		var marker_id := str(marker_id_value)
		if active_ids.has(marker_id):
			continue
		var marker := unit_move_order_cones_by_id.get(marker_id) as MeshInstance3D
		if marker != null and is_instance_valid(marker):
			marker.queue_free()
		unit_move_order_cones_by_id.erase(marker_id)


func _build_move_order_line_mesh(start: Vector3, target: Vector3) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var flat_distance := Vector2(start.x, start.z).distance_to(Vector2(target.x, target.z))
	var segments: int = clampi(int(ceil(flat_distance / UNIT_MOVE_ORDER_LINE_SAMPLE_STEP)), 1, UNIT_MOVE_ORDER_LINE_MAX_SEGMENTS)
	var previous := _move_order_line_sample_position(start, target, 0.0)
	for index in range(1, segments + 1):
		var t: float = float(index) / float(segments)
		var current := _move_order_line_sample_position(start, target, t)
		vertices.append(previous)
		vertices.append(current)
		colors.append(Color(0.40, 0.90, 1.0, 0.68))
		colors.append(Color(0.40, 0.90, 1.0, 0.68))
		previous = current

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	mesh.surface_set_material(0, unit_move_order_line_material)
	return mesh


func _move_order_line_sample_position(start: Vector3, target: Vector3, t: float) -> Vector3:
	var x := lerpf(start.x, target.x, t)
	var z := lerpf(start.z, target.z, t)
	return _ground_position_for_local(x, z) + Vector3(0.0, UNIT_MOVE_ORDER_LINE_SURFACE_OFFSET, 0.0)


func _clear_selection_markers() -> void:
	for marker_value in selected_unit_markers_by_id.values():
		var marker := marker_value as MeshInstance3D
		if marker != null and is_instance_valid(marker):
			marker.queue_free()
	selected_unit_markers_by_id.clear()
	_update_unit_visibility_markers()
	_clear_inactive_move_order_markers({})


func _is_jog_move_order_click(screen_position: Vector2) -> bool:
	var now_msec := Time.get_ticks_msec()
	if now_msec - last_move_order_click_msec > UNIT_MOVE_DOUBLE_CLICK_MAX_MS:
		return false
	return screen_position.distance_to(last_move_order_click_position) <= UNIT_MOVE_DOUBLE_CLICK_MAX_DISTANCE


func _remember_move_order_click(screen_position: Vector2) -> void:
	last_move_order_click_msec = Time.get_ticks_msec()
	last_move_order_click_position = screen_position


func _issue_gather_order_to_selected_units(resource) -> bool:
	var selected_ids := _valid_selected_unit_ids()
	if selected_ids.is_empty() or resource == null or not resource.is_available():
		return false

	var gather_ids: Array = []
	for unit_id_value in selected_ids:
		var unit_data = _unit_data_by_id(str(unit_id_value))
		if unit_data != null and unit_data.can_gather():
			gather_ids.append(str(unit_id_value))
	if gather_ids.is_empty():
		return false

	var move_animation := _first_available_unit_animation(UNIT_CARRY_WALK_ANIMATION_CANDIDATES if _selection_has_carried_resources(gather_ids) else UNIT_WALK_ANIMATION_CANDIDATES)
	for index in range(gather_ids.size()):
		var unit_id := str(gather_ids[index])
		var actor = unit_actors_by_id.get(unit_id)
		if actor == null or not is_instance_valid(actor):
			continue

		var action = _make_gather_action_for_unit(actor, resource, index, gather_ids.size())
		actor.issue_gather_action(action)
		actor.issue_move_order(_make_unit_move_order(action.approach_position, false), false)
		if not move_animation.is_empty():
			_play_unit_animation(unit_id, move_animation, UNIT_WALK_ANIMATION_SPEED)

	Game.debug_event("gather_order units=%d target=%s type=%s" % [gather_ids.size(), str(resource.id), str(resource.resource_type)])
	_update_unit_selection_marker()
	_refresh_overlay()
	return true


func _make_gather_action_for_unit(actor, resource, unit_index: int, unit_count: int):
	var target_position: Vector3 = resource.world_position
	var direction := Vector3(actor.position.x - target_position.x, 0.0, actor.position.z - target_position.z)
	if direction.length_squared() <= 0.001:
		var angle: float = TAU * float(unit_index) / float(max(1, unit_count))
		direction = Vector3(cos(angle), 0.0, sin(angle))
	direction = direction.normalized()
	var side_angle: float = (float(unit_index) - float(unit_count - 1) * 0.5) * 0.18
	direction = direction.rotated(Vector3.UP, side_angle)
	var approach_distance: float = max(2.4, float(resource.gather_range) * 0.70)
	var approach := _ground_position_for_local(target_position.x + direction.x * approach_distance, target_position.z + direction.z * approach_distance)
	return RTSUnitGatherActionScript.new(
		str(resource.id),
		str(resource.resource_type),
		target_position,
		approach,
		float(resource.work_required),
		int(resource.harvest_amount),
		float(resource.gather_range)
	)


func _selection_has_carried_resources(unit_ids: Array) -> bool:
	for unit_id_value in unit_ids:
		var actor = unit_actors_by_id.get(str(unit_id_value))
		if actor != null and is_instance_valid(actor) and actor.carried_total() > 0:
			return true
	return false


func _issue_move_order_to_selected_units(screen_position: Vector2, jog_order: bool = false) -> bool:
	var selected_ids := _valid_selected_unit_ids()
	if selected_ids.is_empty():
		return false

	var ground_hit := _screen_to_ground_position(screen_position)
	if ground_hit.is_empty():
		return false

	var formation_center := ground_hit["position"] as Vector3
	var formation_targets := _formation_targets_for_units(selected_ids, formation_center)
	var walk_animation := _first_available_unit_animation(UNIT_WALK_ANIMATION_CANDIDATES)
	var jog_animation := _first_available_unit_animation(UNIT_JOG_ANIMATION_CANDIDATES)
	var carry_walk_animation := _first_available_unit_animation(UNIT_CARRY_WALK_ANIMATION_CANDIDATES)
	var jogging_unit_count := 0
	for unit_id in selected_ids:
		if not formation_targets.has(unit_id):
			continue
		var actor = unit_actors_by_id.get(unit_id)
		if actor == null or not is_instance_valid(actor):
			continue
		var is_carrying: bool = actor.carried_total() > 0
		var unit_jog_order: bool = jog_order and not is_carrying
		actor.issue_move_order(_make_unit_move_order(formation_targets[unit_id], unit_jog_order))
		var unit_move_animation := jog_animation if unit_jog_order else walk_animation
		var animation_speed := 1.0 if unit_jog_order else UNIT_WALK_ANIMATION_SPEED
		if is_carrying and not carry_walk_animation.is_empty():
			unit_move_animation = carry_walk_animation
		if unit_jog_order:
			jogging_unit_count += 1
		if not unit_move_animation.is_empty():
			_play_unit_animation(unit_id, unit_move_animation, animation_speed)

	var order_label := "jog" if jogging_unit_count == selected_ids.size() else ("mixed_move" if jogging_unit_count > 0 else "move")
	Game.debug_event("%s_order units=%d x=%.1f z=%.1f" % [order_label, selected_ids.size(), formation_center.x, formation_center.z])
	_update_unit_selection_marker()
	_refresh_overlay()
	return true


func _make_unit_move_order(target: Vector3, jog_order: bool):
	return RTSUnitMoveOrderScript.new(
		target,
		RTSUnitMoveOrderScript.GAIT_JOG if jog_order else RTSUnitMoveOrderScript.GAIT_WALK,
		UNIT_JOG_SPEED_MULTIPLIER if jog_order else UNIT_WALK_SPEED_MULTIPLIER,
		1.0 if jog_order else UNIT_WALK_ANIMATION_SPEED
	)


func _screen_to_ground_position(screen_position: Vector2) -> Dictionary:
	if camera == null:
		return {}

	var origin: Vector3 = camera.project_ray_origin(screen_position)
	var direction: Vector3 = camera.project_ray_normal(screen_position)
	if abs(direction.y) <= 0.0001:
		return {}

	var distance_to_plane: float = -origin.y / direction.y
	if distance_to_plane < 0.0:
		return {}

	var approximate_hit: Vector3 = origin + direction * distance_to_plane
	var half_size := MAP_SIZE * 0.5
	var x: float = clamp(approximate_hit.x, -half_size, half_size)
	var z: float = clamp(approximate_hit.z, -half_size, half_size)
	return {
		"position": _ground_position_for_local(x, z),
	}


func _valid_selected_unit_ids() -> Array:
	var unit_ids: Array = []
	for unit_id_value in selected_unit_ids:
		var unit_id := str(unit_id_value)
		var unit_node := unit_nodes_by_id.get(unit_id) as Node3D
		var unit_data = _unit_data_by_id(unit_id)
		if unit_node == null or not is_instance_valid(unit_node) or unit_data == null:
			continue
		unit_ids.append(unit_id)
	return unit_ids


func _formation_targets_for_units(unit_ids: Array, center: Vector3) -> Dictionary:
	var targets := {}
	if unit_ids.is_empty():
		return targets

	if unit_ids.size() == 1:
		targets[str(unit_ids[0])] = _ground_position_for_local(center.x, center.z)
		return targets

	var current_center := _selected_units_center(unit_ids)
	var move_direction := Vector3(center.x - current_center.x, 0.0, center.z - current_center.z)
	if move_direction.length_squared() <= 0.001:
		move_direction = _camera_flat_forward()
	move_direction.y = 0.0
	if move_direction.length_squared() <= 0.001:
		move_direction = Vector3.FORWARD
	move_direction = move_direction.normalized()

	var bar_axis := Vector3(-move_direction.z, 0.0, move_direction.x)
	if bar_axis.length_squared() <= 0.001:
		bar_axis = _camera_flat_right()
	if bar_axis.length_squared() <= 0.001:
		bar_axis = Vector3.RIGHT
	bar_axis = bar_axis.normalized()

	var sorted_entries: Array = []
	for unit_id_value in unit_ids:
		var unit_id := str(unit_id_value)
		var unit_node := unit_nodes_by_id.get(unit_id) as Node3D
		if unit_node == null:
			continue
		sorted_entries.append({
			"id": unit_id,
			"order": unit_node.global_position.dot(bar_axis),
		})
	sorted_entries.sort_custom(Callable(self, "_sort_formation_entries_by_order"))

	var half_size := MAP_SIZE * 0.5
	var start_offset := -UNIT_MOVE_FORMATION_SPACING * float(sorted_entries.size() - 1) * 0.5
	for index in range(sorted_entries.size()):
		var unit_id := str(sorted_entries[index].get("id", ""))
		var offset := start_offset + float(index) * UNIT_MOVE_FORMATION_SPACING
		var target := center + bar_axis * offset
		target.x = clamp(target.x, -half_size, half_size)
		target.z = clamp(target.z, -half_size, half_size)
		targets[unit_id] = _ground_position_for_local(target.x, target.z)
	return targets


func _sort_formation_entries_by_order(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("order", 0.0)) < float(b.get("order", 0.0))


func _selected_units_center(unit_ids: Array) -> Vector3:
	var center := Vector3.ZERO
	var count := 0
	for unit_id_value in unit_ids:
		var unit_node := unit_nodes_by_id.get(str(unit_id_value)) as Node3D
		if unit_node == null:
			continue
		center += unit_node.global_position
		count += 1
	if count <= 0:
		return Vector3.ZERO
	return center / float(count)


func _camera_flat_forward() -> Vector3:
	if camera == null:
		return Vector3.FORWARD
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		return Vector3.FORWARD
	return forward.normalized()


func _camera_flat_right() -> Vector3:
	if camera == null:
		return Vector3.RIGHT
	var right := camera.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() <= 0.001:
		return Vector3.RIGHT
	return right.normalized()


func _update_unit_movement(delta: float) -> void:
	if unit_actors_by_id.is_empty():
		return

	var idle_animation := _first_available_unit_animation(UNIT_IDLE_ANIMATION_CANDIDATES)
	var walk_animation := _first_available_unit_animation(UNIT_WALK_ANIMATION_CANDIDATES)
	var jog_animation := _first_available_unit_animation(UNIT_JOG_ANIMATION_CANDIDATES)
	var carry_walk_animation := _first_available_unit_animation(UNIT_CARRY_WALK_ANIMATION_CANDIDATES)
	var carry_idle_animation := _first_available_unit_animation(UNIT_CARRY_IDLE_ANIMATION_CANDIDATES)
	var swim_animation := _first_available_unit_animation(UNIT_SWIM_ANIMATION_CANDIDATES)
	var tread_animation := _first_available_unit_animation(UNIT_TREAD_WATER_ANIMATION_CANDIDATES)
	var surface_position_provider := Callable(self, "_unit_surface_position_for_local")
	for unit_id_value in unit_actors_by_id.keys():
		var unit_id := str(unit_id_value)
		var actor = unit_actors_by_id.get(unit_id)
		if actor == null or not is_instance_valid(actor):
			continue
		var was_swimming := bool(actor.get_meta("is_swimming", false))
		if actor.has_move_order():
			var move_gait := str(actor.current_order.gait)
			var is_carrying: bool = actor.carried_total() > 0
			var arrived: bool = actor.update_movement(delta, surface_position_provider, UNIT_MOVE_ARRIVAL_RADIUS, "")
			var is_swimming := _is_unit_swimming_at(actor.position.x, actor.position.z)
			actor.set_meta("is_swimming", is_swimming)
			if is_swimming:
				var water_animation := tread_animation if arrived else swim_animation
				if arrived:
					actor.position = _unit_treading_position_for_local(actor.position.x, actor.position.z)
					if actor.unit_data != null:
						actor.unit_data.position = actor.position
				if not water_animation.is_empty():
					actor.play_animation(water_animation, 0.20, 1.0)
			elif arrived:
				if is_carrying:
					_play_carry_stop_animation(actor)
				elif not idle_animation.is_empty():
					actor.play_animation(idle_animation)
			elif was_swimming:
				actor.reset_skeleton_pose()
				var land_animation := carry_walk_animation if is_carrying else (jog_animation if move_gait == RTSUnitMoveOrderScript.GAIT_JOG else walk_animation)
				if not land_animation.is_empty():
					actor.play_animation(land_animation, 0.0, UNIT_WALK_ANIMATION_SPEED)
			continue
		var is_swimming := _is_unit_swimming_at(actor.position.x, actor.position.z)
		actor.set_meta("is_swimming", is_swimming)
		if is_swimming and not tread_animation.is_empty():
			actor.position = _unit_treading_position_for_local(actor.position.x, actor.position.z)
			if actor.unit_data != null:
				actor.unit_data.position = actor.position
			actor.play_animation(tread_animation, 0.20, 1.0)
		elif was_swimming:
			actor.reset_skeleton_pose()
			var dry_animation := carry_idle_animation if actor.carried_total() > 0 else idle_animation
			if not dry_animation.is_empty():
				actor.play_animation(dry_animation, 0.0, 1.0)


func _update_carried_unit_animation_state() -> void:
	var carry_walk_animation := _first_available_unit_animation(UNIT_CARRY_WALK_ANIMATION_CANDIDATES)
	for actor_value in unit_actors_by_id.values():
		var actor = actor_value
		if actor == null or not is_instance_valid(actor):
			continue
		actor.set_animation_paused(false)
		if actor.carried_total() <= 0 or actor.has_move_order() or actor.has_gather_action() or actor.has_delivery_action():
			continue
		if not carry_walk_animation.is_empty() and str(actor.current_animation) == carry_walk_animation:
			_play_carry_stop_animation(actor)


func _play_carry_stop_animation(actor) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var carry_stop_animation := _first_available_unit_animation(UNIT_CARRY_STOP_ANIMATION_CANDIDATES)
	var carry_idle_animation := _first_available_unit_animation(UNIT_CARRY_IDLE_ANIMATION_CANDIDATES)
	if not carry_stop_animation.is_empty():
		actor.play_animation(carry_stop_animation, 0.14, 1.0)
		if not carry_idle_animation.is_empty():
			actor.queue_animation(carry_idle_animation, max(0.1, _unit_animation_duration(carry_stop_animation) * 0.92), 0.16, 1.0)
		return
	if not carry_idle_animation.is_empty():
		actor.play_animation(carry_idle_animation, 0.16, 1.0)


func _update_unit_gather_actions(delta: float) -> void:
	if unit_actors_by_id.is_empty() or resource_nodes_by_id.is_empty():
		return

	var chop_animation := _first_available_unit_animation(UNIT_CHOP_ANIMATION_CANDIDATES)
	var pickup_animation := _first_available_unit_animation(UNIT_PICKUP_ANIMATION_CANDIDATES)
	var carry_walk_animation := _first_available_unit_animation(UNIT_CARRY_WALK_ANIMATION_CANDIDATES)
	var carry_idle_animation := _first_available_unit_animation(UNIT_CARRY_IDLE_ANIMATION_CANDIDATES)
	for unit_id_value in unit_actors_by_id.keys():
		var unit_id := str(unit_id_value)
		var actor = unit_actors_by_id.get(unit_id)
		if actor == null or not is_instance_valid(actor) or not actor.has_gather_action():
			continue

		var action = actor.gather_action()
		var resource = resource_nodes_by_id.get(str(action.target_id))
		if resource == null or not resource.is_available():
			actor.clear_gather_action()
			continue

		var distance := Vector2(actor.position.x, actor.position.z).distance_to(Vector2(resource.world_position.x, resource.world_position.z))
		if distance > float(action.range):
			if not actor.has_move_order():
				actor.issue_move_order(_make_unit_move_order(action.approach_position, false), false)
				var move_animation := carry_walk_animation if actor.carried_total() > 0 and not carry_walk_animation.is_empty() else _first_available_unit_animation(UNIT_WALK_ANIMATION_CANDIDATES)
				if not move_animation.is_empty():
					_play_unit_animation(unit_id, move_animation, UNIT_WALK_ANIMATION_SPEED)
			continue

		actor.clear_move_order()
		actor.face_position(resource.world_position)
		var work_animation := chop_animation if str(resource.resource_type) == "wood" else pickup_animation
		if not work_animation.is_empty():
			_play_unit_animation(unit_id, work_animation, 1.0)
		var work_rate: float = TREE_CHOP_WORK_RATE * max(0.5, float(actor.unit_data.equipment_quality) if actor.unit_data != null else 1.0)
		if resource.add_work(delta * work_rate):
			if str(resource.stage) == RTSResourceNodeScript.STAGE_STANDING_TREE:
				_fell_tree_resource(resource)
			else:
				_complete_gather_action(actor, action, resource, pickup_animation, carry_idle_animation, carry_walk_animation)


func _complete_gather_action(actor, action, resource, pickup_animation: String, carry_idle_animation: String, carry_walk_animation: String) -> void:
	if actor == null or resource == null:
		return
	var harvested_amount: int = resource.harvest(actor.remaining_carry_capacity())
	if harvested_amount > 0:
		actor.add_carried_resource(str(action.resource_type), harvested_amount)
		_sync_actor_carried_resource_visual(actor)
		if str(resource.resource_type) == "wood" and str(resource.stage) == RTSResourceNodeScript.STAGE_FELLED_LOG:
			_sync_split_wood_piece_visibility(resource)
	if resource.depleted:
		resource.hide_visual()
	actor.clear_gather_action()
	var delivery_started := _start_delivery_if_available(actor)
	if not pickup_animation.is_empty():
		actor.play_animation(pickup_animation, 0.12, 1.0)
	if actor.carried_total() > 0:
		var next_animation := carry_walk_animation if delivery_started else carry_idle_animation
		if not next_animation.is_empty():
			actor.queue_animation(next_animation, 0.55, 0.18, 1.0)
	Game.debug_event("resource_gathered unit=%s type=%s amount=%d remaining=%d hp=%d/%d" % [
		str(actor.unit_id),
		str(action.resource_type),
		harvested_amount,
		int(resource.amount_remaining),
		int(resource.health),
		int(resource.max_health),
	])
	_refresh_context_panel()


func _fell_tree_resource(resource) -> void:
	resource.hide_visual(false)
	resource.set_visual_batches([], -1)
	resource.interaction_locked = true
	resource.show_ring = false
	resource.work_progress = 0.0
	_clear_gather_actions_for_resource(resource)
	var falling_visual := _spawn_falling_tree_visual(resource)
	if falling_visual == null:
		_complete_tree_fall(resource)
		return
	var fall_sign := -1.0 if (str(resource.id).hash() & 1) == 0 else 1.0
	resource.set_meta("tree_fall_sign", fall_sign)
	falling_tree_animations.append({
		"resource": resource,
		"node": falling_visual,
		"elapsed": 0.0,
		"fall_sign": fall_sign,
	})
	_rebuild_resource_ring_batches()
	Game.debug_event("tree_fall_started target=%s" % str(resource.id))


func _clear_gather_actions_for_resource(resource) -> void:
	for actor_value in unit_actors_by_id.values():
		var actor = actor_value
		if actor == null or not is_instance_valid(actor) or not actor.has_gather_action():
			continue
		var action = actor.gather_action()
		if str(action.target_id) == str(resource.id):
			actor.clear_gather_action()


func _spawn_falling_tree_visual(resource) -> Node3D:
	if resource == null or terrain_root == null:
		return null
	var scene := _tree_scene_for_path(str(resource.asset_path))
	if scene == null:
		return null
	var instance := scene.instantiate()
	if not instance is Node3D:
		instance.queue_free()
		return null
	var pivot := Node3D.new()
	pivot.name = "FallingTree_%s" % str(resource.id)
	pivot.position = Vector3(
		resource.world_position.x,
		_terrain_surface_height_for_local(resource.world_position.x, resource.world_position.z),
		resource.world_position.z
	)
	pivot.rotation.y = float(resource.rotation_y)
	terrain_root.add_child(pivot)
	var model := instance as Node3D
	pivot.add_child(model)
	model.scale = Vector3.ONE * float(resource.scale_value)
	_apply_battle_lit_materials(model)
	_set_shadow_casting(model, true)
	return pivot


func _update_falling_trees(delta: float) -> void:
	for index in range(falling_tree_animations.size() - 1, -1, -1):
		var fall := falling_tree_animations[index] as Dictionary
		var resource = fall.get("resource")
		var pivot := fall.get("node") as Node3D
		var elapsed := float(fall.get("elapsed", 0.0)) + maxf(0.0, delta)
		fall["elapsed"] = elapsed
		var fall_sign := float(fall.get("fall_sign", 1.0))
		var target_angle := fall_sign * PI * 0.5
		if pivot != null and is_instance_valid(pivot):
			if elapsed < TREE_FALL_DURATION:
				var fall_ratio := clampf(elapsed / TREE_FALL_DURATION, 0.0, 1.0)
				var eased_fall := 1.0 - pow(1.0 - fall_ratio, 3.0)
				pivot.rotation.z = target_angle * eased_fall
			else:
				var bounce_ratio := clampf((elapsed - TREE_FALL_DURATION) / TREE_IMPACT_BOUNCE_DURATION, 0.0, 1.0)
				pivot.rotation.z = target_angle - fall_sign * sin(bounce_ratio * PI) * TREE_IMPACT_REBOUND_RADIANS * (1.0 - bounce_ratio * 0.35)
		if elapsed < TREE_FALL_DURATION + TREE_IMPACT_BOUNCE_DURATION:
			continue
		if pivot != null and is_instance_valid(pivot):
			pivot.queue_free()
		_complete_tree_fall(resource)
		falling_tree_animations.remove_at(index)


func _complete_tree_fall(resource) -> void:
	if resource == null:
		return
	resource.transition_to_felled_log(FELLED_LOG_PROCESS_SECONDS)
	resource.interaction_locked = false
	var tree_length := _tree_base_height_for_asset(str(resource.asset_path)) * float(resource.scale_value)
	resource.visual_radius = max(4.5, tree_length * 0.48)
	resource.selection_height = max(1.4, float(resource.scale_value) * 1.1)
	resource.visual_node = _spawn_felled_resource_visual(resource)
	_rebuild_resource_ring_batches()
	Game.debug_event("tree_felled target=%s pieces=%d" % [str(resource.id), SPLIT_WOOD_PIECE_COUNT])


func _reset_gather_actions_for_felled_log(resource) -> void:
	for actor_value in unit_actors_by_id.values():
		var actor = actor_value
		if actor == null or not is_instance_valid(actor) or not actor.has_gather_action():
			continue
		var action = actor.gather_action()
		if str(action.target_id) != str(resource.id):
			continue
		action.work_required = float(resource.work_required)
		action.work_done = 0.0
		action.state = RTSUnitGatherActionScript.STATE_WORK


func _start_delivery_if_available(actor) -> bool:
	if actor == null or actor.carried_total() <= 0:
		return false
	var storage: RTSBuildingData = _nearest_storage_for_actor(actor)
	if storage == null:
		return false
	var action = RTSUnitDeliveryActionScript.new(str(storage.id), storage.position, STORAGE_DELIVERY_RANGE)
	actor.issue_delivery_action(action)
	actor.issue_move_order(_make_unit_move_order(storage.position, false), false)
	var carry_walk_animation := _first_available_unit_animation(UNIT_CARRY_WALK_ANIMATION_CANDIDATES)
	if not carry_walk_animation.is_empty():
		actor.play_animation(carry_walk_animation, 0.18, UNIT_WALK_ANIMATION_SPEED)
	return true


func _update_unit_delivery_actions() -> void:
	for actor_value in unit_actors_by_id.values():
		var actor = actor_value
		if actor == null or not is_instance_valid(actor):
			continue
		if not actor.has_delivery_action():
			if actor.carried_total() > 0 and not actor.has_gather_action() and not actor.has_move_order():
				_start_delivery_if_available(actor)
			continue
		var action = actor.delivery_action()
		var storage: RTSBuildingData = _building_by_id(str(action.target_id))
		if storage == null or not storage.completed or not storage.can_store_resources():
			actor.clear_delivery_action()
			continue
		action.target_position = storage.position
		var distance := Vector2(actor.position.x, actor.position.z).distance_to(Vector2(storage.position.x, storage.position.z))
		if distance > float(action.range):
			if not actor.has_move_order():
				actor.issue_move_order(_make_unit_move_order(storage.position, false), false)
			continue
		actor.clear_move_order()
		_deposit_actor_resources(actor, storage)
		action.complete()
		actor.clear_delivery_action()
		var idle_animation := _first_available_unit_animation(UNIT_IDLE_ANIMATION_CANDIDATES)
		if not idle_animation.is_empty():
			actor.play_animation(idle_animation)


func _nearest_storage_for_actor(actor) -> RTSBuildingData:
	var nearest: RTSBuildingData = null
	var nearest_distance: float = INF
	for building in battle_buildings:
		if building == null or not building.completed or not building.can_store_resources():
			continue
		if str(building.faction_id) != str(actor.faction_id) or _building_remaining_storage(building) <= 0:
			continue
		var distance: float = actor.position.distance_squared_to(building.position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = building
	return nearest


func _building_by_id(building_id: String) -> RTSBuildingData:
	for building in battle_buildings:
		if building != null and str(building.id) == building_id:
			return building
	return null


func _building_remaining_storage(building) -> int:
	var stored_total := 0
	for amount_value in building.stored_resources.values():
		stored_total += int(amount_value)
	return max(0, int(building.storage_capacity) - stored_total)


func _deposit_actor_resources(actor, storage) -> void:
	var deposited := {}
	for resource_type_value in actor.carried_resources.keys():
		var resource_type := str(resource_type_value)
		var carried_amount := int(actor.carried_resources.get(resource_type_value, 0))
		var amount: int = mini(carried_amount, _building_remaining_storage(storage))
		if amount <= 0 or not storage.store_resource(resource_type, amount):
			continue
		actor.carried_resources[resource_type_value] = carried_amount - amount
		deposited[resource_type] = amount
		if cell != null:
			cell.resources[resource_type] = int(cell.resources.get(resource_type, 0)) + amount
	for resource_type_value in actor.carried_resources.keys():
		if int(actor.carried_resources.get(resource_type_value, 0)) <= 0:
			actor.carried_resources.erase(resource_type_value)
	_sync_actor_carried_resource_visual(actor)
	if not deposited.is_empty():
		Game.debug_event("resources_deposited unit=%s storage=%s payload=%s" % [str(actor.unit_id), str(storage.id), str(deposited)])
		_refresh_overlay()


func _sync_actor_carried_resource_visual(actor) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var unit_id := str(actor.unit_id)
	var carries_wood := int(actor.carried_resources.get("wood", 0)) > 0
	var current_visual := carried_resource_visuals_by_unit_id.get(unit_id) as Node3D
	if not carries_wood:
		if current_visual != null and is_instance_valid(current_visual):
			current_visual.queue_free()
		carried_resource_visuals_by_unit_id.erase(unit_id)
		return
	if current_visual != null and is_instance_valid(current_visual):
		return

	var skeleton := _find_first_skeleton(actor)
	if skeleton == null or skeleton.find_bone("Hand.R") < 0:
		return
	var scene := _tree_scene_for_path(CARRIED_WOOD_MODEL)
	if scene == null:
		return
	var instantiated := scene.instantiate()
	if not instantiated is Node3D:
		instantiated.queue_free()
		return

	var attachment := BoneAttachment3D.new()
	attachment.name = "CarriedWoodAttachment"
	attachment.bone_name = "Hand.R"
	skeleton.add_child(attachment)
	var log_model := instantiated as Node3D
	log_model.name = "CarriedWoodLog"
	attachment.add_child(log_model)
	var inherited_scale := attachment.global_basis.get_scale().abs()
	var parent_scale: float = max(0.001, max(inherited_scale.x, max(inherited_scale.y, inherited_scale.z)))
	_fit_model_to_max_dimension(log_model, CARRIED_WOOD_VISUAL_LENGTH / parent_scale)
	log_model.rotation = Vector3(0.0, 0.0, PI * 0.5)
	log_model.position += Vector3(0.08, -0.04, 0.12)
	_apply_battle_lit_materials(log_model)
	_set_shadow_casting(log_model, true)
	carried_resource_visuals_by_unit_id[unit_id] = attachment


func _update_unit_actor_animation_queues(delta: float) -> void:
	for actor_value in unit_actors_by_id.values():
		var actor = actor_value
		if actor != null and is_instance_valid(actor):
			actor.update_animation_queue(delta)


func _first_available_unit_animation(candidates: Array) -> String:
	if unit_animation_names.is_empty():
		_get_unit_animation_library()
	for candidate_value in candidates:
		var candidate := str(candidate_value)
		if unit_animation_names.has(candidate):
			return candidate
		var lower_candidate := candidate.to_lower()
		for animation_name_value in unit_animation_names:
			var animation_name := str(animation_name_value)
			if animation_name.to_lower() == lower_candidate:
				return animation_name
	for candidate_value in candidates:
		var lower_candidate := str(candidate_value).to_lower()
		for animation_name_value in unit_animation_names:
			var animation_name := str(animation_name_value)
			if animation_name.to_lower().find(lower_candidate) >= 0:
				return animation_name
	return ""


func _unit_animation_duration(animation_name: String) -> float:
	if animation_name.is_empty():
		return 0.0
	var library := _get_unit_animation_library()
	if library == null or not library.has_animation(animation_name):
		return 0.0
	var animation := library.get_animation(animation_name)
	return animation.length if animation != null else 0.0


func _ground_position_for_local(x: float, z: float) -> Vector3:
	return Vector3(x, _terrain_surface_height_for_local(x, z) + 0.08, z)


func _unit_surface_position_for_local(x: float, z: float) -> Vector3:
	if _is_unit_swimming_at(x, z):
		var waterline := maxf(WATER_SURFACE_HEIGHT, _terrain_surface_height_for_local(x, z))
		return Vector3(x, waterline - UNIT_VISUAL_HEIGHT * UNIT_SWIM_SUBMERGENCE_RATIO, z)
	return _ground_position_for_local(x, z)


func _unit_treading_position_for_local(x: float, z: float) -> Vector3:
	if _is_unit_swimming_at(x, z):
		var waterline := maxf(WATER_SURFACE_HEIGHT, _terrain_surface_height_for_local(x, z))
		return Vector3(x, waterline - UNIT_VISUAL_HEIGHT * UNIT_TREAD_WATER_SUBMERGENCE_RATIO, z)
	return _ground_position_for_local(x, z)


func _is_unit_swimming_at(x: float, z: float) -> bool:
	var u := inverse_lerp(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, x)
	var v := inverse_lerp(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, z)
	var sample := _sample_cell_uv(u, v)
	return str(sample.get("terrain", "plains")) == "water" or float(sample.get("river", 0.0)) > 0.42


func _terrain_surface_height_for_local(x: float, z: float) -> float:
	var u := inverse_lerp(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, x)
	var v := inverse_lerp(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, z)
	var sample := _sample_cell_uv(u, v)
	var surface_height := _height_from_smoothed_terrain_at_uv(u, v, terrain_surface_heights, terrain_surface_row_length)
	if str(sample.get("terrain", "plains")) == "water" or float(sample.get("river", 0.0)) > 0.42:
		surface_height = max(surface_height, WATER_SURFACE_HEIGHT)
	return surface_height


func _spawn_scale_unit(parent: Node3D, base_height: float = 0.0) -> void:
	var unit := Node3D.new()
	unit.name = "ScaleUnit_1m65"
	unit.position = Vector3(0.0, base_height, 0.0)
	parent.add_child(unit)

	var unit_resource := load(UNIT_MODEL_MALE)
	if unit_resource is PackedScene:
		var model := (unit_resource as PackedScene).instantiate()
		if model is Node3D:
			var model_3d := model as Node3D
			model_3d.name = "TposeReference_1m65"
			unit.add_child(model_3d)
			_fit_model_to_height(model_3d, UNIT_VISUAL_HEIGHT)
			_set_shadow_casting(model_3d, true)
			return
		model.queue_free()

	_spawn_placeholder_scale_unit(unit)


func _spawn_placeholder_scale_unit(unit: Node3D) -> void:
	var body := MeshInstance3D.new()
	body.name = "Body_1m35"
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.22 * UNIT_VISUAL_SCALE
	body_mesh.bottom_radius = 0.25 * UNIT_VISUAL_SCALE
	body_mesh.height = UNIT_BODY_HEIGHT * UNIT_VISUAL_SCALE
	body_mesh.radial_segments = 12
	body.mesh = body_mesh
	body.material_override = _material(Color(0.16, 0.36, 0.82))
	body.position = Vector3(0.0, UNIT_BODY_HEIGHT * 0.5, 0.0)
	unit.add_child(body)

	var head := MeshInstance3D.new()
	head.name = "Head_0m30"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = UNIT_HEAD_RADIUS * UNIT_VISUAL_SCALE
	head_mesh.height = UNIT_HEAD_RADIUS * 2.0 * UNIT_VISUAL_SCALE
	head_mesh.radial_segments = 16
	head_mesh.rings = 8
	head.mesh = head_mesh
	head.material_override = _material(Color(0.86, 0.70, 0.54))
	head.position = Vector3(0.0, (UNIT_BODY_HEIGHT + UNIT_HEAD_RADIUS) * UNIT_VISUAL_SCALE, 0.0)
	unit.add_child(head)

	var height_marker := MeshInstance3D.new()
	height_marker.name = "HeightMarker_1m65"
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.04 * UNIT_VISUAL_SCALE, UNIT_VISUAL_HEIGHT, 0.04 * UNIT_VISUAL_SCALE)
	height_marker.mesh = marker_mesh
	height_marker.material_override = _material(Color(1.0, 0.92, 0.28))
	height_marker.position = Vector3(0.55 * UNIT_VISUAL_SCALE, UNIT_VISUAL_HEIGHT * 0.5, 0.0)
	unit.add_child(height_marker)


func _fit_model_to_height(model: Node3D, target_height: float) -> void:
	model.position = Vector3.ZERO
	model.rotation = Vector3.ZERO
	model.scale = Vector3.ONE

	var bounds := _combined_local_bounds(model)
	if not bool(bounds.get("valid", false)):
		return

	var min_corner := bounds["min"] as Vector3
	var max_corner := bounds["max"] as Vector3
	var current_height: float = max(max_corner.y - min_corner.y, 0.001)
	var scale_value: float = target_height / current_height
	model.scale = Vector3.ONE * scale_value
	model.position.y = -min_corner.y * scale_value


func _fit_model_to_max_dimension(model: Node3D, target_dimension: float) -> void:
	model.position = Vector3.ZERO
	model.rotation = Vector3.ZERO
	model.scale = Vector3.ONE
	var bounds := _combined_local_bounds(model)
	if not bool(bounds.get("valid", false)):
		return
	var min_corner := bounds["min"] as Vector3
	var max_corner := bounds["max"] as Vector3
	var dimensions := max_corner - min_corner
	var current_dimension: float = max(0.001, max(dimensions.x, max(dimensions.y, dimensions.z)))
	var scale_value := target_dimension / current_dimension
	model.scale = Vector3.ONE * scale_value
	model.position = -(min_corner + max_corner) * 0.5 * scale_value


func _combined_local_bounds(root: Node3D) -> Dictionary:
	var bounds := {
		"valid": false,
		"min": Vector3(1.0e20, 1.0e20, 1.0e20),
		"max": Vector3(-1.0e20, -1.0e20, -1.0e20),
	}
	_accumulate_local_bounds(root, root, bounds)
	return bounds


func _accumulate_local_bounds(root: Node3D, node: Node, bounds: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			var to_root := root.global_transform.affine_inverse() * mesh_instance.global_transform
			var aabb := mesh_instance.get_aabb()
			for endpoint_index in range(8):
				var point := to_root * aabb.get_endpoint(endpoint_index)
				var min_corner := bounds["min"] as Vector3
				var max_corner := bounds["max"] as Vector3
				min_corner.x = min(min_corner.x, point.x)
				min_corner.y = min(min_corner.y, point.y)
				min_corner.z = min(min_corner.z, point.z)
				max_corner.x = max(max_corner.x, point.x)
				max_corner.y = max(max_corner.y, point.y)
				max_corner.z = max(max_corner.z, point.z)
				bounds["min"] = min_corner
				bounds["max"] = max_corner
				bounds["valid"] = true

	for child in node.get_children():
		_accumulate_local_bounds(root, child, bounds)


func _build_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "BattleOverlay"
	add_child(canvas)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(root)

	_build_drag_selection_overlay(root)
	_build_resource_rail(root)
	_build_settlement_strip(root)
	_build_region_header(root)
	_build_world_view_window(root)
	_build_notification_tray(root)
	_build_context_panel(root)
	_build_minimap_window(root)
	_build_order_sidebar(root)
	_build_hud_stat_tooltip(root)


func _build_drag_selection_overlay(root: Control) -> void:
	drag_selection_overlay = DragSelectionOverlay.new()
	drag_selection_overlay.name = "DragSelectionOverlay"
	drag_selection_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(drag_selection_overlay)


func _build_resource_rail(root: Control) -> void:
	var panel := _make_hud_panel(root, "ResourceRail", Vector2(4, 4), Vector2(88, 196))
	resource_rail_panel = panel
	var margin := _add_hud_margin(panel, 8, 8, 8, 8)
	resource_list_container = VBoxContainer.new()
	resource_list_container.add_theme_constant_override("separation", 6)
	margin.add_child(resource_list_container)


func _build_settlement_strip(root: Control) -> void:
	var panel := _make_hud_panel(root, "SettlementStrip", Vector2(98, 4), Vector2(340, 104))
	settlement_strip_panel = panel
	var margin := _add_hud_margin(panel, 12, 8, 10, 8)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)

	summary_label = HudStatText.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_font_size_override("font_size", 13)
	summary_label.stat_hover_started.connect(_on_hud_stat_hover_started)
	summary_label.stat_hover_ended.connect(_on_hud_stat_hover_ended)
	stack.add_child(summary_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	stack.add_child(actions)

	var return_button := _make_compact_button("")
	return_button.icon = _hud_icon_texture("world")
	return_button.tooltip_text = "World map"
	return_button.pressed.connect(_on_return_pressed)
	actions.add_child(return_button)


func _build_region_header(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "RegionHeader"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -150
	panel.offset_top = 4
	panel.offset_right = 150
	panel.offset_bottom = 42
	panel.add_theme_stylebox_override("panel", _hud_panel_style(0.82))
	root.add_child(panel)
	_add_hud_glass(panel, 0.84)
	region_header_panel = panel

	var margin := _add_hud_margin(panel, 12, 8, 12, 8)
	region_name_label = Label.new()
	region_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	region_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	region_name_label.add_theme_font_size_override("font_size", 16)
	margin.add_child(region_name_label)


func _build_world_view_window(root: Control) -> void:
	var frame := Control.new()
	frame.name = "WorldViewFrame"
	frame.anchor_left = 1.0
	frame.anchor_right = 1.0
	frame.offset_left = -270
	frame.offset_top = 4
	frame.offset_right = -8
	frame.offset_bottom = 190
	root.add_child(frame)

	world_view_panel = _make_hud_panel(frame, "WorldViewPanel", Vector2(38, 0), Vector2(224, 154))
	var margin := _add_hud_margin(world_view_panel, 8, 8, 8, 8)
	var globe_container := SubViewportContainer.new()
	globe_container.name = "OptimizedGlobeView"
	globe_container.custom_minimum_size = Vector2(WORLD_GLOBE_VIEWPORT_SIZE)
	globe_container.stretch = true
	globe_container.mouse_filter = Control.MOUSE_FILTER_STOP
	globe_container.gui_input.connect(_on_world_globe_gui_input)
	margin.add_child(globe_container)
	_build_world_globe_view(globe_container)

	world_view_toggle_button = _make_icon_button("-")
	world_view_toggle_button.name = "WorldViewCollapse"
	world_view_toggle_button.position = Vector2(0, 122)
	world_view_toggle_button.pressed.connect(_on_world_view_toggle_pressed)
	frame.add_child(world_view_toggle_button)


func _build_world_globe_view(container: SubViewportContainer) -> void:
	world_globe_viewport = SubViewport.new()
	world_globe_viewport.name = "LowRateWorldGlobeViewport"
	world_globe_viewport.size = WORLD_GLOBE_VIEWPORT_SIZE
	world_globe_viewport.own_world_3d = true
	world_globe_viewport.transparent_bg = false
	world_globe_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	container.add_child(world_globe_viewport)

	world_globe_root = Node3D.new()
	world_globe_root.name = "WorldGlobeRoot"
	world_globe_viewport.add_child(world_globe_root)

	world_globe_scene_root = Node3D.new()
	world_globe_scene_root.name = "MiniWorldScene"
	world_globe_root.add_child(world_globe_scene_root)

	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.004, 0.007, 0.014)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.12, 0.15, 0.20)
	environment.ambient_light_energy = 0.58
	world_environment.environment = environment
	world_globe_root.add_child(world_environment)

	var light := DirectionalLight3D.new()
	light.name = "GlobePreviewSun"
	light.shadow_enabled = false
	light.light_energy = 1.25
	light.light_color = Color(1.0, 0.94, 0.82)
	world_globe_root.add_child(light)
	world_globe_sun_light = light

	world_globe_planet = MeshInstance3D.new()
	world_globe_planet.name = "OptimizedWorldGlobe"
	world_globe_planet.mesh = _build_world_globe_planet_mesh()
	var material := StandardMaterial3D.new()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.86
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.albedo_texture = _build_world_globe_texture()
	world_globe_planet.material_override = material
	world_globe_scene_root.add_child(world_globe_planet)

	var atmosphere := MeshInstance3D.new()
	atmosphere.name = "MiniWorldAtmosphere"
	var atmosphere_sphere := SphereMesh.new()
	atmosphere_sphere.radius = WORLD_GLOBE_RADIUS * 1.045
	atmosphere_sphere.height = WORLD_GLOBE_RADIUS * 2.09
	atmosphere_sphere.radial_segments = 32
	atmosphere_sphere.rings = 16
	atmosphere.mesh = atmosphere_sphere
	var atmosphere_material := StandardMaterial3D.new()
	atmosphere_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	atmosphere_material.albedo_color = Color(0.42, 0.72, 1.0, 0.13)
	atmosphere_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	atmosphere_material.cull_mode = BaseMaterial3D.CULL_FRONT
	atmosphere.material_override = atmosphere_material
	world_globe_scene_root.add_child(atmosphere)

	world_globe_grid = MeshInstance3D.new()
	world_globe_grid.name = "MiniWorldGrid"
	world_globe_grid.mesh = _build_world_globe_grid_mesh()
	world_globe_scene_root.add_child(world_globe_grid)

	world_globe_cell_outline = MeshInstance3D.new()
	world_globe_cell_outline.name = "MiniCurrentCellOutline"
	world_globe_cell_outline.mesh = _build_world_globe_cell_outline_mesh()
	world_globe_scene_root.add_child(world_globe_cell_outline)

	var globe_camera := Camera3D.new()
	globe_camera.name = "GlobePreviewCamera"
	globe_camera.fov = 33.0
	globe_camera.near = 0.05
	globe_camera.far = 16.0
	globe_camera.current = true
	world_globe_root.add_child(globe_camera)
	world_globe_camera = globe_camera
	_update_world_globe_camera_anchor()
	_update_world_globe_scene_rotation()
	_update_world_globe_sun_light()


func _build_world_globe_texture() -> Texture2D:
	if Game.world_state == null:
		return null

	var cache_key := _world_globe_texture_cache_key()
	var cached_texture = Game.get_world_visual_cache(cache_key)
	if cached_texture is Texture2D:
		return cached_texture

	var image := Image.create(WORLD_GLOBE_TEXTURE_SIZE.x, WORLD_GLOBE_TEXTURE_SIZE.y, true, Image.FORMAT_RGBA8)
	for y in range(WORLD_GLOBE_TEXTURE_SIZE.y):
		var v: float = float(y) / float(WORLD_GLOBE_TEXTURE_SIZE.y - 1)
		var lat: float = lerpf(PI / 2.0, -PI / 2.0, v)
		for x in range(WORLD_GLOBE_TEXTURE_SIZE.x):
			var u: float = float(x) / float(WORLD_GLOBE_TEXTURE_SIZE.x - 1)
			var lon: float = lerpf(-PI, PI, u)
			var sample: Dictionary = Game.world_state.sample_world(lat, lon)
			image.set_pixel(x, y, _world_globe_color_from_sample(sample))
	image.generate_mipmaps()

	var texture := ImageTexture.create_from_image(image)
	Game.set_world_visual_cache(cache_key, texture)
	return texture


func _world_globe_texture_cache_key() -> String:
	return "rts_globe_texture:v%d:%d:%dx%d" % [
		WORLD_GLOBE_TEXTURE_VERSION,
		int(Game.world_state.seed),
		WORLD_GLOBE_TEXTURE_SIZE.x,
		WORLD_GLOBE_TEXTURE_SIZE.y,
	]


func _world_globe_color_from_sample(sample: Dictionary) -> Color:
	var base_color := _minimap_color_from_sample(sample)
	var elevation: float = float(sample.get("elevation", WorldState.SEA_LEVEL))
	var river: float = float(sample.get("river", 0.0))
	if elevation >= WorldState.SEA_LEVEL and river < 0.10:
		var detail: float = clamp((float(sample.get("raw_noise", elevation)) - 0.5) * 0.16, -0.055, 0.055)
		if detail > 0.0:
			base_color = base_color.lightened(detail)
		else:
			base_color = base_color.darkened(abs(detail))
	return base_color


func _build_world_globe_planet_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var row_length := WORLD_GLOBE_LONGITUDE_SEGMENTS + 1

	for lat_index in range(WORLD_GLOBE_LATITUDE_SEGMENTS + 1):
		var lat: float = lerpf(PI / 2.0, -PI / 2.0, float(lat_index) / float(WORLD_GLOBE_LATITUDE_SEGMENTS))
		for lon_index in range(WORLD_GLOBE_LONGITUDE_SEGMENTS + 1):
			var lon: float = lerpf(-PI, PI, float(lon_index) / float(WORLD_GLOBE_LONGITUDE_SEGMENTS))
			var direction := _direction_from_lat_lon(lat, lon)
			vertices.append(direction * WORLD_GLOBE_RADIUS)
			normals.append(direction)
			uvs.append(Vector2(
				float(lon_index) / float(WORLD_GLOBE_LONGITUDE_SEGMENTS),
				float(lat_index) / float(WORLD_GLOBE_LATITUDE_SEGMENTS)
			))

	for lat_index in range(WORLD_GLOBE_LATITUDE_SEGMENTS):
		for lon_index in range(WORLD_GLOBE_LONGITUDE_SEGMENTS):
			var base_index := lat_index * row_length + lon_index
			indices.append(base_index)
			indices.append(base_index + 1)
			indices.append(base_index + row_length)

			indices.append(base_index + 1)
			indices.append(base_index + row_length + 1)
			indices.append(base_index + row_length)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_world_globe_grid_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if Game.world_state == null:
		return mesh

	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var grid_color := Color(0.82, 0.90, 1.0, 0.20)
	var width: int = int(Game.world_state.width)
	var height: int = int(Game.world_state.height)
	var segments := 64

	for row in range(1, height):
		var lat: float = lerpf(PI / 2.0, -PI / 2.0, float(row) / float(height))
		for segment in range(segments):
			var lon_a: float = lerpf(-PI, PI, float(segment) / float(segments))
			var lon_b: float = lerpf(-PI, PI, float(segment + 1) / float(segments))
			vertices.append(_direction_from_lat_lon(lat, lon_a) * WORLD_GLOBE_GRID_RADIUS)
			vertices.append(_direction_from_lat_lon(lat, lon_b) * WORLD_GLOBE_GRID_RADIUS)
			colors.append(grid_color)
			colors.append(grid_color)

	for column in range(width):
		var lon: float = lerpf(-PI, PI, float(column) / float(width))
		for segment in range(segments):
			var lat_a: float = lerpf(PI / 2.0, -PI / 2.0, float(segment) / float(segments))
			var lat_b: float = lerpf(PI / 2.0, -PI / 2.0, float(segment + 1) / float(segments))
			vertices.append(_direction_from_lat_lon(lat_a, lon) * WORLD_GLOBE_GRID_RADIUS)
			vertices.append(_direction_from_lat_lon(lat_b, lon) * WORLD_GLOBE_GRID_RADIUS)
			colors.append(grid_color)
			colors.append(grid_color)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.surface_set_material(0, material)
	return mesh


func _build_world_globe_cell_outline_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if Game.world_state == null or cell == null:
		return mesh

	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var color := Color(1.0, 0.92, 0.25, 0.95)
	var corners := _world_globe_cell_corner_directions(cell.x, cell.y, cell.x_span)
	var edges := [
		[corners[0], corners[1]],
		[corners[1], corners[2]],
		[corners[2], corners[3]],
		[corners[3], corners[0]],
	]

	for edge in edges:
		for segment in range(8):
			var t_a := float(segment) / 8.0
			var t_b := float(segment + 1) / 8.0
			vertices.append(edge[0].slerp(edge[1], t_a).normalized() * WORLD_GLOBE_OUTLINE_RADIUS)
			vertices.append(edge[0].slerp(edge[1], t_b).normalized() * WORLD_GLOBE_OUTLINE_RADIUS)
			colors.append(color)
			colors.append(color)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.surface_set_material(0, material)
	return mesh


func _world_globe_cell_corner_directions(x_index: int, y_index: int, x_span: int = 1) -> Array:
	var width: int = int(Game.world_state.width)
	var height: int = int(Game.world_state.height)
	var lon_left: float = lerpf(-PI, PI, float(x_index) / float(width))
	var lon_right: float = lerpf(-PI, PI, float(x_index + x_span) / float(width))
	var lat_top: float = lerpf(PI / 2.0, -PI / 2.0, float(y_index) / float(height))
	var lat_bottom: float = lerpf(PI / 2.0, -PI / 2.0, float(y_index + 1) / float(height))
	return [
		_direction_from_lat_lon(lat_top, lon_left),
		_direction_from_lat_lon(lat_top, lon_right),
		_direction_from_lat_lon(lat_bottom, lon_right),
		_direction_from_lat_lon(lat_bottom, lon_left),
	]


func _direction_from_lat_lon(lat: float, lon: float) -> Vector3:
	var cos_lat := cos(lat)
	return Vector3(
		cos_lat * sin(lon),
		sin(lat),
		cos_lat * cos(lon)
	).normalized()


func _current_cell_globe_direction() -> Vector3:
	if Game.world_state == null or cell == null:
		return Vector3.FORWARD
	var lat_lon: Vector2 = Game.world_state.get_cell_center_lat_lon(cell)
	return _direction_from_lat_lon(lat_lon.x, lat_lon.y)


func _current_battle_sun_planet_direction() -> Vector3:
	var up := _current_cell_globe_direction()
	var east := Vector3.UP.cross(up)
	if east.length_squared() < 0.0001:
		east = Vector3.RIGHT
	east = east.normalized()
	var north := up.cross(east).normalized()
	var local_sun := Game.get_battle_sun_direction()
	return (east * local_sun.x + up * local_sun.y + north * local_sun.z).normalized()


func _update_world_globe_scene_rotation() -> void:
	if world_globe_scene_root == null:
		return
	world_globe_scene_root.rotation.y = Game.get_world_rotation_angle()


func _update_world_globe_camera_anchor() -> void:
	if world_globe_camera == null:
		return

	var rotated_cell_direction := _current_cell_globe_direction().rotated(Vector3.UP, Game.get_world_rotation_angle()).normalized()
	var camera_position := rotated_cell_direction * WORLD_GLOBE_CAMERA_DISTANCE
	var up := Vector3.UP
	if abs(rotated_cell_direction.dot(up)) > 0.92:
		up = Vector3.FORWARD
	world_globe_camera.global_position = camera_position
	world_globe_camera.look_at(Vector3.ZERO, up)


func _update_world_globe_sun_light() -> void:
	if world_globe_sun_light == null:
		return

	var visual_sun_direction := _current_battle_sun_planet_direction().rotated(Vector3.UP, Game.get_world_rotation_angle()).normalized()
	world_globe_sun_light.look_at_from_position(visual_sun_direction * 4.0, Vector3.ZERO, Vector3.UP)
	world_globe_sun_light.light_energy = 1.25


func _update_world_globe_preview(delta: float) -> void:
	if world_globe_viewport == null or world_globe_scene_root == null or world_view_collapsed:
		return

	world_globe_update_elapsed += delta
	if world_globe_update_elapsed < WORLD_GLOBE_UPDATE_INTERVAL:
		return

	world_globe_update_elapsed = 0.0
	_update_world_globe_scene_rotation()
	_update_world_globe_camera_anchor()
	_update_world_globe_sun_light()
	world_globe_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _build_notification_tray(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "NotificationTray"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -190
	panel.offset_top = 48
	panel.offset_right = 190
	panel.offset_bottom = 120
	panel.visible = false
	panel.add_theme_stylebox_override("panel", _hud_panel_style(0.66))
	root.add_child(panel)
	_add_hud_glass(panel, 0.72)

	var margin := _add_hud_margin(panel, 10, 8, 10, 8)
	event_log_label = RichTextLabel.new()
	event_log_label.fit_content = false
	event_log_label.scroll_active = false
	event_log_label.custom_minimum_size = Vector2(360, 54)
	margin.add_child(event_log_label)


func _build_context_panel(root: Control) -> void:
	context_panel = PanelContainer.new()
	context_panel.name = "SelectionContext"
	context_panel.anchor_top = 1.0
	context_panel.anchor_bottom = 1.0
	context_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	context_panel.offset_left = 4
	context_panel.offset_top = -166
	context_panel.offset_right = 440
	context_panel.offset_bottom = -8
	context_panel.add_theme_stylebox_override("panel", _hud_panel_style(0.78))
	root.add_child(context_panel)
	_add_hud_glass(context_panel, 0.82)

	var margin := _add_hud_margin(context_panel, 12, 10, 12, 10)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	context_title_label = Label.new()
	context_title_label.add_theme_font_size_override("font_size", 16)
	stack.add_child(context_title_label)

	context_stats_label = HudStatText.new()
	context_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context_stats_label.add_theme_font_size_override("font_size", 13)
	context_stats_label.stat_hover_started.connect(_on_hud_stat_hover_started)
	context_stats_label.stat_hover_ended.connect(_on_hud_stat_hover_ended)
	stack.add_child(context_stats_label)

	context_carry_panel = PanelContainer.new()
	context_carry_panel.name = "CarrySummary"
	context_carry_panel.add_theme_stylebox_override("panel", _hud_panel_style(0.46))
	stack.add_child(context_carry_panel)
	_add_hud_glass(context_carry_panel, 0.58)
	var carry_margin := _add_hud_margin(context_carry_panel, 8, 6, 8, 6)
	context_carry_label = HudStatText.new()
	context_carry_label.add_theme_font_size_override("font_size", 12)
	context_carry_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	carry_margin.add_child(context_carry_label)

	context_animation_picker = OptionButton.new()
	context_animation_picker.name = "UnitAnimationPicker"
	context_animation_picker.focus_mode = Control.FOCUS_NONE
	context_animation_picker.custom_minimum_size = Vector2(190, 28)
	_apply_hud_control_theme(context_animation_picker)
	context_animation_picker.item_selected.connect(_on_unit_animation_selected)
	stack.add_child(context_animation_picker)


func _build_minimap_window(root: Control) -> void:
	var frame := Control.new()
	frame.name = "MinimapFrame"
	frame.anchor_left = 1.0
	frame.anchor_top = 1.0
	frame.anchor_right = 1.0
	frame.anchor_bottom = 1.0
	frame.offset_left = -248
	frame.offset_top = -226
	frame.offset_right = -8
	frame.offset_bottom = -8
	root.add_child(frame)

	minimap_panel = _make_hud_panel(frame, "MinimapPanel", Vector2(0, 30), Vector2(240, 188))
	var margin := _add_hud_margin(minimap_panel, 8, 8, 8, 8)
	var preview := HudMapPreview.new()
	preview.preview_mode = "minimap"
	preview.custom_minimum_size = Vector2(224, 172)
	preview.mouse_filter = Control.MOUSE_FILTER_STOP
	preview.gui_input.connect(_on_minimap_gui_input)
	margin.add_child(preview)
	minimap_preview = preview

	minimap_toggle_button = _make_icon_button("-")
	minimap_toggle_button.name = "MinimapCollapse"
	minimap_toggle_button.position = Vector2(0, 0)
	minimap_toggle_button.pressed.connect(_on_minimap_toggle_pressed)
	frame.add_child(minimap_toggle_button)


func _build_order_sidebar(root: Control) -> void:
	order_sidebar_panel = PanelContainer.new()
	order_sidebar_panel.name = "OrderSidebar"
	order_sidebar_panel.anchor_left = 1.0
	order_sidebar_panel.anchor_top = 0.5
	order_sidebar_panel.anchor_right = 1.0
	order_sidebar_panel.anchor_bottom = 0.5
	order_sidebar_panel.offset_left = -66.0
	order_sidebar_panel.offset_top = -188.0
	order_sidebar_panel.offset_right = -8.0
	order_sidebar_panel.offset_bottom = 188.0
	order_sidebar_panel.add_theme_stylebox_override("panel", _hud_panel_style(0.86))
	root.add_child(order_sidebar_panel)
	_add_hud_glass(order_sidebar_panel, 0.88)

	var margin := _add_hud_margin(order_sidebar_panel, 7, 8, 7, 8)
	var orders := VBoxContainer.new()
	orders.alignment = BoxContainer.ALIGNMENT_CENTER
	orders.add_theme_constant_override("separation", 5)
	margin.add_child(orders)

	var group := ButtonGroup.new()
	order_buttons_by_mode.clear()
	for mode_value in ["move", "build", "attack", "interact", "auto_move", "repair", "scavenge"]:
		var mode := str(mode_value)
		var button := Button.new()
		button.name = "%sOrder" % mode.to_pascal_case()
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(42.0, 42.0)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 34)
		button.tooltip_text = str(ORDER_CURSOR_TOOLTIPS.get(mode, mode.capitalize()))
		var icon_resource = Game.yarts_thing_selected_cursor_texture if mode == "move" else load(str(ORDER_CURSOR_ICON_PATHS.get(mode, "")))
		if icon_resource is Texture2D:
			button.icon = icon_resource as Texture2D
		_apply_hud_control_theme(button)
		button.pressed.connect(_on_order_mode_pressed.bind(mode))
		orders.add_child(button)
		order_buttons_by_mode[mode] = button

	var move_button := order_buttons_by_mode.get("move") as Button
	if move_button != null:
		move_button.button_pressed = true
	_apply_active_order_cursor()


func _on_order_mode_pressed(mode: String) -> void:
	active_order_mode = mode
	_clear_resource_hover()
	_apply_active_order_cursor()


func _apply_active_order_cursor() -> void:
	match active_order_mode:
		"build":
			Game.set_build_order_cursor_active(true)
		"attack":
			Game.set_attack_order_cursor_active(true)
		"interact":
			Game.set_interact_order_cursor_active(true)
		"auto_move":
			Game.set_auto_move_order_cursor_active(true)
		"repair":
			Game.set_repair_order_cursor_active(true)
		"scavenge":
			Game.set_scavenge_order_cursor_active(true)
		_:
			Game.reset_order_cursor()


func _build_hud_stat_tooltip(root: Control) -> void:
	hud_stat_tooltip_panel = PanelContainer.new()
	hud_stat_tooltip_panel.name = "StatTooltip"
	hud_stat_tooltip_panel.visible = false
	hud_stat_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_stat_tooltip_panel.z_index = 100
	hud_stat_tooltip_panel.custom_minimum_size = Vector2(150, 34)
	hud_stat_tooltip_panel.add_theme_stylebox_override("panel", _hud_panel_style(0.92))
	root.add_child(hud_stat_tooltip_panel)
	_add_hud_glass(hud_stat_tooltip_panel, 0.94)

	var margin := _add_hud_margin(hud_stat_tooltip_panel, 10, 7, 10, 7)
	hud_stat_tooltip_label = Label.new()
	hud_stat_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_stat_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_stat_tooltip_label.custom_minimum_size = Vector2(130, 0)
	hud_stat_tooltip_label.add_theme_font_size_override("font_size", 12)
	margin.add_child(hud_stat_tooltip_label)


func _on_hud_stat_hover_started(stat_key: String) -> void:
	hud_hovered_stat = stat_key
	hud_hover_elapsed = 0.0
	hud_tooltip_expanded = false
	_refresh_hud_stat_tooltip()


func _on_hud_stat_hover_ended() -> void:
	hud_hovered_stat = ""
	hud_hover_elapsed = 0.0
	hud_tooltip_expanded = false
	if hud_stat_tooltip_panel != null:
		hud_stat_tooltip_panel.visible = false


func _update_hud_stat_tooltip(delta: float) -> void:
	if hud_hovered_stat.is_empty() or hud_stat_tooltip_panel == null:
		return
	hud_hover_elapsed += delta
	if not hud_tooltip_expanded and hud_hover_elapsed >= HUD_TOOLTIP_EXPAND_SECONDS:
		hud_tooltip_expanded = true
		_refresh_hud_stat_tooltip()
	var viewport_size := get_viewport().get_visible_rect().size
	var desired := get_viewport().get_mouse_position() + Vector2(16.0, 18.0)
	var panel_size := hud_stat_tooltip_panel.size
	hud_stat_tooltip_panel.position = Vector2(
		clamp(desired.x, 6.0, max(6.0, viewport_size.x - panel_size.x - 6.0)),
		clamp(desired.y, 6.0, max(6.0, viewport_size.y - panel_size.y - 6.0))
	)


func _refresh_hud_stat_tooltip() -> void:
	if hud_stat_tooltip_panel == null or hud_stat_tooltip_label == null:
		return
	var definition := _hud_stat_definition(hud_hovered_stat)
	var title := str(definition.get("title", hud_hovered_stat.capitalize()))
	hud_stat_tooltip_label.custom_minimum_size.x = 300.0 if hud_tooltip_expanded else 130.0
	hud_stat_tooltip_label.text = "%s\n%s" % [title, str(definition.get("description", ""))] if hud_tooltip_expanded else title
	hud_stat_tooltip_panel.visible = true
	hud_stat_tooltip_panel.reset_size()


func _hud_stat_definition(stat_key: String) -> Dictionary:
	var definitions := {
		"population": {"title": "Population", "description": "The estimated number of people supported by this settlement and its current supply capacity."},
		"tech": {"title": "Technology", "description": "The settlement's technology tier, which determines available equipment, production, and construction options."},
		"food": {"title": "Food", "description": "Stored food available to feed inhabitants and military units in this region."},
		"owner": {"title": "Owner", "description": "The faction currently controlling this region and its settlements."},
		"threat": {"title": "Threat", "description": "The known danger level in this region from hostile forces or unresolved events."},
		"sun": {"title": "Time and Sunlight", "description": "The daylight state for this world cell, synchronized with the rotating world and RTS lighting."},
		"units": {"title": "Units", "description": "The number of active people and military units currently loaded in this cell."},
		"buildings": {"title": "Buildings", "description": "The number of constructed buildings currently present in this cell."},
		"entities": {"title": "Loaded Entities", "description": "The total number of gameplay and environmental entities currently loaded by the RTS scene."},
		"full_models": {"title": "Full Models", "description": "Entities currently using their complete 3D model rather than a simplified representation."},
		"impostors": {"title": "Impostor Models", "description": "Entities using a distant simplified representation. The tree impostor system is presently disabled."},
		"health": {"title": "Health", "description": "Current hit points. A unit becomes unable to act when its health reaches zero."},
		"stamina": {"title": "Stamina", "description": "Physical energy used for sustained movement, labor, and combat actions."},
		"morale": {"title": "Morale", "description": "The unit's willingness to continue working or fighting under pressure."},
		"armor": {"title": "Armor", "description": "Protection supplied by equipment that reduces incoming physical damage."},
		"damage": {"title": "Damage", "description": "The unit's base damage before situational and equipment modifiers are applied."},
		"speed": {"title": "Movement Speed", "description": "The unit's normal ground movement speed before jogging or terrain modifiers."},
		"equipment": {"title": "Equipment", "description": "The equipped tool or weapon, which determines profession and available actions."},
		"profession": {"title": "Profession", "description": "The unit's current role and the work or combat actions it can perform."},
		"lead_unit": {"title": "Lead Unit", "description": "The primary member used to summarize a multi-unit selection and organize its formation."},
	}
	return definitions.get(stat_key, {"title": stat_key.capitalize(), "description": "No detailed explanation is available yet."})


func _make_hud_panel(parent: Control, node_name: String, position: Vector2, minimum_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.position = position
	panel.custom_minimum_size = minimum_size
	panel.add_theme_stylebox_override("panel", _hud_panel_style())
	parent.add_child(panel)
	_add_hud_glass(panel)
	return panel


func _add_hud_margin(parent: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	parent.add_child(margin)
	return margin


func _hud_panel_style(alpha: float = 0.74) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.075, 0.047, alpha * 0.28)
	style.border_color = Color(0.38, 0.78, 0.57, 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(0.0, 0.02, 0.012, 0.44)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0.0, 2.0)
	return style


func _add_hud_glass(panel: PanelContainer, opacity: float = 0.76) -> void:
	var glass := ColorRect.new()
	glass.name = "GlassSurface"
	glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.show_behind_parent = true
	var shader_resource = load("res://assets/shaders/hud_liquid_glass.gdshader")
	if shader_resource is Shader:
		var material := ShaderMaterial.new()
		material.shader = shader_resource
		material.set_shader_parameter("glass_tint", Color(0.018, 0.14, 0.085, opacity))
		material.set_shader_parameter("edge_tint", Color(0.40, 0.88, 0.62, 0.42))
		glass.material = material
	panel.add_child(glass)
	panel.move_child(glass, 0)


func _hud_control_style(color: Color, border_alpha: float = 0.34) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.38, 0.78, 0.57, border_alpha)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	return style


func _apply_hud_control_theme(control: Control) -> void:
	control.add_theme_color_override("font_color", Color(0.90, 0.98, 0.93))
	control.add_theme_color_override("font_hover_color", Color.WHITE)
	control.add_theme_color_override("font_pressed_color", Color(0.78, 1.0, 0.86))
	control.add_theme_stylebox_override("normal", _hud_control_style(Color(0.018, 0.10, 0.061, 0.82)))
	control.add_theme_stylebox_override("hover", _hud_control_style(Color(0.035, 0.19, 0.11, 0.90), 0.62))
	control.add_theme_stylebox_override("pressed", _hud_control_style(Color(0.022, 0.23, 0.12, 0.94), 0.78))
	control.add_theme_stylebox_override("focus", _hud_control_style(Color(0.025, 0.16, 0.09, 0.86), 0.78))


func _make_compact_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(34, 26)
	_apply_hud_control_theme(button)
	return button


func _make_icon_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(30, 30)
	_apply_hud_control_theme(button)
	return button


func _is_screen_point_in_hud(screen_position: Vector2) -> bool:
	var controls: Array[Control] = [
		resource_rail_panel,
		settlement_strip_panel,
		region_header_panel,
		world_view_panel,
		world_view_toggle_button,
		minimap_panel,
		minimap_toggle_button,
		context_panel,
		order_sidebar_panel,
	]
	for control in controls:
		if _visible_control_contains(control, screen_position):
			return true
	return false


func _visible_control_contains(control: Control, screen_position: Vector2) -> bool:
	return control != null and control.is_visible_in_tree() and control.get_global_rect().has_point(screen_position)


func _on_world_view_toggle_pressed() -> void:
	world_view_collapsed = not world_view_collapsed
	if world_view_panel != null:
		world_view_panel.visible = not world_view_collapsed
	if world_view_toggle_button != null:
		world_view_toggle_button.text = "+" if world_view_collapsed else "-"
		world_view_toggle_button.position = Vector2(0, 0) if world_view_collapsed else Vector2(0, 122)
	if not world_view_collapsed:
		world_globe_update_elapsed = WORLD_GLOBE_UPDATE_INTERVAL


func _on_world_globe_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		_on_return_pressed()


func _on_minimap_toggle_pressed() -> void:
	minimap_collapsed = not minimap_collapsed
	if minimap_panel != null:
		minimap_panel.visible = not minimap_collapsed
	if minimap_toggle_button != null:
		minimap_toggle_button.text = "+" if minimap_collapsed else "-"


func _on_minimap_gui_input(event: InputEvent) -> void:
	if minimap_preview == null or camera == null or minimap_collapsed:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var normalized_position := _minimap_normalized_position_from_local(event.position)
		if normalized_position.x < 0.0:
			return
		_move_camera_to_minimap_position(normalized_position)
		get_viewport().set_input_as_handled()


func _minimap_normalized_position_from_local(local_position: Vector2) -> Vector2:
	var local_rect := Rect2(Vector2.ZERO, minimap_preview.size)
	var map_rect := minimap_preview._minimap_map_rect(local_rect)
	if not map_rect.has_point(local_position):
		return Vector2(-1.0, -1.0)
	return Vector2(
		clamp(inverse_lerp(map_rect.position.x, map_rect.end.x, local_position.x), 0.0, 1.0),
		clamp(inverse_lerp(map_rect.position.y, map_rect.end.y, local_position.y), 0.0, 1.0)
	)


func _move_camera_to_minimap_position(normalized_position: Vector2) -> void:
	if camera == null:
		return

	var limit := MAP_SIZE * 0.5
	var target_x := lerpf(-limit, limit, normalized_position.x)
	var target_z := lerpf(-limit, limit, normalized_position.y)
	camera.position.x = clamp(target_x, -limit, limit)
	camera.position.z = clamp(target_z, -limit + CAMERA_MIN_Z, limit + CAMERA_MAX_Z * 0.25)
	_update_minimap_preview(1.0)


func _build_loading_overlay() -> void:
	loading_layer = CanvasLayer.new()
	loading_layer.name = "RTSLoadingOverlay"
	add_child(loading_layer)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.025, 0.035, 0.86)
	loading_layer.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -260
	panel.offset_top = -70
	panel.offset_right = 260
	panel.offset_bottom = 70
	panel.add_theme_stylebox_override("panel", _hud_panel_style(0.86))
	loading_layer.add_child(panel)
	_add_hud_glass(panel, 0.90)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	margin.add_child(stack)

	loading_label = Label.new()
	loading_label.text = "Preparing RTS cell..."
	loading_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(loading_label)

	loading_bar = ProgressBar.new()
	loading_bar.min_value = 0.0
	loading_bar.max_value = 100.0
	loading_bar.value = 0.0
	stack.add_child(loading_bar)


func _set_loading(stage: String, progress: float) -> void:
	if loading_label != null:
		loading_label.text = stage
	if loading_bar != null:
		loading_bar.value = clamp(progress, 0.0, 1.0) * 100.0


func _hide_loading_overlay() -> void:
	if loading_layer != null:
		loading_layer.queue_free()
		loading_layer = null
		loading_label = null
		loading_bar = null


func _load_rts_cell() -> void:
	_set_loading("Checking cached RTS terrain...", 0.03)
	await get_tree().process_frame

	var cache_key := _rts_cell_cache_key()
	var cached_cell = Game.get_rts_cell_cache(cache_key)
	if cached_cell is Dictionary:
		_set_loading("Loading cached terrain meshes...", 0.92)
		await get_tree().process_frame
		_apply_rts_cell_data(cached_cell)
		_hide_loading_overlay()
		_refresh_overlay()
		return

	var generated_cell: Dictionary = await _generate_rts_cell_data()
	Game.set_rts_cell_cache(cache_key, generated_cell)
	_apply_rts_cell_data(generated_cell)
	_hide_loading_overlay()
	_refresh_overlay()


func _rts_cell_cache_key() -> String:
	var cell_id := "none"
	if cell != null:
		cell_id = str(cell.id)
	var seed := 0
	if Game.world_state != null:
		seed = int(Game.world_state.seed)
	return "rts_cell:v%d:%d:%s:%d:%d" % [RTS_CACHE_VERSION, seed, cell_id, int(MAP_SIZE), TERRAIN_STEPS]


func _generate_rts_cell_data() -> Dictionary:
	_set_loading("Sampling elevation, moisture, rivers, and biomes...", 0.08)
	await get_tree().process_frame
	_build_smoothed_river_map()

	var terrain_vertices := PackedVector3Array()
	var terrain_normals := PackedVector3Array()
	var terrain_colors := PackedColorArray()
	var terrain_uvs := PackedVector2Array()
	var terrain_indices := PackedInt32Array()
	var terrain_heights := PackedFloat32Array()
	var row_length := TERRAIN_STEPS + 1
	var half_size := MAP_SIZE * 0.5

	for z_index in range(TERRAIN_STEPS + 1):
		var v: float = float(z_index) / float(TERRAIN_STEPS)
		for x_index in range(TERRAIN_STEPS + 1):
			var u: float = float(x_index) / float(TERRAIN_STEPS)
			var x: float = lerpf(-half_size, half_size, u)
			var z: float = lerpf(-half_size, half_size, v)
			var sample := _sample_cell_uv(u, v)
			var height := _height_from_sample(sample)
			terrain_vertices.append(Vector3(x, height, z))
			terrain_heights.append(height)
			terrain_colors.append(_terrain_color_from_sample(sample))
			terrain_uvs.append(Vector2(u, v))

		if z_index % 8 == 0:
			_set_loading("Sampling terrain rows %d/%d..." % [z_index, TERRAIN_STEPS], lerpf(0.08, 0.48, float(z_index) / float(TERRAIN_STEPS)))
			await get_tree().process_frame

	_set_loading("Building terrain mesh...", 0.54)
	await get_tree().process_frame
	terrain_heights = _smooth_terrain_heights(terrain_heights, row_length, TERRAIN_SMOOTH_PASSES)
	terrain_surface_heights = terrain_heights.duplicate()
	terrain_surface_row_length = row_length
	for vertex_index in range(terrain_vertices.size()):
		var vertex := terrain_vertices[vertex_index]
		vertex.y = terrain_heights[vertex_index]
		terrain_vertices[vertex_index] = vertex

	var vertex_spacing := MAP_SIZE / float(TERRAIN_STEPS)
	for z_index in range(TERRAIN_STEPS + 1):
		for x_index in range(TERRAIN_STEPS + 1):
			var left_x: int = max(x_index - 1, 0)
			var right_x: int = min(x_index + 1, TERRAIN_STEPS)
			var down_z: int = max(z_index - 1, 0)
			var up_z: int = min(z_index + 1, TERRAIN_STEPS)
			var left_height: float = terrain_heights[z_index * row_length + left_x]
			var right_height: float = terrain_heights[z_index * row_length + right_x]
			var down_height: float = terrain_heights[down_z * row_length + x_index]
			var up_height: float = terrain_heights[up_z * row_length + x_index]
			var normal := Vector3(left_height - right_height, vertex_spacing * 2.0, down_height - up_height).normalized()
			terrain_normals.append(normal)

	for z_index in range(TERRAIN_STEPS):
		for x_index in range(TERRAIN_STEPS):
			var base_index := z_index * row_length + x_index
			terrain_indices.append(base_index)
			terrain_indices.append(base_index + row_length)
			terrain_indices.append(base_index + 1)
			terrain_indices.append(base_index + 1)
			terrain_indices.append(base_index + row_length)
			terrain_indices.append(base_index + row_length + 1)

	_set_loading("Building shared water plane...", 0.68)
	await get_tree().process_frame

	_set_loading("Preparing cached RTS meshes...", 0.86)
	await get_tree().process_frame
	var terrain_mesh := _mesh_from_arrays(terrain_vertices, terrain_normals, terrain_colors, terrain_uvs, terrain_indices)
	var water_mesh := _build_water_plane_mesh(terrain_heights, row_length)
	var river_mesh := _build_river_surface_mesh(terrain_heights, row_length)
	var grid_mesh := _build_terrain_grid_mesh()
	var prop_data := _generate_prop_data(terrain_heights, row_length)
	var minimap_texture := _build_minimap_texture(prop_data)
	var center_height := _height_from_smoothed_terrain_at_uv(0.5, 0.5, terrain_heights, row_length)

	return {
		"terrain_mesh": terrain_mesh,
		"terrain_heights": terrain_heights,
		"terrain_row_length": row_length,
		"water_mesh": water_mesh,
		"river_mesh": river_mesh,
		"grid_mesh": grid_mesh,
		"props": prop_data,
		"minimap_texture": minimap_texture,
		"center_height": center_height,
	}


func _apply_rts_cell_data(data: Dictionary) -> void:
	rts_state_ready = false
	_clear_generated_nodes()
	_create_unit_selection_marker()
	terrain_surface_heights = data.get("terrain_heights", PackedFloat32Array())
	terrain_surface_row_length = int(data.get("terrain_row_length", 0))

	var terrain_mesh := MeshInstance3D.new()
	terrain_mesh.name = "DetailedTerrain"
	terrain_mesh.mesh = data["terrain_mesh"]
	terrain_mesh.material_override = _terrain_material()
	terrain_root.add_child(terrain_mesh)

	var water_mesh := data["water_mesh"] as ArrayMesh
	if water_mesh != null and water_mesh.get_surface_count() > 0:
		var water := MeshInstance3D.new()
		water.name = "StillOceanWater"
		water.mesh = water_mesh
		water.material_override = _water_material(false)
		terrain_root.add_child(water)
	var river_mesh := data.get("river_mesh") as ArrayMesh
	if river_mesh != null and river_mesh.get_surface_count() > 0:
		var river_water := MeshInstance3D.new()
		river_water.name = "RiverWater"
		river_water.mesh = river_mesh
		river_water.material_override = _water_material(true)
		terrain_root.add_child(river_water)

	var grid_mesh := data.get("grid_mesh") as ArrayMesh
	if grid_mesh != null and grid_mesh.get_surface_count() > 0:
		var grid := MeshInstance3D.new()
		grid.name = "ScaleGrid10m"
		grid.mesh = grid_mesh
		grid.visible = grid_visible
		terrain_root.add_child(grid)

	_spawn_cached_props(data.get("props", []))
	_spawn_starter_battle_entities()
	_apply_minimap_data(data)
	rts_state_ready = true
func _apply_minimap_data(data: Dictionary) -> void:
	if minimap_preview == null:
		return

	var texture := data.get("minimap_texture") as Texture2D
	if texture == null:
		texture = _build_minimap_texture(data.get("props", []))
	minimap_preview.map_texture = texture
	minimap_preview.friendly_points = _minimap_friendly_points()
	_update_minimap_preview(1.0)


func _build_minimap_texture(props: Array) -> Texture2D:
	var image := Image.create(MINIMAP_TEXTURE_SIZE, MINIMAP_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	for y in range(MINIMAP_TEXTURE_SIZE):
		var v: float = float(y) / float(MINIMAP_TEXTURE_SIZE - 1)
		for x in range(MINIMAP_TEXTURE_SIZE):
			var u: float = float(x) / float(MINIMAP_TEXTURE_SIZE - 1)
			var sample: Dictionary = _sample_cell_uv(u, v)
			image.set_pixel(x, y, _minimap_color_from_sample(sample))

	for prop in props:
		if not prop is Dictionary:
			continue
		var prop_data := prop as Dictionary
		var prop_type := str(prop_data.get("type", ""))
		if prop_type != "tree" and prop_type != "tree_impostor":
			continue
		if not prop_data.has("position") or not prop_data["position"] is Vector3:
			continue
		var position := prop_data["position"] as Vector3
		var pixel := _world_position_to_minimap_pixel(position)
		_paint_minimap_pixel(image, pixel, Color(0.68, 1.0, 0.56, 1.0), 1)

	return ImageTexture.create_from_image(image)


func _minimap_color_from_sample(sample: Dictionary) -> Color:
	var terrain: String = str(sample.get("terrain", "plains"))
	var biome: String = str(sample.get("biome", "grassland"))
	var river: float = float(sample.get("river", 0.0))
	if terrain == "water":
		var elevation: float = float(sample.get("elevation", WorldState.SEA_LEVEL))
		var shallow: float = smoothstep(WorldState.SEA_LEVEL - 0.14, WorldState.SEA_LEVEL - 0.012, elevation)
		return Color(0.02, 0.18, 0.52).lerp(Color(0.08, 0.42, 0.72), shallow)
	if river > 0.10:
		return Color(0.10, 0.52, 0.78).lerp(Color(0.18, 0.70, 0.90), clamp(river, 0.0, 1.0))
	if _is_beach_sample(sample):
		return Color(0.74, 0.66, 0.40)

	match biome:
		"rainforest":
			return Color(0.03, 0.42, 0.13)
		"temperate_forest":
			return Color(0.08, 0.48, 0.18)
		"forested_hills":
			return Color(0.12, 0.38, 0.17)
		"grassland":
			return Color(0.33, 0.62, 0.24)
		"dry_steppe":
			return Color(0.56, 0.52, 0.28)
		"hot_desert":
			return Color(0.75, 0.58, 0.30)
		"shallow_sea":
			return Color(0.08, 0.42, 0.72)
		"ocean":
			return Color(0.02, 0.18, 0.52)
		"snowfield", "polar_ice":
			return Color(0.86, 0.92, 0.90)
		"snowy_mountain":
			return Color(0.74, 0.78, 0.76)

	match terrain:
		"forest":
			return Color(0.08, 0.42, 0.16)
		"hills":
			return Color(0.36, 0.48, 0.23)
		"mountains":
			return Color(0.45, 0.42, 0.36)
		"snow":
			return Color(0.86, 0.92, 0.90)
		"desert":
			return Color(0.75, 0.58, 0.30)
		"tundra":
			return Color(0.46, 0.55, 0.46)
	return Color(0.34, 0.60, 0.24)


func _world_position_to_minimap_pixel(position: Vector3) -> Vector2i:
	var half_size := MAP_SIZE * 0.5
	return Vector2i(
		clamp(int(round(inverse_lerp(-half_size, half_size, position.x) * float(MINIMAP_TEXTURE_SIZE - 1))), 0, MINIMAP_TEXTURE_SIZE - 1),
		clamp(int(round(inverse_lerp(-half_size, half_size, position.z) * float(MINIMAP_TEXTURE_SIZE - 1))), 0, MINIMAP_TEXTURE_SIZE - 1)
	)


func _paint_minimap_pixel(image: Image, pixel: Vector2i, color: Color, radius: int) -> void:
	for y_offset in range(-radius, radius + 1):
		for x_offset in range(-radius, radius + 1):
			if x_offset * x_offset + y_offset * y_offset > radius * radius:
				continue
			var x: int = pixel.x + x_offset
			var y: int = pixel.y + y_offset
			if x < 0 or y < 0 or x >= MINIMAP_TEXTURE_SIZE or y >= MINIMAP_TEXTURE_SIZE:
				continue
			image.set_pixel(x, y, color)


func _minimap_friendly_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	var half_size := MAP_SIZE * 0.5
	for unit_data in battle_units:
		var position: Vector3 = unit_data.position
		points.append(Vector2(
			clamp(inverse_lerp(-half_size, half_size, position.x), 0.0, 1.0),
			clamp(inverse_lerp(-half_size, half_size, position.z), 0.0, 1.0)
		))
	return points


func _update_minimap_preview(delta: float) -> void:
	if minimap_preview == null or camera == null or minimap_collapsed:
		return

	minimap_update_elapsed += delta
	if minimap_update_elapsed < 0.08:
		return
	minimap_update_elapsed = 0.0

	var half_size := MAP_SIZE * 0.5
	minimap_preview.camera_map_position = Vector2(
		clamp(inverse_lerp(-half_size, half_size, camera.global_position.x), 0.0, 1.0),
		clamp(inverse_lerp(-half_size, half_size, camera.global_position.z), 0.0, 1.0)
	)
	var forward_3d := -camera.global_transform.basis.z
	minimap_preview.camera_forward = Vector2(forward_3d.x, forward_3d.z)
	minimap_preview.camera_fov_degrees = camera.fov
	minimap_preview.camera_view_distance_ratio = clamp(camera.global_position.y / MAP_SIZE * 1.65, 0.14, 0.48)
	minimap_preview.queue_redraw()


func _clear_generated_nodes() -> void:
	if terrain_root == null:
		return

	loaded_entity_count = 0
	full_model_entity_count = 0
	impostor_entity_count = 0
	resource_nodes_by_id.clear()
	resource_ring_batches_by_type.clear()
	falling_tree_animations.clear()
	resource_node_sequence = 0
	tree_impostor_lod_entries.clear()
	active_tree_impostor_full_nodes.clear()
	tree_impostor_lod_root = null
	tree_impostor_lod_elapsed = 0.0
	for child in terrain_root.get_children():
		child.queue_free()


func _mesh_from_arrays(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, uvs: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _smooth_terrain_heights(heights: PackedFloat32Array, row_length: int, passes: int) -> PackedFloat32Array:
	var smoothed := heights
	if passes <= 0:
		return smoothed

	for pass_index in range(passes):
		var next_heights := smoothed.duplicate()
		for z_index in range(1, row_length - 1):
			for x_index in range(1, row_length - 1):
				var index := z_index * row_length + x_index
				var average := (
					smoothed[index]
					+ smoothed[index - 1]
					+ smoothed[index + 1]
					+ smoothed[index - row_length]
					+ smoothed[index + row_length]
					+ smoothed[index - row_length - 1] * 0.5
					+ smoothed[index - row_length + 1] * 0.5
					+ smoothed[index + row_length - 1] * 0.5
					+ smoothed[index + row_length + 1] * 0.5
				) / 7.0
				next_heights[index] = lerpf(smoothed[index], average, TERRAIN_SMOOTH_BLEND)
		smoothed = next_heights
	return smoothed


func _build_water_plane_mesh(terrain_heights: PackedFloat32Array = PackedFloat32Array(), terrain_row_length: int = 0) -> ArrayMesh:
	var half_size := MAP_SIZE * 0.5
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var water_mask := PackedFloat32Array()
	var row_length := WATER_PLANE_STEPS + 1

	for z_index in range(WATER_PLANE_STEPS + 1):
		var v: float = float(z_index) / float(WATER_PLANE_STEPS)
		for x_index in range(WATER_PLANE_STEPS + 1):
			var u: float = float(x_index) / float(WATER_PLANE_STEPS)
			var sample := _sample_cell_uv(u, v)
			var elevation := float(sample.get("elevation", WorldState.SEA_LEVEL + 1.0))
			var ocean_alpha := 1.0 - smoothstep(WorldState.SEA_LEVEL - 0.008, WorldState.SEA_LEVEL + 0.006, elevation)
			if str(sample.get("terrain", "land")) == "water":
				ocean_alpha = maxf(ocean_alpha, 0.82)
			ocean_alpha = clampf(ocean_alpha, 0.0, 1.0)
			var terrain_height := _height_from_smoothed_terrain_at_uv(u, v, terrain_heights, terrain_row_length)
			var dry_height := minf(WATER_SURFACE_HEIGHT, terrain_height - WATER_SHORE_DROOP_DEPTH)
			var vertex_height := lerpf(dry_height, WATER_SURFACE_HEIGHT, ocean_alpha)
			vertices.append(Vector3(lerpf(-half_size, half_size, u), vertex_height, lerpf(-half_size, half_size, v)))
			normals.append(Vector3.UP)
			uvs.append(Vector2(u, v))
			colors.append(Color(0.5, 0.5, 1.0, ocean_alpha))
			water_mask.append(ocean_alpha)

	for z_index in range(WATER_PLANE_STEPS):
		for x_index in range(WATER_PLANE_STEPS):
			var base_index: int = z_index * row_length + x_index
			var maximum_water_mask := maxf(
				maxf(water_mask[base_index], water_mask[base_index + 1]),
				maxf(water_mask[base_index + row_length], water_mask[base_index + row_length + 1])
			)
			if maximum_water_mask <= 0.001:
				continue
			indices.append(base_index)
			indices.append(base_index + row_length)
			indices.append(base_index + 1)
			indices.append(base_index + 1)
			indices.append(base_index + row_length)
			indices.append(base_index + row_length + 1)
	return _water_mesh_from_arrays(vertices, uvs, indices, normals, colors)


func _build_river_surface_mesh(terrain_heights: PackedFloat32Array = PackedFloat32Array(), terrain_row_length: int = 0) -> ArrayMesh:
	var terrain_vertices := PackedVector3Array()
	var sampled_heights := PackedFloat32Array()
	var river_values := PackedFloat32Array()
	var water_values := PackedFloat32Array()
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var row_length := RIVER_SURFACE_STEPS + 1
	var half_size := MAP_SIZE * 0.5
	for z_index in range(row_length):
		var v := float(z_index) / float(RIVER_SURFACE_STEPS)
		for x_index in range(row_length):
			var u := float(x_index) / float(RIVER_SURFACE_STEPS)
			var sample := _sample_cell_uv(u, v)
			terrain_vertices.append(Vector3(lerpf(-half_size, half_size, u), 0.0, lerpf(-half_size, half_size, v)))
			sampled_heights.append(_height_from_smoothed_terrain_at_uv(u, v, terrain_heights, terrain_row_length))
			river_values.append(float(sample.get("river", 0.0)))
			water_values.append(1.0 if str(sample.get("terrain", "land")) == "water" else 0.0)
	for z_index in range(RIVER_SURFACE_STEPS):
		for x_index in range(RIVER_SURFACE_STEPS):
			_add_river_surface_cell(vertices, uvs, colors, indices, terrain_vertices, sampled_heights, river_values, water_values, row_length, x_index, z_index)
	return _water_mesh_from_arrays(vertices, uvs, indices, PackedVector3Array(), colors)


func _is_water_surface_sample(sample: Dictionary) -> bool:
	return str(sample.get("terrain", "water")) == "water" or float(sample.get("river", 0.0)) >= WATER_RIVER_MASK_THRESHOLD


func _water_mesh_from_arrays(vertices: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, normals: PackedVector3Array = PackedVector3Array(), colors: PackedColorArray = PackedColorArray()) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if vertices.is_empty():
		return mesh

	if normals.is_empty():
		for index in range(vertices.size()):
			normals.append(Vector3.UP)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	if not colors.is_empty():
		arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _add_river_surface_cell(
	vertices: PackedVector3Array,
	uvs: PackedVector2Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	terrain_vertices: PackedVector3Array,
	terrain_heights: PackedFloat32Array,
	river_values: PackedFloat32Array,
	water_values: PackedFloat32Array,
	row_length: int,
	x_index: int,
	z_index: int
) -> void:
	var i00: int = z_index * row_length + x_index
	var i10: int = i00 + 1
	var i01: int = i00 + row_length
	var i11: int = i01 + 1
	var alpha00: float = _river_render_alpha(river_values[i00], water_values[i00])
	var alpha10: float = _river_render_alpha(river_values[i10], water_values[i10])
	var alpha01: float = _river_render_alpha(river_values[i01], water_values[i01])
	var alpha11: float = _river_render_alpha(river_values[i11], water_values[i11])
	if max(max(alpha00, alpha10), max(alpha01, alpha11)) <= RIVER_MESH_EDGE_ALPHA:
		return

	var point00 := _river_surface_point(terrain_vertices[i00], terrain_heights[i00], alpha00, _river_flow_vector_at_vertex(terrain_heights, river_values, water_values, row_length, x_index, z_index))
	var point10 := _river_surface_point(terrain_vertices[i10], terrain_heights[i10], alpha10, _river_flow_vector_at_vertex(terrain_heights, river_values, water_values, row_length, x_index + 1, z_index))
	var point01 := _river_surface_point(terrain_vertices[i01], terrain_heights[i01], alpha01, _river_flow_vector_at_vertex(terrain_heights, river_values, water_values, row_length, x_index, z_index + 1))
	var point11 := _river_surface_point(terrain_vertices[i11], terrain_heights[i11], alpha11, _river_flow_vector_at_vertex(terrain_heights, river_values, water_values, row_length, x_index + 1, z_index + 1))
	_add_clipped_river_triangle(vertices, uvs, colors, indices, point00, point01, point10)
	_add_clipped_river_triangle(vertices, uvs, colors, indices, point10, point01, point11)


func _river_surface_point(position: Vector3, terrain_height: float, alpha: float, flow: Vector2) -> Dictionary:
	return {
		"position": position,
		"terrain_height": terrain_height,
		"alpha": alpha,
		"flow": flow,
	}


func _add_clipped_river_triangle(
	vertices: PackedVector3Array,
	uvs: PackedVector2Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	point_a: Dictionary,
	point_b: Dictionary,
	point_c: Dictionary
) -> void:
	var input_polygon: Array = [point_a, point_b, point_c]
	var clipped_polygon: Array = []
	var previous_point: Dictionary = input_polygon[input_polygon.size() - 1]
	var previous_inside := float(previous_point["alpha"]) > RIVER_MESH_EDGE_ALPHA
	for current_value in input_polygon:
		var current_point: Dictionary = current_value
		var current_inside := float(current_point["alpha"]) > RIVER_MESH_EDGE_ALPHA
		if current_inside != previous_inside:
			clipped_polygon.append(_interpolate_river_surface_point(previous_point, current_point, RIVER_MESH_EDGE_ALPHA))
		if current_inside:
			clipped_polygon.append(current_point)
		previous_point = current_point
		previous_inside = current_inside

	if clipped_polygon.size() < 3:
		return
	for triangle_index in range(1, clipped_polygon.size() - 1):
		var base_index := vertices.size()
		_append_river_surface_point(vertices, uvs, colors, clipped_polygon[0])
		_append_river_surface_point(vertices, uvs, colors, clipped_polygon[triangle_index])
		_append_river_surface_point(vertices, uvs, colors, clipped_polygon[triangle_index + 1])
		indices.append(base_index)
		indices.append(base_index + 1)
		indices.append(base_index + 2)


func _interpolate_river_surface_point(start_point: Dictionary, end_point: Dictionary, target_alpha: float) -> Dictionary:
	var start_alpha := float(start_point["alpha"])
	var end_alpha := float(end_point["alpha"])
	var weight := 0.5
	if not is_equal_approx(start_alpha, end_alpha):
		weight = clampf((target_alpha - start_alpha) / (end_alpha - start_alpha), 0.0, 1.0)
	var start_position: Vector3 = start_point["position"]
	var end_position: Vector3 = end_point["position"]
	var start_flow: Vector2 = start_point["flow"]
	var end_flow: Vector2 = end_point["flow"]
	return _river_surface_point(
		start_position.lerp(end_position, weight),
		lerpf(float(start_point["terrain_height"]), float(end_point["terrain_height"]), weight),
		target_alpha,
		start_flow.lerp(end_flow, weight)
	)


func _append_river_surface_point(vertices: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, point: Dictionary) -> void:
	var position: Vector3 = point["position"]
	var flow: Vector2 = point["flow"]
	_add_river_surface_vertex(vertices, uvs, colors, position, float(point["terrain_height"]), float(point["alpha"]), flow)


func _add_river_surface_vertex(vertices: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, terrain_vertex: Vector3, _terrain_height: float, alpha: float, flow_vector: Vector2) -> void:
	var y: float = WATER_SURFACE_HEIGHT + 0.04
	vertices.append(Vector3(terrain_vertex.x, y, terrain_vertex.z))
	uvs.append(Vector2(terrain_vertex.x, terrain_vertex.z) / MAP_SIZE)
	var flow := flow_vector.normalized()
	if flow.length_squared() <= 0.001:
		flow = Vector2(0.0, 1.0)
	colors.append(Color(flow.x * 0.5 + 0.5, flow.y * 0.5 + 0.5, 1.0, alpha))


func _river_flow_vector_at_vertex(terrain_heights: PackedFloat32Array, river_values: PackedFloat32Array, water_values: PackedFloat32Array, row_length: int, x_index: int, z_index: int) -> Vector2:
	var map_max := row_length - 1
	var clamped_x: int = clamp(x_index, 0, map_max)
	var clamped_z: int = clamp(z_index, 0, map_max)
	var center_index: int = clamped_z * row_length + clamped_x
	var center_height: float = terrain_heights[center_index]
	var best := Vector2.ZERO
	var best_score := INF
	var search_radius := 5

	for z_offset in range(-search_radius, search_radius + 1):
		for x_offset in range(-search_radius, search_radius + 1):
			if x_offset == 0 and z_offset == 0:
				continue
			var sample_x: int = clamp(clamped_x + x_offset, 0, map_max)
			var sample_z: int = clamp(clamped_z + z_offset, 0, map_max)
			var sample_index: int = sample_z * row_length + sample_x
			var candidate_river: float = river_values[sample_index]
			var candidate_water: float = water_values[sample_index]
			if candidate_river < RIVER_RENDER_EDGE and candidate_water < 0.5:
				continue
			var offset := Vector2(float(sample_x - clamped_x), float(sample_z - clamped_z))
			var distance: float = max(offset.length(), 1.0)
			var height_drop: float = center_height - terrain_heights[sample_index]
			var score: float = -height_drop - candidate_water * 7.0 - candidate_river * 0.85 + distance * 0.12
			if score < best_score:
				best_score = score
				best = offset / distance

	if best.length_squared() > 0.001:
		return best

	var left_x: int = max(clamped_x - 1, 0)
	var right_x: int = min(clamped_x + 1, map_max)
	var down_z: int = max(clamped_z - 1, 0)
	var up_z: int = min(clamped_z + 1, map_max)
	var left_height: float = terrain_heights[clamped_z * row_length + left_x]
	var right_height: float = terrain_heights[clamped_z * row_length + right_x]
	var down_height: float = terrain_heights[down_z * row_length + clamped_x]
	var up_height: float = terrain_heights[up_z * row_length + clamped_x]
	return Vector2(left_height - right_height, down_height - up_height).normalized()


func _river_render_alpha(river: float, water: float) -> float:
	var alpha: float = smoothstep(RIVER_RENDER_EDGE, RIVER_RENDER_FULL, river)
	alpha *= 1.0 - smoothstep(0.0, 0.85, water)
	return clamp(alpha, 0.0, 1.0)


func _add_water_quad(vertices: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	var base_index := vertices.size()
	vertices.append(Vector3(x0, y, z0))
	vertices.append(Vector3(x1, y, z0))
	vertices.append(Vector3(x0, y, z1))
	vertices.append(Vector3(x1, y, z1))
	uvs.append(Vector2(x0, z0) / MAP_SIZE)
	uvs.append(Vector2(x1, z0) / MAP_SIZE)
	uvs.append(Vector2(x0, z1) / MAP_SIZE)
	uvs.append(Vector2(x1, z1) / MAP_SIZE)
	indices.append(base_index)
	indices.append(base_index + 2)
	indices.append(base_index + 1)
	indices.append(base_index + 1)
	indices.append(base_index + 2)
	indices.append(base_index + 3)


func _sample_cell_uv(u: float, v: float) -> Dictionary:
	var sample: Dictionary = _sample_cell_uv_raw(u, v)
	sample["river"] = _smooth_river_at_uv(u, v)
	return sample


func _sample_cell_uv_raw(u: float, v: float) -> Dictionary:
	if Game.world_state == null or cell == null:
		return {
			"terrain": "plains",
			"elevation": WorldState.SEA_LEVEL + 0.10,
			"moisture": 0.45,
			"temperature": 0.55,
			"ridge": 0.0,
			"raw_noise": 0.5,
			"river": 0.0,
		}
	return Game.world_state.sample_cell(cell, clamp(u, 0.0, 1.0), clamp(v, 0.0, 1.0))


func _smooth_river_at_uv(u: float, v: float) -> float:
	if smoothed_river_map.is_empty() or smoothed_river_map_size <= 1:
		_build_smoothed_river_map()
	if smoothed_river_map.is_empty() or smoothed_river_map_size <= 1:
		return float(_sample_cell_uv_raw(u, v).get("river", 0.0))

	var map_max := smoothed_river_map_size - 1
	var map_x: float = clamp(u, 0.0, 1.0) * float(map_max)
	var map_y: float = clamp(v, 0.0, 1.0) * float(map_max)
	var base_x: int = int(floor(map_x))
	var base_y: int = int(floor(map_y))
	var tx: float = map_x - float(base_x)
	var ty: float = map_y - float(base_y)
	var rows := PackedFloat32Array()
	for y_offset in range(-1, 3):
		var sample_y := clampi(base_y + y_offset, 0, map_max)
		var p0: float = smoothed_river_map[sample_y * smoothed_river_map_size + clampi(base_x - 1, 0, map_max)]
		var p1: float = smoothed_river_map[sample_y * smoothed_river_map_size + clampi(base_x, 0, map_max)]
		var p2: float = smoothed_river_map[sample_y * smoothed_river_map_size + clampi(base_x + 1, 0, map_max)]
		var p3: float = smoothed_river_map[sample_y * smoothed_river_map_size + clampi(base_x + 2, 0, map_max)]
		rows.append(_catmull_rom_river_value(p0, p1, p2, p3, tx))
	return clampf(_catmull_rom_river_value(rows[0], rows[1], rows[2], rows[3], ty), 0.0, 1.0)


func _catmull_rom_river_value(p0: float, p1: float, p2: float, p3: float, weight: float) -> float:
	var weight_squared := weight * weight
	var weight_cubed := weight_squared * weight
	return 0.5 * (
		2.0 * p1
		+ (-p0 + p2) * weight
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * weight_squared
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * weight_cubed
	)


func _height_from_smoothed_terrain_at_uv(u: float, v: float, terrain_heights: PackedFloat32Array, row_length: int) -> float:
	if terrain_heights.is_empty() or row_length <= 1:
		return _height_from_sample(_sample_cell_uv(u, v))

	var map_max := row_length - 1
	var map_x: float = clamp(u, 0.0, 1.0) * float(map_max)
	var map_y: float = clamp(v, 0.0, 1.0) * float(map_max)
	var x0: int = int(floor(map_x))
	var y0: int = int(floor(map_y))
	var x1: int = min(x0 + 1, map_max)
	var y1: int = min(y0 + 1, map_max)
	var tx: float = map_x - float(x0)
	var ty: float = map_y - float(y0)
	var h00: float = terrain_heights[y0 * row_length + x0]
	var h10: float = terrain_heights[y0 * row_length + x1]
	var h01: float = terrain_heights[y1 * row_length + x0]
	var h11: float = terrain_heights[y1 * row_length + x1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), ty)


func _build_smoothed_river_map() -> void:
	smoothed_river_map_size = RIVER_MASK_STEPS + 1
	var total_size := smoothed_river_map_size * smoothed_river_map_size
	var raw := PackedFloat32Array()
	raw.resize(total_size)
	smoothed_river_map = PackedFloat32Array()
	smoothed_river_map.resize(total_size)

	for y_index in range(smoothed_river_map_size):
		var v: float = float(y_index) / float(smoothed_river_map_size - 1)
		for x_index in range(smoothed_river_map_size):
			var u: float = float(x_index) / float(smoothed_river_map_size - 1)
			var sample: Dictionary = _sample_cell_uv_raw(u, v)
			raw[y_index * smoothed_river_map_size + x_index] = float(sample.get("river", 0.0))

	var radius := RIVER_SMOOTH_RADIUS
	for y_index in range(smoothed_river_map_size):
		for x_index in range(smoothed_river_map_size):
			var weighted_sum := 0.0
			var total_weight := 0.0
			var dilated := 0.0
			for y_offset in range(-radius, radius + 1):
				for x_offset in range(-radius, radius + 1):
					var offset := Vector2(float(x_offset), float(y_offset))
					var distance: float = offset.length()
					if distance > float(radius):
						continue
					var sx: int = clamp(x_index + x_offset, 0, smoothed_river_map_size - 1)
					var sy: int = clamp(y_index + y_offset, 0, smoothed_river_map_size - 1)
					var raw_river: float = raw[sy * smoothed_river_map_size + sx]
					var weight: float = 1.0 - smoothstep(0.0, float(radius), distance)
					weight = max(weight * weight, 0.018)
					weighted_sum += raw_river * weight
					total_weight += weight
					var rounded_falloff: float = 1.0 - smoothstep(0.35, float(radius), distance)
					dilated = max(dilated, raw_river * rounded_falloff)

			var softened: float = weighted_sum / max(total_weight, 0.001)
			var connected: float = max(dilated, softened * 1.22)
			smoothed_river_map[y_index * smoothed_river_map_size + x_index] = clamp(smoothstep(0.04, 0.82, connected), 0.0, 1.0)


func _height_from_sample(sample: Dictionary) -> float:
	var terrain: String = str(sample["terrain"])
	var elevation: float = float(sample["elevation"])
	var ridge: float = float(sample.get("ridge", 0.0))
	var raw_noise: float = float(sample.get("raw_noise", elevation))
	var river: float = float(sample.get("river", 0.0))
	if terrain == "water":
		var depth: float = clamp((WorldState.SEA_LEVEL - elevation) * 12.0, 0.0, 5.5)
		return TERRAIN_BASE_HEIGHT - depth

	var land_height: float = max(0.0, elevation - WorldState.SEA_LEVEL) * TERRAIN_HEIGHT_SCALE
	land_height += (ridge - 0.45) * 4.0
	land_height += (raw_noise - 0.5) * 2.0
	if river > 0.06:
		var bank_cut: float = smoothstep(0.06, 0.22, river)
		var floor_cut: float = smoothstep(0.16, 0.52, river)
		var shoulder_height: float = WATER_SURFACE_HEIGHT + 0.14
		var bed_height: float = WATER_SURFACE_HEIGHT - 0.72 - smoothstep(0.56, 0.92, river) * 0.28
		var river_target_height: float = lerpf(shoulder_height, bed_height, floor_cut)
		land_height = lerpf(land_height, min(land_height, river_target_height), bank_cut)
	return land_height


func _terrain_color_from_sample(sample: Dictionary) -> Color:
	var terrain: String = str(sample["terrain"])
	var elevation: float = float(sample["elevation"])
	var moisture: float = float(sample["moisture"])
	var temperature: float = float(sample["temperature"])
	var river: float = float(sample.get("river", 0.0))
	var ridge: float = float(sample.get("ridge", 0.0))
	var land_height: float = clamp((elevation - WorldState.SEA_LEVEL) / max(1.0 - WorldState.SEA_LEVEL, 0.001), 0.0, 1.0)
	var color := Color(0.32, 0.56, 0.24)
	match terrain:
		"water":
			var depth: float = clamp((WorldState.SEA_LEVEL - elevation) * 7.0, 0.0, 1.0)
			var water_color: Color = Color(0.02, 0.12, 0.25).lerp(Color(0.08, 0.32, 0.48), 1.0 - depth)
			var sea_edge: float = smoothstep(WorldState.SEA_LEVEL - 0.080, WorldState.SEA_LEVEL - 0.006, elevation)
			var sea_floor: Color = Color(0.52, 0.47, 0.36).lerp(Color(0.36, 0.36, 0.34), clamp(ridge * 0.70, 0.0, 1.0))
			water_color = water_color.lerp(sea_floor, clamp(sea_edge * 0.44, 0.0, 0.44))
			return water_color
		"mountains":
			color = Color(0.32, 0.28, 0.22).lerp(Color(0.64, 0.62, 0.56), clamp(ridge * 0.75, 0.0, 0.75))
		"snow":
			color = Color(0.75, 0.84, 0.86).lerp(Color(0.96, 0.98, 0.94), clamp(1.0 - temperature, 0.0, 0.8))
		"desert":
			color = Color(0.62, 0.49, 0.25).lerp(Color(0.84, 0.70, 0.38), clamp(elevation, 0.0, 1.0) * 0.35)
		"tundra":
			color = Color(0.34, 0.43, 0.36).lerp(Color(0.55, 0.62, 0.56), moisture * 0.32)
		"hills":
			color = Color(0.29, 0.43, 0.22).lerp(Color(0.55, 0.51, 0.38), clamp(elevation, 0.0, 1.0) * 0.45)
		"forest":
			color = Color(0.06, 0.30, 0.12).lerp(Color(0.12, 0.45, 0.18), moisture * 0.28)
		_:
			var dry: float = clamp((1.0 - moisture) * 0.7 + temperature * 0.18, 0.0, 1.0)
			color = Color(0.32, 0.56, 0.24).lerp(Color(0.69, 0.60, 0.34), dry * 0.45)

	var coast_edge: float = 1.0 - smoothstep(WorldState.SEA_LEVEL + 0.004, WorldState.SEA_LEVEL + 0.060, elevation)
	if coast_edge > 0.0:
		var coast_sand := Color(0.73, 0.63, 0.40)
		var coast_rock := Color(0.42, 0.39, 0.33)
		var coast_rock_mix: float = clamp(ridge * 0.64 + land_height * 0.28, 0.0, 1.0)
		var coast_color: Color = coast_sand.lerp(coast_rock, coast_rock_mix)
		color = color.lerp(coast_color, clamp(coast_edge * 0.76, 0.0, 0.76))

	var river_bank: float = smoothstep(0.06, 0.34, river) * (1.0 - smoothstep(0.48, 0.74, river))
	if river_bank > 0.0:
		var river_sand := Color(0.73, 0.63, 0.40)
		var river_rock := Color(0.42, 0.39, 0.33)
		var river_rock_mix: float = clamp(ridge * 0.64 + land_height * 0.28, 0.0, 1.0)
		var river_shore_color: Color = river_sand.lerp(river_rock, river_rock_mix)
		color = color.lerp(river_shore_color, clamp(river_bank * 0.76, 0.0, 0.76))

	var river_bed: float = smoothstep(0.42, 0.72, river)
	if river_bed > 0.0:
		var bed_color: Color = Color(0.30, 0.31, 0.29).lerp(Color(0.47, 0.45, 0.39), clamp(1.0 - ridge, 0.0, 0.55))
		color = color.lerp(bed_color, clamp(river_bed * 0.84, 0.0, 0.84))

	return color


func _generate_prop_data(terrain_heights: PackedFloat32Array, row_length: int) -> Array:
	var props: Array = []
	if Game.world_state == null or cell == null:
		return props

	var rng := RandomNumberGenerator.new()
	rng.seed = int(Game.world_state.seed) + int(cell.x) * 99173 + int(cell.y) * 57121
	var tree_spacing_hash: Dictionary = {}
	var full_tree_selection: Dictionary = {
		"count": 0,
		"buckets": {},
	}
	var accepted_tree_count := 0
	var prop_limit := MAP_SIZE * 0.5 - PROP_EDGE_INSET
	for index in range(TREE_SAMPLE_COUNT):
		var x := rng.randf_range(-prop_limit, prop_limit)
		var z := rng.randf_range(-prop_limit, prop_limit)
		var u := inverse_lerp(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, x)
		var v := inverse_lerp(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, z)
		var sample := _sample_cell_uv(u, v)
		if _blocks_tree_spawn(sample, u, v):
			continue
		var tree_asset := _tree_asset_for_sample(sample, rng)
		if not tree_asset.is_empty() and rng.randf() < _tree_chance_for_sample(sample, x, z):
			var next_tree_index := accepted_tree_count + 1
			if next_tree_index % DEAD_TREE_FREQUENCY == 0:
				tree_asset = _dead_tree_asset_for_sample(sample, rng)
			var scale_value := _tree_runtime_scale_for_asset(tree_asset, rng)
			var spacing_radius := _tree_spacing_radius_for_asset(tree_asset, scale_value)
			if not _can_place_tree_at(tree_spacing_hash, x, z, spacing_radius):
				continue
			_remember_tree_position(tree_spacing_hash, x, z, spacing_radius)
			accepted_tree_count = next_tree_index
			var prop_type := "tree"
			if TREE_IMPOSTORS_ENABLED and not _is_dead_tree_asset(tree_asset) and not _reserve_full_tree_slot(full_tree_selection, x, z):
				prop_type = "tree_impostor"
			props.append({
				"type": prop_type,
				"asset": tree_asset,
				"position": Vector3(x, _height_from_smoothed_terrain_at_uv(u, v, terrain_heights, row_length), z),
				"scale": scale_value,
				"rotation": rng.randf_range(0.0, TAU),
			})

	for index in range(DETAIL_PROP_SAMPLE_COUNT):
		var x := rng.randf_range(-prop_limit, prop_limit)
		var z := rng.randf_range(-prop_limit, prop_limit)
		var u := inverse_lerp(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, x)
		var v := inverse_lerp(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, z)
		var sample := _sample_cell_uv(u, v)
		var terrain: String = str(sample["terrain"])
		var river: float = float(sample.get("river", 0.0))
		if terrain == "water" or river > 0.18:
			continue
		var prop_type := ""
		var asset_path := ""
		var prop_scale := rng.randf_range(0.75, 1.45)
		var river_bank_score := _river_bank_detail_score(sample, u, v)
		if river_bank_score > 0.12 and rng.randf() < lerpf(0.16, 0.48, river_bank_score):
			prop_type = "detail"
			asset_path = _pick_tree_asset(FLINT_STONE_ASSETS, rng)
			prop_scale = rng.randf_range(0.85, 1.65)
		elif terrain == "forest" and rng.randf() < 0.030:
			prop_type = "detail"
			asset_path = _pick_tree_asset(BROKEN_TREE_ASSETS, rng)
			prop_scale = rng.randf_range(1.55, 2.75)
		elif terrain in ["forest", "plains", "hills", "desert"] and rng.randf() < 0.010:
			prop_type = "detail"
			asset_path = _pick_tree_asset(BONE_PILE_ASSETS, rng)
			prop_scale = rng.randf_range(1.10, 1.85)
		elif terrain in ["forest", "plains", "hills", "tundra"] and rng.randf() < 0.006:
			prop_type = "detail"
			asset_path = _pick_tree_asset(CARCASS_ASSETS, rng)
			prop_scale = rng.randf_range(1.25, 2.05)
		if prop_type.is_empty() and terrain in ["hills", "mountains", "snow", "desert"] and rng.randf() < 0.68:
			asset_path = _pick_tree_asset(ROCK_ASSETS, rng)
			if rng.randf() < 0.025:
				prop_type = "resource_deposit"
				prop_scale = rng.randf_range(1.35, 2.05)
			else:
				prop_type = "scenery"
		if prop_type.is_empty():
			continue
		var detail_prop := {
			"type": prop_type,
			"asset": asset_path,
			"position": Vector3(x, _height_from_smoothed_terrain_at_uv(u, v, terrain_heights, row_length), z),
			"scale": prop_scale,
			"rotation": rng.randf_range(0.0, TAU),
		}
		if prop_type == "resource_deposit":
			detail_prop.merge({
				"resource_type": "stone",
				"amount": STONE_DEPOSIT_AMOUNT,
				"cluster_count": rng.randi_range(6, 9),
				"cluster_spread": rng.randf_range(5.4, 7.2),
			})
		props.append(detail_prop)

	for index in range(MINERAL_DEPOSIT_SAMPLE_COUNT):
		var ore_x := rng.randf_range(-prop_limit, prop_limit)
		var ore_z := rng.randf_range(-prop_limit, prop_limit)
		var ore_u := inverse_lerp(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, ore_x)
		var ore_v := inverse_lerp(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, ore_z)
		var ore_sample := _sample_cell_uv(ore_u, ore_v)
		var ore_terrain := str(ore_sample.get("terrain", "plains"))
		if ore_terrain not in ["hills", "mountains", "snow", "tundra"]:
			continue
		var ore_chance := 0.11 if ore_terrain in ["hills", "mountains"] else 0.045
		if rng.randf() > ore_chance:
			continue
		var ore_type := _ore_deposit_type_for_sample(ore_sample, rng)
		var ore_asset := str(ORE_DEPOSIT_ASSETS.get(ore_type, ""))
		if ore_asset.is_empty():
			continue
		props.append({
			"type": "resource_deposit",
			"resource_type": ore_type,
			"asset": ore_asset,
			"position": Vector3(ore_x, _height_from_smoothed_terrain_at_uv(ore_u, ore_v, terrain_heights, row_length), ore_z),
			"scale": rng.randf_range(2.2, 3.2),
			"rotation": rng.randf_range(0.0, TAU),
			"amount": _resource_deposit_amount(ore_type),
			"cluster_count": rng.randi_range(5, 8),
			"cluster_spread": rng.randf_range(4.6, 6.4),
		})

	for index in range(FISH_DEPOSIT_SAMPLE_COUNT):
		var fish_x := rng.randf_range(-prop_limit, prop_limit)
		var fish_z := rng.randf_range(-prop_limit, prop_limit)
		var fish_u := inverse_lerp(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, fish_x)
		var fish_v := inverse_lerp(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, fish_z)
		var fish_sample := _sample_cell_uv(fish_u, fish_v)
		var fish_terrain := str(fish_sample.get("terrain", "plains"))
		if fish_terrain != "water":
			continue
		var fish_water_depth := WorldState.SEA_LEVEL - float(fish_sample.get("elevation", 0.0))
		if fish_water_depth < 0.075 or fish_water_depth > 0.24:
			continue
		if rng.randf() > 0.16:
			continue
		props.append({
			"type": "resource_deposit",
			"resource_type": "fish",
			"assets": FISH_DEPOSIT_ASSETS,
			"asset": _pick_tree_asset(FISH_DEPOSIT_ASSETS, rng),
			"position": Vector3(fish_x, WATER_SURFACE_HEIGHT + 0.10, fish_z),
			"scale": rng.randf_range(0.20, 0.30),
			"rotation": rng.randf_range(0.0, TAU),
			"amount": FISH_DEPOSIT_AMOUNT,
			"cluster_count": rng.randi_range(22, 30),
			"cluster_spread": rng.randf_range(46.0, 64.0),
			"visual_y_offset": -1.30,
		})

	for index in range(SHALLOW_FISH_DEPOSIT_SAMPLE_COUNT):
		var shallow_fish_x := rng.randf_range(-prop_limit, prop_limit)
		var shallow_fish_z := rng.randf_range(-prop_limit, prop_limit)
		var shallow_fish_u := inverse_lerp(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, shallow_fish_x)
		var shallow_fish_v := inverse_lerp(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, shallow_fish_z)
		var shallow_fish_sample := _sample_cell_uv(shallow_fish_u, shallow_fish_v)
		var shallow_fish_terrain := str(shallow_fish_sample.get("terrain", "plains"))
		var shallow_fish_river := float(shallow_fish_sample.get("river", 0.0))
		var shallow_fish_water_depth := WorldState.SEA_LEVEL - float(shallow_fish_sample.get("elevation", 0.0))
		var shallow_coastal_water := shallow_fish_terrain == "water" and shallow_fish_water_depth >= 0.008 and shallow_fish_water_depth < 0.075
		var shallow_river_water := shallow_fish_terrain != "water" and shallow_fish_river >= 0.52
		if not shallow_coastal_water and not shallow_river_water:
			continue
		if rng.randf() > (0.15 if shallow_coastal_water else 0.09):
			continue
		props.append({
			"type": "resource_deposit",
			"resource_type": "fish",
			"assets": FISH_DEPOSIT_ASSETS,
			"asset": _pick_tree_asset(FISH_DEPOSIT_ASSETS, rng),
			"position": Vector3(shallow_fish_x, WATER_SURFACE_HEIGHT + 0.10, shallow_fish_z),
			"scale": rng.randf_range(0.15, 0.21),
			"rotation": rng.randf_range(0.0, TAU),
			"amount": SHALLOW_FISH_DEPOSIT_AMOUNT,
			"cluster_count": rng.randi_range(6, 11),
			"cluster_spread": rng.randf_range(22.0, 32.0),
			"visual_y_offset": -0.46,
		})

	for index in range(WHALE_OIL_DEPOSIT_SAMPLE_COUNT):
		var whale_x := rng.randf_range(-prop_limit, prop_limit)
		var whale_z := rng.randf_range(-prop_limit, prop_limit)
		var whale_u := inverse_lerp(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, whale_x)
		var whale_v := inverse_lerp(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, whale_z)
		var whale_sample := _sample_cell_uv(whale_u, whale_v)
		if str(whale_sample.get("terrain", "plains")) != "water":
			continue
		var whale_water_depth := WorldState.SEA_LEVEL - float(whale_sample.get("elevation", 0.0))
		if whale_water_depth < 0.055 or whale_water_depth > 0.24 or rng.randf() > 0.07:
			continue
		props.append({
			"type": "resource_deposit",
			"resource_type": "whale_oil",
			"assets": WHALE_OIL_DEPOSIT_ASSETS,
			"asset": WHALE_ASSET,
			"member_scale_multipliers": WHALE_OIL_MEMBER_SCALE_MULTIPLIERS,
			"position": Vector3(whale_x, WATER_SURFACE_HEIGHT + 0.10, whale_z),
			"scale": rng.randf_range(0.52, 0.68),
			"rotation": rng.randf_range(0.0, TAU),
			"amount": WHALE_OIL_DEPOSIT_AMOUNT,
			"cluster_count": rng.randi_range(10, 14),
			"cluster_spread": rng.randf_range(24.0, 34.0),
			"visual_y_offset": -1.15,
			"swim_speed_range": Vector2(0.18, 0.38),
			"animation_speed": 0.88,
		})

	for index in range(OPEN_GROUND_PROP_SAMPLE_COUNT):
		var cover_x := rng.randf_range(-prop_limit, prop_limit)
		var cover_z := rng.randf_range(-prop_limit, prop_limit)
		var cover_u := inverse_lerp(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, cover_x)
		var cover_v := inverse_lerp(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, cover_z)
		var cover_sample := _sample_cell_uv(cover_u, cover_v)
		if _blocks_ground_cover_spawn(cover_sample):
			continue
		if rng.randf() > _ground_cover_chance_for_sample(cover_sample, cover_x, cover_z):
			continue
		var cover_asset := _ground_cover_asset_for_sample(cover_sample, rng)
		if cover_asset.is_empty():
			continue
		var cover_type := "scenery"
		var cover_name := cover_asset.get_file().get_basename().to_lower()
		if cover_name.begins_with("bushberries") and rng.randf() < 0.10:
			cover_type = "resource_deposit"
		var cover_prop := {
			"type": cover_type,
			"asset": cover_asset,
			"position": Vector3(
				cover_x,
				_height_from_smoothed_terrain_at_uv(cover_u, cover_v, terrain_heights, row_length),
				cover_z
			),
			"scale": _ground_cover_scale_for_asset(cover_asset, rng),
			"rotation": rng.randf_range(0.0, TAU),
		}
		if cover_type == "resource_deposit":
			cover_prop.merge({
				"resource_type": "food",
				"amount": FOOD_DEPOSIT_AMOUNT,
				"cluster_count": rng.randi_range(5, 8),
				"cluster_spread": rng.randf_range(4.5, 6.5),
			})
		props.append(cover_prop)
	return props


func _ore_deposit_type_for_sample(sample: Dictionary, rng: RandomNumberGenerator) -> String:
	var ridge := float(sample.get("ridge", 0.0))
	var elevation := float(sample.get("elevation", WorldState.SEA_LEVEL))
	var roll := rng.randf()
	if ridge > 0.78 and elevation > 0.72 and roll < 0.035:
		return "uranium"
	if ridge > 0.68 and roll < 0.10:
		return "gold_ore"
	if ridge > 0.58 and roll < 0.22:
		return "silver"
	if roll < 0.43:
		return "iron"
	if roll < 0.62:
		return "coal"
	if roll < 0.82:
		return "copper"
	return "tin"


func _resource_deposit_amount(resource_type: String) -> int:
	match resource_type:
		"stone":
			return STONE_DEPOSIT_AMOUNT
		"flint":
			return FLINT_DEPOSIT_AMOUNT
		"food":
			return FOOD_DEPOSIT_AMOUNT
		"fish":
			return FISH_DEPOSIT_AMOUNT
		"whale_oil":
			return WHALE_OIL_DEPOSIT_AMOUNT
		"coal", "iron":
			return 260
		"copper", "tin":
			return 220
		"silver":
			return 160
		"gold", "gold_ore":
			return 120
		"uranium":
			return 90
	return 180


func _tree_chance_for_sample(sample: Dictionary, x: float, z: float) -> float:
	var terrain: String = str(sample.get("terrain", "plains"))
	var biome: String = str(sample.get("biome", "grassland"))
	var moisture: float = float(sample.get("moisture", 0.45))
	var cluster := _forest_cluster_value(x, z)
	if _is_beach_sample(sample):
		return 0.22
	match terrain:
		"forest":
			var forest_base := 0.64
			match biome:
				"rainforest":
					forest_base = 0.82
				"temperate_forest":
					forest_base = 0.72
			return clamp(forest_base + moisture * 0.10 + (cluster - 0.5) * 0.24, 0.42, 0.94)
		"plains":
			var meadow_patch := smoothstep(0.55, 0.92, cluster)
			return clamp((0.025 + clamp(moisture - 0.48, 0.0, 0.12)) * meadow_patch + 0.008, 0.0, 0.13)
		"snow":
			return 0.18 if biome != "polar_ice" else 0.04
		"tundra":
			return 0.08
		"desert":
			return 0.10
		"hills":
			if biome == "forested_hills":
				return clamp(0.32 + (cluster - 0.5) * 0.20, 0.12, 0.48)
			return 0.05
	return 0.0


func _ground_cover_chance_for_sample(sample: Dictionary, x: float, z: float) -> float:
	var terrain: String = str(sample.get("terrain", "plains"))
	var biome: String = str(sample.get("biome", "grassland"))
	var moisture: float = float(sample.get("moisture", 0.45))
	var cluster := _forest_cluster_value(x + 913.0, z - 577.0)
	var patch_factor := lerpf(0.42, 1.18, cluster)
	var chance := 0.0
	match terrain:
		"forest":
			chance = 0.26 + moisture * 0.12
		"plains":
			chance = 0.34 + moisture * 0.16
		"hills":
			chance = 0.32 if biome == "forested_hills" else 0.24
		"snow":
			chance = 0.09
		"tundra":
			chance = 0.11
		"desert":
			chance = 0.22
	if biome == "rainforest":
		chance = max(chance, 0.44)
	elif biome == "hot_desert":
		chance = max(chance, 0.24)
	elif biome == "dry_steppe":
		chance = max(chance, 0.18)
	elif biome == "polar_ice":
		chance = 0.0
	return clamp(chance * patch_factor, 0.0, 0.62)


func _blocks_ground_cover_spawn(sample: Dictionary) -> bool:
	var terrain := str(sample.get("terrain", "plains"))
	if terrain == "water" or terrain == "mountains":
		return true
	# Beaches are excluded before asset selection, so cacti can never leak onto coasts.
	if _is_beach_sample(sample):
		return true
	if float(sample.get("river", 0.0)) > 0.10:
		return true
	return _height_from_sample(sample) <= WATER_SURFACE_HEIGHT + 0.46


func _ground_cover_asset_for_sample(sample: Dictionary, rng: RandomNumberGenerator) -> String:
	if _is_beach_sample(sample):
		return ""
	var terrain := str(sample.get("terrain", "plains"))
	var biome := str(sample.get("biome", "grassland"))
	if terrain == "desert" or biome == "hot_desert":
		return _pick_tree_asset(CACTUS_ASSETS, rng)
	if biome == "dry_steppe":
		return _pick_tree_asset(CACTUS_ASSETS if rng.randf() < 0.38 else BUSH_ASSETS, rng)
	if terrain == "snow" or biome in ["snowfield", "snowy_mountain"]:
		return _pick_tree_asset(SMALL_SNOW_TREE_ASSETS if rng.randf() < 0.28 else SNOW_BUSH_ASSETS, rng)
	var roll := rng.randf()
	if roll < 0.56:
		return _pick_tree_asset(BUSH_ASSETS, rng)
	if roll < 0.78:
		return _pick_tree_asset(FIELD_PLANT_ASSETS, rng)
	return _pick_tree_asset(SMALL_TREE_ASSETS, rng)


func _ground_cover_scale_for_asset(asset_path: String, rng: RandomNumberGenerator) -> float:
	var asset_name := asset_path.get_file().get_basename()
	if asset_name.begins_with("Cactus"):
		return rng.randf_range(2.8, 5.0)
	if asset_name.begins_with("CommonTree_") or asset_name.begins_with("BirchTree_") or asset_name.begins_with("PineTree_"):
		return rng.randf_range(2.6, 4.0)
	if asset_name.begins_with("Plant_"):
		return rng.randf_range(1.2, 2.2)
	return rng.randf_range(1.6, 2.9)


func _ground_cover_casts_shadow(asset_path: String) -> bool:
	var asset_name := asset_path.get_file().get_basename()
	return asset_name.begins_with("Cactus") or asset_name.contains("Tree_")


func _forest_cluster_value(x: float, z: float) -> float:
	var seed_offset := 0.0
	if Game.world_state != null:
		seed_offset = float(int(Game.world_state.seed) % 100000) * 0.00037
	var large := sin(x * 0.0020 + z * 0.0015 + seed_offset) * 0.5 + 0.5
	var medium := sin(x * 0.0058 - z * 0.0047 + seed_offset * 2.13) * 0.5 + 0.5
	var small := sin(x * 0.0140 + z * 0.0110 + seed_offset * 5.31) * 0.5 + 0.5
	return clamp(large * 0.56 + medium * 0.31 + small * 0.13, 0.0, 1.0)


func _tree_asset_for_sample(sample: Dictionary, rng: RandomNumberGenerator) -> String:
	var terrain: String = str(sample.get("terrain", "plains"))
	var biome: String = str(sample.get("biome", "grassland"))
	if terrain == "desert" or biome in ["hot_desert", "dry_steppe"]:
		return ""
	if terrain == "snow" or biome in ["snowfield", "snowy_mountain", "polar_ice"]:
		return _pick_tree_asset(SNOW_CONIFER_TREE_ASSETS, rng)
	if terrain == "tundra":
		return _pick_tree_asset(CONIFER_TREE_ASSETS if rng.randf() < 0.70 else SNOW_CONIFER_TREE_ASSETS, rng)
	if biome == "forested_hills":
		return _pick_tree_asset(CONIFER_TREE_ASSETS if rng.randf() < 0.55 else LEAF_TREE_ASSETS, rng)
	if terrain == "forest":
		return _pick_tree_asset(CONIFER_TREE_ASSETS if rng.randf() < 0.36 else LEAF_TREE_ASSETS, rng)
	if terrain == "plains" or biome == "grassland":
		return _pick_tree_asset(CONIFER_TREE_ASSETS if rng.randf() < 0.42 else LEAF_TREE_ASSETS, rng)
	return ""


func _pick_tree_asset(asset_paths: Array, rng: RandomNumberGenerator) -> String:
	if asset_paths.is_empty():
		return ""
	return str(asset_paths[rng.randi_range(0, asset_paths.size() - 1)])


func _dead_tree_asset_for_sample(sample: Dictionary, rng: RandomNumberGenerator) -> String:
	var terrain: String = str(sample.get("terrain", "plains"))
	if terrain == "snow":
		return _pick_tree_asset(SNOW_DEAD_TREE_ASSETS, rng)
	return _pick_tree_asset(DEAD_TREE_ASSETS, rng)


func _tree_runtime_scale_for_asset(asset_path: String, rng: RandomNumberGenerator) -> float:
	var base_height: float = _tree_base_height_for_asset(asset_path)
	var target_height := UNIT_HEIGHT * rng.randf_range(MIN_TREE_TO_HUMAN_HEIGHT_RATIO, MAX_TREE_TO_HUMAN_HEIGHT_RATIO)
	return clamp(target_height / max(base_height, 0.1), 0.1, 16.0)


func _tree_spacing_radius_for_asset(asset_path: String, scale_value: float) -> float:
	var height := _tree_base_height_for_asset(asset_path) * scale_value
	return clamp(height * TREE_SPACING_RADIUS_RATIO, TREE_SPACING_RADIUS_MIN, TREE_SPACING_RADIUS_MAX)


func _can_place_tree_at(tree_spacing_hash: Dictionary, x: float, z: float, radius: float) -> bool:
	var bucket := _tree_spacing_bucket(x, z)
	for z_offset in range(-1, 2):
		for x_offset in range(-1, 2):
			var neighbor_key := bucket + Vector2i(x_offset, z_offset)
			if not tree_spacing_hash.has(neighbor_key):
				continue
			for placed_tree in tree_spacing_hash[neighbor_key]:
				var placed_position: Vector2 = placed_tree["position"]
				var placed_radius: float = float(placed_tree["radius"])
				var minimum_distance := (radius + placed_radius) * TREE_SPACING_TOUCH_ALLOWANCE
				if placed_position.distance_squared_to(Vector2(x, z)) < minimum_distance * minimum_distance:
					return false
	return true


func _remember_tree_position(tree_spacing_hash: Dictionary, x: float, z: float, radius: float) -> void:
	var bucket := _tree_spacing_bucket(x, z)
	if not tree_spacing_hash.has(bucket):
		tree_spacing_hash[bucket] = []
	tree_spacing_hash[bucket].append({
		"position": Vector2(x, z),
		"radius": radius,
	})


func _tree_spacing_bucket(x: float, z: float) -> Vector2i:
	return Vector2i(
		int(floor((x + MAP_SIZE * 0.5) / TREE_SPACING_BUCKET_SIZE)),
		int(floor((z + MAP_SIZE * 0.5) / TREE_SPACING_BUCKET_SIZE))
	)


func _reserve_full_tree_slot(selection: Dictionary, x: float, z: float) -> bool:
	var count := int(selection.get("count", 0))
	if count >= TREE_FULL_MODEL_MAX:
		return false

	var position_2d := Vector2(x, z)
	if position_2d.length_squared() <= TREE_FULL_MODEL_NEAR_RADIUS * TREE_FULL_MODEL_NEAR_RADIUS:
		selection["count"] = count + 1
		return true

	var buckets: Dictionary = selection.get("buckets", {})
	var bucket := _full_tree_model_bucket(x, z)
	if buckets.has(bucket):
		return false
	buckets[bucket] = true
	selection["buckets"] = buckets
	selection["count"] = count + 1
	return true


func _full_tree_model_bucket(x: float, z: float) -> Vector2i:
	return Vector2i(
		int(floor((x + MAP_SIZE * 0.5) / TREE_FULL_MODEL_GRID_BUCKET)),
		int(floor((z + MAP_SIZE * 0.5) / TREE_FULL_MODEL_GRID_BUCKET))
	)


func _is_dead_tree_asset(asset_path: String) -> bool:
	return asset_path.get_file().get_basename().to_lower().contains("_dead_")


func _tree_base_height_for_asset(asset_path: String) -> float:
	var tree_name := asset_path.get_file().get_basename().trim_suffix("_snow")
	if tree_name.begins_with("CommonTree_"):
		return 2.85
	if tree_name.begins_with("BirchTree_"):
		return 3.65
	if tree_name.begins_with("PineTree_"):
		return 3.20
	if tree_name.begins_with("PalmTree_"):
		return 3.85
	match tree_name:
		"conifer_01":
			return 6.0
		"conifer_02":
			return 7.1
		"conifer_03":
			return 5.2
		"leaf_tree_01":
			return 4.2
		"leaf_tree_02":
			return 4.9
		"leaf_tree_03":
			return 4.1
		"palm_tree_01":
			return 4.5
		"palm_tree_02":
			return 4.2
		"palm_tree_03":
			return 3.4
		"dead_tree_01":
			return 4.9
		"dead_tree_02":
			return 5.6
		"dead_tree_03":
			return 4.2
	return 5.0


func _is_beach_sample(sample: Dictionary) -> bool:
	var terrain: String = str(sample.get("terrain", "plains"))
	if terrain in ["water", "snow", "mountains", "tundra"]:
		return false
	var elevation: float = float(sample.get("elevation", WorldState.SEA_LEVEL + 0.10))
	var river: float = float(sample.get("river", 0.0))
	return river < 0.10 and elevation >= WorldState.SEA_LEVEL and elevation <= WorldState.SEA_LEVEL + 0.055


func _blocks_tree_spawn(sample: Dictionary, u: float, v: float) -> bool:
	var terrain: String = str(sample.get("terrain", "plains"))
	if terrain == "water":
		return true
	if _is_beach_sample(sample):
		return true

	var river: float = float(sample.get("river", 0.0))
	if river > TREE_RIVER_NO_SPAWN_THRESHOLD:
		return true
	if _nearby_river_value(u, v, TREE_RIVER_BANK_BUFFER_METERS) > TREE_RIVER_NEARBY_THRESHOLD:
		return true

	var surface_height := _height_from_sample(sample)
	if surface_height <= WATER_SURFACE_HEIGHT + TREE_SHORE_HEIGHT_BUFFER:
		return true

	return false


func _nearby_river_value(u: float, v: float, radius_meters: float) -> float:
	var du := radius_meters / MAP_SIZE
	var dv := radius_meters / MAP_SIZE
	var max_river := _smooth_river_at_uv(u, v)
	max_river = max(max_river, _smooth_river_at_uv(u + du, v))
	max_river = max(max_river, _smooth_river_at_uv(u - du, v))
	max_river = max(max_river, _smooth_river_at_uv(u, v + dv))
	max_river = max(max_river, _smooth_river_at_uv(u, v - dv))
	max_river = max(max_river, _smooth_river_at_uv(u + du * 0.72, v + dv * 0.72))
	max_river = max(max_river, _smooth_river_at_uv(u - du * 0.72, v + dv * 0.72))
	max_river = max(max_river, _smooth_river_at_uv(u + du * 0.72, v - dv * 0.72))
	max_river = max(max_river, _smooth_river_at_uv(u - du * 0.72, v - dv * 0.72))
	return max_river


func _river_bank_detail_score(sample: Dictionary, u: float, v: float) -> float:
	var terrain: String = str(sample.get("terrain", "plains"))
	if terrain == "water":
		return 0.0
	var river: float = float(sample.get("river", 0.0))
	var nearby_river: float = _nearby_river_value(u, v, 105.0)
	var bank_strength: float = max(river, nearby_river)
	var dry_land_limit: float = 1.0 - smoothstep(0.18, 0.34, river)
	return clamp(smoothstep(0.025, 0.15, bank_strength) * dry_land_limit, 0.0, 1.0)


func _spawn_cached_props(props: Array) -> void:
	var tree_batches: Dictionary = {}
	var tree_impostor_batches: Dictionary = {}
	var scenery_batches: Dictionary = {}
	var tree_shadows: Array = []
	loaded_entity_count = 0
	full_model_entity_count = 0
	impostor_entity_count = 0
	for prop in props:
		var prop_type := str(prop.get("type", ""))
		var position := Vector3.ZERO
		if prop.has("position") and prop["position"] is Vector3:
			position = prop["position"]
		var scale_value: float = float(prop.get("scale", 1.0))
		var rotation_y: float = float(prop.get("rotation", 0.0))
		match prop_type:
			"tree":
				loaded_entity_count += 1
				full_model_entity_count += 1
				var tree_asset_path := str(prop.get("asset", ""))
				_append_tree_shadow_data(tree_shadows, tree_asset_path, position, scale_value)
				if tree_asset_path.is_empty():
					_spawn_tree(position, scale_value, rotation_y)
				else:
					if not tree_batches.has(tree_asset_path):
						tree_batches[tree_asset_path] = []
					tree_batches[tree_asset_path].append(prop)
			"tree_impostor":
				loaded_entity_count += 1
				var impostor_asset_path := str(prop.get("asset", ""))
				if not impostor_asset_path.is_empty():
					_append_tree_shadow_data(tree_shadows, impostor_asset_path, position, scale_value)
					if TREE_IMPOSTORS_ENABLED:
						impostor_entity_count += 1
						if not tree_impostor_batches.has(impostor_asset_path):
							tree_impostor_batches[impostor_asset_path] = []
						tree_impostor_batches[impostor_asset_path].append(prop)
					else:
						full_model_entity_count += 1
						if not tree_batches.has(impostor_asset_path):
							tree_batches[impostor_asset_path] = []
						tree_batches[impostor_asset_path].append(prop)
			"rock":
				loaded_entity_count += 1
				full_model_entity_count += 1
				_spawn_rock(position, scale_value, rotation_y, str(prop.get("asset", "")))
			"detail":
				loaded_entity_count += 1
				full_model_entity_count += 1
				_spawn_detail_asset(position, scale_value, rotation_y, str(prop.get("asset", "")))
			"resource_deposit":
				loaded_entity_count += 1
				full_model_entity_count += 1
				_spawn_resource_deposit(prop)
			"scenery":
				var scenery_asset_path := str(prop.get("asset", ""))
				if not scenery_asset_path.is_empty():
					if not scenery_batches.has(scenery_asset_path):
						scenery_batches[scenery_asset_path] = []
					scenery_batches[scenery_asset_path].append(prop)

	for asset_path in tree_batches.keys():
		_spawn_tree_batch(str(asset_path), tree_batches[asset_path])
	for asset_path in scenery_batches.keys():
		_spawn_scenery_batch(str(asset_path), scenery_batches[asset_path])
	if TREE_IMPOSTORS_ENABLED:
		for asset_path in tree_impostor_batches.keys():
			_spawn_tree_impostor_batch(str(asset_path), tree_impostor_batches[asset_path])
	_restore_resource_state()
	_spawn_tree_shadow_batch(tree_shadows)
	_spawn_resource_ring_batches()
	if TREE_IMPOSTORS_ENABLED:
		_update_tree_impostor_lod(TREE_IMPOSTOR_LOD_UPDATE_INTERVAL)


func _append_tree_shadow_data(tree_shadows: Array, asset_path: String, position: Vector3, scale_value: float) -> void:
	var base_height := _tree_base_height_for_asset(asset_path) if not asset_path.is_empty() else 4.2
	tree_shadows.append({
		"position": position,
		"height": base_height * scale_value,
	})


func _spawn_tree_shadow_batch(tree_shadows: Array) -> void:
	if tree_shadows.is_empty():
		return

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _tree_ground_shadow_mesh()
	multimesh.custom_aabb = _full_map_prop_aabb()
	multimesh.instance_count = tree_shadows.size()

	var shadow_direction := _tree_ground_shadow_direction()
	var shadow_angle := atan2(shadow_direction.x, shadow_direction.z)
	for instance_index in range(tree_shadows.size()):
		var shadow_data := tree_shadows[instance_index] as Dictionary
		var position: Vector3 = shadow_data.get("position", Vector3.ZERO)
		var tree_height: float = float(shadow_data.get("height", UNIT_HEIGHT * 12.0))
		var width: float = clamp(tree_height * 0.34, 5.0, 16.0)
		var length: float = clamp(tree_height * 0.58, 7.0, 34.0)
		var shadow_position: Vector3 = position + shadow_direction * length * 0.22
		shadow_position.y += TREE_GROUND_SHADOW_SURFACE_OFFSET
		var basis: Basis = Basis(Vector3.UP, shadow_angle).scaled(Vector3(width, 1.0, length))
		multimesh.set_instance_transform(instance_index, Transform3D(basis, shadow_position))

	var shadow_batch := MultiMeshInstance3D.new()
	shadow_batch.name = "TreeGroundShadows"
	shadow_batch.multimesh = multimesh
	shadow_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow_batch.material_override = _tree_ground_shadow_material()
	shadow_batch.extra_cull_margin = 128.0
	terrain_root.add_child(shadow_batch)


func _tree_ground_shadow_direction() -> Vector3:
	var sun_direction := Game.get_battle_sun_direction()
	var shadow_direction := Vector3(-sun_direction.x, 0.0, -sun_direction.z)
	if shadow_direction.length_squared() < 0.001:
		shadow_direction = Vector3(0.45, 0.0, 0.82)
	return shadow_direction.normalized()


func _tree_ground_shadow_mesh() -> ArrayMesh:
	if tree_shadow_mesh != null:
		return tree_shadow_mesh

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-0.5, 0.0, -0.5),
		Vector3(0.5, 0.0, -0.5),
		Vector3(0.5, 0.0, 0.5),
		Vector3(-0.5, 0.0, 0.5),
	])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0),
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	tree_shadow_mesh = ArrayMesh.new()
	tree_shadow_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return tree_shadow_mesh


func _tree_ground_shadow_material() -> ShaderMaterial:
	if tree_shadow_material != null:
		return tree_shadow_material

	tree_shadow_material = ShaderMaterial.new()
	tree_shadow_material.shader = load("res://shaders/tree_ground_shadow.gdshader")
	tree_shadow_material.set_shader_parameter("shadow_color", Color(0.015, 0.018, 0.012))
	tree_shadow_material.set_shader_parameter("shadow_alpha", TREE_GROUND_SHADOW_ALPHA)
	return tree_shadow_material


func _spawn_tree_impostor_batch(asset_path: String, tree_props: Array) -> void:
	var texture := _tree_impostor_texture_for_asset(asset_path)
	if texture == null or tree_props.is_empty():
		return

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _tree_impostor_mesh()
	multimesh.instance_count = tree_props.size()

	var base_height: float = _tree_base_height_for_asset(asset_path)
	for instance_index in range(tree_props.size()):
		var prop := tree_props[instance_index] as Dictionary
		var position := Vector3.ZERO
		if prop.has("position") and prop["position"] is Vector3:
			position = prop["position"]
		var scale_value := float(prop.get("scale", 1.0))
		var tree_height: float = max(1.0, base_height * scale_value * TREE_IMPOSTOR_HEIGHT_SCALE)
		var tree_width: float = clamp(tree_height * TREE_IMPOSTOR_WIDTH_RATIO, 5.0, 46.0)
		var impostor_position: Vector3 = position + Vector3(0.0, tree_height * 0.5 + TREE_IMPOSTOR_SURFACE_OFFSET, 0.0)
		var basis: Basis = Basis().scaled(Vector3(tree_width, tree_height, 1.0))
		var instance_transform := Transform3D(basis, impostor_position)
		multimesh.set_instance_transform(instance_index, instance_transform)

	var batch := MultiMeshInstance3D.new()
	batch.name = "TreeImpostors_%s" % asset_path.get_file().get_basename()
	batch.multimesh = multimesh
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.material_override = _tree_impostor_material_for_texture(texture)
	terrain_root.add_child(batch)

	for instance_index in range(tree_props.size()):
		var prop := tree_props[instance_index] as Dictionary
		var position := Vector3.ZERO
		if prop.has("position") and prop["position"] is Vector3:
			position = prop["position"]
		var scale_value := float(prop.get("scale", 1.0))
		var tree_height: float = max(1.0, base_height * scale_value * TREE_IMPOSTOR_HEIGHT_SCALE)
		var tree_width: float = clamp(tree_height * TREE_IMPOSTOR_WIDTH_RATIO, 5.0, 46.0)
		tree_impostor_lod_entries.append({
			"id": tree_impostor_lod_entries.size(),
			"asset_path": asset_path,
			"position": position,
			"scale": scale_value,
			"height": tree_height,
			"width": tree_width,
			"rotation": float(prop.get("rotation", 0.0)),
			"batch": batch,
			"instance_index": instance_index,
			"original_transform": multimesh.get_instance_transform(instance_index),
			"hidden": false,
		})


func _tree_impostor_mesh() -> QuadMesh:
	if tree_impostor_quad_mesh != null:
		return tree_impostor_quad_mesh

	tree_impostor_quad_mesh = QuadMesh.new()
	tree_impostor_quad_mesh.size = Vector2.ONE
	return tree_impostor_quad_mesh


func _tree_impostor_texture_for_asset(asset_path: String) -> Texture2D:
	var sprite_path := _tree_impostor_sprite_path_for_asset(asset_path)
	if sprite_path.is_empty():
		return null
	if tree_impostor_texture_cache.has(sprite_path):
		return tree_impostor_texture_cache[sprite_path] as Texture2D

	var texture := load(sprite_path) as Texture2D
	tree_impostor_texture_cache[sprite_path] = texture
	return texture


func _tree_impostor_sprite_path_for_asset(asset_path: String) -> String:
	var tree_name := asset_path.get_file().get_basename()
	if tree_name.is_empty():
		return ""

	var checked_modes: Dictionary = {}
	for mode_value in [TREE_IMPOSTOR_VIEW_MODE, "angle45", "ground", "top90"]:
		var mode := str(mode_value)
		if mode.is_empty() or checked_modes.has(mode):
			continue
		checked_modes[mode] = true
		var sprite_path := "res://assets/sprites/tree_impostors/%s/%s_%s.png" % [mode, tree_name, mode]
		if ResourceLoader.exists(sprite_path):
			return sprite_path
	return ""


func _tree_impostor_material_for_texture(texture: Texture2D) -> StandardMaterial3D:
	var texture_key := texture.resource_path
	if tree_impostor_material_cache.has(texture_key):
		return tree_impostor_material_cache[texture_key] as StandardMaterial3D

	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.94)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.08
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	tree_impostor_material_cache[texture_key] = material
	return material


func _update_tree_impostor_lod(delta: float) -> void:
	if camera == null or tree_impostor_lod_entries.is_empty():
		return

	tree_impostor_lod_elapsed += delta
	if tree_impostor_lod_elapsed < TREE_IMPOSTOR_LOD_UPDATE_INTERVAL:
		return
	tree_impostor_lod_elapsed = 0.0

	var full_lod_budget := _tree_impostor_full_lod_budget()
	if full_lod_budget <= 0:
		_deactivate_all_tree_impostor_full_lods()
		return

	var viewport_rect := get_viewport().get_visible_rect()
	var lod_rect := viewport_rect.grow(TREE_IMPOSTOR_FULL_LOD_SCREEN_MARGIN)
	var screen_center := viewport_rect.get_center()
	var candidates: Array = []
	for entry_value in tree_impostor_lod_entries:
		var entry := entry_value as Dictionary
		var visibility := _tree_impostor_lod_screen_visibility(entry, lod_rect, screen_center)
		if visibility.is_empty():
			continue
		candidates.append({
			"id": int(entry.get("id", -1)),
			"priority": float(visibility.get("priority", 0.0)),
			"entry": entry,
		})

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("priority", 0.0)) < float(b.get("priority", 0.0))
	)

	var desired: Dictionary = {}
	var desired_count: int = min(candidates.size(), full_lod_budget)
	for candidate_index in range(desired_count):
		var candidate := candidates[candidate_index] as Dictionary
		desired[int(candidate.get("id", -1))] = candidate.get("entry", {})

	for active_id_value in active_tree_impostor_full_nodes.keys():
		var active_id := int(active_id_value)
		if not desired.has(active_id):
			_deactivate_tree_impostor_full_lod(active_id)

	for desired_id_value in desired.keys():
		var desired_id := int(desired_id_value)
		if active_tree_impostor_full_nodes.has(desired_id):
			continue
		_activate_tree_impostor_full_lod(desired_id, desired[desired_id] as Dictionary)


func _tree_impostor_full_lod_budget() -> int:
	if camera == null:
		return 0

	var zoom_ratio := clampf(
		inverse_lerp(CAMERA_MIN_HEIGHT, CAMERA_MAX_HEIGHT, camera.global_position.y),
		0.0,
		1.0
	)
	if zoom_ratio >= TREE_IMPOSTOR_FULL_LOD_DISABLE_ZOOM:
		return 0

	var zoom_keep := 1.0 - smoothstep(
		TREE_IMPOSTOR_FULL_LOD_FADE_START_ZOOM,
		TREE_IMPOSTOR_FULL_LOD_DISABLE_ZOOM,
		zoom_ratio
	)
	return int(round(TREE_IMPOSTOR_FULL_LOD_MAX * clampf(zoom_keep, 0.0, 1.0)))


func _tree_impostor_lod_screen_visibility(entry: Dictionary, lod_rect: Rect2, screen_center: Vector2) -> Dictionary:
	if camera == null:
		return {}

	var position: Vector3 = entry.get("position", Vector3.ZERO)
	var tree_height := float(entry.get("height", _tree_base_height_for_asset(str(entry.get("asset_path", ""))) * float(entry.get("scale", 1.0)) * TREE_IMPOSTOR_HEIGHT_SCALE))
	var samples := [
		position + Vector3(0.0, TREE_IMPOSTOR_SURFACE_OFFSET, 0.0),
		position + Vector3(0.0, tree_height * 0.5, 0.0),
		position + Vector3(0.0, tree_height, 0.0),
	]

	var best_screen_distance_sq := INF
	var best_world_distance_sq := INF
	var visible := false
	for sample in samples:
		var sample_position := sample as Vector3
		if camera.is_position_behind(sample_position):
			continue
		var screen_position := camera.unproject_position(sample_position)
		if lod_rect.has_point(screen_position):
			visible = true
		best_screen_distance_sq = min(best_screen_distance_sq, screen_position.distance_squared_to(screen_center))
		best_world_distance_sq = min(best_world_distance_sq, camera.global_position.distance_squared_to(sample_position))

	if not visible:
		return {}

	return {
		"priority": best_screen_distance_sq + best_world_distance_sq * TREE_IMPOSTOR_FULL_LOD_DEPTH_WEIGHT,
	}


func _deactivate_all_tree_impostor_full_lods() -> void:
	for active_id_value in active_tree_impostor_full_nodes.keys():
		_deactivate_tree_impostor_full_lod(int(active_id_value))


func _activate_tree_impostor_full_lod(entry_id: int, entry: Dictionary) -> void:
	var node := _create_tree_impostor_full_lod_node(entry)
	if node == null:
		return
	_set_tree_impostor_billboard_visible(entry, false)
	active_tree_impostor_full_nodes[entry_id] = node


func _deactivate_tree_impostor_full_lod(entry_id: int) -> void:
	var node := active_tree_impostor_full_nodes.get(entry_id) as Node3D
	if node != null and is_instance_valid(node):
		node.queue_free()
	active_tree_impostor_full_nodes.erase(entry_id)

	if entry_id >= 0 and entry_id < tree_impostor_lod_entries.size():
		var entry := tree_impostor_lod_entries[entry_id] as Dictionary
		_set_tree_impostor_billboard_visible(entry, true)


func _create_tree_impostor_full_lod_node(entry: Dictionary) -> Node3D:
	var asset_path := str(entry.get("asset_path", ""))
	var scene := _tree_scene_for_path(asset_path)
	if scene == null:
		return null

	var node := scene.instantiate()
	if not node is Node3D:
		node.queue_free()
		return null

	var tree_node := node as Node3D
	tree_node.name = "TreeNearLOD_%s" % asset_path.get_file().get_basename()
	tree_node.position = entry.get("position", Vector3.ZERO)
	tree_node.rotation.y = float(entry.get("rotation", 0.0))
	tree_node.scale = Vector3.ONE * float(entry.get("scale", 1.0))
	_set_shadow_casting(tree_node, true)
	_tree_impostor_lod_parent().add_child(tree_node)
	return tree_node


func _tree_impostor_lod_parent() -> Node3D:
	if tree_impostor_lod_root != null and is_instance_valid(tree_impostor_lod_root):
		return tree_impostor_lod_root

	tree_impostor_lod_root = Node3D.new()
	tree_impostor_lod_root.name = "NearTreeLODModels"
	terrain_root.add_child(tree_impostor_lod_root)
	return tree_impostor_lod_root


func _set_tree_impostor_billboard_visible(entry: Dictionary, visible: bool) -> void:
	var batch := entry.get("batch") as MultiMeshInstance3D
	if batch == null or not is_instance_valid(batch) or batch.multimesh == null:
		return
	var instance_index := int(entry.get("instance_index", -1))
	if instance_index < 0 or instance_index >= batch.multimesh.instance_count:
		return

	if visible:
		var original_transform: Transform3D = entry.get("original_transform", Transform3D.IDENTITY)
		batch.multimesh.set_instance_transform(instance_index, original_transform)
		entry["hidden"] = false
	else:
		var position: Vector3 = entry.get("position", Vector3.ZERO)
		var hidden_basis := Basis().scaled(Vector3.ONE * 0.001)
		batch.multimesh.set_instance_transform(instance_index, Transform3D(hidden_basis, position + Vector3(0.0, -5000.0, 0.0)))
		entry["hidden"] = true


func _spawn_tree_batch(asset_path: String, tree_props: Array) -> void:
	var parts := _tree_mesh_parts_for_path(asset_path)
	if parts.is_empty():
		for prop in tree_props:
			var position := Vector3.ZERO
			if prop.has("position") and prop["position"] is Vector3:
				position = prop["position"]
			_spawn_tree(position, float(prop.get("scale", 1.0)), float(prop.get("rotation", 0.0)), asset_path)
		return

	var asset_name := asset_path.get_file().get_basename()
	var part_batches: Array = []
	for part_index in range(parts.size()):
		var part := parts[part_index] as Dictionary
		var mesh := part.get("mesh") as Mesh
		if mesh == null:
			continue
		mesh = _battle_lit_mesh(mesh)

		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.custom_aabb = _full_map_prop_aabb()
		multimesh.instance_count = tree_props.size()

		var local_transform := part.get("transform", Transform3D.IDENTITY) as Transform3D
		for instance_index in range(tree_props.size()):
			var prop := tree_props[instance_index] as Dictionary
			var position := Vector3.ZERO
			if prop.has("position") and prop["position"] is Vector3:
				position = prop["position"]
			var scale_value := float(prop.get("scale", 1.0))
			var rotation_y := float(prop.get("rotation", 0.0))
			var basis := Basis(Vector3.UP, rotation_y).scaled(Vector3.ONE * scale_value)
			var instance_transform := Transform3D(basis, position) * local_transform
			multimesh.set_instance_transform(instance_index, instance_transform)

		var batch := MultiMeshInstance3D.new()
		batch.name = "TreeBatch_%s_%02d" % [asset_name, part_index + 1]
		batch.multimesh = multimesh
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		batch.extra_cull_margin = 128.0
		terrain_root.add_child(batch)
		part_batches.append(batch)

	for instance_index in range(tree_props.size()):
		var prop := tree_props[instance_index] as Dictionary
		_register_tree_resource_node(prop, asset_path, part_batches, instance_index)


func _spawn_scenery_batch(asset_path: String, scenery_props: Array) -> void:
	var parts := _tree_mesh_parts_for_path(asset_path)
	if parts.is_empty() or scenery_props.is_empty():
		return

	var asset_name := asset_path.get_file().get_basename()
	var casts_shadow := _ground_cover_casts_shadow(asset_path)
	for part_index in range(parts.size()):
		var part := parts[part_index] as Dictionary
		var mesh := part.get("mesh") as Mesh
		if mesh == null:
			continue
		mesh = _battle_lit_mesh(mesh)

		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.custom_aabb = _full_map_prop_aabb()
		multimesh.instance_count = scenery_props.size()
		var local_transform := part.get("transform", Transform3D.IDENTITY) as Transform3D
		for instance_index in range(scenery_props.size()):
			var prop := scenery_props[instance_index] as Dictionary
			var position: Vector3 = prop.get("position", Vector3.ZERO)
			var scale_value := float(prop.get("scale", 1.0))
			var rotation_y := float(prop.get("rotation", 0.0))
			var basis := Basis(Vector3.UP, rotation_y).scaled(Vector3.ONE * scale_value)
			multimesh.set_instance_transform(instance_index, Transform3D(basis, position) * local_transform)

		var batch := MultiMeshInstance3D.new()
		batch.name = "SceneryBatch_%s_%02d" % [asset_name, part_index + 1]
		batch.multimesh = multimesh
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.extra_cull_margin = 64.0
		terrain_root.add_child(batch)


func _full_map_prop_aabb() -> AABB:
	var margin := 128.0
	return AABB(
		Vector3(-MAP_SIZE * 0.5 - margin, TERRAIN_BASE_HEIGHT - margin, -MAP_SIZE * 0.5 - margin),
		Vector3(MAP_SIZE + margin * 2.0, TERRAIN_HEIGHT_SCALE + margin * 2.0, MAP_SIZE + margin * 2.0)
	)


func _spawn_tree(position: Vector3, scale_value: float, rotation_y: float, asset_path: String = "") -> void:
	var tree_scene := _tree_scene_for_path(asset_path)
	if tree_scene != null:
		var tree_node := tree_scene.instantiate()
		if tree_node is Node3D:
			var tree_node_3d := tree_node as Node3D
			tree_node_3d.position = position
			tree_node_3d.rotation.y = rotation_y
			tree_node_3d.scale = Vector3.ONE * scale_value
			_apply_battle_lit_materials(tree_node_3d)
			_set_shadow_casting(tree_node_3d, true)
			terrain_root.add_child(tree_node_3d)
			_register_tree_resource_node({
				"position": position,
				"scale": scale_value,
				"rotation": rotation_y,
			}, asset_path, [], -1, tree_node_3d)
			return
		tree_node.queue_free()

	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.08 * scale_value
	trunk_mesh.bottom_radius = 0.12 * scale_value
	trunk_mesh.height = 2.1 * scale_value
	trunk_mesh.radial_segments = 6
	trunk.mesh = trunk_mesh
	trunk.material_override = _material(Color(0.32, 0.20, 0.10))
	trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	trunk.position = position + Vector3(0.0, trunk_mesh.height * 0.5, 0.0)
	trunk.rotation.y = rotation_y
	terrain_root.add_child(trunk)

	var crown := MeshInstance3D.new()
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 0.95 * scale_value
	crown_mesh.height = 1.45 * scale_value
	crown_mesh.radial_segments = 10
	crown_mesh.rings = 6
	crown.mesh = crown_mesh
	crown.material_override = _material(Color(0.05, 0.28, 0.11))
	crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	crown.position = position + Vector3(0.0, trunk_mesh.height + crown_mesh.radius * 0.72, 0.0)
	terrain_root.add_child(crown)


func _spawn_detail_asset(position: Vector3, scale_value: float, rotation_y: float, asset_path: String) -> void:
	if asset_path.is_empty():
		return
	if asset_path.get_file().get_basename().to_lower().begins_with("flint_stone"):
		_spawn_resource_deposit({
			"resource_type": "flint",
			"asset": asset_path,
			"position": position,
			"scale": max(1.3, scale_value * 1.25),
			"rotation": rotation_y,
			"amount": FLINT_DEPOSIT_AMOUNT,
			"cluster_count": 6,
			"cluster_spread": 4.8,
		})
		return
	var detail_scene := _tree_scene_for_path(asset_path)
	if detail_scene == null:
		return
	var detail_node := detail_scene.instantiate()
	if detail_node is Node3D:
		var detail_3d := detail_node as Node3D
		detail_3d.position = position + Vector3(0.0, _detail_asset_surface_offset(asset_path) * scale_value, 0.0)
		detail_3d.rotation.y = rotation_y
		detail_3d.scale = Vector3.ONE * scale_value
		_apply_battle_lit_materials(detail_3d)
		_set_shadow_casting(detail_3d, true)
		terrain_root.add_child(detail_3d)
		_register_detail_resource_node(detail_3d, position, scale_value, rotation_y, asset_path)
		return
	detail_node.queue_free()


func _detail_asset_surface_offset(asset_path: String) -> float:
	var asset_name := asset_path.get_file().get_basename().to_lower()
	if asset_name.begins_with("broken_tree") or asset_name.begins_with("woodlog"):
		return 0.05
	if asset_name.begins_with("flint_stone"):
		return 0.03
	return 0.02


func _register_tree_resource_node(prop: Dictionary, asset_path: String, part_batches: Array = [], instance_index: int = -1, visual_node: Node3D = null) -> void:
	var position := Vector3.ZERO
	if prop.has("position") and prop["position"] is Vector3:
		position = prop["position"]
	var scale_value := float(prop.get("scale", 1.0))
	var rotation_y := float(prop.get("rotation", 0.0))
	var tree_height := _tree_base_height_for_asset(asset_path) * scale_value
	var resource = _register_resource_node({
		"resource_type": "wood",
		"stage": RTSResourceNodeScript.STAGE_STANDING_TREE,
		"position": position,
		"scale": scale_value,
		"rotation": rotation_y,
		"asset_path": asset_path,
		"amount": TREE_CHOP_YIELD,
		"harvest_amount": TREE_CHOP_YIELD,
		"work_required": FELLED_LOG_PROCESS_SECONDS,
		"chopped_down_threshold": TREE_CHOPPED_DOWN_THRESHOLD,
		"gather_range": TREE_CHOP_RANGE,
		"visual_radius": clamp(tree_height * 0.17, 3.8, 12.0),
		"selection_height": clamp(tree_height * 0.52, 2.5, 18.0),
		"show_ring": false,
		"visual_node": visual_node,
	})
	if resource == null:
		return
	resource.set_visual_batches(part_batches, instance_index)


func _register_detail_resource_node(detail_node: Node3D, position: Vector3, scale_value: float, rotation_y: float, asset_path: String) -> void:
	var asset_name := asset_path.get_file().get_basename()
	if asset_name.begins_with("broken_tree") or asset_name.to_lower().begins_with("woodlog"):
		_register_resource_node({
			"resource_type": "wood",
			"stage": RTSResourceNodeScript.STAGE_FELLED_LOG,
			"position": position,
			"scale": scale_value,
			"rotation": rotation_y,
			"asset_path": asset_path,
			"amount": 2,
			"harvest_amount": 2,
			"work_required": 1.0,
			"gather_range": TREE_CHOP_RANGE,
			"visual_radius": max(3.0, scale_value * 3.4),
			"selection_height": max(1.0, scale_value * 1.3),
			"visual_node": detail_node,
		})


func _register_resource_node(data: Dictionary):
	resource_node_sequence += 1
	var resource = RTSResourceNodeScript.new()
	var position := Vector3.ZERO
	if data.has("position") and data["position"] is Vector3:
		position = data["position"]
	resource.configure({
		"id": "res_%05d" % resource_node_sequence,
		"resource_type": str(data.get("resource_type", "wood")),
		"deposit_size": str(data.get("deposit_size", "medium")),
		"stage": str(data.get("stage", RTSResourceNodeScript.STAGE_RAW)),
		"world_position": position,
		"amount_remaining": int(data.get("amount", data.get("harvest_amount", 1))),
		"harvest_amount": int(data.get("harvest_amount", 1)),
		"max_health": int(data.get("max_health", 100 if str(data.get("stage", RTSResourceNodeScript.STAGE_RAW)) == RTSResourceNodeScript.STAGE_FELLED_LOG else 0)),
		"health": int(data.get("health", data.get("max_health", 100 if str(data.get("stage", RTSResourceNodeScript.STAGE_RAW)) == RTSResourceNodeScript.STAGE_FELLED_LOG else 0))),
		"work_required": float(data.get("work_required", 1.0)),
		"chopped_down_threshold": float(data.get("chopped_down_threshold", data.get("work_required", 1.0))),
		"gather_range": float(data.get("gather_range", 8.0)),
		"visual_radius": float(data.get("visual_radius", 3.0)),
		"selection_height": float(data.get("selection_height", 2.0)),
		"asset_path": str(data.get("asset_path", "")),
		"scale": float(data.get("scale", 1.0)),
		"rotation": float(data.get("rotation", 0.0)),
		"show_ring": bool(data.get("show_ring", true)),
	})
	if data.get("visual_node") is Node3D:
		resource.visual_node = data.get("visual_node") as Node3D
	resource_nodes_by_id[resource.id] = resource
	return resource


func _restore_resource_state() -> void:
	if cell == null or not cell.rts_state is Dictionary:
		return
	var saved_resources: Dictionary = cell.rts_state.get("resources", {})
	for resource_id_value in saved_resources.keys():
		var resource = resource_nodes_by_id.get(str(resource_id_value))
		var saved = saved_resources.get(resource_id_value)
		if resource == null or not saved is Dictionary:
			continue
		resource.amount_remaining = int(saved.get("amount_remaining", resource.amount_remaining))
		resource.stage = str(saved.get("stage", resource.stage))
		resource.harvest_amount = int(saved.get("harvest_amount", 1 if resource.stage == RTSResourceNodeScript.STAGE_FELLED_LOG else resource.harvest_amount))
		resource.max_health = int(saved.get("max_health", 100 if resource.stage == RTSResourceNodeScript.STAGE_FELLED_LOG else resource.max_health))
		resource.health = int(saved.get("health", roundi(float(resource.max_health) * float(resource.amount_remaining) / float(max(1, resource.initial_amount)))))
		resource.work_progress = float(saved.get("work_progress", 0.0))
		resource.work_required = float(saved.get("work_required", resource.work_required))
		resource.show_ring = bool(saved.get("show_ring", resource.show_ring))
		resource.depleted = bool(saved.get("depleted", resource.amount_remaining <= 0))
		if resource.depleted:
			resource.hide_visual()
		elif resource.stage == RTSResourceNodeScript.STAGE_FELLED_LOG:
			resource.hide_visual(false)
			resource.set_visual_batches([], -1)
			resource.visual_radius = max(3.0, float(resource.scale_value) * 3.4)
			resource.selection_height = max(1.0, float(resource.scale_value) * 1.3)
			resource.visual_node = _spawn_felled_resource_visual(resource)


func _spawn_resource_ring_batches() -> void:
	if terrain_root == null or resource_nodes_by_id.is_empty():
		return

	resource_ring_batches_by_type.clear()
	var resources_by_type: Dictionary = {}
	for resource_value in resource_nodes_by_id.values():
		var resource = resource_value
		if resource == null or not resource.is_available():
			continue
		if not bool(resource.show_ring):
			resource.set_ring_batch(null, -1)
			continue
		var resource_type := str(resource.resource_type)
		if not resources_by_type.has(resource_type):
			resources_by_type[resource_type] = []
		resources_by_type[resource_type].append(resource)

	for resource_type_value in resources_by_type.keys():
		var resource_type := str(resource_type_value)
		var resources: Array = resources_by_type[resource_type]
		if resources.is_empty():
			continue

		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = _resource_ring_mesh()
		multimesh.instance_count = resources.size()

		for instance_index in range(resources.size()):
			var resource = resources[instance_index]
			var radius: float = max(1.0, float(resource.visual_radius))
			var ring_position: Vector3 = resource.world_position + Vector3(0.0, RESOURCE_RING_SURFACE_OFFSET, 0.0)
			var basis := Basis().scaled(Vector3(radius, 1.0, radius))
			multimesh.set_instance_transform(instance_index, Transform3D(basis, ring_position))
			resource.set_ring_batch(null, -1)

		var ring_batch := MultiMeshInstance3D.new()
		ring_batch.name = "ResourceRings_%s" % resource_type
		ring_batch.multimesh = multimesh
		ring_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring_batch.material_override = _resource_ring_material(resource_type)
		terrain_root.add_child(ring_batch)
		resource_ring_batches_by_type[resource_type] = ring_batch

		for instance_index in range(resources.size()):
			var resource = resources[instance_index]
			resource.set_ring_batch(ring_batch, instance_index)


func _resource_ring_mesh() -> ArrayMesh:
	if resource_ring_mesh != null:
		return resource_ring_mesh

	var vertices := PackedVector3Array()
	for index in range(RESOURCE_RING_SEGMENTS):
		var angle_a: float = TAU * float(index) / float(RESOURCE_RING_SEGMENTS)
		var angle_b: float = TAU * float(index + 1) / float(RESOURCE_RING_SEGMENTS)
		vertices.append(Vector3(cos(angle_a) * RESOURCE_RING_BASE_RADIUS, 0.0, sin(angle_a) * RESOURCE_RING_BASE_RADIUS))
		vertices.append(Vector3(cos(angle_b) * RESOURCE_RING_BASE_RADIUS, 0.0, sin(angle_b) * RESOURCE_RING_BASE_RADIUS))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	resource_ring_mesh = ArrayMesh.new()
	resource_ring_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return resource_ring_mesh


func _resource_ring_material(resource_type: String) -> StandardMaterial3D:
	var color := Color(0.72, 0.95, 0.58, 0.16)
	match resource_type:
		"stone":
			color = Color(0.78, 0.80, 0.76, 0.18)
		"flint":
			color = Color(0.78, 0.92, 1.0, 0.22)
		"food":
			color = Color(0.95, 0.62, 0.42, 0.18)
		"fish":
			color = Color(0.28, 0.74, 1.0, 0.24)
		"whale_oil":
			color = Color(0.92, 0.66, 0.24, 0.24)
		"coal", "iron", "copper", "tin", "silver", "gold_ore", "uranium":
			color = Color(0.88, 0.72, 0.32, 0.20)
	var material := _transparent_unshaded_material(color)
	material.no_depth_test = false
	return material


func _spawn_felled_resource_visual(resource) -> Node3D:
	if resource == null or terrain_root == null:
		return null
	if str(resource.resource_type) != "wood":
		return null

	var felled := Node3D.new()
	felled.name = "SplitWood_%s" % str(resource.id)
	terrain_root.add_child(felled)
	var tree_length := maxf(4.0, _tree_base_height_for_asset(str(resource.asset_path)) * float(resource.scale_value))
	var piece_length := maxf(1.8, tree_length / float(SPLIT_WOOD_PIECE_COUNT) * 1.08)
	var fall_yaw := float(resource.rotation_y)
	var fall_sign := float(resource.get_meta("tree_fall_sign", 1.0))
	var fall_direction := Vector3(-cos(fall_yaw), 0.0, sin(fall_yaw)) * fall_sign
	var side_direction := Vector3(-fall_direction.z, 0.0, fall_direction.x)
	for piece_index in range(SPLIT_WOOD_PIECE_COUNT):
		var asset_path: String = str(BROKEN_TREE_ASSETS[piece_index % BROKEN_TREE_ASSETS.size()]) if not BROKEN_TREE_ASSETS.is_empty() else _felled_tree_asset_for_resource(resource)
		var scene := _tree_scene_for_path(asset_path)
		if scene == null:
			continue
		var node := scene.instantiate()
		if not node is Node3D:
			node.queue_free()
			continue
		var piece := Node3D.new()
		piece.name = "WoodPiece_%d" % (piece_index + 1)
		piece.set_meta("split_wood_piece", true)
		felled.add_child(piece)
		var model := node as Node3D
		piece.add_child(model)
		_fit_model_to_max_dimension(model, piece_length)
		var distance := (float(piece_index) + 0.45) * tree_length * 0.72 / float(SPLIT_WOOD_PIECE_COUNT)
		var side_offset := (-1.0 if piece_index % 2 == 0 else 1.0) * piece_length * 0.14
		var piece_xz: Vector3 = resource.world_position + fall_direction * distance + side_direction * side_offset
		piece.position = Vector3(piece_xz.x, 0.0, piece_xz.z)
		piece.rotation.y = fall_yaw + PI * 0.5 + (-0.10 + float(piece_index) * 0.05)
		var bounds := _combined_local_bounds(piece)
		var bottom_y := float((bounds.get("min", Vector3.ZERO) as Vector3).y) if bool(bounds.get("valid", false)) else 0.0
		piece.position.y = _terrain_surface_height_for_local(piece.position.x, piece.position.z) - bottom_y + 0.02
		_apply_battle_lit_materials(model)
		_set_shadow_casting(model, true)
	if felled.get_child_count() == 0:
		felled.queue_free()
		return null
	_sync_split_wood_piece_visibility(resource, felled)
	return felled


func _sync_split_wood_piece_visibility(resource, split_root: Node3D = null) -> void:
	if resource == null:
		return
	var root := split_root if split_root != null else resource.visual_node as Node3D
	if root == null or not is_instance_valid(root):
		return
	var visible_pieces := clampi(int(resource.amount_remaining), 0, SPLIT_WOOD_PIECE_COUNT)
	var piece_index := 0
	for child in root.get_children():
		if not child is Node3D or not bool((child as Node3D).get_meta("split_wood_piece", false)):
			continue
		(child as Node3D).visible = piece_index < visible_pieces
		piece_index += 1


func _fit_felled_log_to_source_tree(felled: Node3D, resource) -> float:
	var target_length: float = max(1.0, _tree_base_height_for_asset(str(resource.asset_path)) * float(resource.scale_value))
	var bounds := _combined_local_bounds(felled)
	if not bool(bounds.get("valid", false)):
		felled.scale = Vector3.ONE
		return 0.08
	var min_corner := bounds["min"] as Vector3
	var max_corner := bounds["max"] as Vector3
	var dimensions := max_corner - min_corner
	var source_max_dimension: float = max(0.001, max(dimensions.x, max(dimensions.y, dimensions.z)))
	var fitted_scale: float = target_length / source_max_dimension
	_fit_model_to_max_dimension(felled, target_length)
	return max(0.08, dimensions.y * fitted_scale * 0.5)


func _rebuild_resource_ring_batches() -> void:
	for batch_value in resource_ring_batches_by_type.values():
		var batch := batch_value as MultiMeshInstance3D
		if batch != null and is_instance_valid(batch):
			batch.queue_free()
	resource_ring_batches_by_type.clear()
	for resource_value in resource_nodes_by_id.values():
		var resource = resource_value
		if resource != null:
			resource.set_ring_batch(null, -1)
	_spawn_resource_ring_batches()


func _felled_tree_asset_for_resource(resource) -> String:
	if not BROKEN_TREE_ASSETS.is_empty():
		return BROKEN_TREE_ASSETS[abs(hash(str(resource.id))) % BROKEN_TREE_ASSETS.size()]
	if not STUMP_ASSETS.is_empty():
		return STUMP_ASSETS[abs(hash(str(resource.id))) % STUMP_ASSETS.size()]
	return ""


func _tree_scene_for_path(asset_path: String) -> PackedScene:
	if asset_path.is_empty():
		return null
	if tree_scene_cache.has(asset_path):
		return tree_scene_cache[asset_path]
	if not ResourceLoader.exists(asset_path):
		return null
	var resource := load(asset_path)
	if resource is PackedScene:
		tree_scene_cache[asset_path] = resource
		return resource
	if resource is Mesh:
		var root := Node3D.new()
		root.name = asset_path.get_file().get_basename()
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Mesh"
		mesh_instance.mesh = resource as Mesh
		root.add_child(mesh_instance)
		mesh_instance.owner = root
		var packed_scene := PackedScene.new()
		if packed_scene.pack(root) == OK:
			tree_scene_cache[asset_path] = packed_scene
			root.free()
			return packed_scene
		root.free()
	return null


func _tree_mesh_parts_for_path(asset_path: String) -> Array:
	if tree_mesh_part_cache.has(asset_path):
		return tree_mesh_part_cache[asset_path]

	var scene := _tree_scene_for_path(asset_path)
	if scene == null:
		tree_mesh_part_cache[asset_path] = []
		return []

	var root := scene.instantiate()
	var parts: Array = []
	_collect_tree_mesh_parts(root, Transform3D.IDENTITY, parts)
	root.free()
	tree_mesh_part_cache[asset_path] = parts
	return parts


func _collect_tree_mesh_parts(node: Node, parent_transform: Transform3D, parts: Array) -> void:
	var current_transform := parent_transform
	if node is Node3D:
		current_transform = parent_transform * (node as Node3D).transform

	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			var material: Material = mesh_instance.material_override
			if material == null and mesh_instance.mesh.get_surface_count() > 0:
				material = mesh_instance.get_surface_override_material(0)
				if material == null:
					material = mesh_instance.mesh.surface_get_material(0)
			parts.append({
				"mesh": mesh_instance.mesh,
				"transform": current_transform,
				"material": material,
			})

	for child in node.get_children():
		_collect_tree_mesh_parts(child, current_transform, parts)


func _set_shadow_casting(node: Node, enabled: bool) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_set_shadow_casting(child, enabled)


func _battle_lit_mesh(source_mesh: Mesh) -> Mesh:
	if source_mesh == null:
		return null
	var cache_key := "mesh_%d" % source_mesh.get_instance_id()
	if battle_prop_material_cache.has(cache_key):
		return battle_prop_material_cache[cache_key] as Mesh
	var lit_mesh := source_mesh.duplicate() as Mesh
	for surface_index in range(lit_mesh.get_surface_count()):
		var source_material := source_mesh.surface_get_material(surface_index)
		var lit_material := _battle_lit_material(source_material)
		if lit_material != null:
			lit_mesh.surface_set_material(surface_index, lit_material)
	battle_prop_material_cache[cache_key] = lit_mesh
	return lit_mesh


func _apply_battle_lit_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			mesh_instance.mesh = _battle_lit_mesh(mesh_instance.mesh)
		if mesh_instance.material_override != null:
			mesh_instance.material_override = _battle_lit_material(mesh_instance.material_override)
	for child in node.get_children():
		_apply_battle_lit_materials(child)


func _battle_lit_material(source_material: Material) -> Material:
	if source_material == null:
		return null
	var cache_key := "material_%d" % source_material.get_instance_id()
	if battle_prop_material_cache.has(cache_key):
		return battle_prop_material_cache[cache_key] as Material
	var lit_material := source_material.duplicate() as Material
	if lit_material is BaseMaterial3D:
		var base_material := lit_material as BaseMaterial3D
		base_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		base_material.disable_receive_shadows = false
		base_material.roughness = maxf(0.78, base_material.roughness)
		base_material.metallic = 0.0
		base_material.albedo_color = _lift_prop_albedo(base_material.albedo_color)
	battle_prop_material_cache[cache_key] = lit_material
	return lit_material


func _lift_prop_albedo(color: Color) -> Color:
	var srgb := color.linear_to_srgb()
	var value := maxf(srgb.r, maxf(srgb.g, srgb.b))
	if value < 0.58:
		var lift := inverse_lerp(0.0, 0.58, value)
		srgb = srgb.lerp(Color(srgb.r, srgb.g, srgb.b).lightened(0.34), 1.0 - lift)
		srgb *= 1.18
	return Color(srgb.r, srgb.g, srgb.b, color.a).srgb_to_linear()


func _spawn_rock(position: Vector3, scale_value: float, rotation_y: float, asset_path: String = "") -> void:
	_spawn_resource_deposit({
		"resource_type": "stone",
		"position": position,
		"scale": scale_value,
		"rotation": rotation_y,
		"asset": asset_path,
		"amount": STONE_DEPOSIT_AMOUNT,
		"cluster_count": 7,
		"cluster_spread": 6.0,
	})


func _resource_deposit_size(prop: Dictionary, rng: RandomNumberGenerator, resource_type: String) -> String:
	if resource_type == "wood":
		return "medium"
	var requested_size := str(prop.get("deposit_size", ""))
	if requested_size in RESOURCE_DEPOSIT_SIZES:
		return requested_size
	var roll := rng.randf()
	if roll < 0.36:
		return "small"
	if roll < 0.80:
		return "medium"
	return "large"


func _resource_deposit_scale_multiplier(deposit_size: String) -> float:
	match deposit_size:
		"small":
			return 0.78
		"large":
			return 1.28
	return 1.0


func _resource_deposit_count_multiplier(deposit_size: String) -> float:
	match deposit_size:
		"small":
			return 0.72
		"large":
			return 1.36
	return 1.0


func _resource_deposit_spread_multiplier(deposit_size: String) -> float:
	match deposit_size:
		"small":
			return 0.78
		"large":
			return 1.25
	return 1.0


func _resource_deposit_amount_multiplier(deposit_size: String) -> float:
	match deposit_size:
		"small":
			return 0.5
		"large":
			return 2.0
	return 1.0


func _is_rock_resource_type(resource_type: String) -> bool:
	return resource_type in ["stone", "flint", "coal", "copper", "tin", "iron", "silver", "gold", "gold_ore", "uranium"]


func _resource_ground_embed_depth(resource_type: String, deposit_size: String, member_scale: float) -> float:
	if not _is_rock_resource_type(resource_type):
		return clampf(member_scale * 0.018, 0.02, 0.14)
	var embed_ratio := 0.045
	if deposit_size == "medium":
		embed_ratio = 0.075
	elif deposit_size == "large":
		embed_ratio = 0.11
	return clampf(member_scale * embed_ratio, 0.05, 0.58)


func _resource_member_bottom_y(member: Node3D) -> float:
	var bounds := _combined_local_bounds(member)
	if not bool(bounds.get("valid", false)):
		return 0.0
	return float((bounds["min"] as Vector3).y)


func _spawn_resource_deposit(prop: Dictionary) -> void:
	var resource_type := str(prop.get("resource_type", "resource"))
	var position: Vector3 = prop.get("position", Vector3.ZERO)
	var rotation_y := float(prop.get("rotation", 0.0))
	var asset_path := str(prop.get("asset", ""))
	var asset_paths: Array = prop.get("assets", [asset_path])
	if asset_paths.is_empty():
		asset_paths = [asset_path]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(position.x) * 9283.0 + absf(position.z) * 6271.0 + float(resource_type.hash()))
	var deposit_size := _resource_deposit_size(prop, rng, resource_type)
	var scale_value := float(prop.get("scale", 1.0)) * _resource_deposit_scale_multiplier(deposit_size)
	var cluster_count := maxi(1, roundi(float(prop.get("cluster_count", 6)) * _resource_deposit_count_multiplier(deposit_size)))
	if resource_type != "wood":
		cluster_count = maxi(4, cluster_count)
	var cluster_spread := maxf(0.0, float(prop.get("cluster_spread", 5.0)) * _resource_deposit_spread_multiplier(deposit_size))
	var visual_y_offset := float(prop.get("visual_y_offset", 0.0))
	var aquatic_resource := _is_aquatic_resource_type(resource_type)
	var member_scale_multipliers: Dictionary = prop.get("member_scale_multipliers", {})
	var swim_speed_range: Vector2 = prop.get("swim_speed_range", Vector2(0.48, 0.92))
	var animation_speed := float(prop.get("animation_speed", 1.35 if aquatic_resource else 1.0))
	var root := Node3D.new()
	root.name = "ResourceDeposit_%s_%s" % [resource_type, deposit_size]
	root.position = position
	root.set_meta("deposit_size", deposit_size)
	terrain_root.add_child(root)

	var fish_seabed_local_y := -2.0
	if aquatic_resource:
		var fish_u := inverse_lerp(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, position.x)
		var fish_v := inverse_lerp(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, position.z)
		fish_seabed_local_y = _height_from_sample(_sample_cell_uv(fish_u, fish_v)) - position.y
	for index in range(cluster_count):
		var member_path := str(asset_paths[index % asset_paths.size()])
		var scene := _tree_scene_for_path(member_path)
		if scene == null:
			continue
		var member := scene.instantiate()
		if not member is Node3D:
			member.queue_free()
			continue
		var member_3d := member as Node3D
		root.add_child(member_3d)
		var angle := rotation_y if index == 0 else rng.randf_range(0.0, TAU)
		var distance := 0.0 if index == 0 else sqrt(rng.randf()) * cluster_spread * scale_value
		var offset := Vector3(cos(angle) * distance, visual_y_offset, sin(angle) * distance)
		var member_scale := scale_value * (1.22 if index == 0 else rng.randf_range(0.62, 1.02))
		member_scale *= float(member_scale_multipliers.get(member_path, 1.0))
		if not aquatic_resource:
			var member_ground_y := _terrain_surface_height_for_local(position.x + offset.x, position.z + offset.z)
			var member_bottom_y := _resource_member_bottom_y(member_3d) * member_scale
			offset.y = member_ground_y - position.y - member_bottom_y - _resource_ground_embed_depth(resource_type, deposit_size, member_scale)
		else:
			var school_radius := cluster_spread * scale_value
			var depth_amplitude := rng.randf_range(0.08, 0.22)
			var shallow_center_y := visual_y_offset + rng.randf_range(-0.08, 0.10)
			var deepest_center_y := fish_seabed_local_y + 0.24 + depth_amplitude
			var highest_center_y := -0.28 - depth_amplitude
			deepest_center_y = minf(deepest_center_y, highest_center_y)
			var depth_roll := rng.randf()
			var center_y := shallow_center_y
			if depth_roll < 0.24:
				center_y = lerpf(deepest_center_y, highest_center_y, rng.randf_range(0.04, 0.25))
			elif depth_roll < 0.58:
				center_y = lerpf(deepest_center_y, highest_center_y, rng.randf_range(0.38, 0.66))
			center_y = clampf(center_y, deepest_center_y, highest_center_y)
			var orbit_center := Vector3(
				rng.randf_range(-0.24, 0.24) * school_radius,
				center_y,
				rng.randf_range(-0.24, 0.24) * school_radius
			)
			var orbit_radius_x := rng.randf_range(0.24, 0.52) * school_radius
			var orbit_radius_z := orbit_radius_x * rng.randf_range(0.48, 0.82)
			var orbit_phase := rng.randf_range(0.0, TAU)
			var orbit_direction := -1.0 if rng.randf() < 0.22 else 1.0
			var orbit_speed := rng.randf_range(swim_speed_range.x, swim_speed_range.y) * orbit_direction
			var depth_phase := rng.randf_range(0.0, TAU)
			offset = orbit_center + Vector3(
				cos(orbit_phase) * orbit_radius_x,
				sin(depth_phase) * depth_amplitude,
				sin(orbit_phase) * orbit_radius_z
			)
			fish_school_members.append({
				"node": member_3d,
				"center": orbit_center,
				"radius_x": orbit_radius_x,
				"radius_z": orbit_radius_z,
				"phase": orbit_phase,
				"speed": orbit_speed,
				"depth_amplitude": depth_amplitude,
				"depth_phase": depth_phase,
			})
		member_3d.position = offset
		member_3d.rotation.y = angle + rng.randf_range(-0.35, 0.35) if not aquatic_resource else angle
		member_3d.scale = Vector3.ONE * member_scale
		_apply_battle_lit_materials(member_3d)
		_set_shadow_casting(member_3d, not aquatic_resource)
		_play_deposit_animation(member_3d, animation_speed)

	if root.get_child_count() == 0:
		root.queue_free()
		return
	var harvest_amount := ROCK_GATHER_YIELD if resource_type == "stone" else 1
	var work_required := ROCK_GATHER_WORK_SECONDS if resource_type == "stone" else 1.4
	var base_amount := int(prop.get("amount", _resource_deposit_amount(resource_type)))
	var sized_amount := maxi(1, roundi(float(base_amount) * _resource_deposit_amount_multiplier(deposit_size)))
	var registered_resource = _register_resource_node({
		"resource_type": resource_type,
		"deposit_size": deposit_size,
		"position": position,
		"scale": scale_value,
		"rotation": rotation_y,
		"asset_path": asset_path,
		"amount": sized_amount,
		"harvest_amount": int(prop.get("harvest_amount", harvest_amount)),
		"work_required": float(prop.get("work_required", work_required)),
		"gather_range": float(prop.get("gather_range", maxf(ROCK_GATHER_RANGE, cluster_spread * scale_value + 3.0))),
		"visual_radius": float(prop.get("visual_radius", maxf(4.0, cluster_spread * scale_value + 2.0))),
		"selection_height": float(prop.get("selection_height", 1.8 if aquatic_resource else 4.0)),
		"show_ring": bool(prop.get("show_ring", true)),
		"visual_node": root,
	})


func _is_aquatic_resource_type(resource_type: String) -> bool:
	return resource_type in ["fish", "whale_oil"]


func _play_deposit_animation(node: Node3D, playback_speed: float = 1.0) -> void:
	for candidate in node.find_children("*", "AnimationPlayer", true, false):
		var player := candidate as AnimationPlayer
		if player == null:
			continue
		var selected_animation := ""
		for animation_name in player.get_animation_list():
			if animation_name == "RESET":
				continue
			if selected_animation.is_empty():
				selected_animation = animation_name
			if animation_name.to_lower().contains("swimming_normal"):
				selected_animation = animation_name
				break
		if selected_animation.is_empty():
			continue
		var animation := player.get_animation(selected_animation)
		if animation != null:
			animation.loop_mode = Animation.LOOP_LINEAR
		player.speed_scale = playback_speed
		player.play(selected_animation)


func _update_fish_school_motion(delta: float) -> void:
	if fish_school_members.is_empty():
		return
	fish_school_elapsed += maxf(0.0, delta)
	for index in range(fish_school_members.size() - 1, -1, -1):
		var motion := fish_school_members[index] as Dictionary
		var fish := motion.get("node") as Node3D
		if fish == null or not is_instance_valid(fish):
			fish_school_members.remove_at(index)
			continue
		if not fish.is_visible_in_tree():
			continue
		var center: Vector3 = motion.get("center", Vector3.ZERO)
		var radius_x := float(motion.get("radius_x", 1.0))
		var radius_z := float(motion.get("radius_z", 1.0))
		var speed := float(motion.get("speed", 0.6))
		var phase := float(motion.get("phase", 0.0)) + fish_school_elapsed * speed
		var depth_amplitude := float(motion.get("depth_amplitude", 0.15))
		var depth_phase := float(motion.get("depth_phase", 0.0))
		fish.position = center + Vector3(
			cos(phase) * radius_x,
			sin(depth_phase + fish_school_elapsed * absf(speed) * 1.65) * depth_amplitude,
			sin(phase) * radius_z
		)
		var direction := Vector3(-sin(phase) * radius_x * speed, 0.0, cos(phase) * radius_z * speed)
		if direction.length_squared() > 0.0001:
			direction = direction.normalized()
			# These fish assets face local +Z, unlike Godot's usual -Z forward convention.
			fish.rotation.y = atan2(direction.x, direction.z)


func _refresh_overlay() -> void:
	var cell_id := "none"
	var terrain_name := "Unknown"
	var biome_name := "Unknown"
	var climate_name := "Unknown"
	var owner_name := "Unknown"
	var threat_level := 0
	var resources: Dictionary = {}
	if cell != null:
		cell_id = str(cell.id)
		terrain_name = str(cell.terrain).capitalize()
		biome_name = str(cell.biome).capitalize()
		climate_name = str(cell.climate).capitalize()
		owner_name = _owner_short_label(str(cell.owner_id))
		threat_level = int(cell.threat_level)
		resources = cell.resources.duplicate(true)

	displayed_sun_label = _sun_label(Game.get_battle_sun_amount())
	var active_tree_lod_count := active_tree_impostor_full_nodes.size()
	var displayed_full_model_count := full_model_entity_count + active_tree_lod_count
	var displayed_impostor_count = max(0, impostor_entity_count - active_tree_lod_count)
	if summary_label != null:
		summary_label.text = _join_lines([
			"%s %d   %s %s   %s %d" % [_hud_stat_icon("population"), _settlement_population_estimate(resources), _hud_stat_icon("tech"), _tech_level_label(), _hud_stat_icon("food"), int(resources.get("food", 0))],
			"%s / %s / %s" % [terrain_name, biome_name, climate_name],
			"%s %s   %s %d   %s %s" % [_hud_stat_icon("owner"), owner_name, _hud_stat_icon("threat"), threat_level, _hud_stat_icon("sun"), displayed_sun_label],
			"%s %d   %s %d   %s %d   %s %d   %s %d" % [_hud_stat_icon("units"), battle_units.size(), _hud_stat_icon("buildings"), battle_buildings.size(), _hud_stat_icon("entities"), loaded_entity_count, _hud_stat_icon("full_models"), displayed_full_model_count, _hud_stat_icon("impostors"), displayed_impostor_count],
		])
	if region_name_label != null:
		region_name_label.text = "%s  (%s)" % [_settlement_display_name(cell_id, terrain_name), cell_id]
	_refresh_resource_rail(resources)
	_refresh_context_panel()
	if event_log_label != null:
		event_log_label.text = _join_lines(Game.get_recent_events(8))


func _refresh_context_panel() -> void:
	if context_title_label == null or context_stats_label == null:
		return

	if selected_unit_data == null:
		context_title_label.text = "No Selection"
		context_stats_label.text = _join_lines([
			"%s --   %s --   %s --   %s --" % [_hud_stat_icon("health"), _hud_stat_icon("stamina"), _hud_stat_icon("morale"), _hud_stat_icon("armor")],
			"%s --   %s --   %s --" % [_hud_stat_icon("damage"), _hud_stat_icon("speed"), _hud_stat_icon("equipment")],
			"LMB %s   Shift+%s   RMB %s   2xRMB %s" % [_hud_icon("select"), _hud_icon("add_selection"), _hud_icon("move"), _hud_icon("jog")],
		])
		_refresh_carry_panel([])
		_refresh_animation_picker()
		return

	if selected_unit_ids.size() > 1:
		var total_health := 0
		var total_max_health := 0
		var total_stamina := 0
		var total_morale := 0
		var total_damage := 0
		var valid_count := 0
		for unit_id in selected_unit_ids:
			var unit_data = _unit_data_by_id(str(unit_id))
			if unit_data == null:
				continue
			valid_count += 1
			total_health += int(unit_data.health)
			total_max_health += int(unit_data.max_health)
			total_stamina += int(unit_data.stamina)
			total_morale += int(unit_data.morale)
			total_damage += int(unit_data.damage)

		if valid_count <= 0:
			_clear_unit_selection()
			_refresh_context_panel()
			return

		context_title_label.text = "Units x%d" % valid_count
		context_stats_label.text = _join_lines([
			"%s %d/%d   %s %d   %s %d" % [
				_hud_stat_icon("health"),
				total_health,
				total_max_health,
				_hud_stat_icon("stamina"),
				int(round(float(total_stamina) / float(valid_count))),
				_hud_stat_icon("morale"),
				int(round(float(total_morale) / float(valid_count))),
			],
			"%s %d   %s %s" % [_hud_stat_icon("damage"), total_damage, _hud_stat_icon("lead_unit"), str(selected_unit_data.display_name)],
			"RMB %s   2xRMB %s" % [_hud_icon("move"), _hud_icon("jog")],
		])
		_refresh_carry_panel(selected_unit_ids)
		_refresh_animation_picker()
		return

	context_title_label.text = "%s  (%s)" % [str(selected_unit_data.display_name), str(selected_unit_data.id)]
	context_stats_label.text = _join_lines([
		"%s %d/%d   %s %d   %s %d   %s %d" % [
			_hud_stat_icon("health"),
			int(selected_unit_data.health),
			int(selected_unit_data.max_health),
			_hud_stat_icon("stamina"),
			int(selected_unit_data.stamina),
			_hud_stat_icon("morale"),
			int(selected_unit_data.morale),
			_hud_stat_icon("armor"),
			int(selected_unit_data.armor),
		],
		"%s %d   %s %.1f   %s %s   %s %s" % [
			_hud_stat_icon("damage"),
			int(selected_unit_data.damage),
			_hud_stat_icon("speed"),
			float(selected_unit_data.movement_speed),
			_hud_stat_icon("equipment"),
			str(selected_unit_data.equipment_id),
			_hud_stat_icon("profession"),
			str(selected_unit_data.profession).capitalize(),
		],
		"RMB %s   2xRMB %s   Shift %s" % [_hud_icon("move"), _hud_icon("jog"), _hud_icon("add_selection")],
	])
	_refresh_carry_panel(selected_unit_ids)
	_refresh_animation_picker()


func _refresh_carry_panel(unit_ids: Array) -> void:
	if context_carry_panel == null or context_carry_label == null:
		return
	if unit_ids.is_empty():
		context_carry_panel.visible = false
		context_carry_label.text = ""
		return

	var totals := _carried_resource_totals_for_units(unit_ids)
	context_carry_panel.visible = true
	context_carry_label.text = _join_lines(_carry_summary_lines(totals, unit_ids.size()))


func _carried_resource_totals_for_units(unit_ids: Array) -> Dictionary:
	var totals := {}
	var none_count := 0
	for unit_id_value in unit_ids:
		var actor = unit_actors_by_id.get(str(unit_id_value))
		if actor == null or not is_instance_valid(actor) or actor.carried_total() <= 0:
			none_count += 1
			continue
		for resource_name_value in actor.carried_resources.keys():
			var resource_name := str(resource_name_value)
			totals[resource_name] = int(totals.get(resource_name, 0)) + int(actor.carried_resources[resource_name])
	if none_count > 0:
		totals["none"] = none_count
	return totals


func _carry_summary_lines(totals: Dictionary, selected_count: int) -> Array:
	var lines: Array = [_hud_icon("carry")]
	var order := ["wood", "stone", "flint", "food", "gold", "none"]
	var used := {}
	for resource_name in order:
		if not totals.has(resource_name):
			continue
		lines.append("• %s %d" % [_resource_symbol(resource_name), int(totals[resource_name])])
		used[resource_name] = true
	for resource_name_value in totals.keys():
		var resource_name := str(resource_name_value)
		if used.has(resource_name):
			continue
		lines.append("• %s %d" % [_resource_symbol(resource_name), int(totals[resource_name])])
	if lines.size() == 1:
		lines.append("• %s %d" % [_resource_symbol("none"), selected_count])
	return lines


func _refresh_animation_picker() -> void:
	if context_animation_picker == null:
		return

	context_animation_picker_updating = true
	context_animation_picker.clear()

	if selected_unit_data == null:
		context_animation_picker.visible = false
		context_animation_picker.disabled = true
		context_animation_picker_updating = false
		return

	context_animation_picker.visible = true
	if unit_animation_names.is_empty():
		_get_unit_animation_library()

	if unit_animation_names.is_empty():
		context_animation_picker.disabled = true
		context_animation_picker.add_item(unit_animation_status if not unit_animation_status.is_empty() else "No animations available")
		context_animation_picker_updating = false
		return

	context_animation_picker.disabled = false
	context_animation_picker.add_item("Play animation...")
	for animation_name in unit_animation_names:
		context_animation_picker.add_item(str(animation_name))

	var selected_animation := _current_selection_animation_name()
	if selected_animation.is_empty():
		context_animation_picker.select(0)
	else:
		var animation_index := unit_animation_names.find(selected_animation)
		context_animation_picker.select(animation_index + 1 if animation_index >= 0 else 0)

	context_animation_picker_updating = false


func _on_unit_animation_selected(index: int) -> void:
	if context_animation_picker_updating or context_animation_picker == null:
		return
	if index <= 0 or index >= context_animation_picker.item_count:
		return
	var animation_name := context_animation_picker.get_item_text(index)
	_play_animation_on_selected_units(animation_name)


func _refresh_resource_rail(resources: Dictionary) -> void:
	if resource_list_container == null:
		return

	for child in resource_list_container.get_children():
		child.queue_free()

	var entries: Array = []
	var resource_order := [
		"food", "fish", "whale_oil", "wood", "stone", "flint", "coal", "copper", "tin",
		"iron", "silver", "gold_ore", "uranium", "metal", "tools", "weapons", "supply",
	]
	for resource_name in resource_order:
		var amount := int(resources.get(resource_name, 0))
		if amount > 0:
			entries.append({
				"name": resource_name,
				"amount": amount,
			})

	if resource_rail_panel != null:
		resource_rail_panel.visible = not entries.is_empty()

	for entry in entries:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		resource_list_container.add_child(row)

		var symbol := TextureRect.new()
		symbol.texture = _hud_icon_texture("resource_%s" % str(entry["name"]))
		symbol.custom_minimum_size = Vector2(18, 18)
		symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		symbol.tooltip_text = str(entry["name"]).capitalize()
		row.add_child(symbol)

		var amount_label := Label.new()
		amount_label.text = str(int(entry["amount"]))
		amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amount_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(amount_label)


func _resource_symbol(resource_name: String) -> String:
	return _hud_icon("resource_%s" % resource_name)


func _hud_icon(icon_name: String) -> String:
	var icon_path := _hud_icon_path(icon_name)
	if icon_path.is_empty():
		return HUD_MISSING_ICON
	return "[img=%dx%d]%s[/img]" % [HUD_INLINE_ICON_SIZE, HUD_INLINE_ICON_SIZE, icon_path]


func _hud_icon_path(icon_name: String) -> String:
	if icon_name.is_empty():
		return ""
	var icon_path := "%s%s.svg" % [HUD_ICON_ROOT, icon_name]
	return icon_path if ResourceLoader.exists(icon_path) else ""


func _hud_icon_texture(icon_name: String) -> Texture2D:
	if hud_icon_texture_cache.has(icon_name):
		return hud_icon_texture_cache[icon_name] as Texture2D
	var icon_path := _hud_icon_path(icon_name)
	if icon_path.is_empty():
		return null
	var texture := load(icon_path) as Texture2D
	if texture != null:
		hud_icon_texture_cache[icon_name] = texture
	return texture


func _settlement_population_estimate(resources: Dictionary) -> int:
	return max(0, int(resources.get("supply", 0)) * 12)


func _tech_level_label() -> String:
	if cell == null:
		return "I"
	if float(cell.elevation) >= WorldState.MOUNTAIN_LEVEL:
		return "II"
	return "I"


func _owner_short_label(owner_id: String) -> String:
	match owner_id:
		"player":
			return "Player"
		"neutral":
			return "Neutral"
		"bandits":
			return "Bandits"
	if owner_id.is_empty():
		return "Unknown"
	return owner_id.capitalize()


func _settlement_display_name(cell_id: String, terrain_name: String) -> String:
	if cell != null and not str(cell.settlement_name).is_empty():
		return str(cell.settlement_name)
	if terrain_name == "Unknown":
		return "Region"
	return "%s Region" % terrain_name


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material


func _transparent_unshaded_material(color: Color, use_vertex_color: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = use_vertex_color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _sun_label(sun_amount: float) -> String:
	if sun_amount < -0.08:
		return "Night"
	if sun_amount < 0.12:
		return "Sunrise / Sunset"
	return "Day"


func _terrain_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.metallic = 0.0
	material.metallic_specular = 0.0
	material.roughness = 0.94
	return material


func _water_material(use_river_flow: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/lowpoly_water.gdshader")
	material.set_shader_parameter("use_river_flow", use_river_flow)
	material.set_shader_parameter("deep_water_color", Color(0.035, 0.18, 0.28) if use_river_flow else Color(0.006, 0.040, 0.10))
	material.set_shader_parameter("shallow_water_color", Color(0.16, 0.56, 0.72) if use_river_flow else Color(0.045, 0.25, 0.42))
	material.set_shader_parameter("foam_color", Color(0.72, 0.90, 0.94) if use_river_flow else Color(0.78, 0.94, 0.98))
	material.set_shader_parameter("wave_direction", Vector2(0.86, 0.18) if use_river_flow else Vector2(0.72, 0.22))
	material.set_shader_parameter("wave_direction_2", Vector2(-0.25, 0.94) if use_river_flow else Vector2(-0.30, 0.88))
	material.set_shader_parameter("wave_height", 0.08 if use_river_flow else 1.05)
	material.set_shader_parameter("wave_scale", 0.22 if use_river_flow else 0.070)
	material.set_shader_parameter("wave_speed", 2.20 if use_river_flow else 1.35)
	material.set_shader_parameter("edge_foam_distance", 0.65 if use_river_flow else 1.90)
	material.set_shader_parameter("depth_color_distance", 2.6 if use_river_flow else 8.0)
	material.set_shader_parameter("alpha", 0.84 if use_river_flow else 0.86)
	material.set_shader_parameter("facet_contrast", 0.26 if use_river_flow else 0.32)
	material.set_shader_parameter("low_poly_strength", 0.62 if use_river_flow else 0.88)
	material.set_shader_parameter("day_factor", _rts_visibility_factor(Game.get_battle_sun_amount()))
	material.set_shader_parameter("sun_direction", Game.get_battle_sun_direction())
	return material


func _water_noise_texture(noise_seed: int, frequency: float, bump_strength: float) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 5
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.52

	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.as_normal_map = true
	texture.bump_strength = bump_strength
	texture.noise = noise
	return texture


func _sync_sun_lighting() -> void:
	if sun_light == null or sky_material == null or battle_environment == null:
		return

	var sun_amount := Game.get_battle_sun_amount()
	var visibility_factor := _rts_visibility_factor(sun_amount)
	var direct_sun_factor := smoothstep(-0.04, 0.45, sun_amount)
	var night_fill_factor := 1.0 - smoothstep(-0.08, 0.38, sun_amount)
	var sun_direction := Game.get_battle_sun_direction()
	sun_light.light_energy = lerpf(0.0, 1.85, direct_sun_factor)
	sun_light.shadow_enabled = direct_sun_factor > 0.08
	sun_light.light_color = Color(1.0, 0.78, 0.54).lerp(Color(1.0, 0.96, 0.86), direct_sun_factor)
	sun_light.look_at_from_position(sun_direction * 100.0, Vector3.ZERO, Vector3.UP)
	if night_fill_light != null:
		night_fill_light.light_energy = MOON_LIGHT_MAX_ENERGY * night_fill_factor
		var moon_direction := -sun_direction
		if moon_direction.is_zero_approx():
			moon_direction = Vector3(-0.35, 0.82, -0.45).normalized()
		night_fill_light.look_at_from_position(moon_direction * 100.0, Vector3.ZERO, Vector3.UP)
	sky_material.set_shader_parameter("sun_direction", sun_direction)
	sky_material.set_shader_parameter("sun_amount", sun_amount)
	sky_material.set_shader_parameter("day_factor", visibility_factor)
	battle_environment.ambient_light_color = Color(0.13, 0.16, 0.24).lerp(Color(0.62, 0.60, 0.52), visibility_factor)
	battle_environment.ambient_light_energy = lerpf(0.40, 0.72, visibility_factor)
	_sync_water_lighting(visibility_factor, sun_direction)
	_sync_tree_ground_shadow_lighting(direct_sun_factor)
	var next_sun_label := _sun_label(sun_amount)
	if summary_label != null and next_sun_label != displayed_sun_label:
		_refresh_overlay()


func _rts_visibility_factor(sun_amount: float) -> float:
	return smoothstep(-0.18, 0.32, sun_amount)


func _sync_water_lighting(day_factor: float, sun_direction: Vector3) -> void:
	if terrain_root == null:
		return

	for child in terrain_root.get_children():
		if child is MeshInstance3D and child.name in ["StillOceanWater", "RiverWater"]:
			var shader_material := child.material_override as ShaderMaterial
			if shader_material != null:
				shader_material.set_shader_parameter("day_factor", day_factor)
				shader_material.set_shader_parameter("sun_direction", sun_direction)


func _sync_tree_ground_shadow_lighting(direct_sun_factor: float) -> void:
	if tree_shadow_material == null:
		return
	var shadow_visibility := smoothstep(0.10, 0.65, direct_sun_factor)
	tree_shadow_material.set_shader_parameter("shadow_alpha", TREE_GROUND_SHADOW_ALPHA * shadow_visibility)


func _on_return_pressed() -> void:
	_snapshot_current_cell_state()
	if cell != null:
		Game.current_cell_id = str(cell.id)
	get_tree().change_scene_to_file("res://scenes/world/world_map.tscn")


func _snapshot_current_cell_state() -> void:
	if cell == null or not rts_state_ready:
		return
	var serialized_units: Array = []
	var runtime_by_id := {}
	for unit_data in battle_units:
		if unit_data == null:
			continue
		var unit_id := str(unit_data.id)
		var actor = unit_actors_by_id.get(unit_id)
		if actor != null and is_instance_valid(actor):
			unit_data.position = actor.position
			runtime_by_id[unit_id] = {
				"carried_resources": actor.carried_resources.duplicate(true),
			}
		serialized_units.append(unit_data.to_dict())

	var serialized_resources := {}
	for resource_id_value in resource_nodes_by_id.keys():
		var resource = resource_nodes_by_id.get(resource_id_value)
		if resource == null or not resource.has_runtime_changes():
			continue
		serialized_resources[str(resource_id_value)] = {
			"amount_remaining": int(resource.amount_remaining),
			"depleted": bool(resource.depleted),
				"stage": str(resource.stage),
				"harvest_amount": int(resource.harvest_amount),
				"health": int(resource.health),
				"max_health": int(resource.max_health),
				"work_progress": float(resource.work_progress),
			"work_required": float(resource.work_required),
			"show_ring": bool(resource.show_ring),
		}
	var serialized_buildings: Array = []
	for building in battle_buildings:
		if building != null:
			serialized_buildings.append(building.to_dict())

	cell.rts_state = {
		"version": 2,
		"units": serialized_units,
		"unit_runtime": runtime_by_id,
		"buildings": serialized_buildings,
		"resources": serialized_resources,
	}


func _hud_stat_icon(icon_name: String) -> String:
	return "[url=stat:%s]%s[/url]" % [icon_name, _hud_icon(icon_name)]


func _join_lines(lines: Array) -> String:
	var output := ""
	for line in lines:
		if not output.is_empty():
			output += "\n"
		output += str(line)
	return output


func _update_rts_camera(delta: float) -> void:
	if camera == null:
		return

	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	forward = forward.normalized()

	var right := camera.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() <= 0.001:
		right = Vector3.RIGHT
	right = right.normalized()

	var direction := Vector3.ZERO
	if Game.is_move_forward_pressed():
		direction += forward
	if Game.is_move_back_pressed():
		direction -= forward
	if Game.is_move_left_pressed():
		direction -= right
	if Game.is_move_right_pressed():
		direction += right

	if direction == Vector3.ZERO:
		return

	direction = direction.normalized()
	var speed := CAMERA_PAN_SPEED
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= CAMERA_FAST_MULTIPLIER

	var next_position := camera.position + direction * speed * delta
	var limit := MAP_SIZE * 0.5
	next_position.x = clamp(next_position.x, -limit, limit)
	next_position.z = clamp(next_position.z, -limit + CAMERA_MIN_Z, limit + CAMERA_MAX_Z * 0.25)
	camera.position = next_position


func _zoom_camera(amount: float) -> void:
	if free_roam_enabled:
		return

	var next_y: float = clamp(camera.position.y + amount, CAMERA_MIN_HEIGHT, CAMERA_MAX_HEIGHT)
	var zoom_ratio: float = inverse_lerp(CAMERA_MIN_HEIGHT, CAMERA_MAX_HEIGHT, next_y)
	var next_z: float = lerpf(CAMERA_MIN_Z, CAMERA_MAX_Z, zoom_ratio)
	camera.position.y = next_y
	camera.position.z = clamp(camera.position.z, -MAP_SIZE * 0.5 + next_z, MAP_SIZE * 0.5 + next_z * 0.25)
	camera.rotation_degrees.x = lerpf(-58.0, -46.0, zoom_ratio)


func _toggle_free_roam() -> void:
	_set_free_roam_enabled(not free_roam_enabled)


func _set_free_roam_enabled(enabled: bool) -> void:
	free_roam_enabled = enabled
	if camera == null:
		return

	if free_roam_enabled:
		_cancel_unit_selection_drag()
		rts_yaw_dragging = false
		free_roam_yaw = camera.rotation.y
		free_roam_pitch = camera.rotation.x
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _update_free_roam_camera(delta: float) -> void:
	if camera == null:
		return

	var direction := Vector3.ZERO
	if Game.is_move_forward_pressed():
		direction -= camera.global_transform.basis.z
	if Game.is_move_back_pressed():
		direction += camera.global_transform.basis.z
	if Game.is_move_left_pressed():
		direction -= camera.global_transform.basis.x
	if Game.is_move_right_pressed():
		direction += camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_SPACE):
		direction += Vector3.UP
	if Input.is_key_pressed(KEY_C):
		direction -= Vector3.UP

	if direction == Vector3.ZERO:
		return

	direction = direction.normalized()
	var speed := FREE_ROAM_SPEED
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= FREE_ROAM_FAST_MULTIPLIER
	camera.global_position += direction * speed * delta
