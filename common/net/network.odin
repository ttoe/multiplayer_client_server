package net

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
