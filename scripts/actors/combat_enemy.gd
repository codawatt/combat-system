class_name CombatEnemy
extends CharacterBody2D

signal died(enemy: CombatEnemy, killer: Node, packet: Dictionary)

var player: Node
var archetype: StringName = &"skirmisher"
var enemy_name: String = "SKIRMISHER"
var body_color: Color = Color("ff6a87")
var radius: float = 16.0
var max_health: float = 80.0
var health: float = 80.0
var max_shield: float = 0.0
var shield: float = 0.0
var armor_hardness: float = 12.0
var status_resistance: float = 0.0
var knockback_resistance: float = 0.0
var stagger_threshold: float = 42.0
var stagger: float = 0.0
var damage_cap: float = 9999.0
var move_speed: float = 90.0
var contact_damage: float = 9.0
var attack_interval: float = 0.85
var attack_cooldown: float = 0.0
var shield_regen_delay: float = 0.0
var dead: bool = false
var flash: float = 0.0
var stun_remaining: float = 0.0
var freeze_remaining: float = 0.0
var impulse: Vector2 = Vector2.ZERO
var statuses: Dictionary = {}
var resistances: Dictionary = {}
var difficulty_scale: float = 1.0


func configure(target: Node, type: StringName, difficulty: float = 1.0) -> void:
	player = target
	archetype = type
	difficulty_scale = difficulty
	match archetype:
		&"sentinel":
			enemy_name = "SENTINEL"
			body_color = Color("53c8ff")
			radius = 19.0
			max_health = 72.0 * difficulty
			max_shield = 78.0 * difficulty
			armor_hardness = 18.0
			status_resistance = 0.12
			move_speed = 68.0
			contact_damage = 12.0
			resistances = {&"shock": 0.08, &"plasma": 0.06}
		&"bulwark":
			enemy_name = "BULWARK"
			body_color = Color("ffb45e")
			radius = 25.0
			max_health = 210.0 * difficulty
			max_shield = 0.0
			armor_hardness = 72.0
			status_resistance = 0.28
			knockback_resistance = 0.72
			stagger_threshold = 82.0
			damage_cap = 72.0
			move_speed = 48.0
			contact_damage = 20.0
			attack_interval = 1.25
			resistances = {&"kinetic": 0.08, &"fire": 0.15}
		_:
			enemy_name = "SKIRMISHER"
			body_color = Color("ff6685")
			radius = 15.5
			max_health = 82.0 * difficulty
			max_shield = 0.0
			armor_hardness = 10.0
			move_speed = 98.0
			contact_damage = 8.0
			resistances = {&"frost": 0.08}

	health = max_health
	shield = max_shield
	collision_layer = 2
	collision_mask = 1 | 8
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("damageable_enemies")
	var shape_node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	shape_node.shape = shape
	add_child(shape_node)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if dead:
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	shield_regen_delay = maxf(0.0, shield_regen_delay - delta)
	flash = maxf(0.0, flash - delta)
	stun_remaining = maxf(0.0, stun_remaining - delta)
	freeze_remaining = maxf(0.0, freeze_remaining - delta)
	stagger = maxf(0.0, stagger - 10.0 * delta)

	_tick_statuses(delta)
	if max_shield > 0.0 and shield_regen_delay <= 0.0:
		shield = minf(max_shield, shield + max_shield * 0.18 * delta)

	var desired_velocity := Vector2.ZERO
	if is_instance_valid(player) and not player.dead and stun_remaining <= 0.0 and freeze_remaining <= 0.0:
		var to_player: Vector2 = player.global_position - global_position
		var distance := to_player.length()
		var speed_multiplier := _status_speed_multiplier()
		if distance > radius + 24.0:
			desired_velocity = to_player.normalized() * move_speed * speed_multiplier
		if distance <= radius + 25.0 and attack_cooldown <= 0.0:
			attack_cooldown = attack_interval
			player.take_damage(contact_damage, global_position)
			impulse -= to_player.normalized() * 70.0

	impulse = impulse.move_toward(Vector2.ZERO, 360.0 * delta)
	velocity = desired_velocity + impulse
	move_and_slide()
	global_position.x = clampf(global_position.x, 54.0 + radius, 1226.0 - radius)
	global_position.y = clampf(global_position.y, 54.0 + radius, 666.0 - radius)
	queue_redraw()


