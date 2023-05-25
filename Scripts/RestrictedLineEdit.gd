extends TextEdit


var _chars = ""
var _max_length = -1


func _ready():
	self._chars = get_meta("allowed_chars")
	if self._chars == null:
		self._chars = ""
	self._max_length = get_meta("max_length")
	if self._max_length == null:
		self._max_length = -1


func _input(event):
	if event is InputEventKey:
		var new_text = text
		var column = get_caret_column()
		if self._chars != "":
			var filtered_text = ""
			for text_chr in new_text:
				if text_chr in _chars:
					filtered_text += text_chr
			new_text = filtered_text
		if _max_length > -1:
			new_text = new_text.substr(0, _max_length)
		text = new_text
		set_caret_column(column)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
