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

# Параллакс-слои фона: каждый {node, art_w, art_h, drift, bottom_y, sway}.
# drift: 0 = закреплён в мире (едет быстрее всех), 1 = следует за камерой (почти неподвижен).
var bg_layers: Array = []
var start_cam_y: float = 0.0

# Атмосфера по высоте (режим без арта): меняющееся небо/солнце/звёзды/дюны/облака/сакуры.
# Фон экранно-закреплён, но центрируется по центру вьюпорта (как камера) и тянется
# на всю ширину — поэтому раскладку обновляем каждый кадр по реальному размеру экрана.
# Скины: 0 — «Дзен/луг» (атмосфера по высоте), 1 — «Diner» (блинчики в закусочной).
const SKIN_COUNT := 2
const SKIN_NAMES := ["Дзен", "Diner"]
var skin: int = 0
var skin_button: Button

# Diner-скин: экранно-закреплённый интерьер (адаптируется по vw/vh каждый кадр).
var diner_active: bool = false
var diner_floor: Node2D
var diner_counter: Node2D
var diner_window: Node2D
var diner_neon: Node2D
var diner_lamp: Node2D
var diner_clock: Node2D
var diner_menu: Node2D
var diner_stool: Node2D
var diner_steam: CPUParticles2D

var atmo_active: bool = false
var sky_grad: Gradient
var sun_node: Polygon2D
var halo_node: Polygon2D
var motes: CPUParticles2D
var petals: CPUParticles2D
var atmo_glow: Sprite2D
var atmo_fireflies: Array = []  # {node, nx, ny, phase}
var atmo_stars: Array = []   # {node, nx, ny}
var atmo_dunes: Array = []   # {node, base_y, factor, shade}
var atmo_clouds: Array = []  # {node, nx, speed, ny}
var atmo_birds: Array = []   # {node, nx, speed, ny}
var atmo_props: Array = []   # ёлочки/домики/сакуры: {node, nx, base_y, factor}

func _ready() -> void:
	randomize()
	_load_skin()
	_load_theme()
	_setup_background()
	_setup_camera()
	_setup_ui()
	_setup_pedestal()
	_setup_dust()
	camera.position.y = top_y - 150.0
	start_cam_y = camera.position.y
	_update_parallax()
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
		# Дебаг: BT_SCORE=N — выставить высоту для превью фазы атмосферы.
		if OS.get_environment("BT_SCORE") != "":
			score = int(OS.get_environment("BT_SCORE"))
			_atmo_p = float(score)
			_update_score()
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

# far/mid рисуются на широком канвасе и держат ФИКСИРОВАННЫЙ масштаб — горизонт
# стоит на месте при любом соотношении сторон (на широком экране открывается больше
# по бокам). Передний план — отдельные деревья, приклеенные к краям вьюпорта.
const SCENE_SCALE := 1.08
const NEAR_SCALE := 0.62
const FAR_ART_W := 2400.0   # ширина канваса дальнего слоя (для неба над ним)

func _setup_background() -> void:
	if skin == 1:
		_setup_diner()
		return
	# Оригинальная сцена (EPS-референс) как фон. Режим COVER сам адаптирует под любой
	# экран: на узком/портретном сужается по бокам, на широком показывает целиком.
	var scene: Texture2D = theme.get("scene")
	if scene:
		var slayer := CanvasLayer.new()
		slayer.layer = -10
		add_child(slayer)
		var srect := TextureRect.new()
		srect.texture = scene
		srect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		srect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slayer.add_child(srect)
		RenderingServer.set_default_clear_color(_top_color(scene))
		return

	var far: Texture2D = theme.get("far")
	var mid: Texture2D = theme.get("mid")
	var nl: Texture2D = theme.get("near_left")
	var nr: Texture2D = theme.get("near_right")
	if far and mid and nl and nr:
		# drift: 0.8 — дальний почти неподвижен; 0.08 — передний едет быстро.
		_add_bg_layer(far, -100, 0.80, 1346.0, "center", SCENE_SCALE, false)
		_add_bg_layer(mid, -90, 0.45, 1876.0, "center", SCENE_SCALE, false)
		_add_bg_layer(nl, -80, 0.08, 1560.0, "edge_left", NEAR_SCALE, true)
		_add_bg_layer(nr, -80, 0.08, 1560.0, "edge_right", NEAR_SCALE, true)
		RenderingServer.set_default_clear_color(_top_color(far))
		_add_sky_life()
		return

	# «Тёплый рассвет» + атмосфера по высоте: небо меняет цвет рассвет→день→закат→ночь
	# по мере роста башни, восходит/заходит солнце (→луна), проступают звёзды,
	# холмы едут с параллаксом. Всё кодом, экранно-закреплено (фон далёкий).
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)

	sky_grad = Gradient.new()
	sky_grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	sky_grad.colors = PackedColorArray([Color("F8D9A0"), Color("F2B97E"), Color("E89B79")])
	var tex := GradientTexture2D.new()
	tex.gradient = sky_grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 8
	tex.height = int(BASE_H)
	var sky := TextureRect.new()
	sky.texture = tex
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(sky)

	# Звёзды (видны ночью). Хранят нормированный x (0..1) — раскладка под ширину экрана.
	for i in range(30):
		var st := Polygon2D.new()
		st.polygon = _circle_polygon(randf_range(1.6, 3.2), 7)
		st.color = Color(1, 1, 1)
		layer.add_child(st)
		var d := randf_range(0.7, 1.7)
		var tw := st.create_tween().set_loops()
		tw.tween_property(st, "modulate:a", 0.25, d).set_trans(Tween.TRANS_SINE)
		tw.tween_property(st, "modulate:a", 1.0, d).set_trans(Tween.TRANS_SINE)
		atmo_stars.append({"node": st, "nx": randf(), "ny": randf_range(20, BASE_H * 0.55)})

	halo_node = Polygon2D.new()
	halo_node.polygon = _circle_polygon(150.0, 28)
	halo_node.color = Color(0.99, 0.93, 0.81, 0.35)
	layer.add_child(halo_node)
	sun_node = Polygon2D.new()
	sun_node.polygon = _circle_polygon(70.0, 28)
	sun_node.color = Color("FCEBCF")
	layer.add_child(sun_node)

	# Облака (плывут по небу медленно, тинт под фазу).
	for i in range(8):
		var cl := _make_cloud()
		cl.scale = Vector2(randf_range(1.0, 2.0), randf_range(1.0, 2.0))
		layer.add_child(cl)
		atmo_clouds.append({"node": cl, "nx": randf(), "speed": randf_range(0.010, 0.020),
				"ny": randf_range(100, 540)})

	# Тёплый отсвет у горизонта (бликует под цвет солнца) — фокус и глубина.
	atmo_glow = Sprite2D.new()
	atmo_glow.texture = _tex(THEME_DIR + "smoke.svg")
	layer.add_child(atmo_glow)

	# Птицы — лёгкие силуэты, летят по небу (оживляют пустоту, особенно на широком).
	for i in range(5):
		var bird := _make_bird()
		layer.add_child(bird)
		atmo_birds.append({"node": bird, "nx": randf(), "speed": randf_range(0.022, 0.036),
				"ny": randf_range(120, 460)})

	# Слои добавляются строго от дальнего к ближнему (порядок = z). Дома и ёлки
	# вставлены МЕЖДУ волнами земли, чтобы передняя волна перекрывала их низ.
	# nx у ёлок — только края (центр свободен под камни).

	# --- ДАЛЬНИЙ ПЛАН: далёкие горы (за лесом) + много сакур-облаков ---
	_add_dune(layer, 96.0, 4, 71, 706.0, 0.08, -0.24)   # дальняя гряда гор
	_add_dune(layer, 70.0, 5, 73, 730.0, 0.11, -0.12)   # ближняя гряда
	for i in range(9):
		var puff := _make_sakura_puff(randf_range(1.2, 1.8))
		layer.add_child(puff)
		atmo_props.append({"node": puff, "nx": 0.04 + i * 0.115 + randf_range(-0.02, 0.02), "base_y": 700.0, "factor": 0.12})
		_attach_sway(puff, randf_range(0.01, 0.022), randf_range(2.6, 4.0))
	var forest := _make_forest_row()
	layer.add_child(forest)
	atmo_dunes.append({"node": forest, "base_y": 726.0, "factor": 0.16, "shade": 0.50})

	# --- СРЕДНИЙ ПЛАН: волны земли (сглаженные гребни); дома/ёлки сидят на земле,
	# фундамент уходит за свою волну. Дома и ёлки разнесены по X (не слипаются). ---
	_add_dune(layer, 26.0, 7, 3, 760.0, 0.18, 0.00)   # волна 4 (дальняя)
	# мелкие дальние ёлки (плотность у горизонта, по бокам от центра)
	_add_fir(layer, 0.34, 800.0, 1.1, 0.30)
	_add_fir(layer, 0.64, 805.0, 1.2, 0.30)
	_add_dune(layer, 32.0, 8, 16, 840.0, 0.30, 0.18)  # волна 3
	# ПРАВЫЙ дом + правые краевые ёлки — фундамент за волну 2
	var rhouse := _make_house(1.7)
	layer.add_child(rhouse)
	atmo_props.append({"node": rhouse, "nx": 0.70, "base_y": 905.0, "factor": 0.44})
	_add_chimney_smoke(rhouse)
	_add_fir(layer, 0.80, 905.0, 1.7, 0.44)
	_add_fir(layer, 0.88, 918.0, 2.1, 0.44)
	_add_fir(layer, 0.96, 905.0, 2.4, 0.44)
	_add_dune(layer, 30.0, 9, 29, 930.0, 0.44, 0.32)  # волна 2 (закрывает фундамент правого дома)
	# ЛЕВЫЙ дом + левые краевые ёлки — фундамент за переднюю волну 1
	var lhouse := _make_house(2.4)
	layer.add_child(lhouse)
	atmo_props.append({"node": lhouse, "nx": 0.30, "base_y": 1018.0, "factor": 0.60})
	_add_chimney_smoke(lhouse)
	_add_fir(layer, 0.05, 1030.0, 2.6, 0.60)
	_add_fir(layer, 0.14, 1018.0, 2.1, 0.60)
	_add_fir(layer, 0.22, 1028.0, 1.8, 0.60)
	_add_dune(layer, 28.0, 10, 42, 1040.0, 0.60, 0.46) # волна 1 (передняя, тёмная — контраст/глубина)

	# --- ПЕРЕДНИЙ ПЛАН: огромные тёмные ёлки в самых углах (рамка, центр свободен) ---
	_add_fir(layer, -0.05, 1190.0, 4.2, 0.85)
	_add_fir(layer, 1.05, 1210.0, 4.4, 0.90)

	# Лёгкие частицы-пылинки, медленно плывут вверх.
	motes = CPUParticles2D.new()
	motes.amount = 26
	motes.lifetime = 7.0
	motes.preprocess = 4.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(BASE_W, 10)
	motes.direction = Vector2(0, -1)
	motes.spread = 18.0
	motes.gravity = Vector2(8, -16)
	motes.initial_velocity_min = 10.0
	motes.initial_velocity_max = 26.0
	motes.scale_amount_min = 2.0
	motes.scale_amount_max = 4.0
	motes.color = Color(1, 1, 1, 0.18)
	layer.add_child(motes)

	# Лепестки сакуры — падают и кружат сверху по всей ширине.
	petals = CPUParticles2D.new()
	petals.amount = 34
	petals.lifetime = 9.0
	petals.preprocess = 6.0
	petals.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	petals.emission_rect_extents = Vector2(BASE_W, 6)
	petals.direction = Vector2(0.3, 1)
	petals.spread = 25.0
	petals.gravity = Vector2(-14, 26)
	petals.initial_velocity_min = 18.0
	petals.initial_velocity_max = 42.0
	petals.angular_velocity_min = -120.0
	petals.angular_velocity_max = 120.0
	petals.scale_amount_min = 0.32
	petals.scale_amount_max = 0.62
	petals.texture = _tex(THEME_DIR + "petal.svg")  # цветочек 5 лепестков + серединка
	petals.color = Color(1, 1, 1)
	layer.add_child(petals)

	# Светлячки — мерцают и плавают, видны только ночью (низ сцены).
	for i in range(16):
		var ff := Polygon2D.new()
		ff.polygon = _circle_polygon(randf_range(2.5, 4.5), 8)
		ff.color = Color("EBF2A0")
		layer.add_child(ff)
		atmo_fireflies.append({"node": ff, "nx": randf(), "ny": randf_range(BASE_H * 0.55, BASE_H * 0.92),
				"phase": randf() * TAU})

	atmo_active = true
	_update_atmosphere()

