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
var _AXES = []


# These are the touches (in terms of the touch screen) that
# are being tracked. Each touch will consist of:
# - key: the touch index.
# - value: the last element being touched (which can be an
#          analog axis, or a button, or nothing).
#
# Axes are a different kind of component, actually. They're
# composed of a background (main) component which is just a
# rectangle with a circular design.
#
# The goal of this structure is to track for the fingers
# move across touches.
var _TOUCHES = {}


# The current and new states of all the buttons and axes.
var _current_state = []
var _new_state = []


func _find_button(position):
	for setting in _BUTTONS:
		if setting[0].has_point(position):
			return [setting[1], setting[2]]
	return null


func _input(event):
	var position
	var pressed
	var index
	var button
	if event is InputEventScreenTouch:
		position = event.position
		pressed = event.pressed
		index = event.index
		button = null
		if pressed:
			if index not in _TOUCHES:
				button = _find_button(position)
				if button:
					_TOUCHES[index] = button
					button[1].pressed = true
					# TODO the buttons were pressed.
		else:
			if index in _TOUCHES:
				button = _TOUCHES[index]
				button.pressed = false
				_TOUCHES.erase(index)
				# TODO the buttons were released.
	elif event is InputEventScreenDrag:
		position = event.position
		index = event.index
		button = _find_button(position)
		if button != null:
			if index not in _TOUCHES:
				_TOUCHES[index] = button
				button[1].pressed = true
				# TODO the buttons were pressed.
			else:
				# Index is present: update the buttons.
				pass


# Called when the node enters the scene tree for the first time.
func _ready():
	_BUTTONS.clear()
	_AXES.clear()
	var count = 0
	for child in get_tree().get_nodes_in_group("ThemedButtons"):
		var target = _AXES
		if count < 14:
			target = _BUTTONS
		target.append([
			Rect2(child.rect_global_position, child.rect_size),
			child.get_meta("keys"), child
		])
		count += 1


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
