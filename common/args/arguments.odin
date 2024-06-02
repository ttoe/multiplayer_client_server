package args

import "core:strconv"

parse_server_ip_and_port :: proc(
	arguments: []string,
) -> (
	server_ip: string,
	server_port: u16,
) 
{
	if len(arguments) < 2 {
		panic("Please provide the server to connect to: <server> <port>")
	}

	server_port_u64, ok := strconv.parse_u64(arguments[1])
	if !ok || server_port_u64 < 1025 || server_port_u64 > 65535 {
		panic("Please provide a port in the range 1025..=65535")
	}

	server_ip = arguments[0]
	server_port = u16(server_port_u64)
	return
}