# Дымок из трубы дома (дети ноды дома — едут и тускнеют вместе с ним).
func _add_chimney_smoke(house: Node2D) -> void:
	var sm := CPUParticles2D.new()
	sm.amount = 18
	sm.lifetime = 3.8
	sm.preprocess = 2.5
	sm.position = Vector2(0, -103)   # ровно из устья трубы (конёк дома)
	sm.direction = Vector2(0.25, -1)
	sm.spread = 8.0
	sm.gravity = Vector2(3, -7)
	sm.initial_velocity_min = 3.0
	sm.initial_velocity_max = 7.0
	sm.scale_amount_min = 0.25
	sm.scale_amount_max = 0.75
	sm.scale_amount_curve = _ramp_curve()       # растёт по мере подъёма
	sm.texture = _tex(THEME_DIR + "smoke.svg")  # мягкий клуб, не «пузырь»
	sm.color = Color(0.97, 0.96, 0.98, 0.5)
	house.add_child(sm)

# Кривая 0→1 (частица разрастается за время жизни — дым расходится).
func _ramp_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(1, 1.0))
	return c

# Дюна: волнистый гребень вокруг y=0 (range -amp..0), залив до низа. Центрируется
# по экрану через node.position в раскладке; ширина с запасом на любой экран.
func _make_dune(amp: float, step_seed: int, seed: int) -> Polygon2D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var ph := rng.randf() * TAU
	var pts := PackedVector2Array()
	var x := -3200.0
	while x <= 3200.0:
		var y := -amp * 0.5 * (1.0 + sin(x * 0.0016 + ph)) - rng.randf() * amp * 0.35
		pts.append(Vector2(x, y))
		x += 70.0
	pts.append(Vector2(3200.0, 2600.0))
	pts.append(Vector2(-3200.0, 2600.0))
	var p := Polygon2D.new()
	p.polygon = pts
	return p

# Создать дюну, добавить в слой (z = порядок) и зарегистрировать для параллакса.
func _add_dune(layer: CanvasLayer, amp: float, step_seed: int, seed: int, base_y: float, factor: float, shade: float) -> void:
	var dn := _make_dune(amp, step_seed, seed)
	layer.add_child(dn)
	atmo_dunes.append({"node": dn, "base_y": base_y, "factor": factor, "shade": shade})

func _add_fir(layer: CanvasLayer, nx: float, base_y: float, scale: float, factor: float) -> void:
	var fr := _make_fir(scale)
	layer.add_child(fr)
	atmo_props.append({"node": fr, "nx": nx, "base_y": base_y, "factor": factor})
	_attach_sway(fr, randf_range(0.014, 0.03), randf_range(2.0, 3.4))

