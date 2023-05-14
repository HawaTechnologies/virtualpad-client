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


func _reset():
	add_theme_stylebox_override("normal", StyleBoxFlat.new())
	add_theme_stylebox_override("focus", StyleBoxFlat.new())
	add_theme_stylebox_override("hover", StyleBoxFlat.new())
	add_theme_stylebox_override("pressed", StyleBoxFlat.new())
	add_theme_stylebox_override("disabled", StyleBoxFlat.new())
	get_theme_stylebox("focus").draw_center = false


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


func _update_shape_big_pressure():
	var normal = get_theme_stylebox("normal")
	var disabled = get_theme_stylebox("disabled")
	var hover = get_theme_stylebox("hover")
	var pressed = get_theme_stylebox("pressed")
	
	for state in [normal, disabled, hover]:
		state.border_width_left = 4
		state.border_width_right = 4
		state.border_width_top = 4
		state.border_width_bottom = 14
		state.expand_margin_top = 10
		state.content_margin_bottom = 26
		state.border_blend = true
	pressed.border_width_left = 4
	pressed.border_width_right = 4
	pressed.border_width_top = 4
	pressed.border_width_bottom = 8
	pressed.expand_margin_top = 4
	pressed.content_margin_bottom = 16
	pressed.border_blend = true


func _update_shape_small_pressure():
	var normal = get_theme_stylebox("normal")
	var disabled = get_theme_stylebox("disabled")
	var hover = get_theme_stylebox("hover")
	var pressed = get_theme_stylebox("pressed")

	for state in [normal, disabled, hover]:
		state.border_width_left = 2
		state.border_width_right = 2
		state.border_width_top = 2
		state.border_width_bottom = 7
		state.expand_margin_top = 5
		state.content_margin_bottom = 13
		state.border_blend = true
	pressed.border_width_left = 2
	pressed.border_width_right = 2
	pressed.border_width_top = 2
	pressed.border_width_bottom = 4
	pressed.expand_margin_top = 2
	pressed.content_margin_bottom = 8
	pressed.border_blend = true


func _set_borders(top_left, top_right, bottom_left, bottom_right):
	var normal = get_theme_stylebox("normal")
	var disabled = get_theme_stylebox("disabled")
	var hover = get_theme_stylebox("hover")
	var pressed = get_theme_stylebox("pressed")

	if top_left >= 0:
		for state in [normal, disabled, hover, pressed]:
			state.corner_radius_top_left = top_left
	if top_right >= 0:
		for state in [normal, disabled, hover, pressed]:
			state.corner_radius_top_right = top_right
	if bottom_left >= 0:
		for state in [normal, disabled, hover, pressed]:
			state.corner_radius_bottom_left = bottom_left
	if bottom_right >= 0:
		for state in [normal, disabled, hover, pressed]:
			state.corner_radius_bottom_right = bottom_right


func _update_shape():
	var shape = get_meta("shape")
	if shape == "big-corner-radius":
		# North, South, East, West.
		_update_shape_big_pressure()
		_set_borders(40, 40, 40, 40)
	elif shape == "small-corner-radius":
		# L1, L2, R1, R2, Select, Start.
		_update_shape_small_pressure()
		_set_borders(20, 20, 20, 20)
	elif shape == "pad-up":
		_update_shape_small_pressure()
		_set_borders(20, 20, -1, -1)
	elif shape == "pad-up-left":
		_update_shape_small_pressure()
		_set_borders(70, -1, -1, -1)
	elif shape == "pad-left":
		_update_shape_small_pressure()
		_set_borders(20, -1, 20, -1)
	elif shape == "pad-down-left":
		_update_shape_small_pressure()
		_set_borders(-1, -1, 70, -1)
	elif shape == "pad-down":
		_update_shape_small_pressure()
		_set_borders(-1, -1, 20, 20)
	elif shape == "pad-down-right":
		_update_shape_small_pressure()
		_set_borders(-1, -1, -1, 70)
	elif shape == "pad-right":
		_update_shape_small_pressure()
		_set_borders(-1, 20, -1, 20)
	elif shape == "pad-up-right":
		_update_shape_small_pressure()
		_set_borders(-1, 70, -1, -1)



func update_theme():
	print("Updating theme")
	_reset()
	_update_color()
	_update_shape()


# Called when the node enters the scene tree for the first time.
func _ready():
	update_theme()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
