extends Control


# This is the underlying connection manager for the
# session(s) to establish.
var _stream : StreamPeerTCP = StreamPeerTCP.new()
# Also, the last-sent host and login data will be
# held here. Why? Because the same data will be used
# to retry the connection if suddenly terminated by
# a network unstability. For a related purpose, the
# _poll_err is kept.
var _host = ""
var _login = []
var _poll_err = OK

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
signal debug_ping_send_success(delta)
# - A ping was not successfully sent to the server.
signal debug_ping_send_error(error)
# - The ping loop ended.
signal debug_ping_loop_ended
# - The pong loop started.
signal debug_pong_loop_started
# - A pong was received from the server.
signal debug_pong_receive_success(delta)
# - There was an error receiving the pong.
signal debug_pong_receive_error(error)
# - The pong loop ended.
signal debug_pong_loop_ended
# - The data loop started.
signal debug_data_loop_started
# - The data loop ended.
signal debug_data_loop_ended
# - There was an error sending the data.
signal debug_session_send_error(error)
# - There was an error receiving the data.
signal debug_session_receive_error(error)
# - A poll just executed.
signal after_poll

# Reason types for closing/failure:
const REASON_TYPE_SERVER = 1000
const REASON_TYPE_CLIENT = 2000
const REASON_TYPE_LIBRARY = 3000  # This is a poll() error, actually.

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
# - Poll reason (serves as base).
const CLOSE_REASON_LIBRARY_POLL_BASE = 3000

# Messages the client sends to the server:
const REQUEST_CLOSE_CONNECTION = 19
const REQUEST_PING = 20
# Messages the server sends to the client:
const SERVER_AUTH_FAILED = 1
const SERVER_PAD_BUSY = 4
const SERVER_NOTIFICATION_TERMINATED = 5
const SERVER_NOTIFICATION_PONG = 7
const SERVER_NOTIFICATION_TIMEOUT = 8

# Reconnection settings:
const RECONNECTION_ATTEMPTS = 3
const RECONNECTION_INTERVAL = 3

# This is the session status. It will be "active" when
# between session_approved and session_ended. It will
# be "starting" when between session_starting and
# session_approved/session_failed(server, ...). It will
# be NONE in any other moment.
enum SessionStatus { NONE, STARTING, ACTIVE }
var _session_status : SessionStatus = SessionStatus.NONE


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
		await self.after_poll
		if _stream.get_status() in statuses:
			break


############
# Ping related functions.
############


const PING_SEND_INTERVAL : float = 1
const PONG_RECEIVE_INTERVAL : float = 20
var _pong_received : bool = false

func _ping_send(delta):
	"""
	Sends the ping. Attempts until done.
	
	This is a co-routine that must NOT be waited for.
	"""
	
	var result : Error = OK
	var stamp = Time.get_ticks_msec()
	while _stream.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		result = _stream.put_data([REQUEST_PING])
		if result == OK:
			emit_signal("debug_ping_send_success", ((Time.get_ticks_msec() - stamp) + delta) / 1000.0)
			break
		else:
			emit_signal("debug_ping_send_error", result)
			await self.after_poll


func _ping_loop():
	"""
	Performs a ping loop to have this socket still
	active, and not incurring into timeouts.
	
	This is a co-routine that must NOT be waited for.
	It must be invoked when the session is starting.
	"""
	
	var _time = 0
	emit_signal("debug_ping_loop_started")
	await self.after_poll
	var stamp = Time.get_ticks_msec()
	while _stream.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		_time += get_process_delta_time()
		if _time >= PING_SEND_INTERVAL:
			_time -= PING_SEND_INTERVAL
			var new_stamp = Time.get_ticks_msec()
			_ping_send(new_stamp - stamp)
			stamp = new_stamp
		await self.after_poll
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
	await self.after_poll
	var stamp = Time.get_ticks_msec()
	while _stream.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		_time += get_process_delta_time()
		if _pong_received:
			var new_stamp = Time.get_ticks_msec()
			var delta = new_stamp - stamp
			stamp = new_stamp
			_pong_received = false
			_time = 0
			emit_signal("debug_pong_receive_success", delta / 1000.0)
		if _time >= PONG_RECEIVE_INTERVAL:
			_stream.put_data([REQUEST_CLOSE_CONNECTION])
			_stream.disconnect_from_host()
			await _wait_socket_status([
				StreamPeerTCP.STATUS_NONE, StreamPeerTCP.STATUS_ERROR
			])
		await self.after_poll
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
	await self.after_poll
	while _stream.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		if _stream.get_available_bytes() > 0:
			var response = _stream.get_data(_stream.get_available_bytes())
			if response[0] != OK:
				emit_signal("debug_session_receive_error", response[0])
			else:
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
		await self.after_poll
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


