class_name CombatPlayer
extends CharacterBody2D

signal weapon_changed(index: int, weapon: WeaponRuntime)
signal notification(text: String, color: Color)
signal damaged(amount: float)
signal player_died

var combat_system: Node
var arsenal: Array[WeaponRuntime] = []
var current_weapon_index: int = 0
var max_health: float = 100.0
var health: float = 100.0
var max_shield: float = 55.0
var shield: float = 55.0
var shield_regen_delay: float = 0.0
var base_move_speed: float = 245.0
var aim_direction: Vector2 = Vector2.RIGHT
var move_input: Vector2 = Vector2.ZERO
var movement_impulse: Vector2 = Vector2.ZERO
var dash_cooldown: float = 0.0
var invulnerability: float = 0.0
var dead: bool = false
var controls_enabled: bool = true
var muzzle_flash: float = 0.0
var damage_flash: float = 0.0
var buffs: Dictionary = {}
var pending_burst: int = 0
var burst_timer: float = 0.0
var burst_direction: Vector2 = Vector2.RIGHT


func configure(system: Node) -> void:
	combat_system = system
	arsenal = WeaponFactory.create_arsenal()
	collision_layer = 1
	collision_mask = 2 | 8
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape_node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 14.0
	shape_node.shape = shape
	add_child(shape_node)
	queue_redraw()
	weapon_changed.emit(current_weapon_index, current_weapon())


func current_weapon() -> WeaponRuntime:
	return arsenal[current_weapon_index]


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or dead:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:
				switch_weapon(0)
			KEY_2:
				switch_weapon(1)
			KEY_3:
				switch_weapon(2)
			KEY_R:
				if current_weapon().begin_reload():
					notification.emit("RELOAD SEQUENCE", current_weapon().blueprint.accent)
			KEY_SPACE:
				_dash()


func _physics_process(delta: float) -> void:
	if dead:
		return

	_update_timers(delta)
	_update_buffs(delta)
	var firing_input := controls_enabled and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var aiming := controls_enabled and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var active_weapon := current_weapon()
	var beam_active := firing_input and active_weapon.blueprint.delivery == WeaponBlueprint.Delivery.BEAM and active_weapon.can_fire()
	for runtime: WeaponRuntime in arsenal:
		runtime.tick(delta, runtime == active_weapon and beam_active)

	_read_movement()
	var mouse_delta := get_global_mouse_position() - global_position
	if mouse_delta.length_squared() > 4.0:
		aim_direction = mouse_delta.normalized()

	var speed := base_move_speed * active_weapon.get_stat(&"move_speed_multiplier")
	if firing_input:
		speed *= active_weapon.get_stat(&"firing_move_multiplier")
	if aiming:
		speed *= active_weapon.get_stat(&"aiming_move_multiplier")
	if buffs.has(&"speed"):
		speed *= 1.0 + float(buffs[&"speed"].get("magnitude", 0.0))
	movement_impulse = movement_impulse.move_toward(Vector2.ZERO, 700.0 * delta)
	velocity = move_input * speed + movement_impulse
	move_and_slide()
	global_position.x = clampf(global_position.x, 55.0, 1225.0)
	global_position.y = clampf(global_position.y, 55.0, 665.0)

	burst_timer -= delta
	if pending_burst > 0 and burst_timer <= 0.0:
		if active_weapon.can_fire():
			_fire_single(active_weapon, burst_direction, aiming)
			pending_burst -= 1
			burst_timer = active_weapon.get_stat(&"burst_interval")
		else:
			pending_burst = 0

	if firing_input:
		if active_weapon.blueprint.delivery == WeaponBlueprint.Delivery.BEAM:
			_fire_beam(active_weapon, delta)
		elif pending_burst <= 0 and active_weapon.can_fire():
			burst_direction = aim_direction
			_fire_single(active_weapon, burst_direction, aiming)
			pending_burst = maxi(0, active_weapon.stat_int(&"burst_count") - 1)
			burst_timer = active_weapon.get_stat(&"burst_interval")
		elif active_weapon.ammo <= 0:
			active_weapon.begin_reload()

	queue_redraw()


func _read_movement() -> void:
	if not controls_enabled:
		move_input = Vector2.ZERO
		return
	var horizontal := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var vertical := float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	move_input = Vector2(horizontal, vertical).normalized()


func _fire_single(runtime: WeaponRuntime, direction: Vector2, aiming: bool) -> void:
	runtime.consume_discrete_shot()
	var spread_multiplier := 1.0
	if move_input.length_squared() > 0.01:
		spread_multiplier *= runtime.get_stat(&"moving_spread_multiplier")
	if aiming:
		spread_multiplier *= runtime.get_stat(&"ads_spread_multiplier")
	var muzzle := global_position + direction * 22.0
	match runtime.blueprint.delivery:
		WeaponBlueprint.Delivery.HITSCAN:
			combat_system.fire_hitscan(self, runtime, muzzle, direction, spread_multiplier)
		WeaponBlueprint.Delivery.PROJECTILE:
			combat_system.fire_projectile(self, runtime, muzzle, direction, spread_multiplier)
	movement_impulse -= direction * runtime.get_stat(&"recoil") * 2.4
	muzzle_flash = 0.07


