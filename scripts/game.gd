extends Node3D

const MAP_WIDTH = 9
const START_ROW_P1 = 15
const START_COL = 4
const START_ROW_P2 = 1
const FROGS_TO_WIN = 3
const GOAL_ROWS_P1 = [0, 1, 2]
const GOAL_ROWS_P2 = [14, 15, 16]
const JUMP_HEIGHT := 0.8
const AUTO_JUMP_INTERVAL := 0.4

enum GameState { MENU, SEARCHING, COUNTDOWN, PLAYING, GAME_OVER }

var state: GameState = GameState.MENU

var player1: Node3D
var player2: Node3D
var grid_row: int = START_ROW_P1
var grid_col: int = START_COL
var is_on_log: bool = false
var current_log: Node3D = null
var log_offset_x: float = 0.0

var p1_score: int = 0
var p2_score: int = 0
var my_player_num: int = 0
var is_online: bool = false
var is_jumping: bool = false
var jump_tween: Tween
var my_pet_path: String = ""

var opp_on_log: bool = false
var opp_current_log: Node3D = null
var opp_log_offset_x: float = 0.0
var opp_jump_tween: Tween

# UI
var score_label: Label
var status_label: Label
var countdown_label: Label
var menu_layer: CanvasLayer
var game_ui_layer: CanvasLayer
var network: Node

# Carrusel en mundo 3D
var pet_scenes: Array = []
var carousel_nodes: Array = []  # Nodos 3D en el mundo (sin contar el seleccionado)
var carousel_root: Node3D  # Contenedor de los pets del carrusel
var current_pet_index: int = 0
var pet_name_label: Label
const CAROUSEL_SPACING := 1.5
const CAROUSEL_LERP := 8.0
const PET_SCALE := Vector3(0.7, 0.7, 0.7)
const PET_SCALE_SIDE := Vector3(0.45, 0.45, 0.45)

const PET_PATHS = [
	"res://assets/pets/animal-bunny.glb",
	"res://assets/pets/animal-cat.glb",
	"res://assets/pets/animal-dog.glb",
	"res://assets/pets/animal-fox.glb",
	"res://assets/pets/animal-beaver.glb",
	"res://assets/pets/animal-penguin.glb",
	"res://assets/pets/animal-pig.glb",
	"res://assets/pets/animal-cow.glb",
	"res://assets/pets/animal-lion.glb",
	"res://assets/pets/animal-tiger.glb",
	"res://assets/pets/animal-panda.glb",
	"res://assets/pets/animal-koala.glb",
	"res://assets/pets/animal-monkey.glb",
	"res://assets/pets/animal-elephant.glb",
	"res://assets/pets/animal-deer.glb",
	"res://assets/pets/animal-parrot.glb",
	"res://assets/pets/animal-chick.glb",
	"res://assets/pets/animal-bee.glb",
	"res://assets/pets/animal-hog.glb",
	"res://assets/pets/animal-polar.glb",
	"res://assets/pets/animal-crab.glb",
	"res://assets/pets/animal-fish.glb",
	"res://assets/pets/animal-caterpillar.glb",
	"res://assets/pets/animal-giraffe.glb",
]

# Busqueda
var search_timer: float = 0.0
var search_row: int = START_ROW_P1

# Countdown
var countdown_timer: float = 0.0
var countdown_step: int = 3
var countdown_target_row: int = START_ROW_P1
var opp_countdown_row: int = 0
var opp_countdown_target: int = 0
var opp_search_timer: float = 0.0
var gameover_timer: float = 0.0
var gameover_jumping: bool = false

# Match pendiente (espera a que termine el salto y la camara se asiente)
var pending_match: Dictionary = {}
var pending_match_ready: bool = false

@onready var obstacle_manager: Node3D = $Obstacles
@onready var map_node: Node3D = $Map
@onready var camera: Camera3D = $Camera


func _ready():
	player1 = $Players/Player1
	player2 = $Players/Player2
	player2.visible = false

	# Cargar escenas de pets
	for path in PET_PATHS:
		var scene = load(path)
		if scene:
			pet_scenes.append({scene = scene, path = path})

	# Pet aleatorio al inicio
	if pet_scenes.size() > 0:
		current_pet_index = randi() % pet_scenes.size()
		my_pet_path = pet_scenes[current_pet_index].path

	# Solo hierba para el menu (sin mapa real)
	grid_row = 0
	grid_col = START_COL
	map_node.ensure_grass_around(grid_row, 6, 15)
	player1.position = Vector3(grid_col + 0.5, 0.1, grid_row + 0.5)

	# Crear carrusel en el mundo 3D
	_create_carousel()

	# Crear UI
	_create_menu_ui()
	_create_game_ui()

	# Camara sigue al jugador
	camera.follow_single(player1)

	state = GameState.MENU


# --- Carrusel en el mundo 3D ---

func _create_carousel():
	carousel_root = Node3D.new()
	carousel_root.name = "Carousel"
	# El carrusel se posiciona en la misma fila que el jugador
	carousel_root.position = Vector3(grid_col + 0.5, 0.1, grid_row + 0.5)
	add_child(carousel_root)

	for i in range(pet_scenes.size()):
		var instance = pet_scenes[i].scene.instantiate()
		instance.scale = PET_SCALE_SIDE
		instance.position = Vector3((i - current_pet_index) * CAROUSEL_SPACING, 0, 0)
		instance.rotation.y = 0  # mirar hacia la camara
		carousel_root.add_child(instance)
		carousel_nodes.append(instance)

	_update_carousel_selection()


func _update_carousel_selection():
	if pet_scenes.size() == 0:
		return
	my_pet_path = pet_scenes[current_pet_index].path

	# Actualizar nombre
	var filename = my_pet_path.get_file().get_basename()
	if pet_name_label:
		pet_name_label.text = filename.replace("animal-", "").capitalize()


func _process_carousel(delta: float):
	if not carousel_root:
		return
	var total = carousel_nodes.size()
	if total == 0:
		return
	for i in range(total):
		var node = carousel_nodes[i]
		# Calcular offset circular mas corto
		var raw_offset = i - current_pet_index
		if raw_offset > total / 2:
			raw_offset -= total
		elif raw_offset < -total / 2:
			raw_offset += total

		var target_pos = Vector3(raw_offset * CAROUSEL_SPACING, 0, 0)
		node.position = node.position.lerp(target_pos, CAROUSEL_LERP * delta)

		var dist = absf(float(raw_offset))
		var target_scale: Vector3
		if dist < 0.1:
			target_scale = PET_SCALE
		else:
			target_scale = PET_SCALE_SIDE * lerpf(1.0, 0.6, clampf(dist - 1, 0, 2) / 2.0)
		node.scale = node.scale.lerp(target_scale, CAROUSEL_LERP * delta)

		# Ocultar los que estan muy lejos
		node.visible = dist < 5


func _hide_carousel():
	if carousel_root:
		carousel_root.visible = false


