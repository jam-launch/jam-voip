extends Node
class_name AudioInputCapture

signal got_opus_packet(pkt: PackedByteArray, samples: int)

var capture: AudioEffectCapture = null
var input_buffer: PackedVector2Array = []
var encoder: GodOpusEncoder = null

func _ready() -> void:
	pass

func initialize():
	const input_bus = &"AudioInputBus"
	var bus_idx = AudioServer.get_bus_index(input_bus)
	if bus_idx < 0:
		AudioServer.add_bus()
		bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_idx, input_bus)
		AudioServer.set_bus_mute(bus_idx, true)
	capture = AudioEffectCapture.new()
	AudioServer.add_bus_effect(bus_idx, capture)
	$MicAudioPlayer.bus = input_bus
	encoder = GodOpusEncoder.new()

func start_streaming():
	input_buffer = []
	$MicAudioPlayer.play()

func stop_streaming():
	$MicAudioPlayer.stop()
	input_buffer = []

func _process(delta: float) -> void:
	if not $MicAudioPlayer.playing:
		return
	
	var frames = capture.get_frames_available()
	if frames > 0:
		var buf = capture.get_buffer(frames)
		if buf.size() > 0:
			input_buffer.append_array(buf)
		else:
			print("unexpected empty input buffer")
	
	# TODO: when the encoder is configurable, this will be dynamic
	var packet_samples = 960
	
	while input_buffer.size() >= packet_samples:
		var chunk = input_buffer.slice(0, packet_samples)
		var opus_pkt := encoder.encode_stream_buffer(chunk)
		if opus_pkt.size() > 0:
			got_opus_packet.emit(opus_pkt, packet_samples)
		input_buffer = input_buffer.slice(packet_samples)
