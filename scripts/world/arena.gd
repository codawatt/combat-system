class_name CombatArena
extends Node2D

const ARENA_RECT := Rect2(34.0, 34.0, 1212.0, 652.0)


func _ready() -> void:
	z_index = -20
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), Color("07101f"), true)
	draw_rect(ARENA_RECT, Color("0b1830"), true)

	# Layered grid gives movement and projectile travel a readable scale.
	for x: int in range(44, 1246, 40):
		var major := (x - 44) % 200 == 0
		draw_line(Vector2(x, 34), Vector2(x, 686), Color(0.11, 0.27, 0.43, 0.28 if major else 0.12), 1.0)
	for y: int in range(46, 686, 40):
		var major := (y - 46) % 200 == 0
		draw_line(Vector2(34, y), Vector2(1246, y), Color(0.11, 0.27, 0.43, 0.28 if major else 0.12), 1.0)

	# Decorative combat-lab markings.
	for center: Vector2 in [Vector2(320, 360), Vector2(640, 360), Vector2(960, 360)]:
		draw_arc(center, 72.0, 0.0, TAU, 48, Color(0.20, 0.55, 0.75, 0.13), 2.0)
		draw_arc(center, 48.0, 0.0, TAU, 48, Color(0.20, 0.55, 0.75, 0.08), 1.0)
		draw_line(center - Vector2(84, 0), center + Vector2(84, 0), Color(0.2, 0.55, 0.75, 0.10), 1.0)
		draw_line(center - Vector2(0, 84), center + Vector2(0, 84), Color(0.2, 0.55, 0.75, 0.10), 1.0)

	var edge := Color("1a4264")
	draw_rect(ARENA_RECT, edge, false, 3.0)
	draw_line(Vector2(54, 54), Vector2(190, 54), Color("55dff8"), 3.0)
	draw_line(Vector2(1090, 666), Vector2(1226, 666), Color("55dff8"), 3.0)