func _show_carousel():
	if carousel_root:
		carousel_root.visible = true
		# Reposicionar en la posicion actual del jugador
		carousel_root.position = player1.position


func _destroy_carousel():
	if carousel_root:
		carousel_root.queue_free()
		carousel_root = null
		carousel_nodes.clear()


# --- Setup de personajes ---

func _setup_frog(frog: Node3D, pet_path: String, fallback_color: Color, face_down: bool = false):
	for child in frog.get_children():
		child.queue_free()
	var scene = load(pet_path) if pet_path != "" else null
	if scene:
		var model = scene.instantiate()
		model.name = "Mesh"
		model.scale = PET_SCALE
		model.rotation.y = 0.0 if face_down else PI
		_disable_cast_shadow(model)
		frog.add_child(model)
	else:
		var mesh_node = MeshInstance3D.new()
		mesh_node.name = "Mesh"
		var box = BoxMesh.new()
		box.size = Vector3(0.7, 0.7, 0.7)
		mesh_node.mesh = box
		var shader = load("res://shaders/voxel_outline.gdshader")
		var mat = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("albedo_color", fallback_color)
		mat.set_shader_parameter("edge_width", 3.0)
		mesh_node.material_override = mat
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		frog.add_child(mesh_node)
	_add_shadow(frog)


func _disable_cast_shadow(node: Node):
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_disable_cast_shadow(child)


func _add_shadow(frog: Node3D):
	var shadow = MeshInstance3D.new()
	shadow.name = "Shadow"
	var disc = CylinderMesh.new()
	disc.top_radius = 0.35
	disc.bottom_radius = 0.35
	disc.height = 0.02
	shadow.mesh = disc
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0, 0, 0, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = mat
	shadow.position = Vector3(0, 0.01, 0)
	frog.add_child(shadow)


# --- UI del Menu (solo botones 2D, no el carrusel) ---

func _create_menu_ui():
	menu_layer = CanvasLayer.new()
	menu_layer.name = "MenuUI"
	menu_layer.layer = 10
	add_child(menu_layer)

	# Titulo
	var title = Label.new()
	title.text = "FROG RACE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.anchor_top = 0.03
	title.anchor_bottom = 0.10
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	menu_layer.add_child(title)

	# Nombre del pet
	pet_name_label = Label.new()
	pet_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pet_name_label.anchor_left = 0.0
	pet_name_label.anchor_right = 1.0
	pet_name_label.anchor_top = 0.55
	pet_name_label.anchor_bottom = 0.62
	pet_name_label.add_theme_font_size_override("font_size", 20)
	pet_name_label.add_theme_color_override("font_color", Color.WHITE)
	pet_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	pet_name_label.add_theme_constant_override("shadow_offset_x", 1)
	pet_name_label.add_theme_constant_override("shadow_offset_y", 1)
	menu_layer.add_child(pet_name_label)

	# Flechas
	var nav = HBoxContainer.new()
	nav.anchor_left = 0.5
	nav.anchor_right = 0.5
	nav.anchor_top = 0.63
	nav.anchor_bottom = 0.72
	nav.offset_left = -100
	nav.offset_right = 100
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 40)
	menu_layer.add_child(nav)

	var btn_left = Button.new()
	btn_left.text = "<"
	btn_left.custom_minimum_size = Vector2(60, 50)
	btn_left.add_theme_font_size_override("font_size", 30)
	btn_left.pressed.connect(_carousel_prev)
	nav.add_child(btn_left)

	var btn_right = Button.new()
	btn_right.text = ">"
	btn_right.custom_minimum_size = Vector2(60, 50)
	btn_right.add_theme_font_size_override("font_size", 30)
	btn_right.pressed.connect(_carousel_next)
	nav.add_child(btn_right)

	# Boton PLAY
	var btn_play = Button.new()
	btn_play.text = "PLAY"
	btn_play.custom_minimum_size = Vector2(200, 60)
	btn_play.add_theme_font_size_override("font_size", 28)
	btn_play.anchor_left = 0.5
	btn_play.anchor_right = 0.5
	btn_play.anchor_top = 0.78
	btn_play.anchor_bottom = 0.78
	btn_play.offset_left = -100
	btn_play.offset_right = 100
	btn_play.pressed.connect(_on_play_pressed)
	menu_layer.add_child(btn_play)

	# Info del jugador (ID + rating)
	var device_id = _get_device_id()
	var player_info = Label.new()
	player_info.name = "PlayerInfo"
	player_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_info.anchor_left = 0.0
	player_info.anchor_right = 1.0
	player_info.anchor_top = 0.88
	player_info.anchor_bottom = 0.98
	player_info.add_theme_font_size_override("font_size", 14)
	player_info.add_theme_color_override("font_color", Color("#aaaaaa"))
	player_info.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	player_info.add_theme_constant_override("shadow_offset_x", 1)
	player_info.add_theme_constant_override("shadow_offset_y", 1)
	player_info.text = "ID: %s\nRating: ..." % device_id.substr(0, 8)
	menu_layer.add_child(player_info)

	# Cargar rating del servidor
	_fetch_player_rating(device_id, player_info)

	_update_carousel_selection()


func _carousel_prev():
	current_pet_index = (current_pet_index - 1 + pet_scenes.size()) % pet_scenes.size()
	_update_carousel_selection()

func _carousel_next():
	current_pet_index = (current_pet_index + 1) % pet_scenes.size()
	_update_carousel_selection()


# --- UI del juego ---

func _create_game_ui():
	game_ui_layer = CanvasLayer.new()
	game_ui_layer.name = "GameUI"
	game_ui_layer.layer = 5
	game_ui_layer.visible = false
	add_child(game_ui_layer)

	score_label = Label.new()
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	score_label.anchor_left = 0.0
	score_label.anchor_right = 1.0
	score_label.offset_top = 10
	score_label.offset_bottom = 60
	score_label.add_theme_font_size_override("font_size", 28)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	score_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	score_label.add_theme_constant_override("shadow_offset_x", 2)
	score_label.add_theme_constant_override("shadow_offset_y", 2)
	score_label.visible = false
	game_ui_layer.add_child(score_label)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.anchor_left = 0.0
	status_label.anchor_right = 1.0
	status_label.anchor_top = 0.0
	status_label.anchor_bottom = 1.0
	status_label.add_theme_font_size_override("font_size", 28)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	status_label.add_theme_constant_override("shadow_offset_x", 2)
	status_label.add_theme_constant_override("shadow_offset_y", 2)
	game_ui_layer.add_child(status_label)

	countdown_label = Label.new()
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.anchor_left = 0.0
	countdown_label.anchor_right = 1.0
	countdown_label.anchor_top = 0.0
	countdown_label.anchor_bottom = 1.0
	countdown_label.add_theme_font_size_override("font_size", 72)
	countdown_label.add_theme_color_override("font_color", Color.WHITE)
	countdown_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	countdown_label.add_theme_constant_override("shadow_offset_x", 3)
	countdown_label.add_theme_constant_override("shadow_offset_y", 3)
	countdown_label.visible = false
	game_ui_layer.add_child(countdown_label)


