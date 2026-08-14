extends Node2D

const BASE_W := 720.0
const START_CAMERA_Y := 820.0
const LOWER_CENTER := Vector2(360.0, 540.0)
const UPPER_CENTER := Vector2(360.0, -548.0)
const FOREGROUND_CENTER := Vector2(360.0, 490.0)

const VALLEY := preload("res://assets/skins/zen/diorama/valley_base.png")
const SKY_TEMPLE := preload("res://assets/skins/zen/diorama/sky_temple.png")
const FOREGROUND := preload("res://assets/skins/zen/diorama/valley_foreground.png")

var _plates: Array[Sprite2D] = []
var _foreground: MeshInstance2D


func _ready() -> void:
	_build_world_plates()
	_build_foreground()
	_build_petals()


func _process(_delta: float) -> void:
	var viewport_width := get_viewport().get_visible_rect().size.x
	var cover_scale := maxf(1.0, viewport_width / BASE_W)
	for plate in _plates:
		plate.scale = Vector2.ONE * cover_scale
	_foreground.scale = Vector2.ONE * cover_scale

	var camera := get_viewport().get_camera_2d()
	if camera:
		var climb := camera.position.y - START_CAMERA_Y
		_foreground.position.y = FOREGROUND_CENTER.y - climb * 0.025
		var ascent := START_CAMERA_Y - camera.position.y
		_foreground.modulate.a = 1.0 - smoothstep(420.0, 760.0, ascent)


func _build_world_plates() -> void:
	var valley := Sprite2D.new()
	valley.texture = VALLEY
	valley.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	valley.position = LOWER_CENTER
	valley.z_index = -100
	add_child(valley)
	_plates.append(valley)

	var seam_shader := Shader.new()
	seam_shader.code = """
shader_type canvas_item;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float fade = 1.0 - smoothstep(0.84, 1.0, UV.y);
	COLOR = vec4(tex.rgb, tex.a * fade);
}
"""
	var seam_material := ShaderMaterial.new()
	seam_material.shader = seam_shader
	var sky := Sprite2D.new()
	sky.texture = SKY_TEMPLE
	sky.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sky.material = seam_material
	sky.position = UPPER_CENTER
	sky.z_index = -99
	add_child(sky)
	_plates.append(sky)


func _build_foreground() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D art : source_color, filter_linear;
void vertex() {
	float canopy = pow(1.0 - UV.y, 2.4);
	float breath = sin(TIME * 0.72 + UV.y * 3.0) * 1.8;
	float leaves = sin(TIME * 1.35 + UV.x * 8.0) * 0.8;
	VERTEX.x += (breath + leaves) * canopy;
	VERTEX.y += cos(TIME * 0.58 + UV.x * 4.0) * canopy * 0.7;
}
void fragment() {
	COLOR = texture(art, UV);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("art", FOREGROUND)
	_foreground = MeshInstance2D.new()
	_foreground.mesh = _grid_mesh(FOREGROUND, 18, 24)
	_foreground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_foreground.material = material
	_foreground.position = FOREGROUND_CENTER
	_foreground.z_index = -72
	add_child(_foreground)


func _build_petals() -> void:
	var petals := CPUParticles2D.new()
	petals.position = Vector2(360.0, 350.0)
	petals.amount = 18
	petals.lifetime = 7.0
	petals.randomness = 0.8
	petals.direction = Vector2(-0.55, 1.0)
	petals.spread = 28.0
	petals.gravity = Vector2(8.0, 14.0)
	petals.initial_velocity_min = 8.0
	petals.initial_velocity_max = 20.0
	petals.scale_amount_min = 1.6
	petals.scale_amount_max = 3.2
	petals.color = Color(1.0, 0.62, 0.72, 0.72)
	petals.z_index = -68
	add_child(petals)


func _grid_mesh(texture: Texture2D, cols: int, rows: int) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var size := Vector2(texture.get_width(), texture.get_height())
	for row in range(rows + 1):
		for col in range(cols + 1):
			var uv := Vector2(float(col) / cols, float(row) / rows)
			vertices.append((uv - Vector2(0.5, 0.5)) * size)
			uvs.append(uv)
	for row in range(rows):
		for col in range(cols):
			var a := row * (cols + 1) + col
			var b := a + 1
			var c := a + cols + 2
			var d := a + cols + 1
			indices.append_array(PackedInt32Array([a, b, c, a, c, d]))
	var arrays: Array = []
	arrays.resize(ArrayMesh.ARRAY_MAX)
	arrays[ArrayMesh.ARRAY_VERTEX] = vertices
	arrays[ArrayMesh.ARRAY_TEX_UV] = uvs
	arrays[ArrayMesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
