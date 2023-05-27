extends Control


# This is the status of the connection. Only these statuses
# are supported: When the connection is NOT established, when
# the connection is established, and when the connection is
# being established (i.e. a log-in process).
enum Status {DISCONNECTED, LOGGING_IN, LOGGED_IN}


signal connection_approved
signal connection_closed


# The messages.
const CLOSE_CONNECTION = 19
const PING = 20

# The error types
const SUCCESS = 0
const SOCKET_ERROR = 1
const APP_ERROR = 2

# Responses for the connections.
# Application.
const ALREADY_CONNECTED = 1
const INVALID_PAD_INDEX = 2
const INVALID_NICKNAME = 3
const INVALID_PASSWORD = 4
const INVALID_MODE = 5

# Socket responses/notifications.
const PONG = 7
const TIMEOUT = 8


# This is the status for the current connection. Also, a timer
# is used to check to send ping commands properly. Also, the
# reference to the socket. And also, a pong-tracking timer.
var _status : Status = Status.DISCONNECTED
const PING_TIME : float = 3.0
var _ping_timer : float = 0
var _stream : StreamPeerTCP = StreamPeerTCP.new()
const PONG_TIME : float = 10.0
var _pong_timer : float = 0
# Also a timer to delay the disconnection.
var _disconnect_timer : float = 0

# Also, this is the login data to use. If not null, it will be
# send-attempted to the server (and then set to null quickly).
var _login_data = null

# And finally, this is the related buttons overlay component.
var _overlay = null

# Also the buttons to close the connection.
var _left_close = null
var _right_close = null

# This timer, now, regulates the UI time. Pressing both close
# connection buttons at once will open the "Close?" dialog,
# and this timer tracks that.
const CLOSE_HOLD_TIME = 3.0
var _close_timer = 0

# This is the pong time. A constant to check against, and a
# variable to track the time between pongs.


func _reload_settings():
	"""
	Loads the last connection's settings, if any.
	"""

	var config = ConfigFile.new()
	print("Loading settings")

	# Load existing settings if they exist
	if config.load("user://settings.cfg") == OK:
		print("Settings were found. Loading them")
		var host = config.get_value("connection", "host", "")
		var password = config.get_value("connection", "password", "")
		var index = int(config.get_value("connection", "index", 0))
		var nickname = config.get_value("connection", "nickname", "")
		$FormConnect/Host.text = host
		$FormConnect/Pad.selected = index
		$FormConnect/Password.text = password
		$FormConnect/Nickname.text = nickname


func _save_settings():
	"""
	Saves the current connection's settings, if any.
	"""

	var config = ConfigFile.new()
	config.set_value("connection", "host", $FormConnect/Host.text)
	config.set_value("connection", "password", $FormConnect/Password.text)
	config.set_value("connection", "index", $FormConnect/Pad.selected)
	config.set_value("connection", "nickname", $FormConnect/Nickname.text)
	config.save("user://settings.cfg")


func _ready():
	_overlay = get_parent().get_node("ButtonOverlay")
	_overlay.connect("gamepad_input", self._gamepad_send)
	_left_close = get_parent().get_node("Buttons/LeftDisconnect")
	_right_close = get_parent().get_node("Buttons/RightDisconnect")
	$FormConnect/Connect.connect(
		"pressed", self._form_connect__connect
	)
	$FormConnectionFailed/GoBack.connect(
		"pressed", self._form_connection_failed__go_back
	)
	$FormConnectionClosed/GoBack.connect(
		"pressed", self._form_connection_closed__go_back
	)
	$FormCloseConnection/Yes.connect(
		"pressed", self._form_connection_close__yes
	)
	$FormCloseConnection/No.connect(
		"pressed", self._form_connection_close__no
	)
	_reload_settings()
	_show_popup($FormConnect)


func _show_popup(popup):
	"""
	Shows a pop-up and toggles the disconnect buttons.
	"""
	
	$FormConnect.visible = false
	$FormConnecting.visible = false
	$FormCloseConnection.visible = false
	$FormConnectionClosed.visible = false
	$FormConnectionFailed.visible = false
	if popup != null:
		popup.visible = true
		_left_close.visible = false
		_right_close.visible = false
	else:
		_left_close.visible = true
		_right_close.visible = true