func _set_status(text: String):
	status_label.text = text
	status_label.visible = text != ""

func _update_score_label():
	score_label.text = "P1: %d/%d    P2: %d/%d" % [p1_score, FROGS_TO_WIN, p2_score, FROGS_TO_WIN]


# --- PLAY ---

func _on_play_pressed():
	# Ocultar carrusel, dejar solo el pet seleccionado como player1
	_hide_carousel()
	# No llamar _setup_frog: reusar el modelo actual del carrusel central
	# Solo limpiar hijos existentes y crear el modelo como hijo de player1
	for child in player1.get_children():
		child.queue_free()
	var pet_scene = load(my_pet_path)
	if pet_scene:
		var model = pet_scene.instantiate()
		model.name = "Mesh"
		model.scale = PET_SCALE
		model.rotation.y = 0  # empieza mirando a camara, girara con el salto
		_disable_cast_shadow(model)
		player1.add_child(model)
	_add_shadow(player1)
	player1.position = Vector3(grid_col + 0.5, 0.1, grid_row + 0.5)

	menu_layer.visible = false
	game_ui_layer.visible = true
	_set_status("Connecting...")

	search_row = grid_row
	search_timer = 0.0
	state = GameState.SEARCHING

	# Conectar al servidor
	network = preload("res://scripts/network.gd").new()
	network.name = "Network"
	add_child(network)

	network.connected.connect(_on_connected)
	network.waiting.connect(_on_waiting)
	network.match_found.connect(_on_match_found)
	network.opponent_moved.connect(_on_opponent_moved)
	network.opponent_died.connect(_on_opponent_died)
	network.opponent_disconnected.connect(_on_opponent_disconnected)
	network.opponent_respawned.connect(_on_opponent_respawned)
	network.score_updated.connect(_on_score_updated)
	network.game_over.connect(_on_game_over)
	network.tick_received.connect(_on_tick)
	network.connection_failed.connect(_on_connection_failed)

	network.connect_to_server()


func _cancel_search():
	if network:
		network.disconnect_from_server()
		network.queue_free()
		network = null

	_set_status("")
	state = GameState.MENU

	# Girar personaje hacia abajo y saltar de vuelta
	if player1.get_child_count() > 0:
		player1.get_child(0).rotation.y = 0

	var target = Vector3(START_COL + 0.5, 0.1, START_ROW_P1 + 0.5)
	var return_tween = create_tween()
	return_tween.tween_property(player1, "position", target, 0.5).set_ease(Tween.EASE_IN_OUT)
	return_tween.tween_callback(func():
		grid_row = START_ROW_P1
		grid_col = START_COL
		search_row = START_ROW_P1
		map_node.ensure_grass_around(grid_row, 6, 3)
		if player1.get_child_count() > 0:
			player1.get_child(0).rotation.y = PI
		_show_carousel()
		_create_carousel()
		_update_carousel_selection()
		menu_layer.visible = true
		game_ui_layer.visible = false
	)


# --- Network callbacks ---

func _on_connected():
	_set_status("Finding match...")
	network.send_find_match(my_pet_path, _get_device_id())

func _on_waiting():
	_set_status("Waiting for opponent...")

func _on_match_found(player_num: int, _game_seed: int, opponent_pet: String, init_obstacles: Array = []):
	# SIEMPRE diferir — aplicar despues del siguiente salto para que sea fluido
	pending_match = {
		player_num = player_num,
		game_seed = _game_seed,
		opponent_pet = opponent_pet,
		init_obstacles = init_obstacles,
	}


func _apply_match_found(player_num: int, _game_seed: int, opponent_pet: String, init_obstacles: Array = []):
	my_player_num = player_num
	is_online = true
	_set_status("")

	# GUARDAR posicion y size de la camara ANTES de tocar nada
	var saved_cam_pos = camera.global_position
	var saved_cam_size = camera.size
	var _saved_cam_rot = camera.rotation

	_destroy_carousel()

	# Flip de camara para P2 ANTES de generar el mapa
	# Como el personaje esta en hierba simetrica, el flip es invisible
	if my_player_num == 2:
		camera.flip_for_player2()

	map_node.generate_real_map()

	# Configurar personajes
	if my_player_num == 1:
		_setup_frog(player1, my_pet_path, Color("#00cc44"), false)
		_setup_frog(player2, opponent_pet, Color("#cc0000"), true)
	else:
		_setup_frog(player2, my_pet_path, Color("#00cc44"), true)
		_setup_frog(player1, opponent_pet, Color("#cc0000"), false)

	obstacle_manager.clear_all()

	# Ambos jugadores empiezan a 5 saltos de su posicion
	# 5 * 0.4s = 2s para llegar, justo antes del "1"
	var walk_steps = 5
	if my_player_num == 1:
		grid_row = START_ROW_P1 + walk_steps
		countdown_target_row = START_ROW_P1
	else:
		grid_row = START_ROW_P2 - walk_steps
		countdown_target_row = START_ROW_P2
	grid_col = START_COL
	var me = player1 if my_player_num == 1 else player2
	me.position = Vector3(grid_col + 0.5, 0.1, grid_row + 0.5)

	# Oponente tambien empieza fuera y camina hasta su posicion
	var opp = player2 if my_player_num == 1 else player1
	var opp_start = START_ROW_P2 if my_player_num == 1 else START_ROW_P1
	var opp_offset = -walk_steps if my_player_num == 1 else walk_steps
	opp_countdown_row = opp_start + opp_offset
	opp_countdown_target = opp_start
	opp.position = Vector3(START_COL + 0.5, 0.1, opp_countdown_row + 0.5)
	player1.visible = true
	player2.visible = true

	# RESTAURAR camara a la posicion exacta donde estaba
	# Para P2 restaurar posicion pero mantener la nueva rotacion (flipped)
	camera.global_position = saved_cam_pos
	camera.size = saved_cam_size
	camera.follow_single(me)

	# La camara NO transiciona aun — sigue al jugador
	# La transicion empieza cuando aparece el "2"

	# Countdown empieza YA
	state = GameState.COUNTDOWN
	countdown_step = 3
	countdown_timer = 0.0
	countdown_label.visible = true
	countdown_label.text = "3"
	search_timer = 0.0

	# Camara empieza a moverse YA — 3s para llegar antes del GO!
	camera.transition_to_both(3.0)

func _on_opponent_moved(opp_row: int, opp_col: int):
	var opp = player2 if my_player_num == 1 else player1
	var target = Vector3(opp_col + 0.5, _get_row_height(opp_row), opp_row + 0.5)
	opp_on_log = false
	opp_current_log = null
	_animate_opponent_jump(opp, target)

