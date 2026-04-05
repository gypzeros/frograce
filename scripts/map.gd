extends Node3D
## Genera el mapa con tiles estilo Crossy Road

const TILE_SIZE = 1.0
const MAP_WIDTH = 9
const MAP_HEIGHT = 17
const TILE_DEPTH = 0.5
const GRASS_PADDING_TOP = 20
const GRASS_PADDING_BOTTOM = 20

const COLOR_GRASS_TOP = Color("#A7DB61")
const COLOR_GRASS_SIDE = Color("#5A9A32")
const COLOR_GRASS_TOP_ALT = Color("#A2D159")
const COLOR_ROAD_TOP = Color("#6B6B6B")
const COLOR_ROAD_SIDE = Color("#4A4A4A")
const COLOR_WATER_TOP = Color("#74DBFF")
const COLOR_WATER_SIDE = Color("#0F7AAD")

const HEIGHT_GRASS = 0.1
const HEIGHT_ROAD = 0.0
const HEIGHT_WATER = -0.1

var real_rows: Dictionary = {}
var infinite_rows: Dictionary = {}


func _get_row_type(row: int) -> String:
	if row <= 2: return "grass"
	if row <= 5: return "road"
	if row == 6: return "grass"
	if row <= 9: return "water"
	if row == 10: return "grass"
	if row <= 13: return "road"
	return "grass"


func _get_colors(type: String, row: int = 0) -> Array:
	match type:
		"grass":
			if row % 2 == 0:
				return [COLOR_GRASS_TOP, COLOR_GRASS_SIDE]
			else:
				return [COLOR_GRASS_TOP_ALT, COLOR_GRASS_TOP_ALT.darkened(0.3)]
		"road": return [COLOR_ROAD_TOP, COLOR_ROAD_SIDE]
		"water": return [COLOR_WATER_TOP, COLOR_WATER_SIDE]
	return [COLOR_GRASS_TOP, COLOR_GRASS_SIDE]


func _get_height(type: String) -> float:
	match type:
		"grass": return HEIGHT_GRASS
		"road": return HEIGHT_ROAD
		"water": return HEIGHT_WATER
	return 0.0


func _ready():
	pass


# --- Mapa real ---

func generate_real_map():
	clear_real_map()
	# NO limpiar hierba infinita — coexisten sin conflicto

	for row in range(-GRASS_PADDING_TOP, 0):
		var colors = _get_colors("grass", row)
		var node = _create_row_node(row, colors[0], colors[1], HEIGHT_GRASS)
		real_rows[row] = node
		add_child(node)

	for row in range(MAP_HEIGHT):
		var type = _get_row_type(row)
		var colors = _get_colors(type, row)
		var height = _get_height(type)
		var node = _create_row_node(row, colors[0], colors[1], height)
		real_rows[row] = node
		add_child(node)

		if row > 0:
			var prev_type = _get_row_type(row - 1)
			var prev_height = _get_height(prev_type)
			if height != prev_height:
				_create_wall(row, prev_type, type, prev_height, height)

	for row in range(MAP_HEIGHT, MAP_HEIGHT + GRASS_PADDING_BOTTOM):
		var colors = _get_colors("grass", row)
		var node = _create_row_node(row, colors[0], colors[1], HEIGHT_GRASS)
		real_rows[row] = node
		add_child(node)

	# Arboles delimitadores en los bordes
	_create_border_trees()


const TRUNK_COLOR = Color("#4E2931")
const CROWN_TOP = Color("#A6C927")
const CROWN_FRONT = Color("#687C1C")
const CROWN_SIDE = Color("#3C4917")
const CROWN_MID_TOP = Color("#4A6010")
const CROWN_MID_SIDE = Color("#2D4A0A")
const TRUNK_W = 0.4
## [ancho copa, alto copa] — mas alto = menos ancho
const CROWN_VARIANTS = [
	Vector2(0.9, 0.5),    # pequeno: ancho, bajo
	Vector2(0.75, 0.9),   # mediano
	Vector2(0.55, 1.4),   # grande: estrecho, muy alto
]


func _create_border_trees():
	var tree_rng = RandomNumberGenerator.new()
	tree_rng.seed = 12345

	# 10 columnas por cada lado
	var x_positions = []
	for i in range(10):
		x_positions.append(-0.5 - i)
		x_positions.append(MAP_WIDTH + 0.5 + i)

	for row in range(-GRASS_PADDING_TOP, MAP_HEIGHT + GRASS_PADDING_BOTTOM):
		var type = _get_row_type(row) if row >= 0 and row < MAP_HEIGHT else "grass"
		if type != "grass":
			continue
		var height = HEIGHT_GRASS

		for x in x_positions:
			# Siempre un arbol en cada posicion
			if false:
				continue
			var variant = tree_rng.randi() % 3
			var tree = _create_tree(variant)
			tree.rotation.y = [0, PI / 2.0, PI, PI * 1.5][tree_rng.randi() % 4]
			tree.position = Vector3(x, height, row + 0.5)
			tree.name = "Tree_%d_%d" % [row, int(x * 10)]
			add_child(tree)


