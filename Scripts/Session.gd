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
# - The session attempt failed (e.g. auth failure).
signal session_rejected(reason)
# - The session terminated (e.g. timeout).
signal session_ended(reason_type, reason)
# - A ping was sent to the server.
signal debug_ping_send_success
# - A ping was not successfully sent to the server.
signal debug_ping_send_error(error)
# - A pong was received from the server.
signal debug_pong_received

# Reason types for closing/failure:
const REASON_TYPE_LOCAL = 1000
const REASON_TYPE_SERVER = 2000

# Failure reasons:
# - The authentication failed.
const FAIL_REASON_SERVER_AUTH_FAILED = 1001
# - The attempted pad is busy.
const FAIL_REASON_SERVER_PAD_BUSY = 1002

# Close reasons:
# - Graceful disconnection from the server (e.g. kick).
const CLOSE_REASON_SERVER_TERMINATED = 1001
# - The server kicked the client due to timeout (lack of ping).
const CLOSE_REASON_SERVER_TIMEOUT = 1002
# - The server closed due to an unexpected error.
const CLOSE_REASON_SERVER_UNEXPECTED = 1999
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
# session_approved/session_rejected(reason). It will
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
	await get_tree().process_frame
	while _stream.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		_time += get_process_delta_time()
		if _time >= PING_SEND_INTERVAL:
			_time -= PING_SEND_INTERVAL
			_ping_send()
		await get_tree().process_frame

func _pong_loop():
	"""
	Performs a pong loop to know that this socket is
	still acknowledged from the server.
	
	This is a co-routine that must NOT be waited for.
	It must be invoked when the session is starting.
	"""
	
	var _time = 0
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


############
# Stream utilities functions.
############


func _locally_close(reason_type, reason):
	"""
	Closes the connection.
	"""

	_stream.disconnect_from_host()
	_session_status = SessionStatus.NONE
	emit_signal("session_ended", REASON_TYPE_SERVER, CLOSE_REASON_SERVER_TIMEOUT)


func _locally_fail(reason_type, reason):
	"""
	Fails the connection.
	"""

	_stream.disconnect_from_host()
	_session_status = SessionStatus.NONE
	emit_signal("session_failed", REASON_TYPE_SERVER, CLOSE_REASON_SERVER_TIMEOUT)


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
					_locally_close(REASON_TYPE_SERVER, CLOSE_REASON_SERVER_UNEXPECTED)


############
# Public functions to connect, disconnect, and send
# the required keys through the socket.
############


func session_connect(host : String):
	pass


func session_disconnect():
	pass


func session_send():
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	_stream.poll()
