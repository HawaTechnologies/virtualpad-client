extends Control


# This is the status of the connection. Only these statuses
# are supported: When the connection is NOT established, when
# the connection is established, and when the connection is
# being established (i.e. a log-in process).
enum Status {DISCONNECTED, CONNECTING, CONNECTED}


# Callbacks to process when a connection is: started (moves to
# CONNECTING), approved (a successful log-in into an empty pad
# slot -- moves to CONNECTED), failed (the connection has been
# rejected at authentication time), closed (the connection was
# in CONNECTED state, and was closed).
signal connection_started
signal connection_approved
signal connection_failed(reason)
signal connection_closed(reason)


# This is the status for the current connection. Also, a timer
# is used to check to send ping commands properly.
var _status : Status = Status.DISCONNECTED
var _timer : float = 0
var stream : StreamPeerTCP = StreamPeerTCP.new()


func _ping_check(delta):
	"""
	Checks the timer and sends the ping.
	"""

	_timer += delta
	if _timer > 3:
		# Send [19] every 3 seconds.
		stream.put_data([19])


func _process(delta):
	if status != Status.CONNECTED:
		# Clear ping, if any, and abort.
		_timer = 0
		return
	
	# First, send the PING signal and update.
	_ping_check(delta)

	if stream.get_available_bytes() > 0:
		var response = stream.get_data(stream.get_available_bytes())
		match response[0]:
			0:
				_status = Status.CONNECTED
				emit_signal("connection_approved")
			_:
				_status = Status.DISCONNECTED
				stream.disconnect_from_host()
				emit_signal("connection_closed", response[0])

	elif status == Status.CONNECTED:
		elif !stream.is_connected_to_host():
			self.gamepad_disconnect()
			emit_signal("connection_closed")

func gamepad_connect(ip_address):
	var error = stream.connect_to_host(ip_address, 2357)
	if error != OK:
		status = Status.DISCONNECTED
		emit_signal("connection_failed", "Could not connect to host.")
	else:
		status = Status.CONNECTING

func send_data(data):
	if status != Status.CONNECTED:
		print("Cannot send data while not connected.")
		return
	var message = [data.size()]
	for pair in data:
		message.append(pair[0])
		message.append(pair[1])
	stream.put_data(message)

func gamepad_disconnect():
	if status != Status.CONNECTED:
		print("Cannot disconnect while not connected.")
		return
	stream.put_data([18])
	status = Status.DISCONNECTED
	stream.disconnect_from_host()

func get_status():
	return status
