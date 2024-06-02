package net

import "vendor:ENet"

CLIENT_COUNT_MAX :: 4

PeerId :: u16

// Holds all connected client's positions
// to be sent to all clients.
//
Client_Data :: struct {
	clientId:  PeerId,
	connected: bool,
	position:  [2]f32,
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
