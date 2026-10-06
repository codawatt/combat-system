class_name CombatCrosshair
extends Control

var player: CombatPlayer


func configure(player_ref: CombatPlayer) -> void:
	player = player_ref
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(48.0, 48.0)
	size = Vector2(48.0, 48.0)
	process_mode = Node.PROCESS_MODE_ALWAYS
	queue_redraw()


func _process(_delta: float) -> void:
	position = get_viewport().get_mouse_position() - size * 0.5
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(player) or player.arsenal.is_empty():
		return
	var weapon := player.current_weapon()
	var color := weapon.blueprint.accent
	var gap := 5.0 + weapon.current_spread_deg * 2.2
	var center := size * 0.5
	draw_circle(center, 1.8, Color.WHITE)
	draw_line(center + Vector2(gap, 0), center + Vector2(gap + 7.0, 0), color, 1.5)
	draw_line(center - Vector2(gap, 0), center - Vector2(gap + 7.0, 0), color, 1.5)
	draw_line(center + Vector2(0, gap), center + Vector2(0, gap + 7.0), color, 1.5)
	draw_line(center - Vector2(0, gap), center - Vector2(0, gap + 7.0), color, 1.5)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		draw_arc(center, gap + 4.0, 0.0, TAU, 24, Color(color, 0.45), 1.0)

