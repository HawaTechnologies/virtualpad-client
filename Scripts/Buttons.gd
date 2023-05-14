extends Control


# This script is intended to do the following things to all
# the contained buttons:
# - Recognize their different shape: big, small, < ^ > v or
#   d-pad diagonals.
# - Be able to set a different color to all of them at once
#   out of some given preset colors.
# - Efficiently treat the 5 states of a button to generate,
#   on each state, the proper style.
func _override_shape(btn):
	"""
	Overrides the shapes of a button, in their theme overrides.
	We assume that the theme overrides are already initialized
	in this button, to empty.
	"""
	
	var shape = btn.get_meta("shape")

	# TODO for all the styles, use Anti-Aliasing: On (0.313).

	if shape == "small":
		# L1, L2, R1, R2 buttons are here.
		# Also: Select, Start.
		pass
	elif shape == "big":
		# North, South, East, West are here. The button is 80x80
		# and now we must ensure it has this style:
		# - All corners round to a radius of 40.
		# - Focus: Do nothing (keep empty).
		# - Pressed:
		#   - Borders: 4px (Bottom=8px).
		#   - Expand Margins: Top=4px.
		#   - Content Margins: Bottom=16px.
		# - Not Pressed:
		#   - Borders: 4px (Bottom=14px).
		#   - Expand Margins: Top=10px.
		#   - Content Margins: Top=26px.
		pass
	elif shape == "d-pad-up":
		# ^ button
		pass
	elif shape == "d-pad-up-right":
		# ^> button
		pass
	elif shape == "d-pad-right":
		# > button
		pass
	elif shape == "d-pad-down-right":
		# v> button
		pass
	elif shape == "d-pad-down":
		# v button
		pass
	elif shape == "d-pad-down-left":
		# <v button
		pass
	elif shape == "d-pad-left":
		# < button
		pass
	elif shape == "d-pad-up-left":
		# <^ button
		pass
	else:
		# No change here.
		pass

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
