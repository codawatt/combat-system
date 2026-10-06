class_name ImpactField
extends Node2D

var combat_system: Node
var shooter: Node
var weapon: WeaponRuntime
var effect: CombatEffectSpec
var life_remaining: float = 1.0
var total_life: float = 1.0
var tick_accumulator: float = 0.0
var tick_rate: float = 4.0
var pulse_phase: float = 0.0


func configure(system: Node, source: Node, runtime: WeaponRuntime, spec: CombatEffectSpec, at: Vector2) -> void:
	combat_system = system
	shooter = source
	weapon = runtime
	effect = spec.duplicate_effect()
	global_position = at
	total_life = maxf(0.25, effect.duration)
	life_remaining = total_life
	if effect.effect_id == &"gravity_well":
		tick_rate = 5.0
	elif effect.effect_id == &"fire_patch":
		tick_rate = 3.0
	else:
		tick_rate = 4.0
	z_index = -1
	queue_redraw()


func _process(delta: float) -> void:
	life_remaining -= delta
	pulse_phase += delta
	tick_accumulator += delta
	while tick_accumulator >= 1.0 / tick_rate:
		tick_accumulator -= 1.0 / tick_rate
		combat_system.resolve_field_tick(self)
	queue_redraw()
	if life_remaining <= 0.0:
		queue_free()


func _draw() -> void:
	if effect == null:
		return
	var ratio := clampf(life_remaining / total_life, 0.0, 1.0)
	var color := Color("6fdcff")
	match effect.effect_id:
		&"gravity_well":
			color = Color("b66cff")
		&"fire_patch":
			color = Color("ff784f")
		&"healing_zone":
			color = Color("5dff9f")
	var radius := effect.radius
	draw_circle(Vector2.ZERO, radius, Color(color, 0.055 * ratio))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(color, 0.42 * ratio), 2.0)
	draw_arc(Vector2.ZERO, radius * (0.58 + sin(pulse_phase * 4.0) * 0.05), 0.0, TAU, 48, Color(color, 0.25 * ratio), 2.0)
	for i: int in range(8):
		var angle := float(i) / 8.0 * TAU + pulse_phase * (0.7 if i % 2 == 0 else -0.5)
		var outer := Vector2.from_angle(angle) * radius * 0.9
		var inner := Vector2.from_angle(angle + 0.18) * radius * 0.38
		draw_line(outer, inner, Color(color, 0.18 * ratio), 1.0)