# Лёгкое покачивание «на ветру» (вокруг основания ноды), зацикленное.
func _attach_sway(node: Node2D, amp: float, period: float) -> void:
	node.rotation = randf_range(-amp, amp)
	var tw := node.create_tween().set_loops()
	tw.tween_property(node, "rotation", amp, period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "rotation", -amp, period * 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "rotation", 0.0, period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _make_sakura(scale: float) -> Node2D:
	var n := Node2D.new()
	n.scale = Vector2(scale, scale)
	var trunk := Polygon2D.new()
	trunk.polygon = PackedVector2Array([Vector2(-6, 0), Vector2(6, 0), Vector2(4, -58), Vector2(-4, -58)])
	trunk.color = Color("3A2A2E")
	n.add_child(trunk)
	for bx in [-1, 1]:
		var br := Polygon2D.new()
		br.polygon = PackedVector2Array([Vector2(0, -42), Vector2(5 * bx, -44), Vector2(26 * bx, -82), Vector2(19 * bx, -82)])
		br.color = Color("3A2A2E")
		n.add_child(br)
	for c in [[0, -90, 34], [-28, -80, 26], [30, -82, 26], [-10, -108, 24], [16, -104, 22]]:
		var bl := Polygon2D.new()
		bl.polygon = _circle_polygon(float(c[2]), 16)
		bl.position = Vector2(c[0], c[1])
		bl.color = Color("F1C7E4")
		n.add_child(bl)
	return n

# Ёлка — просто тёмный треугольник, без ствола (как в референсе).
func _make_fir(scale: float) -> Node2D:
	var n := Node2D.new()
	n.scale = Vector2(scale, scale)
	# Объём: левая половина — базовый цвет, правая — светлее, по центру тёмная полоса.
	var left := Polygon2D.new()
	left.polygon = PackedVector2Array([Vector2(-32, 0), Vector2(0, -140), Vector2(0, 0)])
	left.color = Color("28392E")
	n.add_child(left)
	var right := Polygon2D.new()
	right.polygon = PackedVector2Array([Vector2(0, 0), Vector2(0, -140), Vector2(32, 0)])
	right.color = Color("3C5634")
	n.add_child(right)
	var seam := Polygon2D.new()
	seam.polygon = PackedVector2Array([Vector2(-3, 0), Vector2(3, 0), Vector2(3, -126), Vector2(-3, -126)])
	seam.color = Color("1A271E")
	n.add_child(seam)
	return n

# Большая розовая сакура-«облако» для дальнего плана: пышные кластеры кругов.
# Розовая сакура-«облако». Каждая разная: свой оттенок, ширина, число и разброс
# комков — чтобы дальний план не выглядел клонами.
func _make_sakura_puff(scale: float) -> Node2D:
	var n := Node2D.new()
	n.scale = Vector2(scale, scale)
	var bases := [Color("E2A4CE"), Color("D98FC0"), Color("E8B0D2"), Color("C99BD4"), Color("EBA6C2"), Color("DDA0D0")]
	var base: Color = bases[randi() % bases.size()]
	var hi := base.lightened(0.20)
	var spread_x := randf_range(56.0, 84.0)   # ширина кроны
	var squish := randf_range(0.7, 1.0)       # приплюснутость
	var nb := randi_range(6, 9)
	for i in range(nb):
		var bl := Polygon2D.new()
		bl.polygon = _circle_polygon(randf_range(30.0, 52.0), 18)
		bl.position = Vector2(randf_range(-spread_x, spread_x), randf_range(-38.0, 26.0) * squish)
		bl.color = base
		n.add_child(bl)
	for i in range(randi_range(3, 5)):
		var bl := Polygon2D.new()
		bl.polygon = _circle_polygon(randf_range(18.0, 30.0), 16)
		bl.position = Vector2(randf_range(-spread_x * 0.6, spread_x * 0.6), randf_range(-34.0, 2.0) * squish)
		bl.color = hi
		n.add_child(bl)
	return n

# Дальняя кромка леса: широкая полоса мелких треугольников (силуэт), центрируется
# по экрану, перекрашивается как дюна. Как лес на среднем плане в референсе.
func _make_forest_row() -> Polygon2D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var pts := PackedVector2Array()
	var x := -3200.0
	pts.append(Vector2(x, 6))
	while x <= 3200.0:
		var h := 22.0 + rng.randf() * 30.0
		pts.append(Vector2(x, 6))
		pts.append(Vector2(x + 13.0, -h))
		pts.append(Vector2(x + 26.0, 6))
		x += 26.0
	pts.append(Vector2(3200.0, 2600.0))
	pts.append(Vector2(-3200.0, 2600.0))
	var p := Polygon2D.new()
	p.polygon = pts
	return p

# Крыша пагоды: широкая, с загнутыми ВВЕРХ краями (азиатский карниз).
func _pagoda_roof(ey: float, hw: float, h: float, col: String) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([
		Vector2(-hw, ey - h * 0.40),         # левый карниз — загнут вверх
		Vector2(-hw * 0.82, ey - h * 0.04),
		Vector2(-hw * 0.55, ey + 6),         # провис карниза
		Vector2(0, ey - h),                  # конёк
		Vector2(hw * 0.55, ey + 6),
		Vector2(hw * 0.82, ey - h * 0.04),
		Vector2(hw, ey - h * 0.40),          # правый карниз — загнут вверх
		Vector2(hw * 0.7, ey + 14),
		Vector2(0, ey + 14),
		Vector2(-hw * 0.7, ey + 14)])
	p.color = Color(col)
	return p

func _trim_band(y: float, hw: float) -> Polygon2D:
	var t := Polygon2D.new()
	t.polygon = PackedVector2Array([Vector2(-hw, y), Vector2(hw, y), Vector2(hw, y + 5), Vector2(-hw, y + 5)])
	t.color = Color("4958B0")
	return t

# Дом как раньше (одна крыша), но с загнутыми вверх карнизами — азиатский акцент.
func _make_house(scale: float) -> Node2D:
	var n := Node2D.new()
	n.scale = Vector2(scale, scale)
	# тело
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-34, 0), Vector2(34, 0), Vector2(30, -42), Vector2(-30, -42)])
	body.color = Color("3C3B66")
	n.add_child(body)
	for sx in [-22, -8, 8, 22]:
		var sl := Polygon2D.new()
		sl.polygon = PackedVector2Array([Vector2(sx - 3, -6), Vector2(sx + 3, -6), Vector2(sx + 3, -36), Vector2(sx - 3, -36)])
		sl.color = Color("33325A")
		n.add_child(sl)
	var door := Polygon2D.new()
	door.polygon = PackedVector2Array([Vector2(-7, 0), Vector2(7, 0), Vector2(7, -24), Vector2(-7, -24)])
	door.color = Color("C8324E")
	n.add_child(door)
	# одна крыша с загнутыми карнизами + синий кант
	n.add_child(_pagoda_roof(-40, 58, 44, "1E1D34"))
	n.add_child(_trim_band(-39, 30))
	# красный конёк
	var fin := Polygon2D.new()
	fin.polygon = PackedVector2Array([Vector2(-3, -82), Vector2(3, -82), Vector2(3, -98), Vector2(-3, -98)])
	fin.color = Color("C8324E")
	n.add_child(fin)
	return n

# Палитра атмосферы по фазам (порог по счёту): рассвет→день→закат→ночь.
# Каждая фаза: [score, top, mid, bot, sun, sun_y, ground, star_a]
func _atmo_phases() -> Array:
	return [
		[0.0,  Color("F8D9A0"), Color("F2B97E"), Color("E89B79"), Color("FCEBCF"), 200.0, Color(0.83, 0.62, 0.48), 0.0],
		[10.0, Color("9CC9E8"), Color("C7E2EC"), Color("E6EFDD"), Color("FFF7DA"), 150.0, Color(0.64, 0.72, 0.56), 0.0],
		[20.0, Color("66689E"), Color("D98E72"), Color("F0A86E"), Color("FF9A5A"), 320.0, Color(0.52, 0.40, 0.50), 0.18],
		[30.0, Color("161E3A"), Color("273056"), Color("433F66"), Color("E7E9F6"), 190.0, Color(0.20, 0.20, 0.34), 1.0],
	]

