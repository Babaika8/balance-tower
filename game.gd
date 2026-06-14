extends Node2D

# Balance Tower — игровое ядро (тема "Камни", прототип на заглушках).
# Носитель ездит влево-вправо, по тапу роняет камень. Настоящая физика:
# кривая укладка кренит башню, а сильный перекос её роняет.

const SCREEN_W := 720.0
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

func _ready() -> void:
	randomize()
	_setup_camera()
	_setup_ui()
	_setup_pedestal()
	camera.position.y = top_y - 150.0
	_spawn_carrier()

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
	score_label.add_theme_color_override("font_color", Color(0.18, 0.3, 0.27))
	layer.add_child(score_label)
	msg_label = Label.new()
	msg_label.position = Vector2(0, 460)
	msg_label.size = Vector2(SCREEN_W, 300)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.add_theme_font_size_override("font_size", 44)
	msg_label.add_theme_color_override("font_color", Color(0.5, 0.15, 0.15))
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
	var vis := Polygon2D.new()
	vis.polygon = _rect_polygon(Vector2(STONE_SIZE.x, 60.0))
	vis.color = Color(0.25, 0.25, 0.28)
	ped.add_child(vis)
	add_child(ped)
	ground_top_y = pedestal_y - 30.0
	top_y = ground_top_y

func _spawn_carrier() -> void:
	carrier = Node2D.new()
	carrier.position = Vector2(MARGIN, top_y - CARRIER_GAP)
	var prev := Polygon2D.new()
	prev.polygon = _rect_polygon(STONE_SIZE)
	prev.color = _stone_color()
	carrier.add_child(prev)
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
	var stone := RigidBody2D.new()
	stone.position = carrier.position
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = STONE_SIZE
	shape.shape = rect
	stone.add_child(shape)
	var vis := Polygon2D.new()
	vis.polygon = _rect_polygon(STONE_SIZE)
	vis.color = (carrier.get_child(0) as Polygon2D).color
	stone.add_child(vis)
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
	var new_top := st.global_position.y - STONE_SIZE.y / 2.0
	if new_top < top_y:
		top_y = new_top
	score += 1
	_update_score()
	current_stone = null
	_spawn_carrier()

func _game_over() -> void:
	state = State.GAME_OVER
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

func _stone_color() -> Color:
	var grays := [
		Color(0.45, 0.45, 0.48),
		Color(0.55, 0.55, 0.58),
		Color(0.38, 0.38, 0.42),
		Color(0.6, 0.58, 0.55),
	]
	return grays[randi() % grays.size()]

func _rect_polygon(size: Vector2) -> PackedVector2Array:
	var hw := size.x / 2.0
	var hh := size.y / 2.0
	return PackedVector2Array([
		Vector2(-hw, -hh),
		Vector2(hw, -hh),
		Vector2(hw, hh),
		Vector2(-hw, hh),
	])
