extends Control

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

const PET_SCALE := Vector3(1.5, 1.5, 1.5)
const CAROUSEL_SPACING := 2.5
const LERP_SPEED := 8.0

var pet_scenes: Array = []
var pet_instances: Array = []
var current_index: int = 0
var carousel_root: Node3D
var target_offset: float = 0.0
var pet_name_label: Label
var sub_viewport: SubViewport


func _ready():
	# Fondo
	var bg = ColorRect.new()
	bg.color = Color("#2d2d2d")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Cargar escenas de pets
	for path in PET_PATHS:
		var scene = load(path)
		if scene:
			pet_scenes.append({scene = scene, path = path})

	# SubViewportContainer para el carrusel 3D
	var container = SubViewportContainer.new()
	container.anchor_left = 0.0
	container.anchor_right = 1.0
	container.anchor_top = 0.15
	container.anchor_bottom = 0.55
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	sub_viewport = SubViewport.new()
	sub_viewport.transparent_bg = true
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(sub_viewport)

	# Escena 3D dentro del viewport
	var scene_root = Node3D.new()
	sub_viewport.add_child(scene_root)

	# Camara del carrusel
	var cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 5.0
	cam.position = Vector3(0, 1.5, 4)
	cam.rotation = Vector3(-0.25, 0, 0)
	cam.current = true
	scene_root.add_child(cam)

	# Luz
	var light = DirectionalLight3D.new()
	light.rotation = Vector3(-0.7, 0.5, 0)
	light.shadow_enabled = false
	light.light_energy = 1.0
	scene_root.add_child(light)

	# Luz ambiental
	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.5
	env_node.environment = env
	scene_root.add_child(env_node)

	# Root del carrusel
	carousel_root = Node3D.new()
	scene_root.add_child(carousel_root)

	# Instanciar todos los pets en linea
	for i in range(pet_scenes.size()):
		var instance = pet_scenes[i].scene.instantiate()
		instance.scale = PET_SCALE
		instance.position = Vector3(i * CAROUSEL_SPACING, 0, 0)
		instance.rotation.y = 0
		carousel_root.add_child(instance)
		pet_instances.append(instance)

	# UI
	var title = Label.new()
	title.text = "FROG RACE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.anchor_top = 0.02
	title.anchor_bottom = 0.15
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("#00cc44"))
	add_child(title)

	# Nombre del pet
	pet_name_label = Label.new()
	pet_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pet_name_label.anchor_left = 0.0
	pet_name_label.anchor_right = 1.0
	pet_name_label.anchor_top = 0.55
	pet_name_label.anchor_bottom = 0.62
	pet_name_label.add_theme_font_size_override("font_size", 22)
	pet_name_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(pet_name_label)

	# Flechas de navegacion
	var nav_container = HBoxContainer.new()
	nav_container.anchor_left = 0.5
	nav_container.anchor_right = 0.5
	nav_container.anchor_top = 0.30
	nav_container.anchor_bottom = 0.45
	nav_container.offset_left = -120
	nav_container.offset_right = 120
	nav_container.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_container.add_theme_constant_override("separation", 40)
	add_child(nav_container)

	var btn_left = Button.new()
	btn_left.text = "<"
	btn_left.custom_minimum_size = Vector2(60, 50)
	btn_left.add_theme_font_size_override("font_size", 30)
	btn_left.pressed.connect(_on_prev)
	nav_container.add_child(btn_left)

	var btn_right = Button.new()
	btn_right.text = ">"
	btn_right.custom_minimum_size = Vector2(60, 50)
	btn_right.add_theme_font_size_override("font_size", 30)
	btn_right.pressed.connect(_on_next)
	nav_container.add_child(btn_right)

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
	add_child(btn_play)

	_update_carousel()


func _process(delta):
	if not carousel_root:
		return
	# Lerp suave del carrusel hacia la posicion target
	var current_x = carousel_root.position.x
	var target_x = -current_index * CAROUSEL_SPACING
	carousel_root.position.x = lerpf(current_x, target_x, LERP_SPEED * delta)

	# Escalar y hacer fade a los pets segun distancia al centro
	for i in range(pet_instances.size()):
		var instance = pet_instances[i]
		var dist = absf(i - current_index)
		var s = lerpf(1.5, 0.8, clampf(dist, 0, 2) / 2.0)
		instance.scale = instance.scale.lerp(Vector3(s, s, s), LERP_SPEED * delta)


func _on_prev():
	current_index = max(0, current_index - 1)
	_update_carousel()


func _on_next():
	current_index = min(pet_scenes.size() - 1, current_index + 1)
	_update_carousel()


func _input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_LEFT, KEY_A:
				_on_prev()
			KEY_RIGHT, KEY_D:
				_on_next()


func _update_carousel():
	# Nombre del pet seleccionado
	var path: String = pet_scenes[current_index].path
	var filename = path.get_file().get_basename()
	var pet_name = filename.replace("animal-", "").capitalize()
	pet_name_label.text = pet_name


func _on_play_pressed():
	# Guardar el pet elegido para que game.gd lo use
	get_tree().root.set_meta("selected_pet", pet_scenes[current_index].path)
	get_tree().change_scene_to_file("res://main.tscn")
