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

var _scalable: Array[CanvasItem] = []


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
	var sky_shader := Shader.new()
	sky_shader.code = """
shader_type canvas_item;
uniform sampler2D art : source_color, filter_linear;
uniform float seam_top = 0.0;
uniform float seam_bottom = 1.0;
void fragment() {
	vec4 base = texture(art, UV);
	float pale = smoothstep(0.58, 0.92, dot(base.rgb, vec3(0.299, 0.587, 0.114)));
	float blue = smoothstep(0.02, 0.24, base.b - base.r * 0.72);
	float cloud = pale * (1.0 - blue);
	vec2 drift_uv = UV + vec2(sin(TIME * 0.055 + UV.y * 5.0) * 0.0025, cos(TIME * 0.04 + UV.x * 4.0) * 0.0015);
	vec4 moving = texture(art, drift_uv);
	vec4 color = mix(base, moving, cloud * 0.42);
	float top_fade = smoothstep(0.0, 0.16, UV.y + seam_top);
	float bottom_fade = 1.0 - smoothstep(seam_bottom - 0.16, seam_bottom, UV.y);
	COLOR = vec4(color.rgb, color.a * top_fade * bottom_fade);
}
"""
	var lower_material := ShaderMaterial.new()
	lower_material.shader = sky_shader
	lower_material.set_shader_parameter("art", FAR)
	var lower := _mesh_sprite(FAR, FAR_LOWER_CENTER, lower_material)
	parent.add_child(lower)
	_scalable.append(lower)

	var upper_material := ShaderMaterial.new()
	upper_material.shader = sky_shader
	upper_material.set_shader_parameter("art", SKY_TEMPLE)
	upper_material.set_shader_parameter("seam_bottom", 0.96)
	var upper := _mesh_sprite(SKY_TEMPLE, FAR_UPPER_CENTER, upper_material)
	parent.add_child(upper)
	_scalable.append(upper)

	var high_material := ShaderMaterial.new()
	high_material.shader = sky_shader
	high_material.set_shader_parameter("art", HIGH_MOUNTAINS)
	var high := _mesh_sprite(HIGH_MOUNTAINS, FAR_HIGH_CENTER, high_material)
	parent.add_child(high)
	_scalable.append(high)

	var sky_material := ShaderMaterial.new()
	sky_material.shader = sky_shader
	sky_material.set_shader_parameter("art", HIGH_SKY)
	var final_sky := _mesh_sprite(HIGH_SKY, FAR_SKY_CENTER, sky_material)
	parent.add_child(final_sky)
	_scalable.append(final_sky)

	var zenith_material := ShaderMaterial.new()
	zenith_material.shader = sky_shader
	zenith_material.set_shader_parameter("art", ZENITH)
	zenith_material.set_shader_parameter("seam_bottom", 1.04)
	var zenith := _mesh_sprite(ZENITH, FAR_ZENITH_CENTER, zenith_material)
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
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D art : source_color, filter_linear;
void fragment() {
	vec4 base = texture(art, UV);
	float cyan = smoothstep(0.05, 0.26, base.g - base.r * 0.72) * smoothstep(0.18, 0.55, base.b);
	float foam = smoothstep(0.62, 0.92, dot(base.rgb, vec3(0.299, 0.587, 0.114))) * cyan;
	vec2 water_uv = UV + vec2(sin(UV.y * 95.0 + TIME * 1.7) * 0.0024, -fract(TIME * 0.028) * 0.018);
	vec4 flowing = texture(art, water_uv);
	vec3 water = mix(base.rgb, flowing.rgb, cyan * 0.68);
	water += vec3(0.08, 0.11, 0.12) * foam * (0.5 + 0.5 * sin(UV.y * 140.0 - TIME * 3.2));
	COLOR = vec4(water, base.a);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("art", MID)
	var mid := _mesh_sprite(MID, MID_CENTER, material)
	parent.add_child(mid)
	_scalable.append(mid)


func _build_near(parent: Node) -> void:
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
	vec4 color = texture(art, UV);
	float edge_fade = smoothstep(0.0, 0.16, UV.y);
	COLOR = vec4(color.rgb, color.a * edge_fade);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("art", NEAR)
	var near := MeshInstance2D.new()
	near.mesh = _grid_mesh(NEAR, 18, 24)
	near.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	near.material = material
	near.position = NEAR_CENTER
	parent.add_child(near)
	_scalable.append(near)


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


func _mesh_sprite(texture: Texture2D, at: Vector2, material: Material) -> MeshInstance2D:
	var mesh_sprite := MeshInstance2D.new()
	mesh_sprite.mesh = _grid_mesh(texture, 12, 18)
	mesh_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mesh_sprite.material = material
	mesh_sprite.position = at
	return mesh_sprite


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
