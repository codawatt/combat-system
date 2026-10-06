class_name WorldProp
extends StaticBody2D

## A minimal environment receiver: shots can destroy it and trigger an impact event.

var combat_system: Node
var durability: float = 55.0
var max_durability: float = 55.0
var blast_radius: float = 118.0
var blast_damage: float = 52.0
var dead: bool = false
var flash: float = 0.0


func configure(system: Node) -> void:
	combat_system = system
	collision_layer = 8
	collision_mask = 0
	add_to_group("world_props")
	var shape_node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 17.0
	shape_node.shape = shape
	add_child(shape_node)
	queue_redraw()


func receive_world_hit(packet: Dictionary, source: Node) -> void:
	if dead:
		return
	durability -= float(packet.get("damage", 0.0))
	flash = 0.12
	queue_redraw()
	if durability <= 0.0:
		dead = true
		collision_layer = 0
		combat_system.explode_world_prop(global_position, blast_radius, blast_damage, source)
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector2(1.55, 1.55), 0.10)
		tween.parallel().tween_property(self, "modulate:a", 0.0, 0.16)
		tween.tween_callback(queue_free)


func _process(delta: float) -> void:
	if flash > 0.0:
		flash -= delta
		queue_redraw()


func _draw() -> void:
	var body_color := Color("fff1c7") if flash > 0.0 else Color("ff5d62")
	draw_circle(Vector2.ZERO, 18.0, Color(0.05, 0.03, 0.07, 0.9))
	draw_circle(Vector2.ZERO, 15.0, body_color)
	draw_arc(Vector2.ZERO, 19.0, 0.0, TAU, 24, Color("ffb357"), 2.0)
	draw_line(Vector2(-8, -5), Vector2(8, -5), Color("3a1521"), 3.0)
	draw_line(Vector2(-8, 5), Vector2(8, 5), Color("3a1521"), 3.0)
	draw_circle(Vector2(0, -18), 4.0, Color("ffd56a"))

