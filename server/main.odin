package main

import "core:fmt"
import "core:mem"
import "core:os"
import "core:strconv"
import "core:time"
import "vendor:ENet"

HOST_IP :: ENet.HOST_ANY
PEER_COUNT_MAX :: 32
CHANNEL_LIMIT :: 2
BANDWIDTH_IN :: 0
BANDWIDTH_OUT :: 0

TIMEOUT_MS_BASE :: 1
TIMEOUT_MS_MAX :: 16
TIMEOUT_MS_NO_CLIENTS :: 1024

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
		PEER_COUNT_MAX,
		CHANNEL_LIMIT,
		BANDWIDTH_IN,
		BANDWIDTH_OUT,
	)
	defer ENet.host_destroy(host)

	peers := make([dynamic]^ENet.Peer)
	defer delete(peers)

	// batch processing events?

	timeout: u32 = TIMEOUT_MS_MAX
	num_clients: u32 = 0
	event: ENet.Event

	for {
		if ENet.host_service(host, &event, timeout) < 0 {
			panic("Could not call host_service")
		}

		switch (event.type) {
		case .NONE:
			timeout = num_clients == 0 ? TIMEOUT_MS_NO_CLIENTS : TIMEOUT_MS_MAX
		case .CONNECT:
			num_clients += 1
		case .RECEIVE:
			ENet.packet_destroy(event.packet)
		case .DISCONNECT:
			num_clients -= 1
		}
	}
}
