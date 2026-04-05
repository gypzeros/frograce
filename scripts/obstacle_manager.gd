extends Node3D
## Renderiza obstaculos recibidos del servidor con interpolacion suave
## En modo offline genera localmente con RNG

const MAP_WIDTH = 9
const MAX_PER_ROW = 4
const MIN_GAP = 2.5
const LERP_SPEED = 15.0
const PLAYER_RADIUS = 0.25  # radio de colision del personaje

## Modelos de coches
var car_model_defs = [
	{path = "res://assets/vehicles/sedan.glb", scale = Vector3(0.55, 0.55, 0.55), half_w = 0.8},
	{path = "res://assets/vehicles/sedan-sports.glb", scale = Vector3(0.55, 0.55, 0.55), half_w = 0.8},
	{path = "res://assets/vehicles/suv.glb", scale = Vector3(0.55, 0.55, 0.55), half_w = 0.8},
	{path = "res://assets/vehicles/taxi.glb", scale = Vector3(0.55, 0.55, 0.55), half_w = 0.8},
	{path = "res://assets/vehicles/hatchback-sports.glb", scale = Vector3(0.55, 0.55, 0.55), half_w = 0.8},
	{path = "res://assets/vehicles/police.glb", scale = Vector3(0.55, 0.55, 0.55), half_w = 0.8},
	{path = "res://assets/vehicles/van.glb", scale = Vector3(0.55, 0.55, 0.55), half_w = 0.8},
	{path = "res://assets/vehicles/ambulance.glb", scale = Vector3(0.55, 0.55, 0.55), half_w = 0.8},
	{path = "res://assets/vehicles/truck.glb", scale = Vector3(0.55, 0.55, 0.55), half_w = 0.8},
	{path = "res://assets/vehicles/firetruck.glb", scale = Vector3(0.55, 0.55, 0.55), half_w = 0.8},
]

var car_models: Array = []
var log_scene: PackedScene = null
const LOG_SCALE := Vector3(0.8, 0.8, 0.8)

## Nodos activos indexados por id del servidor
var active_nodes: Dictionary = {}
## Posiciones target del ultimo tick del servidor
var target_positions: Dictionary = {}
## Datos de obstaculos para colisiones
var obstacle_data: Dictionary = {}

## Modo offline
var is_offline: bool = false
var rng: RandomNumberGenerator
var spawn_timers: Dictionary = {}
var offline_obstacles: Array = []
var started: bool = false

var row_configs = [
	{row = 3, dir = 1, type = "car", min_speed = 1.5, max_speed = 4.5, min_interval = 1.0, max_interval = 3.0},
	{row = 4, dir = -1, type = "car", min_speed = 2.0, max_speed = 5.0, min_interval = 0.8, max_interval = 2.5},
	{row = 5, dir = 1, type = "car", min_speed = 1.5, max_speed = 3.5, min_interval = 1.2, max_interval = 3.5},
	{row = 7, dir = 1, type = "log", min_speed = 0.8, max_speed = 2.0, min_interval = 1.5, max_interval = 4.0, sizes = [Vector3(3.0, 0.4, 0.8), Vector3(4.0, 0.4, 0.8)], colors = [Color("#C4793A")]},
	{row = 8, dir = -1, type = "log", min_speed = 1.0, max_speed = 2.5, min_interval = 1.5, max_interval = 3.5, sizes = [Vector3(2.0, 0.4, 0.8), Vector3(3.0, 0.4, 0.8)], colors = [Color("#C4793A")]},
	{row = 9, dir = 1, type = "log", min_speed = 0.5, max_speed = 1.5, min_interval = 2.0, max_interval = 5.0, sizes = [Vector3(3.0, 0.4, 0.8), Vector3(5.0, 0.4, 0.8)], colors = [Color("#C4793A")]},
	{row = 11, dir = -1, type = "car", min_speed = 2.0, max_speed = 5.0, min_interval = 0.8, max_interval = 2.8},
	{row = 12, dir = 1, type = "car", min_speed = 1.5, max_speed = 3.5, min_interval = 1.2, max_interval = 3.0},
	{row = 13, dir = -1, type = "car", min_speed = 2.5, max_speed = 5.5, min_interval = 0.6, max_interval = 2.5},
]


func _ready():
	_ensure_models_loaded()


func _ensure_models_loaded():
	if car_models.size() > 0:
		return
	for def in car_model_defs:
		var scene = load(def.path)
		if scene:
			car_models.append({scene = scene, scale = def.scale, half_w = def.half_w})
	log_scene = load("res://assets/props/ChoppedLog.glb")


