package player

import rl "vendor:raylib"

Vec2 :: rl.Vector2
Rect :: rl.Rectangle

PLAYER_SPEED: f32 : 150

Player :: struct {
	pos: Vec2,
}

init :: proc() -> Player 
{
	return Player{{0, 0}}
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