# Плавно смешиваем небо/солнце/холмы/звёзды по текущей высоте башни.
var _atmo_p: float = 0.0
func _update_atmosphere() -> void:
	if not atmo_active:
		return
	var phases := _atmo_phases()
	var target: float = clampf(float(score), 0.0, phases[phases.size() - 1][0])
	_atmo_p = lerp(_atmo_p, target, 0.04)
	# Найти сегмент фаз.
	var i := 0
	while i < phases.size() - 2 and _atmo_p > phases[i + 1][0]:
		i += 1
	var a: Array = phases[i]
	var b: Array = phases[i + 1]
	var f: float = clampf((_atmo_p - a[0]) / maxf(1.0, b[0] - a[0]), 0.0, 1.0)
	sky_grad.colors = PackedColorArray([a[1].lerp(b[1], f), a[2].lerp(b[2], f), a[3].lerp(b[3], f)])
	var suncol: Color = a[4].lerp(b[4], f)
	sun_node.color = suncol
	sun_node.position.y = lerp(float(a[5]), float(b[5]), f)
	halo_node.position.y = sun_node.position.y
	halo_node.color = Color(suncol.r, suncol.g, suncol.b, 0.30)
	var ground: Color = a[6].lerp(b[6], f)
	var star_a: float = lerp(float(a[7]), float(b[7]), f)
	var night: float = star_a   # 0 днём, 1 ночью
	motes.color = Color(suncol.r, suncol.g, suncol.b, 0.16)

	# --- Респонсивная раскладка: центр по центру вьюпорта, ширина — вся видимая ---
	var vr: Vector2 = get_viewport().get_visible_rect().size
	var vw: float = vr.x
	var vh: float = vr.y
	var cx: float = vw / 2.0
	var dt: float = get_process_delta_time()
	var climb: float = 0.0
	if camera:
		climb = start_cam_y - camera.position.y

	# Солнце/гало — справа-сверху относительно центра экрана.
	var sun_x: float = cx + vw * 0.18
	sun_node.position = Vector2(sun_x, lerp(float(a[5]), float(b[5]), f))
	halo_node.position = sun_node.position

	# Тёплый отсвет у горизонта — широкий, под цвет солнца, тает к ночи.
	atmo_glow.scale = Vector2(maxf(BASE_W, vw) / 38.0, 7.0)
	atmo_glow.position = Vector2(cx, 706.0 + climb * 0.16)
	atmo_glow.modulate = Color(suncol.r, suncol.g, suncol.b, lerp(0.34, 0.10, night))

	# Звёзды по всей ширине.
	for s in atmo_stars:
		var sn: Polygon2D = s["node"]
		sn.position = Vector2(s["nx"] * vw, s["ny"])
		sn.self_modulate.a = star_a

	# Облака плывут медленно слева-направо, тинт под фазу (ночью почти прячутся).
	for c in atmo_clouds:
		c["nx"] = fmod(c["nx"] + c["speed"] * dt, 1.0)
		var cn: Node2D = c["node"]
		cn.position = Vector2(lerp(-240.0, vw + 240.0, c["nx"]), c["ny"])
		cn.modulate = Color(suncol.r, suncol.g, suncol.b, lerp(0.5, 0.12, night))

	# Птицы — летят по небу, темнеют силуэтом, ночью почти не видны.
	for bd in atmo_birds:
		bd["nx"] = fmod(bd["nx"] + bd["speed"] * dt, 1.0)
		var bn: Node2D = bd["node"]
		bn.position = Vector2(lerp(-120.0, vw + 120.0, bd["nx"]), bd["ny"])
		bn.modulate.a = lerp(0.7, 0.15, night)

	# Дюны/горы: центр по экрану, цвет от фазы (shade>0 темнее земли — ближе;
	# shade<0 светлее — далёкие горы в дымке), параллакс.
	for d in atmo_dunes:
		var dn: Polygon2D = d["node"]
		var sh: float = d["shade"]
		dn.color = ground.darkened(sh) if sh >= 0.0 else ground.lightened(-sh)
		dn.position = Vector2(cx, d["base_y"] + climb * d["factor"])

	# Объекты на лугах (ёлочки/домики/сакуры): по всей ширине, тускнеют к ночи.
	for p in atmo_props:
		var pn: Node2D = p["node"]
		pn.position = Vector2(p["nx"] * vw, p["base_y"] + climb * p["factor"])
		pn.modulate = Color(1, 1, 1).lerp(Color(0.42, 0.42, 0.56), night * 0.85)

	# Частицы-пылинки — на всю ширину у нижней кромки.
	motes.position = Vector2(cx, vh + 20.0)
	motes.emission_rect_extents = Vector2(maxf(BASE_W, vw) / 2.0, 10.0)

	# Лепестки сакуры — сыплются сверху по всей ширине; к ночи чуть тусклее.
	petals.position = Vector2(cx, -20.0)
	petals.emission_rect_extents = Vector2(maxf(BASE_W, vw) / 2.0, 6.0)
	petals.self_modulate.a = lerp(1.0, 0.5, night)

	# Светлячки — плавают и мерцают, видны только ночью (низ сцены).
	var t: float = Time.get_ticks_msec() / 1000.0
	for ff in atmo_fireflies:
		var fn: Polygon2D = ff["node"]
		var ph: float = ff["phase"]
		fn.position = Vector2(ff["nx"] * vw + sin(t * 0.6 + ph) * 14.0, ff["ny"] + cos(t * 0.5 + ph) * 10.0)
		fn.self_modulate.a = night * (0.35 + 0.45 * (0.5 + 0.5 * sin(t * 2.2 + ph)))