func _fire_beam(runtime: WeaponRuntime, delta: float) -> void:
	if runtime.overheated:
		return
	runtime.beam_contact_time += delta
	runtime.beam_tick_accumulator += delta
	var tick_interval := 1.0 / maxf(1.0, runtime.get_stat(&"beam_tick_rate"))
	while runtime.beam_tick_accumulator >= tick_interval:
		runtime.beam_tick_accumulator -= tick_interval
		combat_system.tick_beam(self, runtime, global_position + aim_direction * 20.0, aim_direction)
	muzzle_flash = 0.04


func switch_weapon(index: int) -> void:
	if index < 0 or index >= arsenal.size() or index == current_weapon_index:
		return
	current_weapon().beam_contact_time = 0.0
	current_weapon().is_firing = false
	current_weapon_index = index
	pending_burst = 0
	weapon_changed.emit(current_weapon_index, current_weapon())
	notification.emit(current_weapon().blueprint.weapon_name, current_weapon().blueprint.accent)


func _dash() -> void:
	if dash_cooldown > 0.0:
		return
	var dash_direction := move_input if move_input.length_squared() > 0.01 else aim_direction
	movement_impulse += dash_direction.normalized() * 520.0
	dash_cooldown = 1.25
	invulnerability = 0.18
	notification.emit("KINETIC DASH", Color("8deaff"))


func take_damage(amount: float, source_position: Vector2) -> void:
	if dead or invulnerability > 0.0:
		return
	var remaining := amount
	if shield > 0.0:
		var shield_damage := minf(shield, remaining)
		shield -= shield_damage
		remaining -= shield_damage
	if remaining > 0.0:
		health = maxf(0.0, health - remaining)
	shield_regen_delay = 3.5
	damage_flash = 0.15
	movement_impulse += source_position.direction_to(global_position) * 80.0
	damaged.emit(amount)
	if health <= 0.0:
		dead = true
		controls_enabled = false
		collision_layer = 0
		player_died.emit()
	queue_redraw()


func apply_emitter_effect(effect: CombatEffectSpec, runtime: WeaponRuntime) -> void:
	match effect.effect_id:
		&"shield_on_hit":
			shield = minf(max_shield, shield + effect.magnitude)
		&"heal_on_hit", &"heal_on_kill":
			health = minf(max_health, health + effect.magnitude)
		&"speed_on_kill", &"speed_on_field_tick":
			buffs[&"speed"] = {"magnitude": effect.magnitude, "remaining": effect.duration}
			if effect.effect_id == &"speed_on_kill":
				notification.emit("ADRENAL SURGE", Color("76ffb0"))
		&"ammo_refund_on_kill":
			var rounds := maxi(1, int(ceil(runtime.get_stat(&"magazine_size") * effect.magnitude)))
			runtime.refill_rounds(rounds)
		&"cooldown_on_hit":
			dash_cooldown = maxf(0.0, dash_cooldown - effect.magnitude)


func _update_timers(delta: float) -> void:
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	invulnerability = maxf(0.0, invulnerability - delta)
	muzzle_flash = maxf(0.0, muzzle_flash - delta)
	damage_flash = maxf(0.0, damage_flash - delta)
	shield_regen_delay = maxf(0.0, shield_regen_delay - delta)
	if shield_regen_delay <= 0.0:
		shield = minf(max_shield, shield + max_shield * 0.17 * delta)


func _update_buffs(delta: float) -> void:
	for key: Variant in buffs.keys():
		var state: Dictionary = buffs[key]
		state["remaining"] = float(state.get("remaining", 0.0)) - delta
		if float(state["remaining"]) <= 0.0:
			buffs.erase(key)
		else:
			buffs[key] = state


func _draw() -> void:
	var accent := current_weapon().blueprint.accent if not arsenal.is_empty() else Color("68e8ff")
	var color := Color.WHITE if damage_flash > 0.0 else Color("d8f6ff")
	if invulnerability > 0.0:
		color = Color("fff3a8")

	draw_circle(Vector2.ZERO, 18.0, Color(0.01, 0.03, 0.065, 0.95))
	draw_circle(Vector2.ZERO, 14.0, color)
	draw_arc(Vector2.ZERO, 17.0, -2.7, 2.7, 32, accent, 3.0)
	draw_circle(Vector2.ZERO, 6.0, Color("163452"))
	draw_circle(Vector2.ZERO, 3.0, accent)

	# Directional weapon silhouette.
	var side := aim_direction.rotated(PI * 0.5)
	draw_colored_polygon(PackedVector2Array([
		aim_direction * 27.0 + side * 3.0,
		aim_direction * 10.0 + side * 5.0,
		aim_direction * 10.0 - side * 5.0,
		aim_direction * 27.0 - side * 3.0,
	]), accent)
	if muzzle_flash > 0.0:
		draw_circle(aim_direction * 29.0, 7.0, Color(accent, 0.65))

	if shield > 0.0:
		var shield_ratio := shield / maxf(1.0, max_shield)
		draw_arc(Vector2.ZERO, 22.0, -PI * 0.5, -PI * 0.5 + TAU * shield_ratio, 42, Color("55dfff"), 2.0)
	if dash_cooldown <= 0.0:
		draw_circle(-aim_direction * 17.0, 2.5, Color("a7f7ff"))
