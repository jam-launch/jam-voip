extends Node
class_name NetworkAudio

@export var initial_buffer_packets := 3
var decoder: GodOpusDecoder
var encoder: GodOpusEncoder

var opus_buffers: Dictionary = {}
var buffer_playing: Dictionary = {}
var server_clock: float = 0

var client_buffer: Array[PackedByteArray] = []
var client_playback: AudioStreamGeneratorPlayback

func _ready() -> void:
	decoder = GodOpusDecoder.new()
	encoder = GodOpusEncoder.new()

func _process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
		
	if multiplayer.is_server():
		server_process(delta)
	else:
		client_process()

@rpc("any_peer", "call_remote", "unreliable_ordered")
func send_opus(pkt: PackedByteArray):
	if multiplayer.is_server():
		var pid = multiplayer.get_remote_sender_id()
		if not pid in opus_buffers:
			opus_buffers[pid] = []
		opus_buffers[pid].push_back(pkt)
	else:
		if multiplayer.get_remote_sender_id() != 1:
			return
		client_buffer.push_back(pkt)

func server_process(delta: float):
	server_clock += delta
	var pkt_interval = 0.02
	while server_clock > pkt_interval:
		server_clock -= pkt_interval
		for pid in opus_buffers.keys():
			if buffer_playing.has(pid):
				if opus_buffers[pid].size() < 1:
					buffer_playing.erase(pid)
			else:
				if opus_buffers[pid].size() >= initial_buffer_packets:
					buffer_playing[pid] = true
		
		var pkt_frame_count = 960
		var mixed_frames: PackedVector2Array = []
		for pid in buffer_playing.keys():
			var pkt = opus_buffers[pid].pop_front()
			var decoded_frames = decoder.decode_as_stream_buffer(pkt)
			if mixed_frames.size() < 1:
				mixed_frames = decoded_frames
			else:
				for i in range(mixed_frames.size()):
					mixed_frames[i] += decoded_frames[i]
		for i in range(mixed_frames.size()):
			mixed_frames[i] = mixed_frames[i].clamp(Vector2(-1, -1), Vector2(1, 1))
		
		var tx_pkt = encoder.encode_stream_buffer(mixed_frames)
		if tx_pkt.size() > 0:
			send_opus.rpc(tx_pkt)

func client_process():
	if not $AudioStreamPlayer.playing:
		if client_buffer.size() >= initial_buffer_packets:
			$AudioStreamPlayer.play()
			client_playback = $AudioStreamPlayer.get_stream_playback()
		else:
			#print("not enough opus packets ", client_buffer.size())
			return
	
	while client_buffer.size() > 0 and client_playback.get_frames_available() > 960:
		var opus_pkt = client_buffer.pop_front()
		var decoded_frames = decoder.decode_as_stream_buffer(opus_pkt)
		for f in decoded_frames:
			client_playback.push_frame(f)
