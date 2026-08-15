extends Node2D

const BASE_W := 720.0
const FAR_LOWER_CENTER := Vector2(360.0, 409.0)
const FAR_UPPER_CENTER := Vector2(360.0, -743.0)
const MID_CENTER := Vector2(360.0, 458.0)
const NEAR_CENTER := Vector2(360.0, 457.0)
const ATMOSPHERE_CENTER := Vector2(360.0, 432.0)

const FAR := preload("res://assets/skins/zen/diorama/valley_far.png")
const MID := preload("res://assets/skins/zen/diorama/valley_mid.png")
const SKY_TEMPLE := preload("res://assets/skins/zen/diorama/sky_temple.png")
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
	var lower := _sprite(FAR, FAR_LOWER_CENTER)
	parent.add_child(lower)
	_scalable.append(lower)

	var seam_shader := Shader.new()
	seam_shader.code = """
shader_type canvas_item;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float fade = 1.0 - smoothstep(0.94, 1.0, UV.y);
	COLOR = vec4(tex.rgb, tex.a * fade);
}
"""
	var seam_material := ShaderMaterial.new()
	seam_material.shader = seam_shader
	var upper := _sprite(SKY_TEMPLE, FAR_UPPER_CENTER)
	upper.material = seam_material
	parent.add_child(upper)
	_scalable.append(upper)


func _build_mid(parent: Node) -> void:
	var mid := _sprite(MID, MID_CENTER)
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
	COLOR = texture(art, UV);
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
	parent.add_child(petals)


func _sprite(texture: Texture2D, at: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = at
	return sprite


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
