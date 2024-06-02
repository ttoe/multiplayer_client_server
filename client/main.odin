package main

import "../common/alloc"
import "../common/args"
import "../common/net"
import "core:fmt"
import "core:mem"
import "core:os"
import "player"
import "vendor:ENet"
import rl "vendor:raylib"

main :: proc() 
{
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer alloc.tracking_allocator_check(&track)

	server_ip, server_port := args.parse_server_ip_and_port(os.args[1:])
	server, client := net.initialize_client_connection(server_ip, server_port)
	defer net.destroy_client_connection(server, client)

	// Game
	// 
	rl.InitWindow(300, 300, "MULTIPLAYER")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	// This event will be overwritten each time an a new event arrives
	//
	event: ENet.Event

	// The client's data will be modified before sending.
	// The packet size is not variable and calculated once.
	//
	client_data_self: net.Client_Data

	players: [net.CLIENT_COUNT_MAX_SERVER]net.Client_Data

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
					// Receive own id and set self to connected.
					//
					client_data_self.client_id = packet_data
					client_data_self.connected = true
				case net.Client_Data:
					// Update players array, even with own data.
					// 
					players[packet_data.client_id] = packet_data
				}
				ENet.packet_destroy(event.packet)
			case .DISCONNECT:
				fmt.println("Disconnected from server")
			}
		}

		dt := rl.GetFrameTime()

		if player.handle_input(&client_data_self.player, dt) {
			client_data_update: net.Packet_Data = client_data_self
			net.packet_send(net.Packet_Data, &client_data_update, server)
		}

		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.RAYWHITE)

		// Draw other players
		//
		for c in players {
			if c.connected && c.client_id != client_data_self.client_id {
				position_draw(c.player.pos, 15, rl.BLUE)
			}
		}

		// Draw self
		//
		if client_data_self.connected {
			position_draw(client_data_self.player.pos, 20, rl.RED)
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
