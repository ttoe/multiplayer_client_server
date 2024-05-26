package main

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

	defer 
	{
		if len(track.allocation_map) > 0 {
			fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
			for _, entry in track.allocation_map {
				fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
			}
		}
		if len(track.bad_free_array) > 0 {
			fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
			for entry in track.bad_free_array {
				fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
			}
		}
		mem.tracking_allocator_destroy(&track)
	}

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
	rl.InitWindow(500, 500, "MULTIPLAYER")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	p := player.init()

	// This event will be overwritten each time an a new event arrives
	//
	event: ENet.Event

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
				ENet.packet_destroy(event.packet)
			case .DISCONNECT:
				fmt.println("Disconnected from server")
			}
		}

		dt := rl.GetFrameTime()

		input_received := player.handle_input(&p, dt)

		if input_received {
			send_pos := p.pos
			packet_size: uint = size_of(send_pos)
			position_data_rawptr := raw_data(&send_pos)
			packet := ENet.packet_create(
				position_data_rawptr,
				packet_size,
				{.UNRELIABLE_FRAGMENT},
			)
			send_result := ENet.peer_send(server, 0, packet)
			if send_result != 0 {
				fmt.eprintln("Failure to send packet")
			}
		}

		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.RAYWHITE)

		player.draw(p)

	}

}
