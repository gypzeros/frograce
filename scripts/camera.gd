extends Camera3D
## Camara dinamica con dos modos:
## - follow_single: sigue a un solo jugador (menu, busqueda)
## - follow_both: sigue el punto medio entre ambos jugadores (partida)

const MIN_SIZE := 6.0
const MAX_SIZE := 35.0
const PADDING_CLOSE := 2.0  # cuando estan juntos
const PADDING_FAR := 0.5    # cuando estan lejos
const VIEW_DISTANCE := 20.0
const MENU_SIZE := 8.0

var player1: Node3D
var player2: Node3D
var follow_target: Node3D = null
var mode: String = "single"
var lerp_speed: float = 5.0
var transition_tween: Tween
var is_transitioning: bool = false


func _ready():
	player1 = get_node("/root/Main/Players/Player1")
	player2 = get_node("/root/Main/Players/Player2")


func follow_single(target: Node3D):
	## Modo menu/busqueda: sigue a un solo jugador con zoom fijo
	follow_target = target
	mode = "single"
	if target:
		global_position = target.global_position + basis.z * VIEW_DISTANCE
		size = MENU_SIZE


func follow_both():
	## Modo partida: sigue el punto medio entre ambos jugadores
	mode = "both"
	follow_target = null


var transition_progress: float = 0.0
var transition_duration: float = 3.0

func transition_to_both(duration: float = 3.0):
	## Transicion suave: zoom out + pan hacia midpoint en paralelo
	if not player1 or not player2:
		follow_both()
		return

	is_transitioning = true
	transition_progress = 0.0
	transition_duration = duration
	var target_size := _calc_target_size()

	if transition_tween and transition_tween.is_valid():
		transition_tween.kill()

	transition_tween = create_tween()
	transition_tween.set_parallel(true)
	transition_tween.tween_property(self, "size", target_size, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	transition_tween.tween_property(self, "transition_progress", 1.0, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	transition_tween.set_parallel(false)
	transition_tween.tween_callback(_finish_transition)


func flip_for_player2():
	rotation.y += PI


func _finish_transition():
	is_transitioning = false
	mode = "both"
	lerp_speed = 5.0


func _process(delta: float) -> void:
	if is_transitioning:
		_process_transition(delta)
	elif mode == "single":
		_process_single(delta)
	elif mode == "both":
		_process_both(delta)


func _process_transition(delta: float):
	if not follow_target or not player1 or not player2:
		return
	# Interpolar entre seguir al jugador y seguir el midpoint
	var single_target := follow_target.global_position + basis.z * VIEW_DISTANCE
	var midpoint := (player1.global_position + player2.global_position) / 2.0
	var both_target := midpoint + basis.z * VIEW_DISTANCE
	var blended_target := single_target.lerp(both_target, transition_progress)
	# Lerp MUY lento para que no salte si el target cambia de golpe
	global_position = global_position.lerp(blended_target, delta * 1.5)


func _process_single(delta: float):
	if not follow_target:
		return
	var target_pos := follow_target.global_position + basis.z * VIEW_DISTANCE
	global_position = global_position.lerp(target_pos, delta * 10.0)
	size = lerpf(size, MENU_SIZE, delta * 3.0)


func _process_both(delta: float):
	if not player1 or not player2:
		return
	var midpoint := (player1.global_position + player2.global_position) / 2.0
	var target_pos := midpoint + basis.z * VIEW_DISTANCE
	global_position = global_position.lerp(target_pos, delta * lerp_speed)
	var target_size := _calc_target_size()
	size = lerpf(size, target_size, delta * lerp_speed * 0.6)


func _calc_target_size() -> float:
	var p1_screen := _world_to_view(player1.global_position)
	var p2_screen := _world_to_view(player2.global_position)
	var diff := (p1_screen - p2_screen).abs()
	var dist := diff.length()
	# Padding dinamico: mas cuando estan cerca, menos cuando estan lejos
	var t := clampf(dist / 15.0, 0.0, 1.0)
	var padding := lerpf(PADDING_CLOSE, PADDING_FAR, t)
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / viewport_size.y
	var size_for_width := (diff.x + padding * 2.0) / aspect
	var size_for_height := diff.y + padding * 2.0
	var needed := maxf(size_for_width, size_for_height)
	return clampf(needed, MIN_SIZE, MAX_SIZE)


func _world_to_view(world_pos: Vector3) -> Vector2:
	var local := global_transform.affine_inverse() * world_pos
	return Vector2(local.x, local.y)