func _on_opponent_died():
	var opp = player2 if my_player_num == 1 else player1
	var opp_start = START_ROW_P2 if my_player_num == 1 else START_ROW_P1
	opp_on_log = false
	opp_current_log = null

	if opp.get_child_count() == 0:
		opp.position = Vector3(START_COL + 0.5, _get_row_height(opp_start), opp_start + 0.5)
		return

	var mesh: Node3D = opp.get_child(0)
	var base_scale: Vector3 = mesh.scale
	var opp_row = int(opp.position.z)

	# Detectar tipo de muerte por la fila donde esta
	var is_water = (opp_row >= 7 and opp_row <= 9)

	if is_water:
		_spawn_splash(opp.position)
		var death_tween = create_tween()
		death_tween.tween_property(opp, "position:y", opp.position.y + 0.6, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		death_tween.parallel().tween_property(mesh, "scale", Vector3(base_scale.x * 0.6, base_scale.y * 1.5, base_scale.z * 0.6), 0.12).set_ease(Tween.EASE_OUT)
		death_tween.tween_property(opp, "position:y", opp.position.y - 0.5, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		death_tween.parallel().tween_property(mesh, "scale", Vector3.ZERO, 0.2).set_ease(Tween.EASE_IN)
		death_tween.tween_interval(0.2)
		death_tween.tween_callback(func():
			mesh.scale = base_scale
			opp.position = Vector3(START_COL + 0.5, _get_row_height(opp_start), opp_start + 0.5)
			_opp_spawn_anim(opp, mesh, base_scale)
		)
	else:
		var death_tween = create_tween()
		death_tween.tween_property(mesh, "scale", Vector3(base_scale.x * 1.8, base_scale.y * 0.1, base_scale.z * 1.8), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		death_tween.tween_interval(0.3)
		death_tween.tween_property(mesh, "scale", Vector3.ZERO, 0.15).set_ease(Tween.EASE_IN)
		death_tween.tween_callback(func():
			mesh.scale = base_scale
			opp.position = Vector3(START_COL + 0.5, _get_row_height(opp_start), opp_start + 0.5)
			_opp_spawn_anim(opp, mesh, base_scale)
		)


func _opp_spawn_anim(opp: Node3D, mesh: Node3D, base_scale: Vector3):
	mesh.scale = Vector3(0.01, 0.01, 0.01)
	var spawn_tween = create_tween()
	spawn_tween.tween_property(mesh, "scale", base_scale * Vector3(1.0, 1.3, 1.0), 0.1).set_ease(Tween.EASE_OUT)
	spawn_tween.tween_property(mesh, "scale", base_scale, 0.1).set_ease(Tween.EASE_IN_OUT)

func _on_opponent_respawned():
	var opp = player2 if my_player_num == 1 else player1
	var opp_start = START_ROW_P2 if my_player_num == 1 else START_ROW_P1
	opp_on_log = false
	opp_current_log = null

	if opp.get_child_count() == 0:
		opp.position = Vector3(START_COL + 0.5, _get_row_height(opp_start), opp_start + 0.5)
		return

	var mesh: Node3D = opp.get_child(0)
	var base_scale: Vector3 = mesh.scale
	var dir_z = -1 if my_player_num == 2 else 1  # el oponente va en la otra direccion

	# Crear clon que salta hacia la meta
	var opp_pet_path = ""
	# Intentar obtener el pet del oponente
	if opp.get_child_count() > 0:
		var clone = opp.get_child(0).duplicate()
		clone.position = opp.position
		add_child(clone)
		var goal_tween = create_tween()
		for i in range(6):
			var target_z = clone.position.z + dir_z * (i + 1)
			var mid_y = clone.position.y + JUMP_HEIGHT
			goal_tween.tween_property(clone, "position:z", target_z, 0.07).set_ease(Tween.EASE_IN_OUT)
			goal_tween.parallel().tween_property(clone, "position:y", mid_y, 0.035).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			goal_tween.chain().tween_property(clone, "position:y", opp.position.y, 0.035).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			goal_tween.tween_interval(0.1)
		goal_tween.tween_callback(clone.queue_free)

	# Respawnear oponente con squeeze
	opp.position = Vector3(START_COL + 0.5, _get_row_height(opp_start), opp_start + 0.5)
	mesh.scale = Vector3(0.01, 0.01, 0.01)
	var spawn_tween = create_tween()
	spawn_tween.tween_property(mesh, "scale", base_scale * Vector3(1.5, 0.3, 1.5), 0.08).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	spawn_tween.tween_property(mesh, "scale", base_scale * Vector3(0.7, 1.5, 0.7), 0.1).set_ease(Tween.EASE_OUT)
	spawn_tween.tween_property(mesh, "scale", base_scale * Vector3(1.2, 0.8, 1.2), 0.06).set_ease(Tween.EASE_IN_OUT)
	spawn_tween.tween_property(mesh, "scale", base_scale, 0.08).set_ease(Tween.EASE_IN_OUT)

func _on_opponent_disconnected():
	_on_game_over(my_player_num)

func _on_score_updated(player_num: int, score: int):
	if player_num == 1:
		p1_score = score
	else:
		p2_score = score
	_update_score_label()

func _on_game_over(winner: int):
	state = GameState.GAME_OVER

	# Crear UI de resultado
	var result_layer = CanvasLayer.new()
	result_layer.name = "ResultUI"
	result_layer.layer = 20
	add_child(result_layer)

	# Fondo semitransparente
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_layer.add_child(bg)

	# Contenedor centrado
	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_top = 0.3
	vbox.anchor_bottom = 0.7
	vbox.offset_left = -120
	vbox.offset_right = 120
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	result_layer.add_child(vbox)

	# Titulo
	var title = Label.new()
	var is_winner = (winner == my_player_num)
	title.text = "YOU WIN!" if is_winner else "YOU LOSE!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("#00cc44") if is_winner else Color("#cc0000"))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(title)

	# Score final
	var score_text = Label.new()
	score_text.text = "P1: %d  -  P2: %d" % [p1_score, p2_score]
	score_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_text.add_theme_font_size_override("font_size", 24)
	score_text.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(score_text)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	# Boton Volver a jugar
	var btn_rematch = Button.new()
	btn_rematch.text = "PLAY AGAIN"
	btn_rematch.custom_minimum_size = Vector2(200, 50)
	btn_rematch.add_theme_font_size_override("font_size", 22)
	btn_rematch.pressed.connect(func():
		_fade_and_do(result_layer, _go_to_search)
	)
	vbox.add_child(btn_rematch)

	# Boton Lobby
	var btn_lobby = Button.new()
	btn_lobby.text = "LOBBY"
	btn_lobby.custom_minimum_size = Vector2(200, 50)
	btn_lobby.add_theme_font_size_override("font_size", 22)
	btn_lobby.pressed.connect(func():
		_fade_and_do(result_layer, _restart_to_menu)
	)
	vbox.add_child(btn_lobby)


func _fade_and_do(result_layer: CanvasLayer, callback: Callable):
	# Fade negro
	var fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.anchor_right = 1.0
	fade.anchor_bottom = 1.0
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	result_layer.add_child(fade)

	var tween = create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		callback.call()
		# Fade out
		var fade_out = ColorRect.new()
		fade_out.color = Color(0, 0, 0, 1)
		fade_out.anchor_right = 1.0
		fade_out.anchor_bottom = 1.0
		fade_out.mouse_filter = Control.MOUSE_FILTER_IGNORE
		game_ui_layer.add_child(fade_out)
		var tween2 = create_tween()
		tween2.tween_property(fade_out, "color:a", 0.0, 0.5).set_ease(Tween.EASE_OUT)
		tween2.tween_callback(fade_out.queue_free)
	)


func _go_to_search():
	# Limpiar resultado
	var result_node = get_node_or_null("ResultUI")
	if result_node:
		result_node.queue_free()

	if network:
		network.disconnect_from_server()
		network.queue_free()
		network = null

	obstacle_manager.clear_all()
	map_node.clear_real_map()

	p1_score = 0
	p2_score = 0
	my_player_num = 0
	is_online = false
	is_jumping = false
	is_on_log = false
	score_label.visible = false

	# Posicionar en hierba
	player2.visible = false
	grid_row = 0
	grid_col = START_COL
	map_node.ensure_grass_around(grid_row, 6, 15)
	player1.position = Vector3(grid_col + 0.5, 0.1, grid_row + 0.5)
	_setup_frog(player1, my_pet_path, Color("#00cc44"), false)
	camera.follow_single(player1)

	# Ir directamente a buscar partida
	game_ui_layer.visible = true
	_set_status("Connecting...")
	search_row = grid_row
	search_timer = 0.0
	state = GameState.SEARCHING

	network = preload("res://scripts/network.gd").new()
	network.name = "Network"
	add_child(network)
	network.connected.connect(_on_connected)
	network.waiting.connect(_on_waiting)
	network.match_found.connect(_on_match_found)
	network.opponent_moved.connect(_on_opponent_moved)
	network.opponent_died.connect(_on_opponent_died)
	network.opponent_disconnected.connect(_on_opponent_disconnected)
	network.opponent_respawned.connect(_on_opponent_respawned)
	network.score_updated.connect(_on_score_updated)
	network.game_over.connect(_on_game_over)
	network.tick_received.connect(_on_tick)
	network.connection_failed.connect(_on_connection_failed)
	network.connect_to_server()

func _on_tick(obstacles: Array):
	# Solo procesar cuando el countdown ya muestra numeros o estamos jugando
	if state == GameState.PLAYING:
		obstacle_manager.apply_tick(obstacles)
	elif state == GameState.COUNTDOWN and countdown_step >= 0:
		obstacle_manager.apply_tick(obstacles)

func _on_connection_failed():
	my_player_num = 1
	is_online = false
	_destroy_carousel()
	map_node.clear_infinite()
	map_node.generate_real_map()
	obstacle_manager.clear_all()
	_setup_frog(player1, my_pet_path, Color("#00cc44"), false)
	_setup_frog(player2, "", Color("#cc0000"), true)
	grid_row = START_ROW_P1
	grid_col = START_COL
	_update_my_position()
	player1.visible = true
	player2.visible = true
	player2.position = Vector3(START_COL + 0.5, _get_row_height(START_ROW_P2), START_ROW_P2 + 0.5)
	camera.follow_both()
	_start_playing()


# --- Process ---

func _process(delta):
	match state:
		GameState.MENU:
			_process_carousel(delta)
		GameState.SEARCHING:
			_process_searching(delta)
		GameState.COUNTDOWN:
			_process_countdown(delta)
		GameState.PLAYING:
			_process_playing(delta)


func _process_searching(delta):
	if is_jumping:
		return

	# Esperar a que la camara se asiente antes de aplicar el match
	if pending_match_ready:
		var me = player1
		var cam_target = me.global_position + camera.basis.z * camera.VIEW_DISTANCE
		var cam_dist = camera.global_position.distance_to(cam_target)
		# No saltar mas — esperar a la camara
		if cam_dist < 0.3:
			var pm = pending_match
			pending_match = {}
			pending_match_ready = false
			_apply_match_found(pm.player_num, pm.game_seed, pm.opponent_pet, pm.init_obstacles)
		return  # No hacer mas saltos mientras espera

	search_timer += delta
	if search_timer >= AUTO_JUMP_INTERVAL:
		search_timer = 0.0
		# Saltar hacia -Z (arriba en pantalla)
		grid_row -= 1
		grid_col = START_COL
		# Generar hierba por delante (-Z) y limpiar por detras
		map_node.ensure_grass_around(grid_row, 6, 6)
		var target = Vector3(grid_col + 0.5, 0.1, grid_row + 0.5)
		_animate_jump(target, Vector2(0, -1))


func _process_countdown(delta):
	# Caminar hacia la posicion de inicio (en paralelo con countdown)
	# P1: grid_row > target (camina -Z, decrementa)
	# P2: grid_row < target (camina +Z, incrementa)
	var arrived = (grid_row == countdown_target_row)
	if not arrived and not is_jumping:
		search_timer = minf(search_timer + delta, AUTO_JUMP_INTERVAL)
		if search_timer >= AUTO_JUMP_INTERVAL:
			search_timer = 0.0
			var step_dir: int
			var move_dir_v: Vector2
			if grid_row > countdown_target_row:
				step_dir = -1
				move_dir_v = Vector2(0, -1)
			else:
				step_dir = 1
				move_dir_v = Vector2(0, 1)
			grid_row += step_dir
			grid_col = START_COL
			map_node.ensure_grass_around(grid_row, 3, 3)
			var y = _get_row_height(grid_row)
			var target = Vector3(grid_col + 0.5, y, grid_row + 0.5)
			_animate_jump(target, move_dir_v)

			if grid_row == countdown_target_row:
				map_node.clear_infinite()

	# Auto-walk del oponente (misma cadencia)
	if opp_countdown_row != opp_countdown_target:
		opp_search_timer = minf(opp_search_timer + delta, AUTO_JUMP_INTERVAL)
		if opp_search_timer >= AUTO_JUMP_INTERVAL:
			opp_search_timer = 0.0
			var opp = player2 if my_player_num == 1 else player1
			var opp_step: int
			var opp_dir_v: Vector2
			if opp_countdown_row > opp_countdown_target:
				opp_step = -1
				opp_dir_v = Vector2(0, -1)
			else:
				opp_step = 1
				opp_dir_v = Vector2(0, 1)
			opp_countdown_row += opp_step
			var opp_y = _get_row_height(opp_countdown_row)
			var opp_target = Vector3(START_COL + 0.5, opp_y, opp_countdown_row + 0.5)
			_animate_opponent_jump(opp, opp_target)

	# Countdown 3, 2, 1, GO! (corre desde el principio)
	countdown_timer += delta
	if countdown_timer >= 1.0:
		countdown_timer = 0.0
		countdown_step -= 1
		if countdown_step > 0:
			countdown_label.text = str(countdown_step)
		elif countdown_step == 0:
			countdown_label.text = "GO!"
		else:
			countdown_label.visible = false
			_start_playing()


func _start_playing():
	state = GameState.PLAYING
	camera.lerp_speed = 5.0
	map_node.clear_infinite()
	score_label.visible = true

	var player_label = Label.new()
	player_label.text = "You are P%d" % my_player_num
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player_label.anchor_left = 0.0
	player_label.anchor_right = 1.0
	player_label.anchor_top = 0.0
	player_label.offset_top = 10
	player_label.offset_right = -10
	player_label.add_theme_font_size_override("font_size", 18)
	player_label.add_theme_color_override("font_color", Color("#ffcc00"))
	player_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	player_label.add_theme_constant_override("shadow_offset_x", 1)
	player_label.add_theme_constant_override("shadow_offset_y", 1)
	game_ui_layer.add_child(player_label)
	p1_score = 0
	p2_score = 0
	_update_score_label()
	_set_status("")


func _process_playing(delta):
	if is_jumping:
		return

	var me = player1 if my_player_num == 1 else player2

	if grid_row >= 7 and grid_row <= 9 and not is_jumping:
		if is_on_log and current_log and is_instance_valid(current_log):
			me.position.x = current_log.position.x + log_offset_x
			grid_col = int(me.position.x)
			if me.position.x < -1 or me.position.x > MAP_WIDTH + 1:
				_die_water()
				return
			var half_w = current_log.mesh.size.x / 2.0 if current_log is MeshInstance3D else 1.5
			if absf(log_offset_x) > half_w:
				var other_log = obstacle_manager.get_log_at(grid_row, me.position.x)
				if other_log:
					current_log = other_log
					log_offset_x = me.position.x - other_log.position.x
				else:
					is_on_log = false
					current_log = null
					_die_water()
					return
		else:
			var log_node = obstacle_manager.get_log_at(grid_row, me.position.x)
			if log_node:
				is_on_log = true
				current_log = log_node
				log_offset_x = me.position.x - log_node.position.x
			else:
				is_on_log = false
				current_log = null
				_die_water()
				return

	_check_car_collision()
	_update_opponent_log()


# --- Input ---

func _input(event: InputEvent) -> void:
	match state:
		GameState.MENU:
			_input_menu(event)
		GameState.SEARCHING:
			_input_searching(event)
		GameState.PLAYING:
			_input_playing(event)
		GameState.GAME_OVER:
			_input_game_over(event)

func _input_menu(event: InputEvent):
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_LEFT, KEY_A:
			_carousel_prev()
		KEY_RIGHT, KEY_D:
			_carousel_next()
		KEY_ENTER, KEY_SPACE:
			_on_play_pressed()

func _input_searching(event: InputEvent):
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		_cancel_search()

func _input_playing(event: InputEvent):
	if is_jumping:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var pdir := 1 if my_player_num == 1 else -1
	var move_dir := Vector2.ZERO
	var moved := false
	match event.physical_keycode:
		KEY_UP, KEY_W:
			grid_row -= pdir
			move_dir = Vector2(0, -pdir)
			moved = true
		KEY_DOWN, KEY_S:
			grid_row += pdir
			move_dir = Vector2(0, pdir)
			moved = true
		KEY_LEFT, KEY_A:
			grid_col -= pdir
			move_dir = Vector2(-pdir, 0)
			moved = true
		KEY_RIGHT, KEY_D:
			grid_col += pdir
			move_dir = Vector2(pdir, 0)
			moved = true
	if moved:
		grid_row = clampi(grid_row, 0, 16)
		grid_col = clampi(grid_col, 0, MAP_WIDTH - 1)
		is_on_log = false
		current_log = null
		var target_pos = Vector3(grid_col + 0.5, _get_row_height(grid_row), grid_row + 0.5)
		_animate_jump(target_pos, move_dir)
		if is_online and network:
			network.send_move(grid_row, grid_col)

func _input_game_over(_event: InputEvent):
	pass  # Los botones manejan la interaccion


# --- Alturas ---

func _fetch_player_rating(device_id: String, label: Label):
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, code, headers, body):
		if code == 200:
			var json = JSON.parse_string(body.get_string_from_utf8())
			if json:
				label.text = "ID: %s\nRating: %d  |  W: %d  L: %d" % [
					device_id.substr(0, 8),
					json.get("rating", 0),
					json.get("wins", 0),
					json.get("losses", 0),
				]
		http.queue_free()
	)
	http.request("http://localhost:3000/api/player/" + device_id)


