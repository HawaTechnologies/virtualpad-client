extends Control


# There are some UI elements needed by this main HUD, being:
# - The buttons overlay.
# - The left & right close buttons.
var _overlay = null
var _left_close = null
var _right_close = null
# Also, the timer for the close buttons.
const CLOSE_HOLD_TIME : float = 3.0
var _close_timer : float = 0
# Finally, the reference to the script.
var _script : Script = null


############
# Functions to load and save settings.
############


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


############
# Life-cycle.
############


func _ready():
	_overlay = get_parent().get_node("ButtonOverlay")
	_overlay.connect("gamepad_input", $Session.session_send)
	_script = $Session.get_script()
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
	$Session.connect("session_failed", self._session_failed)
	$Session.connect("session_starting", self._session_starting)
	$Session.connect("session_approved", self._session_approved)
	$Session.connect("session_ended", self._session_ended)
	$Session.connect("debug_data_loop_started", self._debug_data_loop_started)
	$Session.connect("debug_data_loop_ended", self._debug_data_loop_ended)
	$Session.connect("debug_ping_loop_started", self._debug_ping_loop_started)
	$Session.connect("debug_ping_send_success", self._debug_ping_send_success)
	$Session.connect("debug_ping_send_error", self._debug_ping_send_error)
	$Session.connect("debug_ping_loop_ended", self._debug_ping_loop_ended)
	$Session.connect("debug_pong_loop_started", self._debug_pong_loop_started)
	$Session.connect("debug_pong_receive_success", self._debug_pong_receive_success)
	$Session.connect("debug_pong_receive_error", self._debug_pong_receive_error)
	$Session.connect("debug_pong_loop_ended", self._debug_pong_loop_ended)
	$Session.connect("debug_session_send_error", self._debug_session_send_error)
	$Session.connect("debug_session_receive_error", self._debug_session_receive_error)
	_reload_settings()
	_show_popup($FormConnect)


############
# Signal handlers
############


func _session_failed(reason_type, reason):
	"""
	Handler for when the session failed.
	"""
	
	if reason_type == _script.REASON_TYPE_LOCAL:
		match reason:
			_script.FAIL_REASON_CLIENT_INVALID_PAD:
				$FormConnectionFailed/Content.text = "Invalid pad"
			_script.FAIL_REASON_CLIENT_INVALID_NICKNAME:
				$FormConnectionFailed/Content.text = "Invalid/empty nickname"
			_script.FAIL_REASON_CLIENT_INVALID_PASSWORD:
				$FormConnectionFailed/Content.text = "Password must be\n4 lowercase letters"
			_:
				$FormConnectionFailed/Content.text = "Unknown error\nCheck your server settings"
	elif reason_type == _script.REASON_TYPE_SERVER:
		match reason:
			_script.FAIL_REASON_SERVER_AUTH_FAILED:
				$FormConnectionFailed/Content.text = "Pad authentication failed"
			_script.FAIL_REASON_SERVER_PAD_BUSY:
				$FormConnectionFailed/Content.text = "Pad already in use"
			_:
				$FormConnectionFailed/Content.text = "Unknown error\nCheck your server settings"
	else:
		$FormConnectionFailed/Content.text = "Unknown error\nCheck your server settings"
	_show_popup($FormConnectionFailed)


func _session_starting():
	"""
	Handler for when the session is starting.
	"""

	_save_settings()
	_show_popup($FormConnecting)


func _session_approved():
	"""
	Handler for when the session is approved.
	"""

	_show_popup(null)


func _session_ended(reason_type, reason):
	"""
	Handler for when the session ended.
	"""

	if reason_type == _script.REASON_TYPE_SERVER:
		match reason:
			_script.CLOSE_REASON_SERVER_TERMINATED:
				$FormConnectionClosed/Content.text = "The gamepad was disconnected"
			_script.CLOSE_REASON_SERVER_TIMEOUT:
				$FormConnectionClosed/Content.text = "The server lost any contact\nto this pad"
			_:
				$FormConnectionClosed/Content.text = "The connection\nunexpectedly ended"
	elif reason_type == _script.REASON_TYPE_LOCAL:
		match reason:
			_script.CLOSE_REASON_CLIENT_TERMINATED:
				$FormConnectionClosed/Content.text = "Connection terminated successfully"
			_script.CLOSE_REASON_CLIENT_TIMEOUT:
				$FormConnectionClosed/Content.text = "No activity was detected\nfrom the server"
			_:
				$FormConnectionClosed/Content.text = "Unknown error\nCheck your server settings"
	else:
		$FormConnectionClosed/Content.text = "Unknown error"
	_show_popup($FormConnectionClosed)


func _debug_data_loop_started():
	print("Data loop started")


func _debug_data_loop_ended():
	print("Data loop ended")


func _debug_ping_loop_started():
	print("Ping loop started")


func _debug_ping_send_success():
	print("Ping sent")


func _debug_ping_send_error(err):
	print("Ping not sent! Error code: ", err)


func _debug_ping_loop_ended():
	print("Ping loop ended")


func _debug_pong_loop_started():
	print("Pong loop started")


func _debug_pong_receive_success():
	print("Pong received")


func _debug_pong_receive_error(err):
	print("Pong error! Error code: ", err)


func _debug_pong_loop_ended():
	print("Pong loop ended")


func _debug_session_send_error(err):
	print("Send error! Error code: ", err)


func _debug_session_receive_error(err):
	print("Receive error! Error code: ", err)


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
	$Session.session_connect(host, pad, password, nickname)


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
	$Session.session_disconnect()


func _form_connection_close__no():
	"""
	Close this form.
	"""
	
	_show_popup(null)


func _process(delta):
	"""
	The processing here works only while the
	status is connected: A ping is sent every
	3 seconds, and any potential server message
	is properly handled.
	"""
	
	
	_check_close_buttons(delta)
