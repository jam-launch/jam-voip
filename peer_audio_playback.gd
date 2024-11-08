extends Node
class_name PeerAudioPlayback

var initial_buffer_packets := 3
var decoder := GodOpusDecoder.new()
var peer_id := 0
var username := ""

class CompressedAudioPacket:
	var pkt: PackedByteArray
	var samples: int
	
	static func create(pkt: PackedByteArray, samples: int) -> CompressedAudioPacket:
		var p = CompressedAudioPacket.new()
		p.pkt = pkt
		p.samples = samples
		return p

var pkt_buffer: Array[CompressedAudioPacket] = []
var playback: AudioStreamGeneratorPlayback = null

func _ready():
	if multiplayer.get_unique_id() == peer_id:
		$Camera2D.make_current()
		$AudioListener2D.make_current()

func _process(delta: float) -> void:
	if not $AudioStreamPlayer2D.playing:
		if pkt_buffer.size() >= initial_buffer_packets:
			$AudioStreamPlayer2D.play()
			playback = $AudioStreamPlayer2D.get_stream_playback()
		else:
			return
	
	while pkt_buffer.size() > 0:
		if playback.get_frames_available() < pkt_buffer[0].samples:
			break
		var opus_pkt = pkt_buffer.pop_front()
		var decoded_frames = decoder.decode_as_stream_buffer(opus_pkt.pkt)
		for f in decoded_frames:
			playback.push_frame(f)

func queue_pkt(pkt: PackedByteArray, samples: int):
	pkt_buffer.push_back(CompressedAudioPacket.create(pkt, samples))
