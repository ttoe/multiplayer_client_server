package main

import "../common/alloc"
import "../common/net"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strconv"
import "vendor:ENet"

HOST_IP :: ENet.HOST_ANY
CHANNEL_LIMIT :: 2
BANDWIDTH_IN :: 0
BANDWIDTH_OUT :: 0

TIMEOUT_MS_BASE :: 1
TIMEOUT_MS_MAX :: 16
TIMEOUT_MS_NO_CLIENTS :: 1024

main :: proc() 
{
	tracking_alloc: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking_alloc, context.allocator)
	context.allocator = mem.tracking_allocator(&tracking_alloc)
	defer alloc.tracking_allocator_check(&tracking_alloc)

	arguments := os.args[1:]
	if len(arguments) == 0 {
		fmt.println("Please provide the port to listen on: ./server <PORT>")
		return
	}
	serverPort_u64, ok := strconv.parse_u64(arguments[0])
	if !ok || serverPort_u64 < 1025 || serverPort_u64 > 65535 {
		fmt.println("Please provide a port in the range 1025..=65535")
		return
	}
	serverPort := u16(serverPort_u64)

	if ENet.initialize() != 0 {
		fmt.eprintln("Failure to initialize ENet")
		return
	}
	defer ENet.deinitialize()

	address: ENet.Address = {HOST_IP, serverPort}
	host := ENet.host_create(
		&address,
		net.CLIENT_COUNT_MAX,
		CHANNEL_LIMIT,
		BANDWIDTH_IN,
		BANDWIDTH_OUT,
	)
	defer ENet.host_destroy(host)

	fmt.println("Server listening on port", serverPort)

	clients := make(map[net.PeerId]^ENet.Peer)
	defer delete(clients)

	timeout: u32 = TIMEOUT_MS_MAX
	num_clients: u32 = 0
	event: ENet.Event
	packet_size: uint = size_of(net.Packet_Data)

	event_loop: for {
		if ENet.host_service(host, &event, timeout) < 0 {
			panic("Could not call host_service")
		}

		switch (event.type) {
		case .NONE:
			timeout = num_clients == 0 ? TIMEOUT_MS_NO_CLIENTS : TIMEOUT_MS_MAX
		case .CONNECT:
			num_clients += 1
			peerId := event.peer.incomingPeerID
			clients[peerId] = event.peer

			// tell new client its id
			//
			client_id: net.Packet_Data = peerId
			packet_client_id := ENet.packet_create(
				&client_id,
				packet_size,
				{.UNRELIABLE_FRAGMENT},
			)
			ENet.peer_send(event.peer, 0, packet_client_id)

			// broadcast new client data to everyone
			//
			new_client_connection: net.Packet_Data = net.Client_Data {
				clientId  = peerId,
				connected = true,
				position  = {0, 0},
			}

			packet_new_client_connection := ENet.packet_create(
				&new_client_connection,
				packet_size,
				{.UNRELIABLE_FRAGMENT},
			)
			ENet.host_broadcast(host, 0, packet_new_client_connection)
			fmt.println("Client connected: ", event.peer.incomingPeerID)
		case .RECEIVE:
			// TODO: accumulate events?
			clientData := (cast(^net.Client_Data)event.packet.data)^
			clientData.clientId = event.peer.incomingPeerID
			client_data_2: net.Packet_Data = clientData
			packet := ENet.packet_create(
				&client_data_2,
				packet_size,
				{.UNRELIABLE_FRAGMENT},
			)
			ENet.host_broadcast(host, 0, packet)
		case .DISCONNECT:
			num_clients -= 1
			remove_id := event.peer.incomingPeerID
			remove_client: net.Packet_Data = net.Client_Data {
				clientId  = remove_id,
				connected = false,
				position  = {0, 0},
			}
			packet := ENet.packet_create(
				&remove_client,
				packet_size,
				{.UNRELIABLE_FRAGMENT},
			)
			ENet.host_broadcast(host, 0, packet)
			delete_key(&clients, remove_id)
			fmt.println("Client disconnected: ", event.peer.incomingPeerID)

			// allow clean shutdown for development
			//
			if num_clients == 0 {
				break event_loop
			}
		}
	}
}
