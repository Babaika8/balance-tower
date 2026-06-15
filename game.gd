extends Node2D

# Balance Tower — игровое ядро (тема "Камни", стилизация "тёплый рассвет").
# Рука держит камень сверху и по тапу отпускает его на башню. Настоящая физика:
# кривая укладка кренит башню, сильный перекос её роняет. Следующий камень
# появляется сразу при касании — не ждём, пока башня перестанет качаться.

var ssize: Vector2 = Vector2(180, 56)
const CARRIER_GAP := 175.0      # на сколько выше вершины висит рука с камнем
const MARGIN := 90.0            # отступ движения руки от краёв базовой ширины
const CARRIER_SPEED := 330.0    # скорость руки, px/сек
const DROP_PUSH := 260.0        # начальный толчок камня вниз (снаппи бросок)
const MISS_LIMIT := 230.0       # летящий камень провалился ниже вершины => промах
const COLLAPSE_DROP := 150.0    # уложенный камень просел => башня рушится
const COLLAPSE_ANGLE := 0.85    # уложенный камень накренился (~49°) => рушится

const BASE_W := 720.0
const BASE_H := 1280.0

enum State { WAITING, DROPPING, GAME_OVER }

var state: int = State.WAITING
var score: int = 0
var top_y: float = 0.0          # y верхней грани башни (меньше = выше)
var ground_top_y: float = 0.0   # вершина постамента, для рестарта
var base_x: float = BASE_W / 2.0

var carrier: Node2D = null
var carrier_dir: float = 1.0
var current_stone: RigidBody2D = null
var stones: Array[RigidBody2D] = []
var loading_lb: bool = false
var last_action_ms: int = 0
var theme: Dictionary = {}

var camera: Camera2D
var score_label: Label
var msg_label: Label
var dust: CPUParticles2D

func _ready() -> void:
	randomize()
	_load_theme()
	_setup_background()
	_setup_camera()
	_setup_ui()
	_setup_pedestal()
	_setup_dust()
	camera.position.y = top_y - 150.0
	_spawn_carrier()
	if OS.get_environment("BT_SHOT") != "":
		_auto_shot()

func _auto_shot() -> void:
	if OS.get_environment("BT_SHOT") == "hold":
		# Снимок без бросков: видно, как рука держит камень. Останавливаем носитель.
		await get_tree().process_frame
		carrier_dir = 0.0
		if carrier:
			carrier.position.x = base_x
		await get_tree().create_timer(0.5).timeout
		var im0 := get_viewport().get_texture().get_image()
		im0.save_png("/tmp/bt_shot.png")
		get_tree().quit()
		return
	await get_tree().create_timer(0.5).timeout
	for i in range(5):
		var tries := 0
		while tries < 200 and (carrier == null or state != State.WAITING
				or absf(carrier.position.x - base_x) > 8.0):
			await get_tree().process_frame
			tries += 1
		if state == State.WAITING and carrier:
			_drop()
		await get_tree().create_timer(0.9).timeout
	await get_tree().create_timer(0.6).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/bt_shot.png")
	get_tree().quit()

# ---------- Сцена / окружение ----------

