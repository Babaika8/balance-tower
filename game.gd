extends Node2D

# Balance Tower — игровое ядро (тема "Камни", стилизация "тёплый рассвет").
# Носитель-рука возит камень, по тапу роняет его на башню. Настоящая физика:
# кривая укладка кренит башню, сильный перекос её роняет.

const SCREEN_W := 720.0
const SCREEN_H := 1280.0
const STONE_SIZE := Vector2(170, 56)
const CARRIER_GAP := 280.0      # на сколько выше вершины висит носитель
const MARGIN := 90.0            # границы движения носителя по горизонтали
const CARRIER_SPEED := 330.0    # скорость носителя, px/сек
const SETTLE_SPEED := 18.0      # ниже этой скорости камень считается улёгшимся
const SETTLE_HOLD := 0.4        # сколько секунд держать низкую скорость
const MISS_LIMIT := 220.0       # текущий камень упал ниже вершины => промах
const COLLAPSE_DROP := 140.0    # уложенный камень сполз вниз => башня рушится

enum State { WAITING, DROPPING, GAME_OVER }

var state: int = State.WAITING
var score: int = 0
var top_y: float = 0.0          # y верхней грани башни (меньше = выше)
var ground_top_y: float = 0.0   # вершина постамента, для рестарта
var base_x: float = SCREEN_W / 2.0

var carrier: Node2D = null
var carrier_dir: float = 1.0
var current_stone: RigidBody2D = null
var stones: Array[RigidBody2D] = []
var settle_timer: float = 0.0

var camera: Camera2D
var score_label: Label
var msg_label: Label
var dust: CPUParticles2D

func _ready() -> void:
	randomize()
	_setup_background()
	_setup_camera()
	_setup_ui()
	_setup_pedestal()
	_setup_dust()
	camera.position.y = top_y - 150.0
	_spawn_carrier()

# ---------- Сцена / окружение ----------

