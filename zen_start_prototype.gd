extends Node2D

const BASE_W := 720.0
const BASE_H := 1280.0
const START_CAMERA_Y := 820.0

const BACKGROUND := preload("res://assets/skins/zen/prototype/start_clean.png")
const SAKURA := preload("res://assets/skins/zen/prototype/sakura_branch.png")
const WATERFALL := preload("res://assets/skins/zen/prototype/waterfall.png")

var _wind_strength := 0.0
var _wind_target := 0.0
var _next_gust_at := 0.0

var _sakura_material: ShaderMaterial
var _waterfall_material: ShaderMaterial
var _mist_material: ShaderMaterial
var _background: Sprite2D


func _ready() -> void:
	_build_background()
	_build_mist()
	_build_waterfall()
	_build_sakura()
	_next_gust_at = Time.get_ticks_msec() / 1000.0 + 1.5


func _process(delta: float) -> void:
	var viewport_width := get_viewport().get_visible_rect().size.x
	_background.scale = Vector2.ONE * maxf(1.0, viewport_width / BASE_W)
	var now := Time.get_ticks_msec() / 1000.0
	if now >= _next_gust_at:
		_wind_target = randf_range(0.55, 1.0) if _wind_target < 0.1 else 0.0
		_next_gust_at = now + (randf_range(1.4, 2.4) if _wind_target > 0.1 else randf_range(3.5, 6.0))
	_wind_strength = move_toward(_wind_strength, _wind_target, delta * 0.55)
	_sakura_material.set_shader_parameter("wind_strength", _wind_strength)


func _build_background() -> void:
	_background = Sprite2D.new()
	_background.texture = BACKGROUND
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_background.position = Vector2(BASE_W * 0.5, START_CAMERA_Y)
	_background.z_index = -100
	add_child(_background)


func _build_sakura() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float wind_strength = 0.0;
uniform sampler2D branch_texture : source_color, filter_nearest;

void vertex() {
	float free_end = pow(1.0 - UV.x, 2.2);
	float slow_wave = sin(TIME * 1.15 + UV.y * 2.8);
	float leaf_flutter = sin(TIME * 2.6 + UV.x * 8.0 + UV.y * 5.0);
	VERTEX.x += (slow_wave * 34.0 + leaf_flutter * 7.0) * free_end * wind_strength;
	VERTEX.y += cos(TIME * 0.85 + UV.x * 3.0) * 13.0 * free_end * wind_strength;
}

void fragment() {
	COLOR = texture(branch_texture, UV);
}
"""
	_sakura_material = ShaderMaterial.new()
	_sakura_material.shader = shader
	_sakura_material.set_shader_parameter("branch_texture", SAKURA)

	var branch := MeshInstance2D.new()
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var cols := 18
	var rows := 16
	var width := float(SAKURA.get_width())
	var height := float(SAKURA.get_height())
	for row in range(rows + 1):
		for col in range(cols + 1):
			var uv := Vector2(float(col) / cols, float(row) / rows)
			vertices.append(Vector2((uv.x - 0.5) * width, (uv.y - 0.5) * height))
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
	branch.mesh = mesh
	branch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	branch.material = _sakura_material
	branch.position = Vector2(718.0, 438.0)
	branch.scale = Vector2(0.27, 0.27)
	branch.modulate = Color(0.88, 0.82, 0.80, 0.88)
	branch.z_index = -78
	add_child(branch)


func _build_waterfall() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

void fragment() {
	vec2 uv = UV;
	float side_fade = smoothstep(0.0, 0.12, uv.x) * smoothstep(1.0, 0.88, uv.x);
	float flow = sin(uv.y * 92.0 - TIME * 8.0 + sin(uv.x * 18.0) * 1.8);
	float drift = sin(uv.y * 31.0 - TIME * 3.7) * 0.0025;
	vec4 tex = texture(TEXTURE, vec2(clamp(uv.x + drift, 0.0, 1.0), uv.y));
	vec3 highlight = vec3(0.10, 0.18, 0.22) * (0.5 + 0.5 * flow) * side_fade;
	COLOR = vec4(tex.rgb + highlight * tex.a, tex.a);
}
"""
	_waterfall_material = ShaderMaterial.new()
	_waterfall_material.shader = shader

	var waterfall := Sprite2D.new()
	waterfall.texture = WATERFALL
	waterfall.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	waterfall.material = _waterfall_material
	waterfall.position = Vector2(338.0, 692.0)
	waterfall.scale = Vector2(0.024, 0.082)
	waterfall.modulate = Color(0.78, 0.86, 0.92, 0.48)
	waterfall.z_index = -88
	add_child(waterfall)


func _build_mist() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * vec2(4.2, 2.0) + vec2(TIME * 0.018, 0.0);
	float n = noise(p) * 0.62 + noise(p * 2.1) * 0.38;
	float edge = smoothstep(0.0, 0.24, UV.y) * smoothstep(1.0, 0.70, UV.y);
	float alpha = smoothstep(0.47, 0.78, n) * edge * 0.13;
	COLOR = vec4(0.78, 0.86, 0.90, alpha);
}
"""
	_mist_material = ShaderMaterial.new()
	_mist_material.shader = shader

	var mist := Polygon2D.new()
	mist.polygon = PackedVector2Array([
		Vector2(-360.0, -105.0), Vector2(360.0, -105.0),
		Vector2(360.0, 105.0), Vector2(-360.0, 105.0),
	])
	mist.uv = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0),
		Vector2(1.0, 1.0), Vector2(0.0, 1.0),
	])
	mist.material = _mist_material
	mist.position = Vector2(BASE_W * 0.5, 350.0)
	mist.z_index = -90
	add_child(mist)
