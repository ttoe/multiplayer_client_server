package main

import "../common/alloc"
import "../common/net"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strconv"
import "vendor:ENet"

HOST_IP :: ENet.HOST_ANY

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
		net.CLIENT_COUNT_MAX_SERVER,
		net.CHANNEL_LIMIT,
		net.BANDWIDTH_IN,
		net.BANDWIDTH_OUT,
	)
	defer ENet.host_destroy(host)

	fmt.println("Server listening on port", serverPort)

	clients := make(map[net.PeerId]^ENet.Peer)
	defer delete(clients)

	timeout: u32 = TIMEOUT_MS_MAX
	num_clients: u32 = 0
	event: ENet.Event

	event_loop: for {
		if ENet.host_service(host, &event, timeout) < 0 {
			panic("Could not call host_service")
		}

		switch (event.type) {
		case .NONE:
			timeout = num_clients == 0 ? TIMEOUT_MS_NO_CLIENTS : TIMEOUT_MS_MAX
		case .CONNECT:
			// Keep track of the client count and save the client (peer)
			// into the array of clients.
			//
			num_clients += 1
			peer_id := event.peer.incomingPeerID
			clients[peer_id] = event.peer

			// tell new client its id
			//
			client_id: net.Packet_Data = peer_id
			net.packet_send(net.Packet_Data, &client_id, event.peer)

			// broadcast new client data to everyone
			//
			new_client_connection: net.Packet_Data = net.Client_Data {
				client_id = peer_id,
				connected = true,
				player    = {{0, 0}},
			}
			net.packet_broadcast(net.Packet_Data, &new_client_connection, host)

			// TODO: broadcast already connected clients to newly connected client

			fmt.println("Client connected: ", peer_id)
		case .RECEIVE:
			// TODO: accumulate events?
			packet_data := (cast(^net.Packet_Data)event.packet.data)^
			#partial switch &data in packet_data {
			case net.Client_Data:
				data.client_id = event.peer.incomingPeerID
				packet: net.Packet_Data = data
				net.packet_broadcast(net.Packet_Data, &packet, host)
			}
		case .DISCONNECT:
			// Keep track of client count and broadcast the disconnected client's
			// status to others.
			// 
			num_clients -= 1
			disconnected_client_id := event.peer.incomingPeerID
			disconnected_client: net.Packet_Data = net.Client_Data {
				client_id = disconnected_client_id,
				connected = false,
				player    = {{0, 0}},
			}
			net.packet_broadcast(net.Packet_Data, &disconnected_client, host)

			delete_key(&clients, disconnected_client_id)
			fmt.println("Client disconnected: ", disconnected_client_id)

			// allow clean shutdown for development
			//
			if num_clients == 0 {
				break event_loop
			}
		}
	}
}