# --- Modo online: recibir estado del servidor ---

const VALID_ROWS = [3, 4, 5, 7, 8, 9, 11, 12, 13]

func apply_tick(obstacles_data: Array):
	## Recibe el estado completo del servidor y actualiza
	var received_ids: Dictionary = {}

	for obs in obstacles_data:
		var id: int = obs.get("id", 0)
		var row: int = obs.get("row", 0)
		received_ids[id] = true

		# Ignorar obstaculos en filas que no son carretera ni agua
		if row not in VALID_ROWS:
			continue

		# Guardar target para interpolacion
		target_positions[id] = obs.get("x", 0.0)

		# Guardar datos para colisiones
		var size_arr = obs.get("size", [1.5, 0.5, 0.8])
		obstacle_data[id] = {
			row = row,
			x = obs.get("x", 0.0),
			type = obs.get("type", "car"),
			half_w = size_arr[0] / 2.0,
			dir = obs.get("dir", 1),
			speed = obs.get("speed", 2.0),
		}

		# Crear nodo si no existe
		if not active_nodes.has(id):
			var node = _create_obstacle_node(obs)
			if node:
				active_nodes[id] = node
				add_child(node)

	# Eliminar nodos que ya no estan en el servidor
	var to_remove: Array = []
	for id in active_nodes:
		if not received_ids.has(id):
			to_remove.append(id)
	for id in to_remove:
		if is_instance_valid(active_nodes[id]):
			active_nodes[id].queue_free()
		active_nodes.erase(id)
		target_positions.erase(id)
		obstacle_data.erase(id)


func _create_obstacle_node(obs: Dictionary) -> Node3D:
	_ensure_models_loaded()
	var obs_type: String = obs.get("type", "car")
	var row: int = obs.get("row", 0)
	var dir: int = obs.get("dir", 1)
	var x: float = obs.get("x", 0.0)
	var size_arr = obs.get("size", [1.5, 0.5, 0.8])
	var model_idx: int = obs.get("modelIdx", 0)

	var node: Node3D

	if obs_type == "car" and car_models.size() > 0:
		var car_def = car_models[model_idx % car_models.size()]
		node = car_def.scene.instantiate()
		node.scale = car_def.scale
		if dir > 0:
			node.rotation.y = PI / 2.0
		else:
			node.rotation.y = -PI / 2.0
		node.position = Vector3(x, 0, row + 0.5)
	elif obs_type == "log" and log_scene:
		node = log_scene.instantiate()
		var log_width = size_arr[0]
		node.scale = Vector3(LOG_SCALE.x * log_width / 3.0, LOG_SCALE.y, LOG_SCALE.z)
		node.rotation.y = PI if model_idx % 2 == 0 else 0.0
		node.position = Vector3(x, -0.1, row + 0.5)
	else:
		var obs_size = Vector3(size_arr[0], size_arr[1], size_arr[2])
		node = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = obs_size
		node.mesh = box
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color("#C4793A")
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		node.material_override = mat
		node.position = Vector3(x, obs_size.y / 2.0, row + 0.5)

	node.set_meta("type", obs_type)
	return node


func _process(delta):
	if is_offline:
		_process_offline(delta)
		return

	# Interpolar posiciones hacia el target del servidor
	for id in active_nodes:
		if not target_positions.has(id):
			continue
		var node: Node3D = active_nodes[id]
		if not is_instance_valid(node):
			continue
		var target_x: float = target_positions[id]
		node.position.x = lerpf(node.position.x, target_x, LERP_SPEED * delta)

		# Actualizar datos de colision con la posicion interpolada
		if obstacle_data.has(id):
			obstacle_data[id].x = node.position.x


# --- Modo offline ---

func start_offline():
	_ensure_models_loaded()
	is_offline = true
	rng = RandomNumberGenerator.new()
	rng.seed = randi()
	for config in row_configs:
		spawn_timers[config.row] = rng.randf_range(0.0, config.min_interval)
	started = true
	# Pre-poblar
	var dt := 0.05
	for i in range(200):
		_tick_offline(dt)


func _process_offline(delta):
	if not started:
		return
	_tick_offline(delta)


