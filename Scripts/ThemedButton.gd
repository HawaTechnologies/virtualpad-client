extends Button


var _COLORS = {
	"black": {
		# No particular "Focus".
		# Disabled.
		"disabled-bg-color": Color(.2, .2, .2),
		"disabled-border-color": Color(.1, .1, .1),
		# Hover.
		"hover-bg-color": Color(.25, .25, .25),
		"hover-border-color": Color(.1, .1, .1),
		# Normal, Pressed.
		"normal-bg-color": Color(.15, .15, .15),
		"normal-border-color": Color(.1, .1, .1),
		# Font & Icon color.
		"foreground-color": Color(.8, .8, .8)
	},
	"white": {
		# No particular "Focus".
		# Disabled.
		"disabled-bg-color": Color(.4, .4, .4),
		"disabled-border-color": Color(.2, .2, .2),
		# Hover.
		"hover-bg-color": Color(.7, .7, .7),
		"hover-border-color": Color(.5, .5, .5),
		# Normal, Pressed.
		"normal-bg-color": Color(.6, .6, .6),
		"normal-border-color": Color(.4, .4, .4),
		# Font & Icon color.
		"foreground-color": Color(.2, .2, .2)
	},
	"dragon": {
		# No particular "Focus".
		# Disabled.
		"disabled-bg-color": Color(.4, 0, 0),
		"disabled-border-color": Color(.2, 0, 0),
		# Hover.
		"hover-bg-color": Color(.7, 0, 0),
		"hover-border-color": Color(.4, 0, 0),
		# Normal, Pressed.
		"normal-bg-color": Color(.6, 0, 0),
		"normal-border-color": Color(.4, 0, 0),
		# Font & Icon color.
		"foreground-color": Color(240.0 / 255, 100.0 / 255, 0)
	},
	"shark": {
		# No particular "Focus".Qué lugar encontraste?
		# Disabled.
		"disabled-bg-color": Color(0, 0.13, 0.4),
		"disabled-border-color": Color(0, .06, .2),
		# Hover.
		"hover-bg-color": Color(0, .25, .7),
		"hover-border-color": Color(0, .16, .5),
		# Normal, Pressed.
		"normal-bg-color": Color(0, .2, .6),
		"normal-border-color": Color(0, 0.13, 0.4),
		# Font & Icon color.
		"foreground-color": Color(0, .5, 155.0 / 255)
	},
}


func _update_color():
	var color = get_meta("pad_color")
	if color in _COLORS:
		var color_settings = _COLORS[color]
		print("Using color:", color_settings)
		var normal = get_theme_stylebox("normal")
		var disabled = get_theme_stylebox("disabled")
		var hover = get_theme_stylebox("hover")
		var pressed = get_theme_stylebox("pressed")
		var focus = get_theme_stylebox("focus")
		var foreground_color = color_settings["foreground-color"]
		add_theme_color_override("font_color", foreground_color)
		add_theme_color_override("font_disabled_color", foreground_color)
		add_theme_color_override("font_focus_color", foreground_color)
		add_theme_color_override("font_hover_color", foreground_color)
		add_theme_color_override("font_hover_pressed_color", foreground_color)
		add_theme_color_override("font_outline_color", foreground_color)
		add_theme_color_override("font_pressed_color", foreground_color)
		disabled.bg_color = color_settings["disabled-bg-color"]
		disabled.border_color = color_settings["disabled-border-color"]
		hover.bg_color = color_settings["hover-bg-color"]
		hover.border_color = color_settings["hover-border-color"]
		normal.bg_color = color_settings["normal-bg-color"]
		normal.border_color = color_settings["normal-border-color"]
		pressed.bg_color = color_settings["normal-bg-color"]
		pressed.border_color = color_settings["normal-border-color"]
		focus.border_color = Color(0, 0, 0, 0)
		focus.shadow_color = Color(0, 0, 0, 0)
	else:
		print("No pad-color (or invalid one) was set in the metadata.")
		print("Set it to one of these values: white, black, dragon, shark.")


func _update_theme():
	print("Updating theme")
	_update_color()


# Called when the node enters the scene tree for the first time.
func _ready():
	_update_theme()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
