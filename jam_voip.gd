extends Node2D

func _ready() -> void:
	pass


func _on_audio_input_capture_got_opus_packet(pkt: PackedByteArray) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.is_server():
		return
	$NetworkAudio.send_opus.rpc_id(1, pkt)


func _on_jam_connect_local_player_joined() -> void:
	print("local player init")
	$AudioInputCapture.initialize()
	$AudioInputCapture.start_streaming()


func _on_timer_timeout() -> void:
	print("Session timed out, ending...")
	get_tree().quit(1)

func _on_jam_connect_server_post_ready() -> void:
	$Timer.start(3 * 60)

func _on_jam_connect_player_connected(_pid: int, _username: String) -> void:
	$Timer.start(2 * 60)