func _tick_offline(delta: float):
	# Spawn
	for config in row_configs:
		var row = config.row
		spawn_timers[row] -= delta
		if spawn_timers[row] <= 0:
			if _can_spawn_offline(row, config.dir):
				_spawn_offline(config)
			else:
				rng.randf()
				rng.randi()
			spawn_timers[row] = rng.randf_range(config.min_interval, config.max_interval)

	# Mover y limpiar
	var to_remove: Array = []
	for i in range(offline_obstacles.size()):
		var obs = offline_obstacles[i]
		var node: Node3D = obs.node
		if not is_instance_valid(node):
			to_remove.append(i)
			continue
		node.position.x += obs.dir * obs.speed * delta
		obs.x = node.position.x
		if obs.dir > 0 and node.position.x > MAP_WIDTH + 4:
			node.queue_free()
			to_remove.append(i)
		elif obs.dir < 0 and node.position.x < -4:
			node.queue_free()
			to_remove.append(i)

	to_remove.reverse()
	for i in to_remove:
		offline_obstacles.remove_at(i)


func _can_spawn_offline(row: int, dir: int) -> bool:
	var spawn_x: float = -2.0 if dir > 0 else MAP_WIDTH + 2.0
	var count := 0
	for obs in offline_obstacles:
		if obs.row != row:
			continue
		count += 1
		if absf(obs.x - spawn_x) < MIN_GAP + obs.half_w:
			return false
	return count < MAX_PER_ROW


func _spawn_offline(config: Dictionary):
	var speed = rng.randf_range(config.min_speed, config.max_speed)
	var model_idx = rng.randi()
	var size_idx = rng.randi()
	var start_x: float = -2.0 if config.dir > 0 else MAP_WIDTH + 2.0
	var row: int = config.row

	var node: Node3D
	var half_w: float

	if config.type == "car" and car_models.size() > 0:
		var car_def = car_models[model_idx % car_models.size()]
		node = car_def.scene.instantiate()
		node.scale = car_def.scale
		if config.dir > 0:
			node.rotation.y = PI / 2.0
		else:
			node.rotation.y = -PI / 2.0
		node.position = Vector3(start_x, 0, row + 0.5)
		half_w = car_def.half_w
	elif config.type == "log" and log_scene:
		var obs_size: Vector3 = config.sizes[size_idx % config.sizes.size()]
		node = log_scene.instantiate()
		node.scale = Vector3(LOG_SCALE.x * obs_size.x / 3.0, LOG_SCALE.y, LOG_SCALE.z)
		node.rotation.y = PI if model_idx % 2 == 0 else 0.0
		node.position = Vector3(start_x, -0.1, row + 0.5)
		half_w = obs_size.x / 2.0
	else:
		var obs_size: Vector3 = config.sizes[size_idx % config.sizes.size()]
		node = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = obs_size
		node.mesh = box
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color("#C4793A")
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		node.material_override = mat
		node.position = Vector3(start_x, obs_size.y / 2.0, row + 0.5)
		half_w = obs_size.x / 2.0

	node.set_meta("type", config.type)
	add_child(node)
	offline_obstacles.append({node = node, dir = config.dir, speed = speed, row = row, x = start_x, half_w = half_w})


# --- Deteccion de colisiones (funciona en ambos modos) ---

func get_log_at(row: int, pos_x: float) -> Node3D:
	if is_offline:
		for obs in offline_obstacles:
			if obs.row != row or obs.node.get_meta("type") != "log":
				continue
			if not is_instance_valid(obs.node):
				continue
			if absf(obs.x - pos_x) < obs.half_w + PLAYER_RADIUS:
				return obs.node
	else:
		for id in obstacle_data:
			var d = obstacle_data[id]
			if d.row != row or d.type != "log":
				continue
			if absf(d.x - pos_x) < d.half_w + PLAYER_RADIUS:
				if active_nodes.has(id) and is_instance_valid(active_nodes[id]):
					return active_nodes[id]
	return null


func is_car_at(row: int, pos_x: float) -> bool:
	if is_offline:
		for obs in offline_obstacles:
			if obs.row != row or obs.node.get_meta("type") != "car":
				continue
			if not is_instance_valid(obs.node):
				continue
			if absf(obs.x - pos_x) < obs.half_w + PLAYER_RADIUS:
				return true
	else:
		for id in obstacle_data:
			var d = obstacle_data[id]
			if d.row != row or d.type != "car":
				continue
			if absf(d.x - pos_x) < d.half_w + PLAYER_RADIUS:
				return true
	return false


func clear_all():
	for id in active_nodes:
		if is_instance_valid(active_nodes[id]):
			active_nodes[id].visible = false
			active_nodes[id].queue_free()
	active_nodes.clear()
	target_positions.clear()
	obstacle_data.clear()
	for obs in offline_obstacles:
		if is_instance_valid(obs.node):
			obs.node.visible = false
			obs.node.queue_free()
	offline_obstacles.clear()
	spawn_timers.clear()
	started = false
	is_offline = false
