extends Control


func set_button_colors_and_update(theme):
	for child in get_tree().get_nodes_in_group("ThemedButtons"):
		child.set_meta("color", theme)
		child.update_theme()
	for child in get_tree().get_nodes_in_group("ThemedAxes"):
		child.set_meta("color", theme)
		child.update_theme()
	for child in get_tree().get_nodes_in_group("ThemedImages"):
		child.set_meta("color", theme)
		child.update_theme()


func _ready():
	set_button_colors_and_update(get_meta("default_color"))
