extends Node
class_name PeerAudioBroadcast

signal got_audio_packet(peer_id: int, pkt: PackedByteArray, samples: int)

func _ready() -> void:
	pass

@rpc("any_peer", "call_remote", "unreliable_ordered")
func broadcast_audio_packet(pkt: PackedByteArray, samples: int):
	if multiplayer.is_server():
		var src_id = multiplayer.get_remote_sender_id()
		for dst_id in multiplayer.get_peers():
			if dst_id == 1:
				continue
			if dst_id == src_id:
				continue
			receive_audio_packet.rpc_id(dst_id, src_id, pkt, samples)

@rpc
func receive_audio_packet(peer_id: int, pkt: PackedByteArray, samples: int):
	got_audio_packet.emit(peer_id, pkt, samples)
