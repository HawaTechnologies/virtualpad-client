extends Button


func _ready():
	connect("pressed", self._on_button_pressed)


func _on_button_pressed():
	var color = get_meta("color")
	get_parent().get_node("../Buttons").set_button_colors_and_update(color)