func _get_device_id() -> String:
	var path = "user://device_id.txt"
	# Si se pasa --player2 como argumento, usar otro archivo
	if "--player2" in OS.get_cmdline_args():
		path = "user://device_id_p2.txt"

	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var id = file.get_as_text().strip_edges()
		file.close()
		return id
	else:
		var id = ""
		for i in range(32):
			id += "0123456789abcdef"[randi() % 16]
		var file = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(id)
		file.close()
		return id


func _get_row_height(row: int) -> float:
	if row < 0: return 0.1   # hierba extra arriba
	if row <= 2: return 0.1
	if row <= 5: return 0.0
	if row == 6: return 0.1
	if row <= 9: return -0.1
	if row == 10: return 0.1
	if row <= 13: return 0.0
	if row <= 16: return 0.1
	return 0.1                # hierba extra abajo


# --- Posiciones ---

func _update_my_position():
	var me = player1 if my_player_num == 1 else player2
	me.position = Vector3(grid_col + 0.5, _get_row_height(grid_row), grid_row + 0.5)

func _update_opponent_log():
	if opp_jump_tween and opp_jump_tween.is_running():
		return
	var opp = player2 if my_player_num == 1 else player1
	var opp_row = int(opp.position.z)
	if opp_row < 7 or opp_row > 9:
		opp_on_log = false
		opp_current_log = null
		return
	if opp_on_log and opp_current_log and is_instance_valid(opp_current_log):
		opp.position.x = opp_current_log.position.x + opp_log_offset_x
	else:
		var log_node = obstacle_manager.get_log_at(opp_row, opp.position.x)
		if log_node:
			opp_on_log = true
			opp_current_log = log_node
			opp_log_offset_x = opp.position.x - log_node.position.x
		else:
			opp_on_log = false
			opp_current_log = null


