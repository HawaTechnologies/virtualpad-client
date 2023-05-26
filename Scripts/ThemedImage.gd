extends TextureRect


var _COLORS = {
	"black": load("res://Graphics/blackhole.png"),
	"white": load("res://Graphics/whitenoise.png"),
	"dragon": load("res://Graphics/lava.png"),
	"shark": load("res://Graphics/ocean.png"),
}


func update_theme():
	texture = _COLORS.get(get_meta("color"))


# Called when the node enters the scene tree for the first time.
func _ready():
	add_to_group("ThemedImages")
	update_theme()