func _add_bg_layer(tex: Texture2D, z: int, drift: float, bottom_y: float, mode: String, scale: float, sway: bool) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sp.z_index = z
	sp.scale = Vector2(scale, scale)
	sp.position = Vector2(base_x, bottom_y - tex.get_height() * scale / 2.0)
	add_child(sp)
	bg_layers.append({
		"node": sp, "art_w": float(tex.get_width()), "art_h": float(tex.get_height()),
		"drift": drift, "bottom_y": bottom_y, "mode": mode, "scale": scale,
	})
	if sway:
		# Лёгкое покачивание деревьев «на ветру».
		var tw := create_tween().set_loops()
		tw.tween_property(sp, "rotation", 0.02, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(sp, "rotation", -0.02, 4.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(sp, "rotation", 0.0, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return sp

# Адаптив + параллакс. far/mid — фиксированный масштаб, по центру (горизонт стоит).
# Деревья переднего плана приклеены к левому/правому краю вьюпорта: на телефоне
# сходятся, на широком экране расходятся — кадр читается на любом устройстве.
# По вертикали слои едут с разной скоростью (drift) при росте башни.
func _update_parallax() -> void:
	if bg_layers.is_empty() or camera == null:
		return
	var vw: float = get_viewport().get_visible_rect().size.x
	var view_left: float = base_x - vw / 2.0
	var view_right: float = base_x + vw / 2.0
	for L in bg_layers:
		var node: Sprite2D = L["node"]
		var scale: float = L["scale"]
		var sw: float = L["art_w"] * scale
		var sh: float = L["art_h"] * scale
		var world_bottom: float = L["bottom_y"] + (camera.position.y - start_cam_y) * L["drift"]
		var x: float = base_x
		match L["mode"]:
			"edge_left":
				x = view_left + sw / 2.0
			"edge_right":
				x = view_right - sw / 2.0
		node.position = Vector2(x, world_bottom - sh / 2.0)

# Небо над дальним планом: звёзды, облака, птица, дракон, воздушный шар.
# Всё — дети дальнего слоя (в его арт-координатах), чтобы двигаться как дальний план.
func _add_sky_life() -> void:
	if bg_layers.is_empty():
		return
	var far: Sprite2D = bg_layers[0]["node"]
	# Звёзды/блики в верхнем небе (арт y < 240, над солнцем).
	for i in range(16):
		var st := Polygon2D.new()
		st.polygon = _circle_polygon(randf_range(2.5, 4.5), 8)
		st.color = Color(1, 1, 1)
		st.position = Vector2(randf_range(40, FAR_ART_W - 40), randf_range(-1200, 180))
		st.modulate.a = randf_range(0.3, 0.9)
		far.add_child(st)
		var d := randf_range(0.8, 1.8)
		var tw := create_tween().set_loops()
		tw.tween_property(st, "modulate:a", 0.2, d).set_trans(Tween.TRANS_SINE)
		tw.tween_property(st, "modulate:a", 0.9, d).set_trans(Tween.TRANS_SINE)
	# Плывущие облака.
	for i in range(5):
		var cl := _make_cloud()
		cl.position = Vector2(randf_range(0, FAR_ART_W), randf_range(-1100, 220))
		far.add_child(cl)
		_drift_across(cl, randf_range(34.0, 60.0))
	# Птица, воздушный шар, дракон — по одному, в разных высотах неба.
	var bird := _make_bird()
	bird.position = Vector2(randf_range(200, 900), randf_range(-300, 60))
	far.add_child(bird)
	_drift_across(bird, 26.0)
	var balloon := _make_balloon()
	balloon.position = Vector2(randf_range(150, 1000), randf_range(-900, -300))
	far.add_child(balloon)
	_drift_across(balloon, 70.0)
	var dragon := _make_dragon()
	dragon.position = Vector2(randf_range(200, 900), randf_range(-1500, -800))
	far.add_child(dragon)
	_drift_across(dragon, 48.0)

func _drift_across(n: Node2D, dur: float) -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(n, "position:x", FAR_ART_W + 220.0, dur)
	tw.tween_callback(func() -> void: n.position.x = -220.0)

func _make_cloud() -> Node2D:
	var n := Node2D.new()
	var col := Color(1, 1, 1, 0.16)
	for p in [[0.0, 0.0, 72.0, 26.0], [52.0, 8.0, 56.0, 22.0], [-48.0, 10.0, 50.0, 20.0], [16.0, -14.0, 48.0, 22.0]]:
		var e := Polygon2D.new()
		e.polygon = _ellipse_polygon(p[2], p[3], 18)
		e.color = col
		e.position = Vector2(p[0], p[1])
		n.add_child(e)
	return n

func _make_bird() -> Node2D:
	# Простой силуэт «галочкой» с лёгким взмахом крыльев.
	var n := Node2D.new()
	var w := Polygon2D.new()
	w.polygon = PackedVector2Array([Vector2(-20, 0), Vector2(0, -7), Vector2(20, 0), Vector2(0, -2)])
	w.color = Color(0.16, 0.14, 0.22, 0.85)
	n.add_child(w)
	var tw := create_tween().set_loops()
	tw.tween_property(w, "scale", Vector2(1.0, 0.5), 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(w, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_SINE)
	return n

func _make_balloon() -> Node2D:
	var n := Node2D.new()
	var env := Polygon2D.new()
	env.polygon = _ellipse_polygon(30, 38, 22)
	env.color = Color("E07A6E")
	n.add_child(env)
	var stripe := Polygon2D.new()
	stripe.polygon = _ellipse_polygon(8, 36, 16)
	stripe.color = Color("F0B59A")
	n.add_child(stripe)
	var basket := Polygon2D.new()
	basket.polygon = PackedVector2Array([Vector2(-7, 44), Vector2(7, 44), Vector2(5, 56), Vector2(-5, 56)])
	basket.color = Color("4A3326")
	n.add_child(basket)
	# Лёгкое покачивание.
	var tw := create_tween().set_loops()
	tw.tween_property(n, "rotation", 0.06, 2.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "rotation", -0.06, 2.2).set_trans(Tween.TRANS_SINE)
	return n

func _make_dragon() -> Node2D:
	# Стилизованный восточный дракон: волнистое тело сегментами + голова.
	var n := Node2D.new()
	var col := Color("C8324E")
	for i in range(7):
		var seg := Polygon2D.new()
		seg.polygon = _circle_polygon(11.0 - i * 0.9, 14)
		seg.color = col
		seg.position = Vector2(-i * 22.0, sin(i * 0.9) * 14.0)
		n.add_child(seg)
	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([Vector2(22, -10), Vector2(40, 0), Vector2(22, 10), Vector2(14, 0)])
	head.color = col
	n.add_child(head)
	# Волнообразное «дыхание» тела.
	var tw := create_tween().set_loops()
	tw.tween_property(n, "position:y", n.position.y - 10.0, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "position:y", n.position.y, 1.6).set_trans(Tween.TRANS_SINE)
	return n

func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.position = Vector2(base_x, 0)
	add_child(camera)
	camera.make_current()

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var txt := Color("F4ECE0") if skin == 1 else Color("4A3326")
	score_label = Label.new()
	score_label.position = Vector2(30, 30)
	score_label.add_theme_font_size_override("font_size", 48)
	score_label.add_theme_color_override("font_color", txt)
	layer.add_child(score_label)
	msg_label = Label.new()
	msg_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg_label.add_theme_font_size_override("font_size", 30)
	msg_label.add_theme_color_override("font_color", Color("F4ECE0") if skin == 1 else Color("7A2218"))
	msg_label.visible = false
	layer.add_child(msg_label)

	# Кнопка смены скина (верх-право), стилизованная «пилюля» под тему скина.
	skin_button = Button.new()
	skin_button.text = SKIN_NAMES[skin]
	skin_button.add_theme_font_size_override("font_size", 34)
	skin_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skin_button.position = Vector2(-228, 30)
	skin_button.custom_minimum_size = Vector2(196, 64)
	skin_button.focus_mode = Control.FOCUS_NONE
	# Кнопка — только визуал; тап по её области ловим в _unhandled_input (работает
	# и на тач, и на клик, в отличие от сигнала Button на тач-устройствах).
	skin_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Цвета пилюли под текущий скин.
	var fill := Color("2B2B33") if skin == 1 else Color("FBF4E8")
	var bord := Color("FF7FD0") if skin == 1 else Color("C9A24B")
	var fcol := Color("FFE7F6") if skin == 1 else Color("5A4326")
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill.lightened(0.06) if st == "hover" else (fill.darkened(0.10) if st == "pressed" else fill)
		sb.border_color = bord
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(32)
		sb.set_content_margin_all(10)
		sb.shadow_color = Color(0, 0, 0, 0.22)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 3)
		skin_button.add_theme_stylebox_override(st, sb)
	skin_button.add_theme_color_override("font_color", fcol)
	skin_button.add_theme_color_override("font_hover_color", fcol)
	skin_button.add_theme_color_override("font_pressed_color", fcol)
	layer.add_child(skin_button)
	_update_score()

func _switch_skin() -> void:
	skin = (skin + 1) % SKIN_COUNT
	_save_skin()
	get_tree().reload_current_scene()

func _save_skin() -> void:
	var f := FileAccess.open("user://skin.dat", FileAccess.WRITE)
	if f:
		f.store_8(skin)

func _load_skin() -> void:
	var env := OS.get_environment("BT_SKIN")   # дебаг-превью скина
	if env != "":
		skin = clampi(int(env), 0, SKIN_COUNT - 1)
		return
	if FileAccess.file_exists("user://skin.dat"):
		var f := FileAccess.open("user://skin.dat", FileAccess.READ)
		if f:
			skin = clampi(f.get_8(), 0, SKIN_COUNT - 1)

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
	elif skin == 1:
		var shadow := Polygon2D.new()
		shadow.polygon = _ellipse_polygon(ssize.x * 0.86, 14.0, 24)
		shadow.color = Color(0, 0, 0, 0.20)
		shadow.position = Vector2(0, -4)
		ped.add_child(shadow)
		ped.add_child(_make_plate(ssize.x))
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
	_update_parallax()
	_update_atmosphere()
	_update_diner()

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
	var pos := Vector2(-1, -1)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		act = true; pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		act = true; pos = event.position
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		act = true
	if not act:
		return
	# Защита от двойного срабатывания (тач + эмулированный клик на одном тапе).
	var now := Time.get_ticks_msec()
	if now - last_action_ms < 200:
		return
	last_action_ms = now
	# Тап по кнопке скина — переключаем скин, башню не трогаем.
	if pos.x >= 0.0 and skin_button and skin_button.get_global_rect().has_point(pos):
		_switch_skin()
		return
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
	# Бросок: рука дёргается вверх, чуть отклоняется и тает.
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(c, "position:y", c.position.y - 110.0, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(c, "rotation", -0.18, 0.30)
	tw.tween_property(c, "modulate:a", 0.0, 0.30).set_delay(0.10)
	tw.set_parallel(false)
	tw.tween_callback(c.queue_free)

# ---------- Рисование (заглушки векторной графикой) ----------

# --- Тема/скин: подхватывает картинки из res://assets/zen/, если они есть ---

const THEME_DIR := "res://assets/zen/"

# false — вернуться к самому первому виду «тёплый рассвет» (всё рисуется кодом:
# градиентное небо, солнце, холмы, камни-булыжники, рука). true — подхватить
# SVG-скин из assets/zen/ (самурайская сцена и т.п.). Переключатель арта.
const USE_ART := false

func _load_theme() -> void:
	if not USE_ART:
		theme = {"stones": [], "hand": null, "hand_release": null}
		return
	theme = {
		"stones": [],
		"hand": _tex(THEME_DIR + "hand.svg"),
		"hand_release": null,
		"background": _tex(THEME_DIR + "background.svg"),
		"scene": _tex(THEME_DIR + "scene.svg"),
		"far": _tex(THEME_DIR + "far.svg"),
		"mid": _tex(THEME_DIR + "mid.svg"),
		"near_left": _tex(THEME_DIR + "near_left.svg"),
		"near_right": _tex(THEME_DIR + "near_right.svg"),
		"pedestal": _tex(THEME_DIR + "pedestal.svg"),
	}
	for n in ["stone.svg", "stone2.svg", "stone3.svg", "stone4.svg"]:
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

# Возвращает узел «кирпичика» башни: блинчик (Diner) или камень (Дзен).
func _stone_visual(size: Vector2, base: Color, idx: int) -> Node2D:
	if skin == 1:
		return _make_pancake(size, idx)
	var stones_arr: Array = theme.get("stones", [])
	if idx >= 0 and idx < stones_arr.size():
		return _sprite_scaled_to_width(stones_arr[idx], size.x)
	return _make_rock(size, base)

# Блинчик: золотистая стопкообразная лепёшка с тёмным краем, бликом и кусочком масла.
func _make_pancake(size: Vector2, idx: int) -> Node2D:
	var n := Node2D.new()
	var hw := size.x / 2.0
	var hh := size.y / 2.0
	# тело блина (скруглённый прямоугольник), вертикальный градиент золотистого
	var poly := PackedVector2Array([
		Vector2(-hw, -hh * 0.2), Vector2(-hw * 0.86, -hh * 0.85), Vector2(-hw * 0.5, -hh),
		Vector2(hw * 0.5, -hh), Vector2(hw * 0.86, -hh * 0.85), Vector2(hw, -hh * 0.2),
		Vector2(hw * 0.86, hh * 0.85), Vector2(hw * 0.5, hh), Vector2(-hw * 0.5, hh), Vector2(-hw * 0.86, hh * 0.85)])
	var body := Polygon2D.new()
	body.polygon = poly
	var top := Color("F0B95E")
	var bot := Color("BE7C33")
	var cols := PackedColorArray()
	for v in poly:
		cols.append(top.lerp(bot, clampf(v.y / size.y + 0.5, 0.0, 1.0)))
	body.vertex_colors = cols
	n.add_child(body)
	# тёмный нижний край (поджарка)
	var rim := Polygon2D.new()
	rim.polygon = PackedVector2Array([Vector2(-hw, hh * 0.1), Vector2(hw, hh * 0.1),
		Vector2(hw * 0.86, hh * 0.85), Vector2(hw * 0.5, hh), Vector2(-hw * 0.5, hh), Vector2(-hw * 0.86, hh * 0.85)])
	rim.color = Color("A9692A")
	n.add_child(rim)
	# СИРОП: янтарная лужа на верхушке + потёки через передний край (читается как блин)
	var syrup := Polygon2D.new()
	syrup.polygon = _ellipse_polygon(hw * 0.82, hh * 0.64, 20)
	syrup.position = Vector2(0, -hh * 0.22)
	syrup.color = Color("B0651A")
	n.add_child(syrup)
	# потёки вниз по переднему краю (длины разные для каждого блина)
	for d in [[-hw * 0.5, hh * 1.5], [-hw * 0.05, hh * 2.1], [hw * 0.4, hh * 1.2], [hw * 0.66, hh * 1.7]]:
		var dx: float = d[0]
		var dl: float = d[1] * (0.7 + 0.6 * float((idx + int(dx)) % 3) / 2.0)
		var drip := Polygon2D.new()
		drip.polygon = PackedVector2Array([
			Vector2(dx - 6, -hh * 0.1), Vector2(dx + 6, -hh * 0.1),
			Vector2(dx + 5, dl - 6), Vector2(dx, dl), Vector2(dx - 5, dl - 6)])
		drip.color = Color("A85B12")
		n.add_child(drip)
	# глянец на сиропе
	var gloss := Polygon2D.new()
	gloss.polygon = _ellipse_polygon(hw * 0.4, hh * 0.16, 16)
	gloss.position = Vector2(-hw * 0.12, -hh * 0.5)
	gloss.color = Color(1, 1, 1, 0.18)
	n.add_child(gloss)
	# кубик масла сверху
	if idx % 2 == 0:
		var butter := Polygon2D.new()
		butter.polygon = PackedVector2Array([Vector2(-15, -hh - 12), Vector2(15, -hh - 12), Vector2(12, -hh + 2), Vector2(-12, -hh + 2)])
		butter.color = Color("FBE08A")
		n.add_child(butter)
		var bhi := Polygon2D.new()
		bhi.polygon = PackedVector2Array([Vector2(-13, -hh - 11), Vector2(2, -hh - 11), Vector2(0, -hh - 4), Vector2(-12, -hh - 4)])
		bhi.color = Color("FEEFB0")
		n.add_child(bhi)
	return n

# Тарелка под нижним блином.
func _make_plate(w: float) -> Node2D:
	var n := Node2D.new()
	var base := Polygon2D.new()
	base.polygon = _ellipse_polygon(w * 0.78, 18.0, 28)
	base.position = Vector2(0, -16)   # под нижним блином (он садится на тарелку)
	base.color = Color("E9E4DA")
	n.add_child(base)
	var lip := Polygon2D.new()
	lip.polygon = _ellipse_polygon(w * 0.80, 9.0, 28)
	lip.position = Vector2(0, -26)
	lip.color = Color("FBF8F2")
	n.add_child(lip)
	return n

# ---------- Скин «Diner»: интерьер закусочной ----------

func _setup_diner() -> void:
	RenderingServer.set_default_clear_color(Color("7FB8B1"))
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)

	# Стена — вертикальный градиент (верх светлее), на весь экран.
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color("9AD0C8"), Color("6FA9A2")])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0); gt.fill_to = Vector2(0, 1)
	gt.width = 8; gt.height = 256
	var wall := TextureRect.new()
	wall.texture = gt
	wall.stretch_mode = TextureRect.STRETCH_SCALE
	wall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(wall)

	# Окно с ночным городом + неон-вывеска (верх).
	diner_window = _diner_window()
	layer.add_child(diner_window)
	diner_neon = _diner_neon()
	layer.add_child(diner_neon)
	# Часы и лампа.
	diner_clock = _diner_clock()
	layer.add_child(diner_clock)
	diner_menu = _diner_menu()
	layer.add_child(diner_menu)
	diner_lamp = _diner_lamp()
	layer.add_child(diner_lamp)
	# Пол в шашечку + стойка + табурет + декор.
	diner_floor = _diner_floor()
	layer.add_child(diner_floor)
	diner_stool = _diner_stool()
	layer.add_child(diner_stool)
	diner_counter = _diner_counter()
	layer.add_child(diner_counter)

	diner_active = true
	_update_diner()

