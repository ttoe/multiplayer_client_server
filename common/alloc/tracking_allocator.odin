package alloc

import "core:fmt"
import "core:mem"

tracking_allocator_check :: proc(tracking_allocator: ^mem.Tracking_Allocator) 
{
	fmt.println("Checking tracking allocator")
	if len(tracking_allocator.allocation_map) > 0 {
		fmt.eprintf(
			"=== %v allocations not freed: ===\n",
			len(tracking_allocator.allocation_map),
		)
		for _, entry in tracking_allocator.allocation_map {
			fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
		}
	}
	if len(tracking_allocator.bad_free_array) > 0 {
		fmt.eprintf(
			"=== %v incorrect frees: ===\n",
			len(tracking_allocator.bad_free_array),
		)
		for entry in tracking_allocator.bad_free_array {
			fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
		}
	}
	mem.tracking_allocator_destroy(tracking_allocator)
}