func _setup_background() -> void:
	# Высокий фон-картинка живёт в мире и едет вниз, пока камера поднимается.
	var bg_tex: Texture2D = theme.get("background")
	if bg_tex:
		var bg := Sprite2D.new()
		bg.texture = bg_tex
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bg.z_index = -100
		var s := BASE_W / float(bg_tex.get_width())
		bg.scale = Vector2(s, s)
		var bg_h := bg_tex.get_height() * s
		# Низ фона — у нижней кромки стартового вида; вверх уходит небо.
		var bottom_y := 1500.0
		bg.position = Vector2(base_x, bottom_y - bg_h / 2.0)
		add_child(bg)
		# Цвет очистки = верхний пиксель фона (если башня перерастёт картинку).
		RenderingServer.set_default_clear_color(_top_color(bg_tex))
		return

	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)

	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color("F8D9A0"), Color("F2B97E"), Color("E89B79")])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = int(BASE_W)
	tex.height = int(BASE_H)
	var sky := TextureRect.new()
	sky.texture = tex
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(sky)

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

	var hills := Polygon2D.new()
	hills.polygon = PackedVector2Array([
		Vector2(-80, 820), Vector2(180, 770), Vector2(380, 805),
		Vector2(560, 760), Vector2(BASE_W + 80, 800),
		Vector2(BASE_W + 80, BASE_H + 80), Vector2(-80, BASE_H + 80),
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
	msg_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg_label.add_theme_font_size_override("font_size", 30)
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
	rect.size = Vector2(ssize.x, 60.0)
	shape.shape = rect
	ped.add_child(shape)
	var ped_tex: Texture2D = theme.get("pedestal")
	var stones_arr: Array = theme.get("stones", [])
	if ped_tex:
		ped.add_child(_sprite_scaled_to_width(ped_tex, ssize.x))
	elif stones_arr.size() > 0:
		# Нет отдельного постамента — кладём камень как основание.
		ped.add_child(_sprite_scaled_to_width(stones_arr[0], ssize.x))
	else:
		var shadow := Polygon2D.new()
		shadow.polygon = _ellipse_polygon(ssize.x * 0.72, 18.0, 24)
		shadow.color = Color(0.3, 0.18, 0.12, 0.32)
		shadow.position = Vector2(0, 40)
		ped.add_child(shadow)
		ped.add_child(_make_rock(Vector2(ssize.x, 60.0), Color("6E635C")))
	add_child(ped)
	ground_top_y = pedestal_y - 30.0
	top_y = ground_top_y

func _setup_dust() -> void:
	dust = CPUParticles2D.new()
	dust.emitting = false
	dust.one_shot = true
	dust.explosiveness = 1.0
	dust.amount = 24
	dust.lifetime = 0.8
	dust.direction = Vector2(0, -1)
	dust.spread = 80.0
	dust.initial_velocity_min = 60.0
	dust.initial_velocity_max = 190.0
	dust.gravity = Vector2(0, 340)
	dust.scale_amount_min = 3.0
	dust.scale_amount_max = 7.0
	dust.color = Color(0.86, 0.72, 0.55, 0.9)
	add_child(dust)

# ---------- Игровой цикл ----------

func _spawn_carrier() -> void:
	carrier = Node2D.new()
	carrier.position = Vector2(MARGIN, top_y - CARRIER_GAP)
	var color := _stone_color()
	var idx := _pick_stone()
	carrier.set_meta("stone_color", color)
	carrier.set_meta("stone_idx", idx)
	var rock := _stone_visual(ssize, color, idx)
	carrier.add_child(rock)
	carrier.set_meta("rock_node", rock)
	_add_hand_top(carrier, ssize)
	add_child(carrier)
	carrier_dir = 1.0
	state = State.WAITING

func _process(delta: float) -> void:
	if loading_lb:
		_poll_leaderboard()
	if state == State.WAITING and carrier:
		var x := carrier.position.x + carrier_dir * CARRIER_SPEED * delta
		if x > BASE_W - MARGIN:
			x = BASE_W - MARGIN
			carrier_dir = -1.0
		elif x < MARGIN:
			x = MARGIN
			carrier_dir = 1.0
		carrier.position.x = x
	if camera:
		var target_y := top_y - 150.0
		camera.position.y = lerp(camera.position.y, target_y, clamp(delta * 3.0, 0.0, 1.0))

func _physics_process(_delta: float) -> void:
	if state == State.GAME_OVER:
		return
	# Промах: летящий камень провалился мимо башни.
	if is_instance_valid(current_stone) and not current_stone.get_meta("placed", false):
		if current_stone.global_position.y > top_y + MISS_LIMIT:
			_game_over(current_stone.global_position)
			return
	# Обвал: уложенный камень накренился или сильно просел.
	for s in stones:
		if not is_instance_valid(s) or not s.get_meta("placed", false):
			continue
		var miny: float = s.get_meta("min_y")
		if s.global_position.y < miny:
			s.set_meta("min_y", s.global_position.y)
			miny = s.global_position.y
		if absf(s.rotation) > COLLAPSE_ANGLE or s.global_position.y > miny + COLLAPSE_DROP:
			_game_over(s.global_position)
			return

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
	# Защита от двойного срабатывания (тач + эмулированный клик на одном тапе).
	var now := Time.get_ticks_msec()
	if now - last_action_ms < 200:
		return
	last_action_ms = now
	if state == State.WAITING and carrier:
		_drop()
	elif state == State.GAME_OVER:
		_restart()

func _drop() -> void:
	var color: Color = carrier.get_meta("stone_color")
	var idx: int = carrier.get_meta("stone_idx")
	var drop_pos: Vector2 = carrier.position
	_animate_release(carrier)
	carrier = null
	state = State.DROPPING

	var stone := RigidBody2D.new()
	stone.position = drop_pos
	stone.linear_velocity = Vector2(0, DROP_PUSH)
	stone.contact_monitor = true
	stone.max_contacts_reported = 4
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = ssize
	shape.shape = rect
	stone.add_child(shape)
	stone.add_child(_stone_visual(ssize, color, idx))
	var mat := PhysicsMaterial.new()
	mat.friction = 0.9
	mat.bounce = 0.0
	stone.physics_material_override = mat
	stone.mass = 1.0
	stone.linear_damp = 0.3
	stone.angular_damp = 0.4
	stone.set_meta("placed", false)
	stone.body_entered.connect(_on_stone_contact.bind(stone))
	add_child(stone)
	stones.append(stone)
	current_stone = stone

func _on_stone_contact(_body: Node, stone: RigidBody2D) -> void:
	if state == State.GAME_OVER:
		return
	if stone.get_meta("placed", false):
		return
	stone.set_meta("placed", true)
	stone.set_meta("min_y", stone.global_position.y)
	var new_top := stone.global_position.y - ssize.y / 2.0
	if new_top < top_y:
		top_y = new_top
	score += 1
	_update_score()
	_puff(Vector2(stone.global_position.x, stone.global_position.y + ssize.y / 2.0))
	if stone == current_stone:
		current_stone = null
	# Рука появляется сразу — даже пока башня ещё качается.
	_spawn_carrier()

func _game_over(at: Vector2) -> void:
	state = State.GAME_OVER
	_puff(at)
	if carrier:
		carrier.queue_free()
		carrier = null
	msg_label.text = _gameover_text("")
	msg_label.visible = true
	# Веб (Telegram): отправить счёт и подтянуть топ-10.
	if OS.has_feature("web"):
		msg_label.text = "Башня упала!\nВысота: %d\n\nЗагружаю рекорды…" % score
		JavaScriptBridge.eval("window.BT_finish && window.BT_finish(%d)" % score, true)
		loading_lb = true

func _gameover_text(board: String) -> String:
	var t := "Башня упала!\nВысота: %d\n" % score
	if board != "":
		t += "\n🏆 Топ:\n" + board
	t += "\nТап — заново"
	return t

# Опрос результата лидерборда из JS (window.BT_lb заполняется асинхронно).
func _poll_leaderboard() -> void:
	var r = JavaScriptBridge.eval("window.BT_lb", true)
	if typeof(r) != TYPE_STRING or r == "":
		return
	loading_lb = false
	var board := ""
	var arr = JSON.parse_string(r)
	if arr is Array:
		var i := 1
		for e in arr:
			if e is Dictionary:
				board += "%d. %s — %d\n" % [i, str(e.get("username", "?")), int(e.get("best_score", 0))]
				i += 1
	msg_label.text = _gameover_text(board)

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
	loading_lb = false
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

func _animate_release(c: Node2D) -> void:
	var rock = c.get_meta("rock_node")
	if is_instance_valid(rock):
		rock.queue_free()
	# Кадр «отпустил» (вторая картинка руки).
	var hand_rel: Texture2D = theme.get("hand_release")
	if hand_rel and c.has_meta("hand_node"):
		var hn = c.get_meta("hand_node")
		if is_instance_valid(hn):
			hn.texture = hand_rel
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(c, "position:y", c.position.y - 70.0, 0.22)
	tw.tween_property(c, "modulate:a", 0.0, 0.22)
	tw.set_parallel(false)
	tw.tween_callback(c.queue_free)

# ---------- Рисование (заглушки векторной графикой) ----------

# --- Тема/скин: подхватывает картинки из res://assets/zen/, если они есть ---

const THEME_DIR := "res://assets/zen/"

func _load_theme() -> void:
	theme = {
		"stones": [],
		"hand": _tex(THEME_DIR + "hand1.png"),       # кадр «держит»
		"hand_release": _tex(THEME_DIR + "hand2.png"),  # кадр «отпустил»
		"background": _tex(THEME_DIR + "background.png"),
		"pedestal": _tex(THEME_DIR + "pedestal.png"),
	}
	if theme["hand"] == null:
		theme["hand"] = _tex(THEME_DIR + "hand.png")
	for n in ["stone.png", "stone2.png", "stone3.png", "stone4.png"]:
		var t := _tex(THEME_DIR + n)
		if t:
			theme["stones"].append(t)
	# Подгоняем физическую коробку камня под пропорции арта (ширина 180).
	var arr: Array = theme["stones"]
	if arr.size() > 0:
		var t0: Texture2D = arr[0]
		ssize = Vector2(180.0, round(180.0 * t0.get_height() / float(t0.get_width())))

func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _top_color(tex: Texture2D) -> Color:
	var img := tex.get_image()
	if img:
		return img.get_pixel(int(img.get_width() / 2), 1)
	return Color(0.1, 0.08, 0.15)

func _pick_stone() -> int:
	var stones_arr: Array = theme.get("stones", [])
	if stones_arr.size() > 0:
		return randi() % stones_arr.size()
	return -1

# Возвращает узел камня: спрайт из текстуры темы, либо векторную заглушку.
func _stone_visual(size: Vector2, base: Color, idx: int) -> Node2D:
	var stones_arr: Array = theme.get("stones", [])
	if idx >= 0 and idx < stones_arr.size():
		return _sprite_scaled_to_width(stones_arr[idx], size.x)
	return _make_rock(size, base)

func _sprite_scaled_to_width(tex: Texture2D, target_w: float) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var s := target_w / float(maxi(1, tex.get_width()))
	sp.scale = Vector2(s, s)
	return sp

func _make_rock(size: Vector2, base: Color) -> Polygon2D:
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
	return p

func _add_hand_top(parent: Node, size: Vector2) -> void:
	var hand_tex: Texture2D = theme.get("hand")
	if hand_tex:
		var sp := _sprite_scaled_to_width(hand_tex, size.x * 1.9)
		var hand_h := hand_tex.get_height() * sp.scale.y
		# Точка хвата (между пальцами и большим) смещена от центра картинки —
		# сдвигаем спрайт так, чтобы хват пришёлся ровно на камень.
		sp.position = Vector2(10.0, -size.y / 2.0 - hand_h / 2.0 + 250.0)
		parent.add_child(sp)
		parent.set_meta("hand_node", sp)
		return

	var skin := Color("E8C49C")
	var skin_d := Color("D8B488")
	var hh := size.y / 2.0
	# Тыльная сторона ладони над камнем.
	var back := Polygon2D.new()
	back.polygon = _ellipse_polygon(46, 28, 20)
	back.color = skin
	back.position = Vector2(6, -hh - 30)
	parent.add_child(back)
	# Большой палец справа.
	var thumb := Polygon2D.new()
	thumb.polygon = _ellipse_polygon(12, 20, 14)
	thumb.color = skin_d
	thumb.position = Vector2(size.x * 0.42, -hh + 6)
	parent.add_child(thumb)
	# Пальцы, обхватывающие камень сверху.
	for x in [-size.x * 0.30, -size.x * 0.08, size.x * 0.14]:
		var f := Polygon2D.new()
		f.polygon = _ellipse_polygon(11, 18, 14)
		f.color = skin
		f.position = Vector2(x, -hh + 2)
		parent.add_child(f)

func _rock_polygon(size: Vector2) -> PackedVector2Array:
	var hw := size.x / 2.0
	var hh := size.y / 2.0
	var c := minf(hw, hh) * 0.45
	var j := minf(hw, hh) * 0.12
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
	var tones := [Color("9A8F86"), Color("8C8178"), Color("A79B8E"), Color("7E736B")]
	return tones[randi() % tones.size()]