func _update_diner() -> void:
	if not diner_active:
		return
	var vr: Vector2 = get_viewport().get_visible_rect().size
	var vw: float = vr.x
	var vh: float = vr.y
	var cx: float = vw / 2.0
	# Экранная Y, где стоит нижний блин (мир→экран при стартовой камере).
	var counter_y: float = (965.0 - start_cam_y) + vh * 0.5
	diner_window.position = Vector2(cx, vh * 0.27)
	diner_neon.position = Vector2(cx, vh * 0.10)
	diner_clock.position = Vector2(cx - vw * 0.36, vh * 0.12)
	diner_menu.position = Vector2(cx + vw * 0.37, vh * 0.30)
	diner_lamp.position = Vector2(cx + vw * 0.16, 0)
	diner_floor.position = Vector2(cx, counter_y)
	diner_floor.scale.x = maxf(1.0, vw / 1400.0)
	diner_counter.position = Vector2(cx, counter_y)
	diner_counter.scale.x = maxf(1.0, vw / 1300.0)
	diner_stool.position = Vector2(cx - vw * 0.40, counter_y + 16.0)

func _diner_floor() -> Node2D:
	# Чёрно-белая шашечка от стойки вниз. Ширина клетки одинаковая (колонки ровные),
	# высота рядов чуть растёт к низу — лёгкая перспектива.
	var n := Node2D.new()
	var tw := 88.0
	var y := 0.0
	for r in range(11):
		var th := 22.0 + r * 5.0
		var x := -1760.0
		var c := 0
		while x < 1760.0:
			var q := Polygon2D.new()
			q.polygon = PackedVector2Array([Vector2(x, y), Vector2(x + tw, y), Vector2(x + tw, y + th), Vector2(x, y + th)])
			q.color = Color("23222E") if (r + c) % 2 == 0 else Color("E7E1D6")
			n.add_child(q)
			x += tw; c += 1
		y += th
	return n