func _setup_background() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)

	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([
		Color("F8D9A0"), Color("F2B97E"), Color("E89B79"),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = int(SCREEN_W)
	tex.height = int(SCREEN_H)
	var sky := TextureRect.new()
	sky.texture = tex
	sky.position = Vector2.ZERO
	sky.size = Vector2(SCREEN_W, SCREEN_H)
	layer.add_child(sky)

	# Солнце с мягким ореолом.
	var halo := Polygon2D.new()
	halo.polygon = _circle_polygon(150.0, 28)
	halo.color = Color(0.99, 0.93, 0.81, 0.35)
	halo.position = Vector2(520, 200)
	layer.add_child(halo)
	var sun := Polygon2D.new()
	sun.polygon = _circle_polygon(70.0, 28)
	sun.color = Color("FCEBCF")
	sun.position = Vector2(520, 200)
	layer.add_child(sun)

	# Дальние холмы.
	var hills := Polygon2D.new()
	hills.polygon = PackedVector2Array([
		Vector2(0, 820), Vector2(180, 770), Vector2(380, 805),
		Vector2(560, 760), Vector2(SCREEN_W, 800),
		Vector2(SCREEN_W, SCREEN_H), Vector2(0, SCREEN_H),
	])
	hills.color = Color(0.79, 0.55, 0.42, 0.45)
	layer.add_child(hills)

func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.position = Vector2(base_x, 0)
	add_child(camera)
	camera.make_current()

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	score_label = Label.new()
	score_label.position = Vector2(30, 30)
	score_label.add_theme_font_size_override("font_size", 48)
	score_label.add_theme_color_override("font_color", Color("4A3326"))
	layer.add_child(score_label)
	msg_label = Label.new()
	msg_label.position = Vector2(0, 460)
	msg_label.size = Vector2(SCREEN_W, 300)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.add_theme_font_size_override("font_size", 44)
	msg_label.add_theme_color_override("font_color", Color("7A2218"))
	msg_label.visible = false
	layer.add_child(msg_label)
	_update_score()

func _setup_pedestal() -> void:
	var pedestal_y := 1000.0
	var ped := StaticBody2D.new()
	ped.position = Vector2(base_x, pedestal_y)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(STONE_SIZE.x, 60.0)
	shape.shape = rect
	ped.add_child(shape)
	# Тень под башней (в мире, у земли).
	var shadow := Polygon2D.new()
	shadow.polygon = _ellipse_polygon(STONE_SIZE.x * 0.62, 16.0, 24)
	shadow.color = Color(0.32, 0.2, 0.14, 0.22)
	shadow.position = Vector2(0, 36)
	ped.add_child(shadow)
	_add_rock_visual(ped, Vector2(STONE_SIZE.x, 60.0), Color("6E635C"))
	add_child(ped)
	ground_top_y = pedestal_y - 30.0
	top_y = ground_top_y

func _setup_dust() -> void:
	dust = CPUParticles2D.new()
	dust.emitting = false
	dust.one_shot = true
	dust.explosiveness = 0.9
	dust.amount = 16
	dust.lifetime = 0.7
	dust.direction = Vector2(0, -1)
	dust.spread = 75.0
	dust.initial_velocity_min = 40.0
	dust.initial_velocity_max = 130.0
	dust.gravity = Vector2(0, 320)
	dust.scale_amount_min = 2.0
	dust.scale_amount_max = 4.5
	dust.color = Color(0.83, 0.69, 0.52, 0.85)
	add_child(dust)

# ---------- Игровой цикл ----------

func _spawn_carrier() -> void:
	carrier = Node2D.new()
	carrier.position = Vector2(MARGIN, top_y - CARRIER_GAP)
	var color := _stone_color()
	carrier.set_meta("stone_color", color)
	_add_hand(carrier, STONE_SIZE)
	_add_rock_visual(carrier, STONE_SIZE, color)
	add_child(carrier)
	carrier_dir = 1.0
	state = State.WAITING

func _process(delta: float) -> void:
	if state == State.WAITING and carrier:
		var x := carrier.position.x + carrier_dir * CARRIER_SPEED * delta
		if x > SCREEN_W - MARGIN:
			x = SCREEN_W - MARGIN
			carrier_dir = -1.0
		elif x < MARGIN:
			x = MARGIN
			carrier_dir = 1.0
		carrier.position.x = x
	if camera:
		var target_y := top_y - 150.0
		camera.position.y = lerp(camera.position.y, target_y, clamp(delta * 3.0, 0.0, 1.0))

func _physics_process(delta: float) -> void:
	if state == State.GAME_OVER:
		return
	for s in stones:
		if not is_instance_valid(s) or s == current_stone:
			continue
		if s.has_meta("rest_y") and s.global_position.y > float(s.get_meta("rest_y")) + COLLAPSE_DROP:
			_game_over()
			return
	if state == State.DROPPING and is_instance_valid(current_stone):
		if current_stone.global_position.y > top_y + MISS_LIMIT:
			_game_over()
			return
		if current_stone.linear_velocity.length() < SETTLE_SPEED:
			settle_timer += delta
			if settle_timer > SETTLE_HOLD:
				_on_settled()
		else:
			settle_timer = 0.0

func _unhandled_input(event: InputEvent) -> void:
	var act := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		act = true
	elif event is InputEventScreenTouch and event.pressed:
		act = true
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		act = true
	if not act:
		return
	if state == State.WAITING:
		_drop()
	elif state == State.GAME_OVER:
		_restart()

func _drop() -> void:
	var color: Color = carrier.get_meta("stone_color")
	var stone := RigidBody2D.new()
	stone.position = carrier.position
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = STONE_SIZE
	shape.shape = rect
	stone.add_child(shape)
	_add_rock_visual(stone, STONE_SIZE, color)
	var mat := PhysicsMaterial.new()
	mat.friction = 0.9
	mat.bounce = 0.0
	stone.physics_material_override = mat
	stone.mass = 1.0
	stone.linear_damp = 0.3
	stone.angular_damp = 0.4
	add_child(stone)
	stones.append(stone)
	current_stone = stone
	carrier.queue_free()
	carrier = null
	state = State.DROPPING
	settle_timer = 0.0

func _on_settled() -> void:
	var st := current_stone
	st.set_meta("rest_y", st.global_position.y)
	_puff(Vector2(st.global_position.x, st.global_position.y + STONE_SIZE.y / 2.0))
	var new_top := st.global_position.y - STONE_SIZE.y / 2.0
	if new_top < top_y:
		top_y = new_top
	score += 1
	_update_score()
	current_stone = null
	_spawn_carrier()

func _game_over() -> void:
	state = State.GAME_OVER
	if is_instance_valid(current_stone):
		_puff(current_stone.global_position)
	msg_label.text = "Башня упала!\nВысота: %d\n\nТап — заново" % score
	msg_label.visible = true

func _restart() -> void:
	for s in stones:
		if is_instance_valid(s):
			s.queue_free()
	stones.clear()
	if carrier:
		carrier.queue_free()
		carrier = null
	current_stone = null
	score = 0
	top_y = ground_top_y
	msg_label.visible = false
	_update_score()
	camera.position.y = top_y - 150.0
	_spawn_carrier()

func _update_score() -> void:
	score_label.text = "Высота: %d" % score

func _puff(at: Vector2) -> void:
	dust.global_position = at
	dust.restart()
	dust.emitting = true

# ---------- Рисование (заглушки векторной графикой) ----------

func _add_rock_visual(parent: Node, size: Vector2, base: Color) -> void:
	var poly := _rock_polygon(size)
	var p := Polygon2D.new()
	p.polygon = poly
	var top := base.lightened(0.18)
	var bot := base.darkened(0.28)
	var cols := PackedColorArray()
	for v in poly:
		var t: float = clamp(v.y / size.y + 0.5, 0.0, 1.0)
		cols.append(top.lerp(bot, t))
	p.vertex_colors = cols
	parent.add_child(p)

func _add_hand(parent: Node, size: Vector2) -> void:
	var skin := Color("E8C49C")
	var skin_d := Color("D8B488")
	var wrist := Polygon2D.new()
	wrist.polygon = _rect_polygon(Vector2(54, 20))
	wrist.color = skin_d
	wrist.position = Vector2(-size.x * 0.5 - 36, size.y * 0.45)
	parent.add_child(wrist)
	var palm := Polygon2D.new()
	palm.polygon = _ellipse_polygon(34, 22, 18)
	palm.color = skin
	palm.position = Vector2(-size.x * 0.5 + 2, size.y * 0.45)
	parent.add_child(palm)

func _rock_polygon(size: Vector2) -> PackedVector2Array:
	var hw := size.x / 2.0
	var hh := size.y / 2.0
	var c := minf(hw, hh) * 0.45    # срез углов под валун
	var j := minf(hw, hh) * 0.12    # лёгкая неровность
	return PackedVector2Array([
		Vector2(-hw + c + randf_range(-j, j), -hh),
		Vector2(hw - c + randf_range(-j, j), -hh),
		Vector2(hw, -hh + c + randf_range(-j, j)),
		Vector2(hw, hh - c + randf_range(-j, j)),
		Vector2(hw - c + randf_range(-j, j), hh),
		Vector2(-hw + c + randf_range(-j, j), hh),
		Vector2(-hw, hh - c + randf_range(-j, j)),
		Vector2(-hw, -hh + c + randf_range(-j, j)),
	])

func _circle_polygon(r: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	return pts

func _ellipse_polygon(rx: float, ry: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _stone_color() -> Color:
	var tones := [
		Color("9A8F86"), Color("8C8178"), Color("A79B8E"), Color("7E736B"),
	]
	return tones[randi() % tones.size()]

func _rect_polygon(size: Vector2) -> PackedVector2Array:
	var hw := size.x / 2.0
	var hh := size.y / 2.0
	return PackedVector2Array([
		Vector2(-hw, -hh),
		Vector2(hw, -hh),
		Vector2(hw, hh),
		Vector2(-hw, hh),
	])
