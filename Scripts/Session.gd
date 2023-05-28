extends Control


# This is the underlying connection manager for the
# session(s) to establish.
var _stream : StreamPeerTCP = StreamPeerTCP.new()

# All these signals are intended for the flow of this
# connection, like this:
# - The session could not be established.
signal session_failed(failure_type, failure_code)
# - The session is being attempted.
signal session_starting
# - The session attempt succeeded.
signal session_approved
# - The session terminated (e.g. timeout).
signal session_ended(reason_type, reason)
# - The ping loop started.
signal debug_ping_loop_started
# - A ping was sent to the server.
signal debug_ping_send_success
# - A ping was not successfully sent to the server.
signal debug_ping_send_error(error)
# - The ping loop ended.
signal debug_ping_loop_ended
# - The pong loop started.
signal debug_pong_loop_started
# - A pong was received from the server.
signal debug_pong_received
# - The pong loop ended.
signal debug_pong_loop_ended
# - The data loop started.
signal debug_data_loop_started
# - The data loop ended.
signal debug_data_loop_ended
# - There was an error sending the data.
signal debug_session_send_error(error)

# Reason types for closing/failure:
const REASON_TYPE_LOCAL = 1000
const REASON_TYPE_SERVER = 2000

# Failure reasons:
# - The authentication failed.
const FAIL_REASON_SERVER_AUTH_FAILED = 1001
# - The attempted pad is busy.
const FAIL_REASON_SERVER_PAD_BUSY = 1002
# - Invalid pad.
const FAIL_REASON_CLIENT_INVALID_PAD = 2001
# - Invalid password (not being 4 lowercase letters).
const FAIL_REASON_CLIENT_INVALID_PASSWORD = 2002
# - Invalid nickname (empty).
const FAIL_REASON_CLIENT_INVALID_NICKNAME = 2003
# - The attempted server could not be reached
#   or something else happened.
const FAIL_REASON_CLIENT_UNKNOWN = 2999

# Close reasons:
# - Graceful disconnection from the server (e.g. kick).
const CLOSE_REASON_SERVER_TERMINATED = 1001
# - The server kicked the client due to timeout (lack of ping).
const CLOSE_REASON_SERVER_TIMEOUT = 1002
# - The server closed due to an unexpected error.
const CLOSE_REASON_SERVER_UNKNOWN = 1999
# - Graceful disconnection from the client.
const CLOSE_REASON_CLIENT_TERMINATED = 2001
# - The client never received a PONG timeout from the server.
const CLOSE_REASON_CLIENT_TIMEOUT = 2002

# Messages the client sends to the server:
const REQUEST_CLOSE_CONNECTION = 19
const REQUEST_PING = 20
# Messages the server sends to the client:
const SERVER_AUTH_FAILED = 1
const SERVER_PAD_BUSY = 4
const SERVER_NOTIFICATION_TERMINATED = 5
const SERVER_NOTIFICATION_PONG = 7
const SERVER_NOTIFICATION_TIMEOUT = 8

# This is the session status. It will be "active" when
# between session_approved and session_ended. It will
# be "starting" when between session_starting and
# session_approved/session_failed(server, ...). It will
# be NONE in any other moment.
enum SessionStatus { NONE, STARTING, ACTIVE }
var _session_status : SessionStatus = SessionStatus.NONE

# This is the mode the pad will use.
var MODE_COMPATIBLE = 1


############
# General session functions.
############


func _wait_socket_status(statuses : Array):
	"""
	Waits until the status is in a certain set of values.
	
	This is a co-routine that must be waited for.
	"""
	
	if len(statuses) == 0:
		return
	
	while true:
		await get_tree().process_frame
		if _stream.get_status() in statuses:
			break


############
# Ping related functions.
############


const PING_SEND_INTERVAL : float = 3
const PONG_RECEIVE_INTERVAL : float = 10
var _pong_received : bool = false

func _ping_send():
	"""
	Sends the ping. Attempts until done.
	
	This is a co-routine that must NOT be waited for.
	"""
	
	var result : Error = OK
	while _stream.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		result = _stream.put_data([REQUEST_PING])
		if result == OK:
			emit_signal("debug_ping_send_success")
			break
		else:
			emit_signal("debug_ping_send_error", result)
			await get_tree().process_frame

func _ping_loop():
	"""
	Performs a ping loop to have this socket still
	active, and not incurring into timeouts.
	
	This is a co-routine that must NOT be waited for.
	It must be invoked when the session is starting.
	"""
	
	var _time = 0
	emit_signal("debug_ping_loop_started")
	await get_tree().process_frame
	while _stream.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		_time += get_process_delta_time()
		if _time >= PING_SEND_INTERVAL:
			_time -= PING_SEND_INTERVAL
			_ping_send()
		await get_tree().process_frame
	emit_signal("debug_ping_loop_ended")

func _pong_loop():
	"""
	Performs a pong loop to know that this socket is
	still acknowledged from the server.
	
	This is a co-routine that must NOT be waited for.
	It must be invoked when the session is starting.
	"""
	
	var _time = 0
	emit_signal("debug_pong_loop_started")
	await get_tree().process_frame
	while _stream.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		_time += get_process_delta_time()
		if _pong_received:
			_pong_received = false
			_time = 0
			emit_signal("debug_pong_received")
		if _time >= PONG_RECEIVE_INTERVAL:
			_stream.put_data([REQUEST_CLOSE_CONNECTION])
			_stream.disconnect_from_host()
			await _wait_socket_status([
				StreamPeerTCP.STATUS_NONE, StreamPeerTCP.STATUS_ERROR
			])
		await get_tree().process_frame
	emit_signal("debug_pong_loop_ended")


