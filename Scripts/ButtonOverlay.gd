extends Control


# Buttons are: North, East, South, West, L1, R1, L2, R2,
#              Select, Start, Up, Down, Left, Right.
const N_BUTTONS = 14
const BTN_NORTH = 0
const BTN_EAST = 1
const BTN_SOUTH = 2
const BTN_WEST = 3
const BTN_L1 = 4
const BTN_R1 = 5
const BTN_L2 = 6
const BTN_R2 = 7
const BTN_SELECT = 8
const BTN_START = 9
const BTN_UP = 10
const BTN_DOWN = 11
const BTN_LEFT = 12
const BTN_RIGHT = 13
var _buttons_by_name = {
	"north": BTN_NORTH,
	"east": BTN_EAST,
	"south": BTN_SOUTH,
	"west": BTN_WEST,
	"l1": BTN_L1,
	"r1": BTN_R1,
	"l2": BTN_L2,
	"r2": BTN_R2,
	"select": BTN_SELECT,
	"start": BTN_START,
	"up": BTN_UP,
	"down": BTN_DOWN,
	"left": BTN_LEFT,
	"right": BTN_RIGHT,
}


# Axes are: X, Y, RX, RY.
const N_AXES = 4
const ABS_X = 14
const ABS_Y = 15
const ABS_RX = 16
const ABS_RY = 17
var _axes_by_name = {
	"analog_left": [ABS_X, ABS_Y],
	"analog_right": [ABS_RX, ABS_RY]
}


# The buttons will be contained here. In this case, we'll keep
# for each element (rect, key, button) being:
# - rect: The button rect (remember: they're rectangular and
#         not rotated).
# - key: The key to send. All the buttons (incl. d-pad) will
#        send a key between 0-13 (both inclusive), except the
#        D-Pad's diagonals, which will send TWO keys instead
#        of one (always in 10-13 range).
# - button: The button that is matched against this entry.
#           The buttons are always rectangular.
#
# This is only populated on startup.
var _BUTTONS = []


# The axes will be contained here. In this case, we'll keep
# for each element (rect, key, shape). These are the analog
# sticks (left, and right -- the D-Pad will not count as axes
# in this case). They're expressed as:
# - rect: The rectangle they exist into (remember: they're
#         still rectangular shapes).
# - key: The key to send. All the axes will send two values
#        in the 14-17 range (both inclusive), being each one
#        a value between 0 and 255 (both inclusive), being
#        127 in the exact middle.
#
# This is only populated on startup.
var _ANALOGS = []


func _collect_controls():
	"""
	Collects all the controls that can send a key and all the
	related keys to send and their types. Controls' types are
	either button or analog stick, and they'll never overlap.
	They'll be collected in two different collections: one is
	intended for buttons, and another one is intended for the
	analog sticks.
	"""
	
	_BUTTONS.clear()
	_ANALOGS.clear()
	for child in get_tree().get_nodes_in_group("ThemedButtons"):
		# We'll be populating both the buttons that will
		# serve as "buttons" and those that will serve as
		# "analogs" (they work as pairs of axes). Most of
		# the buttons will have only ONE key, except for
		# the D-Pad diagonals. Also, all the analogs will
		# have TWO keys, which are pairs of axes: (X, Y).

		# First, determine whether it is an analog or button.
		var is_analog = child.get_meta("is_analog") == true
		var target = _ANALOGS
		var keys_source = _axes_by_name
		if not is_analog:
			target = _BUTTONS
			keys_source = _buttons_by_name

		# Then, add the tuple (rect, keys, button) for each
		# button or axis, accordingly.
		#
		# Buttons, on pressed, will send one or more keys
		# simultaneously and, on released, will un-send
		# those keys.
		# 
		# Axes, on the other hand, will send always two keys
		# (standing for their axes) and based on their trig
		# distances to the center (on press), and will send
		# the pair (127, 127) otherwise (on release).
		var keys = child.get_meta("keys")
		if keys != null:
			var mapped_keys = []
			for key in keys:
				mapped_keys.append(keys_source[key])
			target.append([
				Rect2(child.global_position, child.size),
				mapped_keys, child
			])


func _find_control(position):
	""""
	Finds a button or an analog stick at a given position.
	By design, a given position will only match one single
	button or analog (no two of them at all).
	
	In the worst case, it does not find any component at
	the current position (returns null in that case). In
	the best case, it returns a triple of:
	
	- The mapped keys or axes of the involved component.
	- The control for the button or analog stick.
	- A boolean telling whether the control is an analog.
	"""

	for button in _BUTTONS:
		if button[0].has_point(position):
			# (mapped keys, button node, true)
			# - The mapped keys (one or two) to press/release.
			# - The button node (control).
			# - false: It is a button, not an analog.
			return [button[1], button[2], false]
	for analog in _ANALOGS:
		if analog[0].has_point(position):
			# (mapped keys, button node, true)
			# - The mapped keys (always two: x, y) to change/release.
			# - The analog node (control).
			# - true: It is an analog.
			return [analog[1], analog[2], true]
	return null


func _input(event):
	var position
	var pressed
	var index
	var button
	# if event is InputEventScreenTouch:
	# 	position = event.position
	# 	pressed = event.pressed
	# 	index = event.index
	# 	button = null
	# 	if pressed:
	# 		if index not in _TOUCHES:
	# 			button = _find_button(position)
	# 			if button:
	# 				_TOUCHES[index] = button
	# 				button[1].pressed = true
	# 				# TODO the buttons were pressed.
	# 	else:
	# 		if index in _TOUCHES:
	# 			button = _TOUCHES[index]
	# 			button.pressed = false
	# 			_TOUCHES.erase(index)
	# 			# TODO the buttons were released.
	# elif event is InputEventScreenDrag:
	# 	position = event.position
	# 	index = event.index
	# 	button = _find_button(position)
	# 	if button != null:
	# 		if index not in _TOUCHES:
	# 			_TOUCHES[index] = button
	# 			button[1].pressed = true
	# 			# TODO the buttons were pressed.
	# 		else:
	# 			# Index is present: update the buttons.
	# 			pass


# Called when the node enters the scene tree for the first time.
func _ready():
	_collect_controls()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