# --- Animaciones de salto ---

func _animate_jump(target_pos: Vector3, move_dir: Vector2 = Vector2.ZERO):
	var me = player1 if my_player_num == 1 else player2
	# Durante busqueda siempre mover player1
	if state == GameState.SEARCHING:
		me = player1
	if me.get_child_count() == 0:
		me.position = target_pos
		return
	var mesh: Node3D = me.get_child(0)
	var base_scale: Vector3 = mesh.scale
	is_jumping = true
	if jump_tween and jump_tween.is_valid():
		jump_tween.kill()
	jump_tween = create_tween()
	# Girar suavemente hacia la direccion de movimiento durante el squeeze
	if move_dir != Vector2.ZERO:
		var target_angle = atan2(move_dir.x, move_dir.y)
		jump_tween.tween_property(mesh, "rotation:y", target_angle, 0.04).set_ease(Tween.EASE_IN_OUT)
	var sq_out = base_scale * Vector3(1.3, 0.6, 1.3)
	jump_tween.parallel().tween_property(mesh, "scale", sq_out, 0.04).set_ease(Tween.EASE_OUT)
	jump_tween.tween_callback(_do_jump_arc.bind(me, mesh, base_scale, me.position, target_pos))

func _do_jump_arc(me: Node3D, mesh: Node3D, base_scale: Vector3, _start_pos: Vector3, target_pos: Vector3):
	var arc_tween = create_tween()
	arc_tween.set_parallel(true)
	arc_tween.tween_property(mesh, "scale", base_scale, 0.07).set_ease(Tween.EASE_OUT)
	arc_tween.tween_property(me, "position:x", target_pos.x, 0.07).set_ease(Tween.EASE_IN_OUT)
	arc_tween.tween_property(me, "position:z", target_pos.z, 0.07).set_ease(Tween.EASE_IN_OUT)
	var mid_y = target_pos.y + JUMP_HEIGHT
	arc_tween.tween_property(me, "position:y", mid_y, 0.035).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	arc_tween.chain().tween_property(me, "position:y", target_pos.y, 0.035).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	arc_tween.chain().tween_callback(_do_land_squeeze.bind(me, mesh, base_scale, target_pos))

