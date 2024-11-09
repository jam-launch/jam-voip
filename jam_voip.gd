extends Node2D

var peer_audio_playback_scn = preload("res://peer_audio_playback.tscn")

@export_range(60, 10 * 60, 1, "suffix:s") var initial_timeout := 3 * 60
@export_range(60, 30 * 60, 1, "suffix:s") var post_join_duration := 30 * 60
@export_range(0, 60, 1, "suffix:s") var countdown_amount := 30:
	set(v):
		countdown_amount = v
		if is_node_ready():
			%CountdownClock.text = "0:%02d" % v
var active_countdown := 0
var counting_down := false

func _ready() -> void:
	%CountdownClock.visible = false
	countdown_amount = countdown_amount

#
# Local player init
#

func _on_jam_connect_local_player_joined() -> void:
	%CountdownClock.visible = false
	$AudioInputCapture.initialize()
	$AudioInputCapture.start_streaming()

func _on_jam_connect_local_player_left() -> void:
	%CountdownClock.visible = false
	$AudioInputCapture.stop_streaming()
	for p in $Peers.get_children():
		p.queue_free()

#
# Server-side peer node management
#

func _on_jam_connect_player_connected(pid: int, username: String) -> void:
	$Timer.start(post_join_duration)

	var p = peer_audio_playback_scn.instantiate()
	p.peer_id = pid
	p.username = username
	p.position = $Peers.get_child_count() * Vector2(50, 0)
	p.modulate = Color(randf_range(0.1, 1.0), randf_range(0.1, 1.0), randf_range(0.1, 1.0))
	$Peers.add_child(p)

func _on_jam_connect_player_disconnected(pid: int, username: String) -> void:
	for p in $Peers.get_children():
		if p.peer_id == pid:
			p.queue_free()

#
# Audio packet routing
#

func _on_audio_input_capture_got_opus_packet(pkt: PackedByteArray, samples: int) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.is_server():
		return
	$PeerAudioBroadcast.broadcast_audio_packet.rpc_id(1, pkt, samples)

func _on_peer_audio_broadcast_got_audio_packet(peer_id: int, pkt: PackedByteArray, samples: int) -> void:
	for p in $Peers.get_children():
		if p.peer_id == peer_id:
			p.queue_pkt(pkt, samples)

#
# Session timer and countdown
#

func _on_jam_connect_server_post_ready() -> void:
	$Timer.start(initial_timeout)

func _on_timer_timeout() -> void:
	if counting_down:
		print("Session timed out, ending...")
		get_tree().quit(1)
	else:
		start_countdown.rpc()

@rpc("call_local")
func start_countdown():
	active_countdown = countdown_amount
	counting_down = true
	
	if not multiplayer.is_server():
		$Countdown.start(1)
		%CountdownClock.visible = true
	else:
		$Timer.start(countdown_amount + 1)

func _on_countdown_timeout() -> void:
	if multiplayer.is_server():
		return
	if countdown_amount > 0:
		countdown_amount -= 1