func _diner_counter() -> Node2D:
	# Стойка: красная панель + хромированная столешница; крупный декор по всей длине.
	var n := Node2D.new()
	var splash := Polygon2D.new()
	splash.polygon = PackedVector2Array([Vector2(-1900, -10), Vector2(1900, -10), Vector2(1900, 90), Vector2(-1900, 90)])
	splash.color = Color("C23B4A")
	n.add_child(splash)
	var top := Polygon2D.new()
	top.polygon = PackedVector2Array([Vector2(-1900, -26), Vector2(1900, -26), Vector2(1900, -6), Vector2(-1900, -6)])
	top.color = Color("D8DEE3")
	n.add_child(top)
	var edge := Polygon2D.new()
	edge.polygon = PackedVector2Array([Vector2(-1900, -32), Vector2(1900, -32), Vector2(1900, -24), Vector2(-1900, -24)])
	edge.color = Color("9AA4AC")
	n.add_child(edge)
	# Крупный декор, разнесён по длине (заполняет и широкий экран).
	n.add_child(_diner_bottle(-250, "C0303C", 1.7))   # кетчуп
	n.add_child(_diner_bottle(-205, "E7B62E", 1.7))   # горчица
	var pie := _diner_pie(); pie.position = Vector2(-430, -26); n.add_child(pie)
	var nap := Polygon2D.new()
	nap.polygon = PackedVector2Array([Vector2(235, -26), Vector2(305, -26), Vector2(305, -86), Vector2(235, -86)])
	nap.color = Color("CFD6DB")
	n.add_child(nap)
	var coffee := _diner_coffee(); coffee.scale = Vector2(1.6, 1.6); coffee.position = Vector2(360, -26); n.add_child(coffee)
	var shake := _diner_milkshake(); shake.position = Vector2(520, -26); n.add_child(shake)
	return n

func _diner_bottle(x: float, col: String, sc: float) -> Node2D:
	var n := Node2D.new()
	n.position = Vector2(x, -26); n.scale = Vector2(sc, sc)
	var b := Polygon2D.new()
	b.polygon = PackedVector2Array([Vector2(-10, 0), Vector2(10, 0), Vector2(8, -38), Vector2(-8, -38)])
	b.color = Color(col)
	n.add_child(b)
	var lbl := Polygon2D.new()
	lbl.polygon = PackedVector2Array([Vector2(-8, -10), Vector2(8, -10), Vector2(8, -24), Vector2(-8, -24)])
	lbl.color = Color("F4ECE0")
	n.add_child(lbl)
	var cap := Polygon2D.new()
	cap.polygon = PackedVector2Array([Vector2(-5, -38), Vector2(5, -38), Vector2(5, -50), Vector2(-5, -50)])
	cap.color = Color("2B2B33")
	n.add_child(cap)
	return n

func _diner_milkshake() -> Node2D:
	var n := Node2D.new()
	var glass := Polygon2D.new()
	glass.polygon = PackedVector2Array([Vector2(-22, 0), Vector2(22, 0), Vector2(18, -64), Vector2(-18, -64)])
	glass.color = Color("F7EFE6")
	n.add_child(glass)
	var shake := Polygon2D.new()
	shake.polygon = PackedVector2Array([Vector2(-19, -34), Vector2(19, -34), Vector2(17, -64), Vector2(-17, -64)])
	shake.color = Color("F1A7C4")
	n.add_child(shake)
	var dome := Polygon2D.new()
	dome.polygon = _ellipse_polygon(20, 14, 18); dome.position = Vector2(0, -66)
	dome.color = Color("F7C7DC")
	n.add_child(dome)
	var cherry := Polygon2D.new()
	cherry.polygon = _circle_polygon(7, 14); cherry.position = Vector2(2, -80)
	cherry.color = Color("D7263D")
	n.add_child(cherry)
	var straw := Polygon2D.new()
	straw.polygon = PackedVector2Array([Vector2(10, -70), Vector2(16, -70), Vector2(24, -110), Vector2(18, -110)])
	straw.color = Color("E7322F")
	n.add_child(straw)
	return n

func _diner_pie() -> Node2D:
	# Кусок пирога под стеклянным колпаком.
	var n := Node2D.new()
	var plate := Polygon2D.new()
	plate.polygon = _ellipse_polygon(54, 12, 22); plate.position = Vector2(0, -8)
	plate.color = Color("E9E4DA")
	n.add_child(plate)
	var crust := Polygon2D.new()
	crust.polygon = PackedVector2Array([Vector2(-40, -12), Vector2(40, -12), Vector2(0, -64)])
	crust.color = Color("D79A4E")
	n.add_child(crust)
	var fill := Polygon2D.new()
	fill.polygon = PackedVector2Array([Vector2(-30, -16), Vector2(30, -16), Vector2(0, -50)])
	fill.color = Color("9C3B2E")
	n.add_child(fill)
	var dome := Polygon2D.new()
	dome.polygon = PackedVector2Array([Vector2(-58, -8), Vector2(-58, -60), Vector2(0, -86), Vector2(58, -60), Vector2(58, -8)])
	dome.color = Color(0.8, 0.9, 0.95, 0.18)
	n.add_child(dome)
	return n

func _diner_coffee() -> Node2D:
	var n := Node2D.new()
	var cup := Polygon2D.new()
	cup.polygon = PackedVector2Array([Vector2(-16, 0), Vector2(16, 0), Vector2(13, -26), Vector2(-13, -26)])
	cup.color = Color("F3EFE8")
	n.add_child(cup)
	var handle := Polygon2D.new()
	handle.polygon = _ellipse_polygon(8, 8, 12)
	handle.position = Vector2(20, -12)
	handle.color = Color("CBCBD0")
	n.add_child(handle)
	# пар
	diner_steam = CPUParticles2D.new()
	diner_steam.amount = 12
	diner_steam.lifetime = 2.6
	diner_steam.preprocess = 2.0
	diner_steam.position = Vector2(0, -26)
	diner_steam.direction = Vector2(0.2, -1)
	diner_steam.spread = 8.0
	diner_steam.gravity = Vector2(4, -10)
	diner_steam.initial_velocity_min = 5.0
	diner_steam.initial_velocity_max = 10.0
	diner_steam.scale_amount_min = 0.2
	diner_steam.scale_amount_max = 0.6
	diner_steam.texture = _tex(THEME_DIR + "smoke.svg")
	diner_steam.color = Color(1, 1, 1, 0.5)
	n.add_child(diner_steam)
	return n

