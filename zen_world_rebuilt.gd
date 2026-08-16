extends Node2D

const W := 720.0
const START := preload("res://assets/skins/zen/rebuilt/valley_start.png")
const TEMPLE := preload("res://assets/skins/zen/rebuilt/sky_temple.png")
const MOUNTAINS := preload("res://assets/skins/zen/rebuilt/high_mountains.png")
const HIGH_SKY := preload("res://assets/skins/zen/rebuilt/high_sky.png")
const ZENITH := preload("res://assets/skins/zen/rebuilt/zenith.png")
const PETAL := preload("res://assets/zen/petal.svg")

var _cover: Array[Sprite2D] = []


func _ready() -> void:
	var world := _layer("PaintedWorld", Vector2(0.10, 0.84), -100)
	_add_plate(world, START, 770.0)
	_add_plate(world, TEMPLE, -382.0)
	_add_plate(world, MOUNTAINS, -1534.0)
	_add_plate(world, HIGH_SKY, -2686.0)
	_add_plate(world, ZENITH, -3838.0)
	for seam_y in [194.0, -958.0, -2110.0, -3262.0]:
		_add_mist_seam(world, seam_y)
	var life := _layer("LivingWorld", Vector2(0.10, 0.84), -92)
	_add_stream(life, Vector2(360.0, 1040.0))
	_add_clouds(life)
	_add_petals(life, Vector2(120.0, 625.0), 0.0)
	_add_petals(life, Vector2(585.0, 420.0), 2.4)
	_add_petals(life, Vector2(180.0, -500.0), 4.1)
	_add_birds(life)


func _process(_delta: float) -> void:
	var factor := maxf(1.0, get_viewport().get_visible_rect().size.x / W)
	for sprite in _cover:
		sprite.scale = Vector2.ONE * factor


func _layer(title: String, depth: Vector2, z: int) -> Parallax2D:
	var layer := Parallax2D.new()
	layer.name = title
	layer.scroll_scale = depth
	layer.follow_viewport = true
	layer.repeat_size = Vector2.ZERO
	layer.limit_begin = Vector2(-100000.0, -5550.0)
	layer.limit_end = Vector2(100000.0, 1500.0)
	layer.z_index = z
	add_child(layer)
	return layer


func _add_plate(parent: Node, texture: Texture2D, center_y: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = Vector2(360.0, center_y)
	parent.add_child(sprite)
	_cover.append(sprite)


func _add_mist_seam(parent: Node, center_y: float) -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.22, 0.5, 0.78, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.93, 0.98, 0.98, 0.0), Color(0.93, 0.98, 0.98, 0.42),
		Color(0.96, 0.99, 0.99, 0.72), Color(0.93, 0.98, 0.98, 0.40),
		Color(0.93, 0.98, 0.98, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 720
	texture.height = 360
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	var mist := Sprite2D.new()
	mist.texture = texture
	mist.position = Vector2(360.0, center_y)
	parent.add_child(mist)
	_cover.append(mist)


func _add_stream(parent: Node, at: Vector2) -> void:
	var root := Node2D.new()
	root.position = at
	parent.add_child(root)
	for i in range(9):
		var ripple := Line2D.new()
		ripple.width = 2.0
		ripple.default_color = Color(0.78, 1.0, 1.0, 0.44)
		ripple.points = PackedVector2Array([Vector2(-28, 0), Vector2(0, 3), Vector2(28, 0)])
		ripple.position = Vector2(sin(i * 2.1) * 35.0, i * 34.0 - 40.0)
		root.add_child(ripple)
		var flow := ripple.create_tween().set_loops()
		flow.tween_interval(i * 0.13)
		flow.tween_property(ripple, "position:y", ripple.position.y + 42.0, 1.25).set_trans(Tween.TRANS_SINE)
		flow.parallel().tween_property(ripple, "modulate:a", 0.0, 1.25).from(0.7)


func _add_clouds(parent: Node) -> void:
	for data in [[-1180.0, 24.0, 0.22], [-2240.0, 31.0, 0.18], [-3350.0, 38.0, 0.15]]:
		var cloud := Node2D.new()
		cloud.position = Vector2(-170.0, data[0])
		parent.add_child(cloud)
		for i in range(7):
			var puff := Polygon2D.new()
			puff.polygon = _ellipse(70.0 - i * 3.0, 28.0 + i % 2 * 7.0, 24)
			puff.color = Color(0.96, 0.99, 1.0, data[2])
			puff.position = Vector2(i * 58.0, sin(i * 1.7) * 14.0)
			cloud.add_child(puff)
		var drift := cloud.create_tween().set_loops()
		drift.tween_property(cloud, "position:x", 890.0, data[1]).set_trans(Tween.TRANS_LINEAR)


func _add_petals(parent: Node, at: Vector2, delay: float) -> void:
	var petals := CPUParticles2D.new()
	petals.position = at
	petals.amount = 18
	petals.lifetime = 7.0
	petals.preprocess = 2.0
	petals.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	petals.emission_rect_extents = Vector2(95.0, 65.0)
	petals.direction = Vector2(0.65, 1.0)
	petals.spread = 24.0
	petals.gravity = Vector2(7.0, 12.0)
	petals.initial_velocity_min = 8.0
	petals.initial_velocity_max = 21.0
	petals.angular_velocity_min = -110.0
	petals.angular_velocity_max = 110.0
	petals.scale_amount_min = 0.18
	petals.scale_amount_max = 0.38
	petals.texture = PETAL
	petals.color = Color(1.0, 0.72, 0.80, 0.82)
	petals.emitting = false
	parent.add_child(petals)
	var cycle := petals.create_tween().set_loops()
	cycle.tween_interval(delay + 1.0)
	cycle.tween_callback(func(): petals.emitting = true)
	cycle.tween_interval(2.8)
	cycle.tween_callback(func(): petals.emitting = false)
	cycle.tween_interval(4.2)


func _add_birds(parent: Node) -> void:
	for i in range(4):
		var bird := Node2D.new()
		bird.position = Vector2(-80.0, -720.0 - i * 920.0)
		parent.add_child(bird)
		for side in [-1.0, 1.0]:
			var wing := Line2D.new()
			wing.width = 3.0
			wing.default_color = Color(0.08, 0.18, 0.24, 0.58)
			wing.points = PackedVector2Array([Vector2.ZERO, Vector2(side * 13.0, -7.0), Vector2(side * 25.0, 0)])
			bird.add_child(wing)
			var flap := wing.create_tween().set_loops()
			flap.tween_property(wing, "rotation", side * 0.24, 0.20).set_trans(Tween.TRANS_SINE)
			flap.tween_property(wing, "rotation", -side * 0.14, 0.20).set_trans(Tween.TRANS_SINE)
		var flight := bird.create_tween().set_loops()
		flight.tween_interval(i * 1.9)
		flight.tween_property(bird, "position:x", 800.0, 11.0 + i * 2.0).set_trans(Tween.TRANS_LINEAR)


func _ellipse(rx: float, ry: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * i / count
		points.append(Vector2(cos(angle) * rx, sin(angle) * ry))
	return points
