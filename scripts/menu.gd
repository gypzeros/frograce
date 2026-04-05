extends Control
## Pantalla de inicio del juego

var title_label: Label
var play_button: Button
var subtitle_label: Label


func _ready():
	# Fondo
	var bg = ColorRect.new()
	bg.color = Color("#2d2d2d")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Contenedor centrado
	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_top = 0.3
	vbox.anchor_bottom = 0.7
	vbox.offset_left = -140
	vbox.offset_right = 140
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	add_child(vbox)

	# Titulo
	title_label = Label.new()
	title_label.text = "FROG RACE"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 52)
	title_label.add_theme_color_override("font_color", Color("#00cc44"))
	vbox.add_child(title_label)

	# Subtitulo
	subtitle_label = Label.new()
	subtitle_label.text = "1v1 Frogger Battle"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 18)
	subtitle_label.add_theme_color_override("font_color", Color("#aaaaaa"))
	vbox.add_child(subtitle_label)

	# Espaciador
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)

	# Boton Play
	play_button = Button.new()
	play_button.text = "PLAY"
	play_button.custom_minimum_size = Vector2(200, 60)
	play_button.add_theme_font_size_override("font_size", 28)
	play_button.pressed.connect(_on_play_pressed)
	vbox.add_child(play_button)

	# Instrucciones
	var instructions = Label.new()
	instructions.text = "Move: Arrow keys / WASD\nGet 3 frogs across to win!"
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_theme_font_size_override("font_size", 14)
	instructions.add_theme_color_override("font_color", Color("#777777"))
	vbox.add_child(instructions)


func _on_play_pressed():
	get_tree().change_scene_to_file("res://main.tscn")


func _input(event: InputEvent) -> void:
	# Cualquier toque o clic o tecla inicia el juego
	if event is InputEventMouseButton and event.pressed:
		get_tree().change_scene_to_file("res://main.tscn")
	elif event is InputEventKey and event.pressed and not event.echo:
		get_tree().change_scene_to_file("res://main.tscn")
	elif event is InputEventScreenTouch and event.pressed:
		get_tree().change_scene_to_file("res://main.tscn")