func _diner_window() -> Node2D:
	# Окно: хром-рама, за ней ночной город + луна. Большое — на пол-стены.
	var n := Node2D.new()
	var W := 660.0; var H := 380.0
	var frame := Polygon2D.new()
	frame.polygon = PackedVector2Array([Vector2(-W/2-14, -H/2-14), Vector2(W/2+14, -H/2-14), Vector2(W/2+14, H/2+14), Vector2(-W/2-14, H/2+14)])
	frame.color = Color("B9C0C6")
	n.add_child(frame)
	var sky := Polygon2D.new()
	sky.polygon = PackedVector2Array([Vector2(-W/2, -H/2), Vector2(W/2, -H/2), Vector2(W/2, H/2), Vector2(-W/2, H/2)])
	sky.color = Color("1E2746")
	n.add_child(sky)
	var moon := Polygon2D.new()
	moon.polygon = _circle_polygon(46, 28)
	moon.position = Vector2(W/2 - 96, -H/2 + 92)
	moon.color = Color("EFE9D2")
	n.add_child(moon)
	# силуэты домов
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var x := -W/2
	while x < W/2:
		var bw := rng.randf_range(44, 86)
		var bh := rng.randf_range(H * 0.28, H * 0.7)
		var b := Polygon2D.new()
		b.polygon = PackedVector2Array([Vector2(x, H/2), Vector2(x, H/2-bh), Vector2(x+bw, H/2-bh), Vector2(x+bw, H/2)])
		b.color = Color("2B3A63")
		n.add_child(b)
		# окошки
		var wy := H/2 - bh + 10
		while wy < H/2 - 8:
			if rng.randf() < 0.5:
				var lw := Polygon2D.new()
				lw.polygon = PackedVector2Array([Vector2(x+6, wy), Vector2(x+14, wy), Vector2(x+14, wy+8), Vector2(x+6, wy+8)])
				lw.color = Color("F2D479")
				n.add_child(lw)
			wy += 18
		x += bw + rng.randf_range(2, 8)
	# рамные перекладины
	var bar := Polygon2D.new()
	bar.polygon = PackedVector2Array([Vector2(-3, -H/2), Vector2(3, -H/2), Vector2(3, H/2), Vector2(-3, H/2)])
	bar.color = Color("B9C0C6")
	n.add_child(bar)
	return n

func _diner_neon() -> Node2D:
	# Неон-вывеска DINER (розовое свечение).
	var n := Node2D.new()
	var glow := Label.new()
	glow.text = "D I N E R"
	glow.add_theme_font_size_override("font_size", 116)
	glow.add_theme_color_override("font_color", Color("FF7FD0", 0.35))
	glow.position = Vector2(-272, -76)
	n.add_child(glow)
	var lab := Label.new()
	lab.text = "D I N E R"
	lab.add_theme_font_size_override("font_size", 104)
	lab.add_theme_color_override("font_color", Color("FFB3E6"))
	lab.position = Vector2(-266, -70)
	n.add_child(lab)
	# мигание неона
	var tw := n.create_tween().set_loops()
	tw.tween_property(n, "modulate:a", 0.78, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE)
	return n

func _diner_clock() -> Node2D:
	var n := Node2D.new()
	var ring := Polygon2D.new()
	ring.polygon = _circle_polygon(54, 30)
	ring.color = Color("E7322F")
	n.add_child(ring)
	var face := Polygon2D.new()
	face.polygon = _circle_polygon(43, 30)
	face.color = Color("F4EFE6")
	n.add_child(face)
	var hh := Polygon2D.new()
	hh.polygon = PackedVector2Array([Vector2(-4, 6), Vector2(4, 6), Vector2(3, -26), Vector2(-3, -26)])
	hh.color = Color("2B2B33")
	n.add_child(hh)
	var mh := Polygon2D.new()
	mh.polygon = PackedVector2Array([Vector2(-3, 6), Vector2(3, 6), Vector2(22, -3), Vector2(19, -9)])
	mh.color = Color("2B2B33")
	n.add_child(mh)
	return n

func _diner_lamp() -> Node2D:
	# Большой подвесной светильник сверху.
	var n := Node2D.new()
	var cord := Polygon2D.new()
	cord.polygon = PackedVector2Array([Vector2(-3, 0), Vector2(3, 0), Vector2(3, 90), Vector2(-3, 90)])
	cord.color = Color("2B2B33")
	n.add_child(cord)
	var shade := Polygon2D.new()
	shade.polygon = PackedVector2Array([Vector2(-58, 168), Vector2(58, 168), Vector2(32, 90), Vector2(-32, 90)])
	shade.color = Color("E7322F")
	n.add_child(shade)
	var glow := Polygon2D.new()
	glow.polygon = _ellipse_polygon(46, 16, 20)
	glow.position = Vector2(0, 170)
	glow.color = Color("FBE9A8")
	n.add_child(glow)
	return n

func _diner_menu() -> Node2D:
	# Доска-меню на стене (с «надписями»).
	var n := Node2D.new()
	var board := Polygon2D.new()
	board.polygon = PackedVector2Array([Vector2(-110, -84), Vector2(110, -84), Vector2(110, 84), Vector2(-110, 84)])
	board.color = Color("2B2B33")
	n.add_child(board)
	var frame := Polygon2D.new()
	frame.polygon = PackedVector2Array([Vector2(-118, -92), Vector2(118, -92), Vector2(118, 92), Vector2(-118, 92)])
	frame.color = Color("C9A24B")
	n.add_child(frame)
	n.move_child(frame, 0)
	var title := Label.new()
	title.text = "MENU"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("FFB3E6"))
	title.position = Vector2(-52, -78)
	n.add_child(title)
	var lines := ["Pancakes  $5", "Coffee    $2", "Shake     $4", "Pie       $3"]
	for i in range(lines.size()):
		var l := Label.new()
		l.text = lines[i]
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", Color("E9E4DA"))
		l.position = Vector2(-96, -30 + i * 30)
		n.add_child(l)
	return n

func _diner_stool() -> Node2D:
	var n := Node2D.new()
	var seat := Polygon2D.new()
	seat.polygon = _ellipse_polygon(34, 12, 22)
	seat.color = Color("C23B4A")
	n.add_child(seat)
	var post := Polygon2D.new()
	post.polygon = PackedVector2Array([Vector2(-6, 8), Vector2(6, 8), Vector2(6, 120), Vector2(-6, 120)])
	post.color = Color("AAB2B8")
	n.add_child(post)
	return n

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
		var sp := _sprite_scaled_to_width(hand_tex, size.x * 1.1)
		# В hand.svg кончики пальцев ~ y=185 при центре viewBox 105 → +80 от центра.
		sp.position = Vector2(0.0, -size.y / 2.0 - 80.0 * sp.scale.y + 40.0)
		parent.add_child(sp)
		parent.set_meta("hand_node", sp)
		# Лёгкое «дыхание» руки, пока держит камень.
		# Tween привязан к спрайту — гибнет вместе с рукой при броске (без варнингов).
		var by := sp.position.y
		var bt := sp.create_tween().set_loops()
		bt.tween_property(sp, "position:y", by - 6.0, 0.9).set_trans(Tween.TRANS_SINE)
		bt.tween_property(sp, "position:y", by, 0.9).set_trans(Tween.TRANS_SINE)
		return
	# Без арт-руки: ничего не рисуем — камень «несётся» сам (рука убрана по просьбе).

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