func _create_tree(variant: int) -> Node3D:
	var root = Node3D.new()
	var crown_w = CROWN_VARIANTS[variant].x
	var crown_h = CROWN_VARIANTS[variant].y
	var trunk_h = 0.4

	# Tronco
	var trunk = MeshInstance3D.new()
	var trunk_mesh = BoxMesh.new()
	trunk_mesh.size = Vector3(TRUNK_W, trunk_h, TRUNK_W)
	trunk.mesh = trunk_mesh
	var trunk_mat = StandardMaterial3D.new()
	trunk_mat.albedo_color = TRUNK_COLOR
	trunk.material_override = trunk_mat
	trunk.position = Vector3(0, trunk_h / 2.0, 0)
	root.add_child(trunk)

	# Copa dividida en 3 secciones: inferior, franja, superior
	var stripe_h = 0.06  # franja fina
	var section_h = (crown_h - stripe_h) / 2.0
	var y = trunk_h

	# Seccion inferior
	var bottom = _create_crown_section(crown_w, section_h, CROWN_TOP, CROWN_FRONT, CROWN_SIDE)
	bottom.position.y = y + section_h / 2.0
	root.add_child(bottom)
	y += section_h

	# Franja oscura (mismo ancho, no metida)
	var mid = _create_crown_section(crown_w, stripe_h, CROWN_MID_TOP, CROWN_MID_SIDE, CROWN_MID_SIDE)
	mid.position.y = y + stripe_h / 2.0
	root.add_child(mid)
	y += stripe_h

	# Seccion superior
	var top_section = _create_crown_section(crown_w, section_h, CROWN_TOP, CROWN_FRONT, CROWN_SIDE)
	top_section.position.y = y + section_h / 2.0
	root.add_child(top_section)

	return root


func _create_crown_section(width: float, height: float, top_color: Color, front_color: Color, side_color: Color) -> Node3D:
	var section = Node3D.new()

	# Cubo solido cerrado con color lateral como base
	var box = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(width, height, width)
	box.mesh = box_mesh
	var box_mat = StandardMaterial3D.new()
	box_mat.albedo_color = front_color
	box.material_override = box_mat
	section.add_child(box)

	# Cara superior con color claro (encima del cubo)
	var top = MeshInstance3D.new()
	var top_mesh = QuadMesh.new()
	top_mesh.size = Vector2(width, width)
	top.mesh = top_mesh
	var top_mat = StandardMaterial3D.new()
	top_mat.albedo_color = top_color
	top.material_override = top_mat
	top.rotation.x = -PI / 2.0
	top.position.y = height / 2.0 + 0.001
	section.add_child(top)

	# Caras laterales derecha e izquierda con color mas oscuro
	var side_mat = StandardMaterial3D.new()
	side_mat.albedo_color = side_color
	var right = MeshInstance3D.new()
	var right_mesh = QuadMesh.new()
	right_mesh.size = Vector2(width, height)
	right.mesh = right_mesh
	right.material_override = side_mat
	right.rotation.y = -PI / 2.0
	right.position = Vector3(width / 2.0 + 0.001, 0, 0)
	section.add_child(right)

	var left = MeshInstance3D.new()
	var left_mesh = QuadMesh.new()
	left_mesh.size = Vector2(width, height)
	left.mesh = left_mesh
	left.material_override = side_mat
	left.rotation.y = PI / 2.0
	left.position = Vector3(-width / 2.0 - 0.001, 0, 0)
	section.add_child(left)

	return section


func clear_real_map():
	for row in real_rows:
		if is_instance_valid(real_rows[row]):
			real_rows[row].queue_free()
	real_rows.clear()
	for child in get_children():
		if child.name.begins_with("Wall_") or child.name.begins_with("Tree_"):
			child.queue_free()


# --- Hierba infinita para busqueda ---

func ensure_grass_around(center_row: int, ahead: int = 15, behind: int = 6):
	## ahead = filas por delante (+Z, filas mayores)
	## behind = filas por detras (-Z, filas menores)
	var min_row = center_row - behind
	var max_row = center_row + ahead

	for row in range(min_row, max_row + 1):
		if real_rows.has(row) or infinite_rows.has(row):
			continue
		var colors = _get_colors("grass", row)
		var node = _create_row_node(row, colors[0], colors[1], HEIGHT_GRASS)
		infinite_rows[row] = node
		add_child(node)

	var to_remove: Array = []
	for row in infinite_rows:
		if row < min_row - 2 or row > max_row + 2:
			to_remove.append(row)
	for row in to_remove:
		if is_instance_valid(infinite_rows[row]):
			infinite_rows[row].queue_free()
		infinite_rows.erase(row)