func _do_land_squeeze(me: Node3D, mesh: Node3D, base_scale: Vector3, target_pos: Vector3):
	me.position = target_pos
	var land_tween = create_tween()
	land_tween.tween_property(mesh, "scale", base_scale * Vector3(1.2, 0.5, 1.2), 0.02).set_ease(Tween.EASE_OUT)
	land_tween.tween_property(mesh, "scale", base_scale, 0.03).set_ease(Tween.EASE_OUT)
	land_tween.tween_callback(_on_jump_finished)

func _on_jump_finished():
	is_jumping = false

	# Si hay un match pendiente, esperar a que la camara se asiente
	if pending_match.size() > 0:
		pending_match_ready = true
		return

	if state == GameState.PLAYING:
		_check_hazards()
		_check_goal()

func _animate_opponent_jump(opp: Node3D, target_pos: Vector3):
	opp_on_log = false
	opp_current_log = null
	if opp.get_child_count() == 0:
		opp.position = target_pos
		return
	var mesh: Node3D = opp.get_child(0)
	var base_scale: Vector3 = mesh.scale
	var diff_x = target_pos.x - opp.position.x
	var diff_z = target_pos.z - opp.position.z
	if absf(diff_x) > 0.01 or absf(diff_z) > 0.01:
		mesh.rotation.y = atan2(diff_x, diff_z)
	if opp_jump_tween and opp_jump_tween.is_valid():
		opp_jump_tween.kill()
	opp_jump_tween = create_tween()
	opp_jump_tween.tween_property(mesh, "scale", base_scale * Vector3(1.3, 0.6, 1.3), 0.04)
	opp_jump_tween.set_parallel(true)
	opp_jump_tween.tween_property(mesh, "scale", base_scale, 0.07).set_ease(Tween.EASE_OUT).set_delay(0.04)
	opp_jump_tween.tween_property(opp, "position:x", target_pos.x, 0.07).set_ease(Tween.EASE_IN_OUT).set_delay(0.04)
	opp_jump_tween.tween_property(opp, "position:z", target_pos.z, 0.07).set_ease(Tween.EASE_IN_OUT).set_delay(0.04)
	opp_jump_tween.tween_property(opp, "position:y", target_pos.y + JUMP_HEIGHT, 0.035).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD).set_delay(0.04)
	opp_jump_tween.chain().tween_property(opp, "position:y", target_pos.y, 0.035).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	opp_jump_tween.set_parallel(false)
	opp_jump_tween.tween_property(mesh, "scale", base_scale * Vector3(1.2, 0.5, 1.2), 0.02)
	opp_jump_tween.tween_property(mesh, "scale", base_scale, 0.03)


# --- Logica de juego ---

func _cancel_jump():
	is_jumping = false
	if jump_tween and jump_tween.is_valid():
		jump_tween.kill()
	var me = player1 if my_player_num == 1 else player2
	if me.get_child_count() > 0:
		me.get_child(0).scale = PET_SCALE

func _check_hazards():
	var me = player1 if my_player_num == 1 else player2
	if grid_row >= 7 and grid_row <= 9:
		var log_node = obstacle_manager.get_log_at(grid_row, me.position.x)
		if log_node:
			is_on_log = true
			current_log = log_node
			log_offset_x = me.position.x - log_node.position.x
		else:
			is_on_log = false
			current_log = null
			_die_water()
	else:
		is_on_log = false
		current_log = null

func _check_car_collision():
	var me = player1 if my_player_num == 1 else player2
	if (grid_row >= 3 and grid_row <= 5) or (grid_row >= 11 and grid_row <= 13):
		if obstacle_manager.is_car_at(grid_row, me.position.x):
			_die_car()

func _check_goal():
	var goal_rows = GOAL_ROWS_P1 if my_player_num == 1 else GOAL_ROWS_P2
	if grid_row in goal_rows:
		# Detectar si es el gol ganador antes de enviar
		var my_score = p1_score if my_player_num == 1 else p2_score
		var is_winning_goal = (my_score + 1) >= FROGS_TO_WIN

		if is_online and network:
			network.send_scored()
		else:
			p1_score += 1
			_update_score_label()
			if is_winning_goal:
				_on_game_over(1)

		if not is_winning_goal:
			_goal_animation()

func _goal_animation():
	var me = player1 if my_player_num == 1 else player2
	var dir_z = -1 if my_player_num == 1 else 1  # J1 va hacia -Z, J2 hacia +Z

	# Crear un clon del modelo que salta solo hacia la meta
	if me.get_child_count() > 0 and my_pet_path != "":
		var clone_scene = load(my_pet_path)
		if clone_scene:
			var clone = clone_scene.instantiate()
			clone.scale = PET_SCALE
			clone.rotation.y = me.get_child(0).rotation.y
			clone.position = me.position
			add_child(clone)

			# Animar: 6 saltos consecutivos hacia la meta
			var goal_tween = create_tween()
			for i in range(6):
				var target_z = clone.position.z + dir_z * (i + 1)
				var target_pos = Vector3(clone.position.x, clone.position.y, target_z)
				var mid_y = clone.position.y + JUMP_HEIGHT
				# Subir
				goal_tween.tween_property(clone, "position:z", target_pos.z, 0.07).set_ease(Tween.EASE_IN_OUT)
				goal_tween.parallel().tween_property(clone, "position:y", mid_y, 0.035).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
				goal_tween.chain().tween_property(clone, "position:y", clone.position.y, 0.035).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
				# Pausa entre saltos
				goal_tween.tween_interval(0.1)
			# Eliminar al final
			goal_tween.tween_callback(clone.queue_free)

	# Respawnear el personaje real inmediatamente
	_respawn()


