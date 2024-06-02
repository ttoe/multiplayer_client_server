package net

import "../../client/player"
import "core:strings"
import "vendor:ENet"

CLIENT_COUNT_MAX_SERVER :: 4
PEER_COUNT_MAX_CLIENT :: 1
CHANNEL_LIMIT :: 2
BANDWIDTH_IN :: 0
BANDWIDTH_OUT :: 0

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

// The server is a Peer and the client (self) is a Host from this client's perspective.
initialize_client_connection :: proc(
	server_ip: string,
	server_port: u16,
) -> (
	server: ^ENet.Peer,
	client: ^ENet.Host,
) 
{
	if ENet.initialize() != 0 {
		panic("Failure to initialize ENet")
	}

	client = ENet.host_create(
		nil,
		PEER_COUNT_MAX_CLIENT,
		CHANNEL_LIMIT,
		BANDWIDTH_IN,
		BANDWIDTH_OUT,
	)

	server_address: ENet.Address
	server_ip_cstr := strings.clone_to_cstring(server_ip)
	if ENet.address_set_host_ip(&server_address, server_ip_cstr) < 0 {
		panic("Failure to parse and set server IP address")
	}
	delete_cstring(server_ip_cstr)

	server_address.port = server_port
	server = ENet.host_connect(client, &server_address, 2, 0)
	if server == nil {
		panic("Failure to connect to server")
	}

	return
}

// The server is a Peer and the client (self) is a Host from this client's perspective.
destroy_client_connection :: proc(server: ^ENet.Peer, client: ^ENet.Host) 
{
	ENet.peer_disconnect_now(server, 0)
	ENet.host_destroy(client)
	ENet.deinitialize()
}