func _check_close_buttons(delta):
	"""
	Checks whether the close buttons are being
	simultaneously pressed for 3 seconds.
	"""
	
	if not _left_close.visible or not _left_close.button_pressed or \
		not _right_close.visible or not _right_close.button_pressed:
			_close_timer = 0
	else:
		_close_timer += delta
		if _close_timer >= CLOSE_HOLD_TIME:
			_show_popup($FormCloseConnection)


func _form_connect__connect():
	"""
	Attempts to connect, using the form data.
	"""
	
	var nickname = $FormConnect/Nickname.text
	var password = $FormConnect/Password.text
	var pad = $FormConnect/Pad.selected
	var host = $FormConnect/Host.text
	var result = _gamepad_connect(host, pad, password, nickname)
	var type = result[0]
	var error_code = result[1]
	
	match type:
		SOCKET_ERROR:
			$FormConnectionFailed/Content.text = "Wrong or unreachable server"
			_show_popup($FormConnectionFailed)
		APP_ERROR:
			match error_code:
				INVALID_MODE:
					$FormConnectionFailed/Content.text = "Unexpected pad mode"
				INVALID_NICKNAME:
					$FormConnectionFailed/Content.text = "Choose a nickname"
				INVALID_PAD_INDEX:
					$FormConnectionFailed/Content.text = "Choose a pad 1-8"
				INVALID_PASSWORD:
					$FormConnectionFailed/Content.text = "The password must have 4 letters"
				ALREADY_CONNECTED:
					$FormConnectionFailed/Content.text = "Already connected"
			_show_popup($FormConnectionFailed)
		_:
			_save_settings()
			_show_popup($FormConnecting)


func _form_connection_failed__go_back():
	"""
	Closes this form, open the Connect form again.
	"""
	
	_reload_settings()
	_show_popup($FormConnect)


func _form_connection_closed__go_back():
	"""
	Closes this form, open the Connect form again.
	"""

	_reload_settings()
	_show_popup($FormConnect)


func _form_connection_close__yes():
	"""
	Close this form, and disconnect.
	"""

	_show_popup(null)
	_gamepad_disconnect()


func _form_connection_close__no():
	"""
	Close this form.
	"""
	
	_show_popup(null)


func _ping_send(delta):
	"""
	Checks the timer and sends the ping.
	"""

	_ping_timer += delta
	if _ping_timer > PING_TIME:
		_ping_timer -= PING_TIME
		_stream.put_data([PING])


func _pong_check(delta):
	"""
	Checks the timer since the last pong and disconnects
	if no pong received for a while.
	"""

	_pong_timer += delta
	if _pong_timer > PONG_TIME:
		_gamepad_disconnect(8)


func _connection_termination_text(idx):
	return {
		1: "Authentication failed",
		4: "Pad already in use",
		5: "Connection terminated successfully",
		8: "Connection timed out",
	}.get(idx, "Unexpected error (%d)" % idx)


func _process_server_answer():
	"""
	Retrieves and processes any potential answer
	from the server. Typically, messages other
	than "connection successful" count as reasons
	to terminate the connection.
	"""

	if _stream.get_available_bytes() > 0:
		var response = _stream.get_data(_stream.get_available_bytes())
		match response[1][0]:
			0:
				_status = Status.LOGGED_IN
				_show_popup(null)
				$FormConnecting.visible = false
				emit_signal("connection_approved")
			PONG:
				pass
			_:
				# Typical messages: 1, 4, and 5.
				# Codes 2, 3, 6 become Unexpected Error.
				self._gamepad_disconnect(response[1][0], false)
				_status = Status.DISCONNECTED
				_stream.disconnect_from_host()
				$FormConnectionClosed/Label.text = _connection_termination_text(
					response[1][0]
				)
				emit_signal("connection_closed")
				_show_popup($FormConnectionClosed)


func _send_login():
	"""
	Sends the login data, if present.
	"""

	if _login_data != null:
		_stream.set_no_delay(true)
		_stream.put_data(_login_data)
		_login_data = null