func show_all_rows():
	## Hace visibles todas las filas ocultas (carretera, agua, walls)
	for row in real_rows:
		if is_instance_valid(real_rows[row]):
			real_rows[row].visible = true
	for child in get_children():
		if child.name.begins_with("Wall_"):
			child.visible = true


func clear_infinite():
	for row in infinite_rows:
		if is_instance_valid(infinite_rows[row]):
			infinite_rows[row].queue_free()
	infinite_rows.clear()


# --- Generacion de nodos ---

func _create_row_node(row: int, top_color: Color, side_color: Color, height: float) -> Node3D:
	var extra_width = 11.0  # espacio extra para cubrir debajo de los arboles (10 columnas + margen)
	var total_width = MAP_WIDTH + extra_width * 2
	var root = Node3D.new()
	root.position = Vector3(MAP_WIDTH / 2.0, height, row + 0.5)
	root.name = "Row_%d" % row

	var side_mat = StandardMaterial3D.new()
	side_mat.albedo_color = side_color
	side_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var top = MeshInstance3D.new()
	var top_mesh = QuadMesh.new()
	top_mesh.size = Vector2(total_width, TILE_SIZE)
	top.mesh = top_mesh
	var top_mat = StandardMaterial3D.new()
	top_mat.albedo_color = top_color
	top_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	top.material_override = top_mat
	top.rotation.x = -PI / 2.0
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(top)

	# Plano receptor de sombras (transparente, solo oscurece donde hay sombra)
	var shadow_plane = MeshInstance3D.new()
	var shadow_mesh = QuadMesh.new()
	shadow_mesh.size = Vector2(total_width, TILE_SIZE)
	shadow_plane.mesh = shadow_mesh
	var shadow_mat = StandardMaterial3D.new()
	shadow_mat.albedo_color = Color(1, 1, 1, 1)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	shadow_plane.material_override = shadow_mat
	shadow_plane.rotation.x = -PI / 2.0
	shadow_plane.position.y = 0.02
	shadow_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shadow_plane)

	var front = MeshInstance3D.new()
	var front_mesh = QuadMesh.new()
	front_mesh.size = Vector2(total_width, TILE_DEPTH)
	front.mesh = front_mesh
	front.material_override = side_mat
	front.position = Vector3(0, -TILE_DEPTH / 2.0, TILE_SIZE / 2.0)
	front.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(front)

	var right = MeshInstance3D.new()
	var right_mesh = QuadMesh.new()
	right_mesh.size = Vector2(TILE_SIZE, TILE_DEPTH)
	right.mesh = right_mesh
	right.material_override = side_mat
	right.rotation.y = -PI / 2.0
	right.position = Vector3(total_width / 2.0, -TILE_DEPTH / 2.0, 0)
	right.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(right)

	var back = MeshInstance3D.new()
	var back_mesh = QuadMesh.new()
	back_mesh.size = Vector2(total_width, TILE_DEPTH)
	back.mesh = back_mesh
	back.material_override = side_mat
	back.rotation.y = PI
	back.position = Vector3(0, -TILE_DEPTH / 2.0, -TILE_SIZE / 2.0)
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(back)

	var left = MeshInstance3D.new()
	var left_mesh = QuadMesh.new()
	left_mesh.size = Vector2(TILE_SIZE, TILE_DEPTH)
	left.mesh = left_mesh
	left.material_override = side_mat
	left.rotation.y = PI / 2.0
	left.position = Vector3(-total_width / 2.0, -TILE_DEPTH / 2.0, 0)
	left.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(left)

	return root


func _create_wall(row: int, prev_type: String, curr_type: String, prev_h: float, curr_h: float) -> MeshInstance3D:
	var higher_h = maxf(prev_h, curr_h)
	var lower_h = minf(prev_h, curr_h)
	var wall_height = higher_h - lower_h
	var wall_type = prev_type if prev_h > curr_h else curr_type
	var colors = _get_colors(wall_type)

	var wall = MeshInstance3D.new()
	var wall_mesh = QuadMesh.new()
	wall_mesh.size = Vector2(MAP_WIDTH, wall_height)
	wall.mesh = wall_mesh
	var wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = colors[1]
	wall_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wall.material_override = wall_mat
	wall.position = Vector3(MAP_WIDTH / 2.0, higher_h - wall_height / 2.0, float(row))
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wall.name = "Wall_%d" % row
	add_child(wall)
	return wall