func receive_damage(packet: Dictionary) -> Dictionary:
	if dead:
		return {"actual_damage": 0.0, "killed": false, "shield_broken": false}

	var damage := maxf(0.0, float(packet.get("damage", 0.0)))
	var damage_type := StringName(packet.get("damage_type", &"kinetic"))
	var resistance := float(resistances.get(damage_type, 0.0))
	resistance = maxf(0.0, resistance - float(packet.get("resistance_penetration", 0.0)))
	damage *= 1.0 - clampf(resistance, 0.0, 0.85)

	if statuses.has(&"mark"):
		var mark: Dictionary = statuses[&"mark"]
		damage *= 1.0 + minf(0.45, float(mark.get("magnitude", 0.0)) * int(mark.get("stacks", 1)))

	var old_shield := shield
	var bypass := clampf(float(packet.get("shield_bypass", 0.0)), 0.0, 1.0)
	var shield_bound := damage * (1.0 - bypass)
	var direct_health := damage * bypass
	var shield_damage := minf(shield, shield_bound)
	shield -= shield_damage
	var spill := maxf(0.0, shield_bound - shield_damage)
	var health_bound := direct_health + spill

	var corrosion_amount := 0.0
	if statuses.has(&"corrosion"):
		var corrosion: Dictionary = statuses[&"corrosion"]
		corrosion_amount = minf(0.75, float(corrosion.get("magnitude", 0.0)) * int(corrosion.get("stacks", 1)))
	var penetration := float(packet.get("armor_penetration", 0.0))
	var effective_armor := maxf(0.0, armor_hardness * (1.0 - corrosion_amount) - penetration)
	var armor_mitigation := minf(0.68, effective_armor / (effective_armor + 100.0))
	var health_damage := minf(damage_cap, health_bound * (1.0 - armor_mitigation))
	health = maxf(0.0, health - health_damage)
	shield_regen_delay = 3.0
	flash = 0.09

	var stagger_amount := float(packet.get("stagger_damage", 0.0))
	stagger += stagger_amount
	if stagger >= stagger_threshold:
		stagger = 0.0
		stun_remaining = maxf(stun_remaining, 0.55 * (1.0 - status_resistance))

	var actual := shield_damage + health_damage
	var killed := health <= 0.0
	var result := {
		"actual_damage": actual,
		"health_damage": health_damage,
		"shield_damage": shield_damage,
		"shield_broken": old_shield > 0.0 and shield <= 0.0,
		"killed": killed,
	}
	queue_redraw()
	if killed:
		_die(packet.get("source", null), packet)
	return result


func apply_status(effect: CombatEffectSpec, source: Node) -> void:
	if dead:
		return
	var adjusted_duration := effect.duration * (1.0 - status_resistance)
	var state: Dictionary = statuses.get(effect.effect_id, {
		"remaining": adjusted_duration,
		"magnitude": effect.magnitude,
		"stacks": 0,
		"tick": 0.5,
		"source": source,
	})
	state["remaining"] = maxf(float(state.get("remaining", 0.0)), adjusted_duration)
	state["magnitude"] = maxf(float(state.get("magnitude", 0.0)), effect.magnitude)
	state["stacks"] = mini(12, int(state.get("stacks", 0)) + effect.stacks)
	state["source"] = source
	statuses[effect.effect_id] = state

	if effect.effect_id == &"shock" and int(state["stacks"]) >= 4:
		stun_remaining = maxf(stun_remaining, 0.72 * (1.0 - status_resistance))
		statuses.erase(&"shock")
	if effect.effect_id == &"frost" and int(state["stacks"]) >= 5:
		freeze_remaining = maxf(freeze_remaining, 1.15 * (1.0 - status_resistance))
		statuses.erase(&"frost")
	queue_redraw()


func add_impulse(force: Vector2) -> void:
	impulse += force * (1.0 - knockback_resistance)


