extends Control


# This is the status of the connection. Only these statuses
# are supported: When the connection is NOT established, when
# the connection is established, and when the connection is
# being established (i.e. a log-in process).
enum Status {DISCONNECTED, CONNECTING, CONNECTED}


# The messages.
const CLOSE_CONNECTION = 18
const PING = 19


# Local errors for the connections.
const ALREADY_CONNECTED = 1
const INVALID_PAD_INDEX = 2
const INVALID_NICKNAME = 3
const INVALID_PASSWORD = 4
const INVALID_MODE = 5


# Callbacks to process when a connection is: started (moves to
# CONNECTING), approved (a successful log-in into an empty pad
# slot -- moves to CONNECTED), and closed (the connection was
# in CONNECTED state, and was closed).
signal connection_started
signal connection_approved
signal connection_closed(reason)


# This is the status for the current connection. Also, a timer
# is used to check to send ping commands properly. Also, the
# reference to the socket.
var _status : Status = Status.DISCONNECTED
var _timer : float = 0
var _stream : StreamPeerTCP = StreamPeerTCP.new()


# And finally, this is the related buttons overlay component.
var _overlay = null


func _ready():
	_overlay = get_parent().get_node("ButtonOverlay")
	_overlay.connect("gamepad_input", self._gamepad_send)


func _ping_send(delta):
	"""
	Checks the timer and sends the ping.
	"""

	_timer += delta
	if _timer > 3:
		# Send [PING] every 3 seconds.
		_stream.put_data([PING])


func _process_server_answer():
	"""
	Retrieves and processes any potential answer
	from the server. Typically, messages other
	than "connection successful" count as reasons
	to terminate the connection.
	"""

	if _stream.get_available_bytes() > 0:
		var response = _stream.get_data(_stream.get_available_bytes())
		match response[0]:
			0:
				_status = Status.CONNECTED
				emit_signal("connection_approved")
			_:
				# Typical messages: 1 2 3 4 6
				_status = Status.DISCONNECTED
				_stream.disconnect_from_host()
				emit_signal("connection_closed", response[0])


func _process(delta):
	"""
	The processing here works only while the
	status is connected: A ping is sent every
	3 seconds, and any potential server message
	is properly handled.
	"""
	
	if _status != Status.CONNECTED:
		# Clear ping, if any, and abort.
		_timer = 0
		return
	
	# First, send the PING signal and update.
	_ping_send(delta)

	# Then, process any server answer.
	_process_server_answer()

	# Finally, fix the status if the socket
	# is not connected.
	if !_stream.is_connected_to_host():
		self.gamepad_disconnect()
		emit_signal("connection_closed", 0)


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
	

func gamepad_connect(host, index, password, nickname, mode=1):
	"""
	Attempts a connection to a given host. Returns
	a triple [success, is_socket_error, error_code].
	"""
	
	var message = PackedByteArray([])
	if _status != Status.DISCONNECTED:
		return [false, false, ALREADY_CONNECTED]
	
	if index < 0 or index > 7:
		return [false, false, INVALID_PAD_INDEX]
	message.append(index)

	if mode not in [0, 1]:
		return [false, false, INVALID_MODE]
	message.append(mode)

	nickname = _filter_only_letters(nickname, 16)
	if len(nickname) == 0:
		return [false, false, INVALID_NICKNAME]	
	message += (nickname + " ".repeat(16 - len(nickname))).to_utf8_buffer()

	password = _filter_only_letters(password, 4)
	if len(password) != 4:
		return [false, false, INVALID_PASSWORD]
	message += password.to_utf8_buffer()
		
	var error = _stream.connect_to_host(host, 2357)
	if error != OK:
		_status = Status.DISCONNECTED
		return [false, true, error]
	else:
		_status = Status.CONNECTING
		emit_signal("connection_started")
		_stream.put_data(message)
		return [true, false, OK]


func _gamepad_send(data):
	"""
	Attempts to send command data.
	"""

	if _status != Status.CONNECTED:
		return false

	var message = PackedByteArray([len(data)])
	for pair in data:
		if not (pair is Array) or len(pair) != 2:
			continue
		message.append(pair[0])
		message.append(pair[1])
	_stream.put_data(message)
	return true


func gamepad_disconnect():
	"""
	Attempts to disconnect the socket.
	"""

	if _status == Status.DISCONNECTED:
		return false

	_status = Status.DISCONNECTED
	if _stream.is_connected_to_host():
		_stream.put_data([CLOSE_CONNECTION])
		_stream.disconnect_from_host()
		emit_signal("connection_closed", 0)
	return true


func get_status():
	"""
	Returns the socket status, as string.
	"""

	match _status:
		Status.CONNECTED:
			return "connected"
		Status.CONNECTING:
			return "connecting"
		Status.DISCONNECTED:
			return "disconnected"
		_:
			return "unknown"
