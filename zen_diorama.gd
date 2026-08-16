extends Node2D

const BASE_W := 720.0
const FAR_LOWER_CENTER := Vector2(360.0, 770.0)
const FAR_UPPER_CENTER := Vector2(360.0, -382.0)
const FAR_HIGH_CENTER := Vector2(360.0, -1534.0)
const FAR_SKY_CENTER := Vector2(360.0, -2361.0)
const FAR_ZENITH_CENTER := Vector2(360.0, -3513.0)
const MID_CENTER := Vector2(360.0, 818.0)
const NEAR_CENTER := Vector2(360.0, 817.0)
const ATMOSPHERE_CENTER := Vector2(360.0, 760.0)

const FAR := preload("res://assets/skins/zen/diorama/valley_base.png")
const MID := preload("res://assets/skins/zen/diorama/valley_mid.png")
const SKY_TEMPLE := preload("res://assets/skins/zen/diorama/sky_temple.png")
const HIGH_MOUNTAINS := preload("res://assets/skins/zen/diorama/high_mountains.png")
const HIGH_SKY := preload("res://assets/skins/zen/diorama/high_sky.png")
const ZENITH := preload("res://assets/skins/zen/diorama/zenith.png")
const NEAR := preload("res://assets/skins/zen/diorama/valley_foreground.png")
const WATERFALL_SHEET := preload("res://assets/skins/zen/live/waterfall_sheet_v2.png")
const SAKURA_SHEET := preload("res://assets/skins/zen/live/sakura_sheet_v2.png")

var _scalable: Array[CanvasItem] = []
var _animated_scalable: Array[Dictionary] = []


func _ready() -> void:
	var far_world := _parallax("FarWorld", Vector2(0.08, 0.84), -100)
	_build_far(far_world)

	var mid_world := _parallax("MidWorld", Vector2(0.18, 0.90), -90)
	_build_mid(mid_world)

	var near_world := _parallax("NearWorld", Vector2(0.38, 0.96), -80)
	_build_near(near_world)

	var atmosphere := _parallax("Atmosphere", Vector2(0.24, 0.88), -70)
	_build_atmosphere(atmosphere)


func _process(_delta: float) -> void:
	var viewport_width := get_viewport().get_visible_rect().size.x
	var cover_scale := maxf(1.0, viewport_width / BASE_W)
	for item in _scalable:
		item.scale = Vector2.ONE * cover_scale
	for data in _animated_scalable:
		var animated: AnimatedSprite2D = data["node"]
		animated.scale = Vector2(data["scale_x"], data["scale_y"]) * cover_scale


func _parallax(node_name: String, depth: Vector2, z: int) -> Parallax2D:
	var layer := Parallax2D.new()
	layer.name = node_name
	layer.scroll_scale = depth
	layer.repeat_size = Vector2.ZERO
	layer.repeat_times = 1
	layer.follow_viewport = true
	layer.ignore_camera_scroll = false
	layer.limit_begin = Vector2(-100000.0, -5420.0)
	layer.limit_end = Vector2(100000.0, 1460.0)
	layer.z_index = z
	add_child(layer)
	return layer


func _build_far(parent: Node) -> void:
	var lower := _sprite(FAR, FAR_LOWER_CENTER)
	parent.add_child(lower)
	_scalable.append(lower)

	var upper := _sprite(SKY_TEMPLE, FAR_UPPER_CENTER)
	parent.add_child(upper)
	_scalable.append(upper)

	var high := _sprite(HIGH_MOUNTAINS, FAR_HIGH_CENTER)
	parent.add_child(high)
	_scalable.append(high)

	var final_sky := _sprite(HIGH_SKY, FAR_SKY_CENTER)
	parent.add_child(final_sky)
	_scalable.append(final_sky)

	var zenith := _sprite(ZENITH, FAR_ZENITH_CENTER)
	parent.add_child(zenith)
	_scalable.append(zenith)

	# A deep cloud bank is a story transition, not a visible join between plates.
	# It also gives the climb a short moment of open air before the upper temples.
	_add_transition_mist(parent, 194.0)
	_add_transition_mist(parent, -958.0)
	_add_transition_mist(parent, -1947.0)
	_add_transition_mist(parent, -2937.0)


