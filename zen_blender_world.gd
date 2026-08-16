extends Node2D

const WORLD := preload("res://assets/skins/zen/blender/zen_world.glb")
const START_Z := 5.1
const WORLD_Z_PER_PIXEL := 32.4 / 5000.0

var _camera_3d: Camera3D
var _camera_2d: Camera2D
var _start_camera_y := 0.0
var _has_start := false
var _subviewport: SubViewport


func _ready() -> void:
	_subviewport = SubViewport.new()
	_subviewport.name = "Zen3DViewport"
	_subviewport.size = Vector2i(720, 1280)
	_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_subviewport.own_world_3d = true
	add_child(_subviewport)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("4C91A3")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("B8D8D0")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	_subviewport.add_child(environment_node)

	var world := WORLD.instantiate()
	world.name = "BlenderZenWorld"
	_subviewport.add_child(world)
	_disable_imported_cameras_and_lights(world)
	_play_world_animations(world)

	var sunlight := DirectionalLight3D.new()
	sunlight.name = "ZenSunlight"
	sunlight.light_color = Color("FFD6AA")
	sunlight.light_energy = 0.85
	sunlight.rotation_degrees = Vector3(-32.0, -24.0, -18.0)
	sunlight.shadow_enabled = true
	_subviewport.add_child(sunlight)

	_camera_3d = Camera3D.new()
	_camera_3d.name = "GameplayZenCamera"
	_camera_3d.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera_3d.size = 10.4
	_camera_3d.position = Vector3(0.0, START_Z, 18.5)
	_subviewport.add_child(_camera_3d)
	_camera_3d.look_at(Vector3(0.0, START_Z - 0.4, 0.0), Vector3.UP)
	_camera_3d.make_current()

	var canvas := CanvasLayer.new()
	canvas.layer = -20
	add_child(canvas)
	var view := TextureRect.new()
	view.name = "Zen3DView"
	view.texture = _subviewport.get_texture()
	view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(view)


func _process(_delta: float) -> void:
	if _camera_2d == null:
		_camera_2d = get_viewport().get_camera_2d()
		if _camera_2d != null:
			_start_camera_y = _camera_2d.position.y
			_has_start = true
	if not _has_start or _camera_3d == null:
		return
	var climb := maxf(0.0, _start_camera_y - _camera_2d.position.y)
	_camera_3d.position.y = START_Z + climb * WORLD_Z_PER_PIXEL
	_camera_3d.look_at(Vector3(0.0, _camera_3d.position.y - 0.4, 0.0), Vector3.UP)


func _disable_imported_cameras_and_lights(node: Node) -> void:
	if node is Camera3D:
		(node as Camera3D).current = false
	elif node is Light3D:
		(node as Light3D).visible = false
	for child in node.get_children():
		_disable_imported_cameras_and_lights(child)


func _play_world_animations(node: Node) -> void:
	if node is AnimationPlayer:
		var player := node as AnimationPlayer
		for animation_name in player.get_animation_list():
			if animation_name == "RESET":
				continue
			var animation := player.get_animation(animation_name)
			animation.loop_mode = Animation.LOOP_LINEAR
			player.play(animation_name)
			break
		return
	for child in node.get_children():
		_play_world_animations(child)