func _tick_statuses(delta: float) -> void:
	for key: Variant in statuses.keys():
		var kind := StringName(key)
		var state: Dictionary = statuses[kind]
		state["remaining"] = float(state.get("remaining", 0.0)) - delta
		state["tick"] = float(state.get("tick", 0.5)) - delta
		if kind == &"burn" and float(state["tick"]) <= 0.0:
			state["tick"] = 0.5
			var dot_packet := {
				"damage": float(state.get("magnitude", 0.0)),
				"damage_type": &"fire",
				"armor_penetration": 45.0,
				"shield_bypass": 0.25,
				"stagger_damage": 0.0,
				"resistance_penetration": 0.0,
				"source": state.get("source", null),
				"is_dot": true,
			}
			receive_damage(dot_packet)
			if dead:
				return
		if float(state["remaining"]) <= 0.0:
			statuses.erase(kind)
		else:
			statuses[kind] = state


func _status_speed_multiplier() -> float:
	var multiplier := 1.0
	if statuses.has(&"slow"):
		multiplier *= 1.0 - clampf(float(statuses[&"slow"].get("magnitude", 0.0)), 0.0, 0.78)
	if statuses.has(&"frost"):
		var frost: Dictionary = statuses[&"frost"]
		multiplier *= 1.0 - minf(0.62, float(frost.get("magnitude", 0.0)) * int(frost.get("stacks", 1)))
	return multiplier


func _die(killer: Node, packet: Dictionary) -> void:
	if dead:
		return
	dead = true
	collision_layer = 0
	collision_mask = 0
	died.emit(self, killer, packet)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.45, 1.45), 0.10)
	tween.parallel().tween_property(self, "rotation", rotation + 0.7, 0.16)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.20)
	tween.tween_callback(queue_free)


func _draw() -> void:
	var color := Color.WHITE if flash > 0.0 else body_color
	var forward := Vector2.RIGHT
	if is_instance_valid(player):
		forward = global_position.direction_to(player.global_position)

	draw_circle(Vector2.ZERO, radius + 3.0, Color(0.01, 0.025, 0.06, 0.95))
	match archetype:
		&"sentinel":
			var points := PackedVector2Array()
			for i: int in range(6):
				points.append(Vector2.from_angle(float(i) / 6.0 * TAU) * radius)
			draw_colored_polygon(points, color)
			draw_arc(Vector2.ZERO, radius + 5.0, -2.6, 2.6, 24, Color("72d8ff"), 2.0)
		&"bulwark":
			draw_circle(Vector2.ZERO, radius, color)
			draw_arc(Vector2.ZERO, radius - 5.0, 0.0, TAU, 32, Color("6b351b"), 5.0)
			draw_line(-forward.rotated(PI * 0.5) * 12.0, forward.rotated(PI * 0.5) * 12.0, Color("fff0c9"), 3.0)
		_:
			var side := forward.rotated(PI * 0.5)
			var points := PackedVector2Array([forward * radius, -forward * radius * 0.72 + side * radius * 0.72, -forward * radius * 0.72 - side * radius * 0.72])
			draw_colored_polygon(points, color)

	# Weak point and defense bars.
	draw_circle(Vector2.ZERO, radius * 0.28, Color("fff5d6"))
	draw_circle(Vector2.ZERO, radius * 0.14, Color("3a1c39"))
	var bar_width := radius * 2.3
	draw_rect(Rect2(-bar_width * 0.5, -radius - 12.0, bar_width, 4.0), Color(0.02, 0.03, 0.06, 0.9), true)
	draw_rect(Rect2(-bar_width * 0.5, -radius - 12.0, bar_width * health / maxf(1.0, max_health), 4.0), Color("ff6685"), true)
	if max_shield > 0.0:
		draw_rect(Rect2(-bar_width * 0.5, -radius - 17.0, bar_width * shield / maxf(1.0, max_shield), 3.0), Color("5bd8ff"), true)

	var pip_index := 0
	for key: Variant in statuses.keys():
		var pip_color := _status_color(StringName(key))
		draw_circle(Vector2(-radius + 4.0 + pip_index * 7.0, radius + 7.0), 2.5, pip_color)
		pip_index += 1


func _status_color(kind: StringName) -> Color:
	match kind:
		&"burn":
			return Color("ff6b45")
		&"corrosion":
			return Color("9dff4f")
		&"shock":
			return Color("66e9ff")
		&"frost", &"slow":
			return Color("89bfff")
		&"mark":
			return Color("ff76c9")
		_:
			return Color.WHITE