func _session_try_connect(retrying : bool = false):
	"""
	Attempts a connection from the last stored values in the
	_host and _login variables. Can tell whether this function
	is re-connecting or is connecting for the first time.
	"""
	
	var error = OK
	if retrying:
		# We wait-and-retry some times until we give up.
		for index in range(RECONNECTION_ATTEMPTS):
			await get_tree().create_timer(RECONNECTION_INTERVAL).timeout
			error = _stream.connect_to_host(_host, 2357)
			if error == OK:
				break
		
		# Then we fail with the error.
		if error != OK:
			# Always close with the previous poll error.
			_session_status = SessionStatus.NONE
			emit_signal(
				"session_ended", REASON_TYPE_LIBRARY,
				CLOSE_REASON_LIBRARY_POLL_BASE + _poll_err
			)
	else:
		# We try only once, and fail with session_failed.
		error = _stream.connect_to_host(_host, 2357)
		if error != OK:
			emit_signal("session_failed", REASON_TYPE_CLIENT, FAIL_REASON_CLIENT_UNKNOWN)
			return
	
	# Mark the session as starting, and wait until
	# the socket is connected, if this is not a retry.
	if not retrying:
		_session_status = SessionStatus.STARTING
	# Then wait until it is established.
	await _wait_socket_status([StreamPeerTCP.STATUS_CONNECTED])
	# Then, trigger the signal if it is not a retry.
	if not retrying:
		emit_signal("session_starting")
	# Then, do the authentication.
	var result = _stream.put_data(_login)
	if result != OK:
		if not retrying:
			# On new connection, close normally.
			_locally_close(REASON_TYPE_CLIENT, FAIL_REASON_CLIENT_UNKNOWN)
			await _wait_socket_status([
				StreamPeerTCP.STATUS_NONE, StreamPeerTCP.STATUS_ERROR
			])
		else:
			# On retrying, always close with the poll error.
			emit_signal(
				"session_ended", REASON_TYPE_LIBRARY,
				CLOSE_REASON_LIBRARY_POLL_BASE + _poll_err
			)
	else:
		_poll_err = false
		_ping_loop()
		_pong_loop()
		_data_arrival_loop()


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
		_locally_close(REASON_TYPE_CLIENT, CLOSE_REASON_CLIENT_TERMINATED)
		await _wait_socket_status([
			StreamPeerTCP.STATUS_NONE, StreamPeerTCP.STATUS_ERROR
		])

	# Then, prepare the message.
	var message = PackedByteArray([])

	# 1. Start by checking/adding the padd.
	if pad_index < 0 or pad_index > 7:
		emit_signal("session_failed", REASON_TYPE_CLIENT, FAIL_REASON_CLIENT_INVALID_PAD)
		return
	message.append(pad_index)

	# 2. Add the password.
	password = _filter_only_letters(password, 4)
	if len(password) != 4:
		emit_signal("session_failed", REASON_TYPE_CLIENT, FAIL_REASON_CLIENT_INVALID_PASSWORD)
		return
	message += password.to_utf8_buffer()

	# 3. Add the nickname (pad it with spaces)
	nickname = _filter_only_letters(nickname, 16)
	if len(nickname) == 0:
		emit_signal("session_failed", REASON_TYPE_CLIENT, FAIL_REASON_CLIENT_INVALID_NICKNAME)
		return
	message += (nickname + " ".repeat(16 - len(nickname))).to_utf8_buffer()

	# Keep these variables, for the next step.
	_host = host
	_login = message
	
	# Attempt the connection.
	await _session_try_connect()


func session_disconnect():
	"""
	Disconnects any existing connection.
	
	This is a co-routine that must be waited for.
	"""
	
	_locally_close(REASON_TYPE_CLIENT, CLOSE_REASON_CLIENT_TERMINATED)
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
	var err = _stream.poll()
	emit_signal("after_poll")
	# Finally, we process the poll error, if any.
	# On error, the socket is already disconnected
	# from any host, so we fulfill the disconnection
	# and start the recovery process.
	if err != OK:
		_poll_err = OK
		# This one is idempotent, save for the status set.
		_stream.disconnect_from_host()
		# Start the session
		_session_try_connect(true)