############
# Stream utilities functions.
############


func _locally_close(reason_type, reason):
	"""
	Closes the connection.
	"""

	_stream.disconnect_from_host()
	if _session_status in [SessionStatus.ACTIVE, SessionStatus.STARTING]:
		_session_status = SessionStatus.NONE
		emit_signal("session_ended", reason_type, reason)


func _locally_fail(reason_type, reason):
	"""
	Fails the connection.
	"""

	_stream.disconnect_from_host()
	_session_status = SessionStatus.NONE
	emit_signal("session_failed", reason_type, reason)


############
# Data arrival functions.
############


func _data_arrival_loop():
	"""
	Performs a data arrival loop to read data from this
	socket. This also processes the response accordingly.

	This is a co-routine that must NOT be waited for.
	It must be invoked when the session is starting.
	"""

	emit_signal("debug_data_loop_started")
	while _stream.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		await get_tree().process_frame
		if _stream.get_available_bytes() > 0:
			var response = _stream.get_data(_stream.get_available_bytes())
			match response[1][0]:
				0:
					_session_status = SessionStatus.ACTIVE
					emit_signal("session_approved")
				SERVER_AUTH_FAILED:
					_locally_fail(REASON_TYPE_SERVER, FAIL_REASON_SERVER_AUTH_FAILED)
				SERVER_PAD_BUSY:
					_locally_fail(REASON_TYPE_SERVER, FAIL_REASON_SERVER_PAD_BUSY)
				SERVER_NOTIFICATION_PONG:
					_pong_received = true
				SERVER_NOTIFICATION_TIMEOUT:
					_locally_close(REASON_TYPE_SERVER, CLOSE_REASON_SERVER_TIMEOUT)
				SERVER_NOTIFICATION_TERMINATED:
					_locally_close(REASON_TYPE_SERVER, CLOSE_REASON_SERVER_TERMINATED)
				_:
					_locally_close(REASON_TYPE_SERVER, CLOSE_REASON_SERVER_UNKNOWN)
	emit_signal("debug_data_loop_ended")


############
# Public functions to connect, disconnect, and send
# the required keys through the socket.
############


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


func session_connect(
	host : String, pad_index : int, password : String, nickname : String
):
	"""
	Attempts a socket connection. It may fail due to server, due
	to client settings (e.g. bad parameters) or due to auth or
	pad settings. It will close any pre-existing connection.
	
	This is a co-routine that must be waited for.
	"""

	# First, disconnect the previous session, if any.
	if _stream.get_status() != StreamPeerTCP.STATUS_NONE:
		_locally_close(REASON_TYPE_LOCAL, CLOSE_REASON_CLIENT_TERMINATED)
		await _wait_socket_status([
			StreamPeerTCP.STATUS_NONE, StreamPeerTCP.STATUS_ERROR
		])

	# Then, prepare the message.
	var message = PackedByteArray([])

	# 1. Start by checking/adding the padd.
	if pad_index < 0 or pad_index > 7:
		emit_signal("session_failed", REASON_TYPE_LOCAL, FAIL_REASON_CLIENT_INVALID_PAD)
		return
	message.append(pad_index)

	# 2. Add the mode. It will be constant here.
	message.append(MODE_COMPATIBLE)

	# 3. Add the password.
	password = _filter_only_letters(password, 4)
	if len(password) != 4:
		emit_signal("session_failed", REASON_TYPE_LOCAL, FAIL_REASON_CLIENT_INVALID_PASSWORD)
		return
	message += password.to_utf8_buffer()

	# 4. Add the nickname (pad it with spaces)
	nickname = _filter_only_letters(nickname, 16)
	if len(nickname) == 0:
		emit_signal("session_failed", REASON_TYPE_LOCAL, FAIL_REASON_CLIENT_INVALID_NICKNAME)
		return
	message += (nickname + " ".repeat(16 - len(nickname))).to_utf8_buffer()
		
	var error = _stream.connect_to_host(host, 2357)
	if error != OK:
		emit_signal("session_failed", REASON_TYPE_LOCAL, FAIL_REASON_CLIENT_UNKNOWN)
		return
	else:
		# Mark the session as starting, and wait until
		# the socket is connected.
		_session_status = SessionStatus.STARTING
		await _wait_socket_status([StreamPeerTCP.STATUS_CONNECTED])
		# Then, mark the session as starting and attempt the
		# login message.
		emit_signal("session_starting")
		var result = _stream.put_data(message)
		if result != OK:
			_locally_close(REASON_TYPE_LOCAL, FAIL_REASON_CLIENT_UNKNOWN)
			await _wait_socket_status([
				StreamPeerTCP.STATUS_NONE, StreamPeerTCP.STATUS_ERROR
			])
		else:
			_ping_loop()
			_pong_loop()
			_data_arrival_loop()


func session_disconnect():
	"""
	Disconnects any existing connection.
	
	This is a co-routine that must be waited for.
	"""
	
	_locally_close(REASON_TYPE_LOCAL, CLOSE_REASON_CLIENT_TERMINATED)
	await _wait_socket_status([
		StreamPeerTCP.STATUS_NONE, StreamPeerTCP.STATUS_ERROR
	])


func session_send(data):
	"""
	Attempts to send data.
	"""

	if _session_status != SessionStatus.ACTIVE:
		return false

	var message = PackedByteArray([len(data)])
	for pair in data:
		if not (pair is Array) or len(pair) != 2:
			continue
		message.append(pair[0])
		message.append(pair[1])
	var result = _stream.put_data(message)
	if result != OK:
		emit_signal("debug_session_send_error", result)
	return true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	_stream.poll()
