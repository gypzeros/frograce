extends Node3D
## Controla una rana jugador con movimiento por casillas

const TILE_SIZE = 1.0
const MAP_WIDTH = 9

@export var player_id: int = 1
@export var start_row: int = 14
@export var start_col: int = 8
@export var frog_color: Color = Color("#00ff00")

var grid_row: int
var grid_col: int
var is_on_log: bool = false
var current_log: MeshInstance3D = null

@onready var obstacle_manager: Node3D = get_node("/root/Main/Obstacles")


func _ready():
	grid_row = start_row
	grid_col = start_col
	_create_mesh()
	_update_position()
	print("Player %d ready at row %d col %d" % [player_id, grid_row, grid_col])


func _create_mesh():
	var mesh_instance = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.7, 0.7, 0.7)
	mesh_instance.mesh = box

	var shader = load("res://shaders/voxel_outline.gdshader")
	var material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("albedo_color", frog_color)
	material.set_shader_parameter("edge_width", 0.05)
	mesh_instance.material_override = material

	mesh_instance.name = "Mesh"
	add_child(mesh_instance)


func _update_position():
	position = Vector3(grid_col + 0.5, 0.35, grid_row + 0.5)


func _process_input():
	# Solo jugador 1 por ahora con teclado
	if player_id != 1:
		return

	var moved = false
	if Input.is_action_just_pressed("ui_up"):
		print("UP pressed")
		grid_row -= 1
		moved = true
	elif Input.is_action_just_pressed("ui_down"):
		grid_row += 1
		moved = true
	elif Input.is_action_just_pressed("ui_left"):
		grid_col -= 1
		moved = true
	elif Input.is_action_just_pressed("ui_right"):
		grid_col += 1
		moved = true

	if moved:
		grid_row = clamp(grid_row, 0, 15)
		grid_col = clamp(grid_col, 0, MAP_WIDTH - 1)
		_update_position()
		_check_hazards()


func _process(_delta):
	_process_input()


func _check_hazards():
	is_on_log = false
	current_log = null

	# Filas de agua (7-9): morir si no hay tronco
	if grid_row >= 7 and grid_row <= 9:
		var log_node = obstacle_manager.get_log_at(grid_row, position.x)
		if log_node:
			is_on_log = true
			current_log = log_node
		else:
			_die()


func _check_car_collision():
	# Filas de carretera: 3-5 y 10-12
	if (grid_row >= 3 and grid_row <= 5) or (grid_row >= 10 and grid_row <= 12):
		if obstacle_manager.is_car_at(grid_row, position.x):
			_die()


func _die():
	grid_row = start_row
	grid_col = start_col
	is_on_log = false
	current_log = null
	_update_position()
