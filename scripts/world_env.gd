extends WorldEnvironment
## Luz ambiental uniforme estilo Crossy Road

func _ready():
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#87CEEB")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.4
	environment = env