func _die_car():
	_cancel_jump()
	is_on_log = false
	current_log = null
	is_jumping = true

	var me = player1 if my_player_num == 1 else player2
	if me.get_child_count() == 0:
		_do_respawn()
		return

	var mesh: Node3D = me.get_child(0)
	var base_scale: Vector3 = mesh.scale

	# Animacion de aplastamiento por coche
	var death_tween = create_tween()
	death_tween.tween_property(mesh, "scale", Vector3(base_scale.x * 1.8, base_scale.y * 0.1, base_scale.z * 1.8), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	death_tween.tween_interval(0.3)
	death_tween.tween_property(mesh, "scale", Vector3.ZERO, 0.15).set_ease(Tween.EASE_IN)
	death_tween.tween_callback(func():
		mesh.scale = base_scale
		_do_respawn()
	)

	if is_online and network:
		network.send_died()


func _die_water():
	_cancel_jump()
	is_on_log = false
	current_log = null
	is_jumping = true

	var me = player1 if my_player_num == 1 else player2
	if me.get_child_count() == 0:
		_do_respawn()
		return

	var mesh: Node3D = me.get_child(0)
	var base_scale: Vector3 = mesh.scale
	var water_y = _get_row_height(grid_row)

	# Crear salpicadura (4 cubitos azules)
	_spawn_splash(me.position)

	# Animacion: saltar, estirarse y hundirse
	var death_tween = create_tween()
	# Fase 1: saltar hacia arriba
	death_tween.tween_property(me, "position:y", water_y + 0.6, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Fase 2: estirarse verticalmente (como un clavado)
	death_tween.parallel().tween_property(mesh, "scale", Vector3(base_scale.x * 0.6, base_scale.y * 1.5, base_scale.z * 0.6), 0.12).set_ease(Tween.EASE_OUT)
	# Fase 3: hundirse en el agua
	death_tween.tween_property(me, "position:y", water_y - 0.5, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	# Fase 4: encoger al hundirse
	death_tween.parallel().tween_property(mesh, "scale", Vector3.ZERO, 0.2).set_ease(Tween.EASE_IN)
	# Fase 5: pausa bajo el agua
	death_tween.tween_interval(0.2)
	# Fase 6: respawn
	death_tween.tween_callback(func():
		mesh.scale = base_scale
		me.position.y = water_y
		_do_respawn()
	)

	if is_online and network:
		network.send_died()


func _spawn_splash(pos: Vector3):
	## Crea 4 cubitos azules que salen disparados como salpicadura
	var water_color = Color("#0F7AAD")
	for i in range(4):
		var cube = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.12, 0.12, 0.12)
		cube.mesh = box
		var mat = StandardMaterial3D.new()
		mat.albedo_color = water_color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cube.material_override = mat
		cube.position = pos + Vector3(0, 0.1, 0)
		add_child(cube)

		# Direccion aleatoria hacia arriba y a los lados
		var angle = (PI / 2.0) * i + randf() * 0.5
		var dir_x = cos(angle) * (0.5 + randf() * 0.3)
		var dir_z = sin(angle) * (0.5 + randf() * 0.3)
		var target_pos = pos + Vector3(dir_x, 0.5 + randf() * 0.3, dir_z)
		var fall_pos = target_pos + Vector3(0, -0.8, 0)

		var splash_tween = create_tween()
		# Subir
		splash_tween.tween_property(cube, "position", target_pos, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		# Caer
		splash_tween.tween_property(cube, "position", fall_pos, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		# Desaparecer
		splash_tween.parallel().tween_property(cube, "scale", Vector3.ZERO, 0.15).set_delay(0.15)
		# Limpiar
		splash_tween.tween_callback(cube.queue_free)


func _do_respawn():
	var start_row = START_ROW_P1 if my_player_num == 1 else START_ROW_P2
	grid_row = start_row
	grid_col = START_COL
	is_jumping = false
	_update_my_position()

	# Animacion de aparicion con squeeze
	var me = player1 if my_player_num == 1 else player2
	if me.get_child_count() > 0:
		var mesh: Node3D = me.get_child(0)
		var base_scale: Vector3 = Vector3(PET_SCALE)
		mesh.scale = Vector3(0.01, 0.01, 0.01)
		var spawn_tween = create_tween()
		# Crecer aplastado (ancho y bajo)
		spawn_tween.tween_property(mesh, "scale", base_scale * Vector3(1.5, 0.3, 1.5), 0.08).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		# Estirarse hacia arriba
		spawn_tween.tween_property(mesh, "scale", base_scale * Vector3(0.7, 1.5, 0.7), 0.1).set_ease(Tween.EASE_OUT)
		# Rebote aplastado
		spawn_tween.tween_property(mesh, "scale", base_scale * Vector3(1.2, 0.8, 1.2), 0.06).set_ease(Tween.EASE_IN_OUT)
		# Volver a normal
		spawn_tween.tween_property(mesh, "scale", base_scale, 0.08).set_ease(Tween.EASE_IN_OUT)

func _respawn():
	_cancel_jump()
	is_on_log = false
	current_log = null
	_do_respawn()

func _restart_to_menu():
	# Limpiar resultado
	var result_node = get_node_or_null("ResultUI")
	if result_node:
		result_node.queue_free()

	if network:
		network.disconnect_from_server()
		network.queue_free()
		network = null

	obstacle_manager.clear_all()
	obstacle_manager.visible = true
	map_node.clear_real_map()
	map_node.clear_infinite()

	p1_score = 0
	p2_score = 0
	my_player_num = 0
	is_online = false
	is_jumping = false
	is_on_log = false

	score_label.visible = false
	score_label.add_theme_font_size_override("font_size", 28)
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	score_label.anchor_bottom = 0.0
	countdown_label.visible = false
	_set_status("")

	player2.visible = false
	grid_row = 0
	grid_col = START_COL
	map_node.ensure_grass_around(grid_row, 6, 15)
	_setup_frog(player1, my_pet_path, Color("#00cc44"), false)
	player1.position = Vector3(grid_col + 0.5, 0.1, grid_row + 0.5)

	_create_carousel()
	_update_carousel_selection()

	# Actualizar rating en el label
	var player_info = menu_layer.get_node_or_null("PlayerInfo")
	if player_info:
		_fetch_player_rating(_get_device_id(), player_info)

	camera.is_transitioning = false
	if camera.transition_tween and camera.transition_tween.is_valid():
		camera.transition_tween.kill()
	camera.follow_single(player1)
	menu_layer.visible = true
	game_ui_layer.visible = false
	state = GameState.MENU