func _process(delta):
	"""
	The processing here works only while the
	status is connected: A ping is sent every
	3 seconds, and any potential server message
	is properly handled.
	"""
	
	
	_check_close_buttons(delta)
	
	# Socket interactions start here.
	
	_stream.poll()
	var status = _stream.get_status()
	if status == StreamPeerTCP.STATUS_CONNECTED:
		# First, sends the login if any.
		_send_login()
		
		# Then, send the PING signal properly and update.
		_ping_send(delta)

		# Then, process any server answer.
		_process_server_answer()
	else:
		# Clear ping, if any.
		_ping_timer = 0
		_pong_timer = 0
	
	if status in [StreamPeerTCP.STATUS_ERROR, StreamPeerTCP.STATUS_NONE] and \
		_status in [Status.LOGGED_IN, Status.LOGGING_IN]:
		_disconnect_timer += delta
		_gamepad_disconnect()
	else:
		_disconnect_timer = 0


func _filter_only_letters(value, length):
	"""
	Filters a value to use only letters and a given length.
	"""
	
	value = value.to_lower().strip_edges()
	var filtered_value = ""
	for character in value:
		if character in "abcdefghijklmnopqrstuvwxyz":
			filtered_value += character
	return filtered_value.substr(0, length)
	

func _gamepad_connect(host, index, password, nickname, mode=1):
	"""
	Attempts a connection to a given host. Returns
	a triple [success, is_socket_error, error_code].
	"""
	
	var message = PackedByteArray([])
	_stream.poll()
	if _stream.get_status() != StreamPeerTCP.STATUS_NONE:
		return [APP_ERROR, ALREADY_CONNECTED]
	
	if index < 0 or index > 7:
		return [APP_ERROR, INVALID_PAD_INDEX]
	message.append(index)

	if mode not in [0, 1]:
		return [APP_ERROR, INVALID_MODE]
	message.append(mode)

	password = _filter_only_letters(password, 4)
	if len(password) != 4:
		return [APP_ERROR, INVALID_PASSWORD]
	message += password.to_utf8_buffer()

	nickname = _filter_only_letters(nickname, 16)
	if len(nickname) == 0:
		return [APP_ERROR, INVALID_NICKNAME]
	message += (nickname + " ".repeat(16 - len(nickname))).to_utf8_buffer()
		
	var error = _stream.connect_to_host(host, 2357)
	if error != OK:
		_status = Status.DISCONNECTED
		return [SOCKET_ERROR, error]
	else:
		_status = Status.LOGGING_IN
		print("Login data:", message, "(", len(message), ")")
		_login_data = message
		return [SUCCESS, OK]


func _gamepad_send(data):
	"""
	Attempts to send command data.
	"""

	print("Sending data: ", data)
	if _status != Status.LOGGED_IN:
		return false

	var message = PackedByteArray([len(data)])
	for pair in data:
		if not (pair is Array) or len(pair) != 2:
			continue
		message.append(pair[0])
		message.append(pair[1])
	_stream.put_data(message)
	return true


func _gamepad_disconnect(code = 5, send_terminate = false):
	"""
	Attempts to disconnect the socket.
	"""

	_status = Status.DISCONNECTED
	_stream.poll()
	var status = _stream.get_status()
	var result = false
	if status in [StreamPeerTCP.STATUS_CONNECTED,
					StreamPeerTCP.STATUS_CONNECTING]:
		if status == StreamPeerTCP.STATUS_CONNECTED and send_terminate:
			_stream.put_data([CLOSE_CONNECTION])
		_stream.disconnect_from_host()
		result = true

	$FormConnectionClosed/Label.text = _connection_termination_text(code)
	emit_signal("connection_closed")
	_show_popup($FormConnectionClosed)
	return result


func get_status():
	"""
	Returns the socket status, as string.
	"""

	match _status:
		Status.LOGGED_IN:
			return "connected"
		Status.LOGGING_IN:
			return "connecting"
		Status.DISCONNECTED:
			return "disconnected"
		_:
			return "unknown"
