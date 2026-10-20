class_name NetworkManager
extends RefCounted

## Future multiplayer transport stub. It fixes the shape the game will talk
## to when it goes online, so callers can be written and tested now, but it
## does no real networking: no sockets, no peers, no packets. Every call is
## a no-op and the manager never reports a connection.
##
## The wire format lives in scripts/net_packet.gd (class NetPacket).

var connected: bool = false
var peer_network_id: String = ""


## Joins a host. Returns false: the stub has no transport, so it never
## connects and the caller stays in solo play.
func connect_to(host: String) -> bool:
	return false


## Leaves the session. The stub was never connected, so there is nothing to
## tear down.
func disconnect() -> void:
	pass


## Sends one packet to the transport. The stub drops it.
func send_state(packet: Dictionary) -> void:
	pass


## Takes the packets that arrived since the last call. The stub has none,
## so this is always empty.
func receive_state() -> Array:
	return []
