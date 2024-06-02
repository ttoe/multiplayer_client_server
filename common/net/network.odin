package net

import "../../client/player"
import "vendor:ENet"

CLIENT_COUNT_MAX :: 4

PeerId :: u16

// Holds a connected client's position to be sent to the server.
//
Client_Data :: struct {
	client_id: PeerId,
	connected: bool,
	player:    player.Player,
}

Packet_Data :: union {
	PeerId,
	Client_Data,
}

packet_send :: proc(
	$T: typeid,
	data: ^T,
	to: ^ENet.Peer,
	channel: u8 = 0,
	flags: ENet.PacketFlags = {.UNRELIABLE_FRAGMENT},
) -> i32 
{
	packet := ENet.packet_create(data, size_of(T), flags)
	return ENet.peer_send(to, 0, packet)
}

packet_broadcast :: proc(
	$T: typeid,
	data: ^T,
	host: ^ENet.Host,
	channel: u8 = 0,
	flags: ENet.PacketFlags = {.UNRELIABLE_FRAGMENT},
) 
{
	packet := ENet.packet_create(data, size_of(T), flags)
	ENet.host_broadcast(host, 0, packet)
}
