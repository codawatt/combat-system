class_name ProjectileDelivery
extends CharacterBody2D

var combat_system: Node
var shooter: Node
var weapon: WeaponRuntime
var direction: Vector2 = Vector2.RIGHT
var travel_speed: float = 0.0
var acceleration: float = 0.0
var gravity: float = 0.0
var life_remaining: float = 1.0
var distance_travelled: float = 0.0
var bounces_left: int = 0
var pierces_left: int = 0
var damage_scale: float = 1.0
var is_fragment: bool = false
var hit_ids: Dictionary = {}
var radius: float = 7.0
var target: Node = null


func configure(
		system: Node,
		source: Node,
		runtime: WeaponRuntime,
		start: Vector2,
		shot_direction: Vector2,
		scale_value: float = 1.0,
		fragment: bool = false) -> void:
	combat_system = system
	shooter = source
	weapon = runtime
	global_position = start
	direction = shot_direction.normalized()
	travel_speed = weapon.get_stat(&"projectile_speed") * (1.35 if fragment else 1.0)
	acceleration = weapon.get_stat(&"projectile_acceleration")
	gravity = weapon.get_stat(&"projectile_gravity")
	life_remaining = weapon.get_stat(&"projectile_lifetime") * (0.72 if fragment else 1.0)
	bounces_left = weapon.stat_int(&"bounce_count")
	pierces_left = weapon.stat_int(&"piercing_count")
	damage_scale = scale_value
	is_fragment = fragment
	radius = maxf(3.0, weapon.get_stat(&"projectile_size") * (0.56 if fragment else 1.0))
	collision_layer = 4
	collision_mask = 2 | 8
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var collision_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	collision_shape.shape = circle
	add_child(collision_shape)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if weapon == null:
		queue_free()
		return

	life_remaining -= delta
	if life_remaining <= 0.0:
		combat_system.finish_projectile(self, true)
		return

	_apply_homing(delta)
	travel_speed += acceleration * delta
	direction = (direction + Vector2.DOWN * gravity * delta / maxf(1.0, travel_speed)).normalized()
	velocity = direction * travel_speed
	var motion := velocity * delta
	var collision := move_and_collide(motion)
	distance_travelled += motion.length()
	if collision != null:
		combat_system.resolve_projectile_collision(self, collision)


func _apply_homing(delta: float) -> void:
	var strength := weapon.get_stat(&"homing_strength")
	if strength <= 0.0:
		return
	if not is_instance_valid(target) or target.dead:
		target = combat_system.find_nearest_enemy(global_position, 310.0, hit_ids)
	if not is_instance_valid(target):
		return
	var desired := global_position.direction_to(target.global_position)
	var max_turn := weapon.get_stat(&"projectile_turn_rate") * delta
	var angle := clampf(direction.angle_to(desired), -max_turn, max_turn)
	direction = direction.rotated(angle * clampf(strength, 0.0, 1.0)).normalized()


func reflect(normal: Vector2) -> void:
	direction = direction.bounce(normal).normalized()
	global_position += direction * (radius + 2.0)


func pass_through(body: CollisionObject2D) -> void:
	hit_ids[body.get_instance_id()] = true
	add_collision_exception_with(body)
	global_position += direction * (radius * 2.2)


func _draw() -> void:
	var color := weapon.blueprint.accent if weapon != null else Color.WHITE
	draw_line(-direction * radius * 3.3, -direction * radius * 0.4, Color(color, 0.18), radius * 1.25)
	draw_circle(Vector2.ZERO, radius * 1.45, Color(color, 0.16))
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(-direction * radius * 0.25, radius * 0.42, Color.WHITE)