func _add_transition_mist(parent: Node, center_y: float) -> void:
	var mist := Sprite2D.new()
	var mist_gradient := Gradient.new()
	mist_gradient.offsets = PackedFloat32Array([0.0, 0.22, 0.50, 0.78, 1.0])
	mist_gradient.colors = PackedColorArray([
		Color(0.94, 0.98, 0.96, 0.0),
		Color(0.94, 0.98, 0.96, 0.54),
		Color(0.97, 0.99, 0.98, 0.82),
		Color(0.91, 0.97, 0.96, 0.48),
		Color(0.91, 0.97, 0.96, 0.0),
	])
	var mist_texture := GradientTexture2D.new()
	mist_texture.gradient = mist_gradient
	mist_texture.width = 720
	mist_texture.height = 520
	mist_texture.fill_from = Vector2(0.5, 0.0)
	mist_texture.fill_to = Vector2(0.5, 1.0)
	mist.texture = mist_texture
	mist.position = Vector2(360.0, center_y)
	parent.add_child(mist)
	_scalable.append(mist)


func _build_mid(parent: Node) -> void:
	var mid := _sprite(MID, MID_CENTER)
	parent.add_child(mid)
	_scalable.append(mid)

	var waterfall := _add_animated_sheet(parent, WATERFALL_SHEET, 4, 2, 9.0,
			Vector2(365.0, 930.0), Vector2(0.15, 0.22), 2)
	waterfall.modulate = Color(0.60, 0.88, 0.82, 0.62)


func _build_near(parent: Node) -> void:
	var near := _sprite(NEAR, NEAR_CENTER)
	parent.add_child(near)
	_scalable.append(near)

	var sakura := _add_animated_sheet(parent, SAKURA_SHEET, 4, 2, 5.5,
			Vector2(142.0, 292.0), Vector2(0.58, 0.58), 1)
	sakura.modulate.a = 0.92


func _build_atmosphere(parent: Node) -> void:
	var petals := CPUParticles2D.new()
	petals.position = ATMOSPHERE_CENTER
	petals.amount = 28
	petals.lifetime = 8.5
	petals.preprocess = 8.0
	petals.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	petals.emission_rect_extents = Vector2(360.0, 520.0)
	petals.randomness = 0.8
	petals.direction = Vector2(-0.55, 1.0)
	petals.spread = 28.0
	petals.gravity = Vector2(8.0, 14.0)
	petals.initial_velocity_min = 10.0
	petals.initial_velocity_max = 24.0
	petals.angular_velocity_min = -95.0
	petals.angular_velocity_max = 95.0
	petals.scale_amount_min = 0.22
	petals.scale_amount_max = 0.48
	petals.texture = load("res://assets/zen/petal.svg")
	petals.color = Color(1.0, 0.82, 0.88, 0.78)
	parent.add_child(petals)


func _sprite(texture: Texture2D, at: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = at
	return sprite


func _add_animated_sheet(parent: Node, texture: Texture2D, columns: int, rows: int,
		fps: float, at: Vector2, art_scale: Vector2, start_frame: int) -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.add_animation("loop")
	frames.set_animation_speed("loop", fps)
	frames.set_animation_loop("loop", true)
	var frame_size := Vector2i(texture.get_width() / columns, texture.get_height() / rows)
	for row in range(rows):
		for column in range(columns):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2i(Vector2i(column, row) * frame_size, frame_size)
			frames.add_frame("loop", atlas)
	var animated := AnimatedSprite2D.new()
	animated.sprite_frames = frames
	animated.animation = "loop"
	animated.position = at
	animated.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	animated.frame = start_frame % (columns * rows)
	animated.play()
	parent.add_child(animated)
	_animated_scalable.append({
		"node": animated,
		"scale_x": art_scale.x,
		"scale_y": art_scale.y,
	})
	return animated
