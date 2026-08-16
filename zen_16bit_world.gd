extends Node2D

const SECTION_SIZE := Vector2(720.0, 1280.0)
const SECTION_STEP_Y := 1152.0
const START_CENTER_Y := 572.0
const CHAPTERS := [
	preload("res://assets/skins/zen/v2/chapter_0.png"),
	preload("res://assets/skins/zen/v2/chapter_1.png"),
	preload("res://assets/skins/zen/v2/chapter_2.png"),
	preload("res://assets/skins/zen/v2/chapter_3.png"),
	preload("res://assets/skins/zen/v2/chapter_4.png"),
]


func _ready() -> void:
	z_index = -100
	for index in range(CHAPTERS.size()):
		var chapter := Sprite2D.new()
		chapter.name = "ZenChapter%d" % index
		chapter.texture = CHAPTERS[index]
		chapter.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		chapter.position = Vector2(360.0, START_CENTER_Y - SECTION_STEP_Y * index)
		add_child(chapter)
	var lower_fill := Polygon2D.new()
	lower_fill.polygon = PackedVector2Array([
		Vector2(0, START_CENTER_Y + 640), Vector2(720, START_CENTER_Y + 640),
		Vector2(720, START_CENTER_Y + 1100), Vector2(0, START_CENTER_Y + 1100),
	])
	lower_fill.color = Color("102B24")
	lower_fill.z_index = -1
	add_child(lower_fill)
	_build_chapter_zero_life()
	RenderingServer.set_default_clear_color(Color("101B3A"))


func _build_chapter_zero_life() -> void:
	var chapter_top := START_CENTER_Y - SECTION_SIZE.y * 0.5
	_add_waterfall(Vector2(168, chapter_top + 582), Vector2(0.64, 0.92), 8.0)
	_add_waterfall(Vector2(276, chapter_top + 420), Vector2(0.58, 0.80), 9.0)
	_add_waterfall(Vector2(455, chapter_top + 485), Vector2(1.08, 1.34), 7.0)
	_add_waterfall(Vector2(430, chapter_top + 898), Vector2(0.92, 0.88), 10.0)
	_add_frame_animation("sakura", 6, Vector2(600, chapter_top + 544), 3.2, 4)
	_add_frame_animation("banner", 6, Vector2(606, chapter_top + 839), 4.0, 5)
	_add_cloud(0, Vector2(260, chapter_top + 195), 32.0, 1)
	_add_cloud(2, Vector2(330, chapter_top + 390), 38.0, 1)
	for point in [Vector2(70, 1045), Vector2(642, 1048)]:
		_add_lantern_glow(Vector2(point.x, chapter_top + point.y))
	_add_petals(chapter_top)


func _add_waterfall(position_value: Vector2, scale_value: Vector2, fps: float) -> void:
	var waterfall := _make_animated_sprite("waterfall", 8, fps)
	waterfall.position = position_value
	waterfall.scale = scale_value
	waterfall.modulate = Color(0.62, 0.79, 0.88, 0.72)
	waterfall.z_index = 3
	add_child(waterfall)
	waterfall.play("flow")


func _add_frame_animation(prefix: String, frame_count: int, position_value: Vector2,
		fps: float, layer: int) -> void:
	var sprite := _make_animated_sprite(prefix, frame_count, fps)
	sprite.position = position_value
	sprite.z_index = layer
	add_child(sprite)
	sprite.play("flow")


func _make_animated_sprite(prefix: String, frame_count: int, fps: float) -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.add_animation("flow")
	frames.set_animation_speed("flow", fps)
	frames.set_animation_loop("flow", true)
	for index in range(frame_count):
		var path := "res://assets/skins/zen/v2/anim/chapter_0/%s_%d.png" % [prefix, index]
		frames.add_frame("flow", load(path))
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite


func _add_cloud(index: int, start: Vector2, duration: float, layer: int) -> void:
	var cloud := Sprite2D.new()
	cloud.texture = load("res://assets/skins/zen/v2/anim/chapter_0/cloud_%d.png" % index)
	cloud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cloud.position = start
	cloud.scale = Vector2(0.72, 0.72)
	cloud.z_index = layer
	cloud.modulate = Color(0.72, 0.82, 0.90, 0.46)
	add_child(cloud)
	var tween := cloud.create_tween().set_loops()
	tween.tween_property(cloud, "position:x", start.x + 360.0, duration).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(func() -> void: cloud.position.x = start.x)


func _add_lantern_glow(position_value: Vector2) -> void:
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(-8, -13), Vector2(8, -13), Vector2(8, 13), Vector2(-8, 13),
	])
	glow.color = Color("FFB43C")
	glow.position = position_value
	glow.z_index = 6
	add_child(glow)
	var tween := glow.create_tween().set_loops()
	tween.tween_property(glow, "modulate", Color(1.0, 0.78, 0.45, 0.68), 1.2).set_trans(Tween.TRANS_SINE)
	tween.tween_property(glow, "modulate", Color(1.0, 1.0, 0.82, 1.0), 1.6).set_trans(Tween.TRANS_SINE)


func _add_petals(chapter_top: float) -> void:
	for index in range(14):
		var petal := Polygon2D.new()
		petal.polygon = PackedVector2Array([
			Vector2(-3, 0), Vector2(0, -2), Vector2(4, 0), Vector2(0, 3),
		])
		petal.color = Color("F5A0B8") if index % 3 else Color("FFD0D2")
		var start := Vector2(760.0 + index * 18.0, chapter_top + 300.0 + (index * 47) % 500)
		petal.position = start
		petal.z_index = 7
		add_child(petal)
		var tween := petal.create_tween().set_loops()
		tween.tween_property(petal, "position", start + Vector2(-900.0, 360.0), 8.0 + index * 0.35).set_trans(Tween.TRANS_LINEAR)
		tween.parallel().tween_property(petal, "rotation", TAU * (1.0 + index % 3), 8.0 + index * 0.35)
		tween.tween_callback(func() -> void:
			petal.position = start
			petal.rotation = 0.0
		)
