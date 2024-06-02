package main

import "../common/alloc"
import "../common/net"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strconv"
import "core:strings"
import "player"
import "vendor:ENet"
import rl "vendor:raylib"

PEER_COUNT_MAX :: 1
CHANNEL_LIMIT :: 2
BANDWIDTH_IN :: 0
BANDWIDTH_OUT :: 0

main :: proc() 
{
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer alloc.tracking_allocator_check(&track)

	arguments := os.args[1:]
	if len(arguments) < 2 {
		fmt.println("Please provide the server to connect to: <server> <port>")
		return
	}

	serverPort_u64, ok := strconv.parse_u64(arguments[1])
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

	client := ENet.host_create(nil, 1, CHANNEL_LIMIT, BANDWIDTH_IN, BANDWIDTH_OUT)
	defer ENet.host_destroy(client)

	serverAddress: ENet.Address
	serverIp := strings.clone_to_cstring(arguments[0])
	if ENet.address_set_host_ip(&serverAddress, serverIp) < 0 {
		fmt.eprintln("Failure to parse and set server IP address")
		return
	}
	delete_cstring(serverIp)

	serverAddress.port = serverPort
	server := ENet.host_connect(client, &serverAddress, 2, 0)
	if server == nil {
		fmt.eprintln("Failure to connect to server")
		return
	}
	defer ENet.peer_disconnect(server, 0)

	// game
	// 
	rl.InitWindow(300, 300, "MULTIPLAYER")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	p := player.init()

	// This event will be overwritten each time an a new event arrives
	//
	event: ENet.Event

	// The client's data will be modified before sending.
	// The packet size is not variable and calculated once.
	//
	client_data_self: net.Client_Data
	packet_size: uint = size_of(net.Packet_Data)

	players: [net.CLIENT_COUNT_MAX]net.Client_Data

	for !rl.WindowShouldClose() {

		event_loop: for {
			// Timeout needs to be zero to be non-blocking,
			// as game code needs to run each frame as well.
			//
			if ENet.host_service(client, &event, 0) < 0 {
				panic("Could not call host_service")
			}

			switch (event.type) {
			case .NONE:
				break event_loop
			case .CONNECT:
				fmt.println("Connected to server")
			case .RECEIVE:
				packet := (cast(^net.Packet_Data)event.packet.data)^
				switch packet_data in packet {
				case net.PeerId:
					// receive own id and set self to connected
					//
					client_data_self.clientId = packet_data
					client_data_self.connected = true
				case net.Client_Data:
					players[packet_data.clientId] = packet_data
				}
				ENet.packet_destroy(event.packet)
			case .DISCONNECT:
				fmt.println("Disconnected from server")
			}
		}

		dt := rl.GetFrameTime()

		if player.handle_input(&p, dt) {
			client_data_self.position = p.pos
			packet := ENet.packet_create(
				&client_data_self,
				packet_size,
				{.UNRELIABLE_FRAGMENT},
			)
			ENet.peer_send(server, 0, packet)
		}

		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.RAYWHITE)

		// Draw other players
		//
		for c in players {
			if c.connected && c.clientId != client_data_self.clientId {
				position_draw(c.position, 15, rl.BLUE)
			}
		}

		// Draw self
		//
		if client_data_self.connected {
			c := players[client_data_self.clientId]
			position_draw(c.position, 20, rl.RED)
		}
	}
}

position_draw :: proc(position: [2]f32, size: f32, color: rl.Color) 
{
	rl.DrawRectanglePro(
		rl.Rectangle{position.x, position.y, size, size},
		{0, 0},
		0,
		color,
	)
}
