package player

import rl "vendor:raylib"

Vec2 :: rl.Vector2
Rect :: rl.Rectangle

PLAYER_SPEED: f32 : 150
PLAYER_SIZE :: 30

State :: enum {
	CONNECTED,
	DISCONNECTED,
}

Player :: struct {
	pos:   Vec2,
	state: State,
}

init :: proc() -> Player 
{
	return Player{{PLAYER_SIZE / 2, PLAYER_SIZE / 2}, .DISCONNECTED}
}

handle_input :: proc(player: ^Player, dt: f32) -> bool 
{
	input_received := false

	if rl.IsKeyDown(.LEFT) {
		player.pos += dt * PLAYER_SPEED * Vec2{-1, 0}
		input_received = true
	}
	if rl.IsKeyDown(.UP) {
		player.pos += dt * PLAYER_SPEED * Vec2{0, -1}
		input_received = true
	}
	if rl.IsKeyDown(.RIGHT) {
		player.pos += dt * PLAYER_SPEED * Vec2{1, 0}
		input_received = true
	}
	if rl.IsKeyDown(.DOWN) {
		player.pos += dt * PLAYER_SPEED * Vec2{0, 1}
		input_received = true
	}

	return input_received
}

draw :: proc(player: Player) 
{
	rl.DrawRectanglePro(
		Rect{player.pos.x, player.pos.y, PLAYER_SIZE, PLAYER_SIZE},
		{PLAYER_SIZE / 2, PLAYER_SIZE / 2},
		0,
		rl.RED,
	)
}
