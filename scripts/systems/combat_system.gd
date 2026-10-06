class_name CombatSystem
extends Node2D

## Delivery is resolved here, then routed to emitter, receiver, impact, and world lanes.

var player: CombatPlayer
var rng := RandomNumberGenerator.new()
var tracers: Array[Dictionary] = []
var pulses: Array[Dictionary] = []
var damage_numbers: Array[Dictionary] = []


func configure(player_ref: CombatPlayer, seed_value: int = 0) -> void:
	player = player_ref
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	z_index = 4


func _process(delta: float) -> void:
	_tick_visual_list(tracers, delta)
	_tick_visual_list(pulses, delta)
	for number: Dictionary in damage_numbers:
		number["life"] = float(number.get("life", 0.0)) - delta
		number["position"] = Vector2(number.get("position", Vector2.ZERO)) + Vector2.UP * 24.0 * delta
	for index: int in range(damage_numbers.size() - 1, -1, -1):
		if float(damage_numbers[index].get("life", 0.0)) <= 0.0:
			damage_numbers.remove_at(index)
	if not tracers.is_empty() or not pulses.is_empty() or not damage_numbers.is_empty():
		queue_redraw()


func _tick_visual_list(items: Array[Dictionary], delta: float) -> void:
	for item: Dictionary in items:
		item["life"] = float(item.get("life", 0.0)) - delta
	for index: int in range(items.size() - 1, -1, -1):
		if float(items[index].get("life", 0.0)) <= 0.0:
			items.remove_at(index)


func fire_hitscan(shooter: CombatPlayer, weapon: WeaponRuntime, origin: Vector2, direction: Vector2, spread_multiplier: float = 1.0) -> bool:
	var shot_direction := _spread_direction(direction, weapon.current_spread_deg * spread_multiplier)
	var ray_start := origin
	var remaining_range := weapon.get_stat(&"range")
	var distance_travelled := 0.0
	var max_receiver_hits := maxi(1, weapon.stat_int(&"maximum_hits_per_shot"))
	var receiver_hits := 0
	var ricochets_left := weapon.stat_int(&"ricochet_count")
	var excludes: Array[RID] = [shooter.get_rid()]
	var hit_something := false

	for _step: int in range(12):
		if remaining_range <= 1.0:
			break
		var ray_end := ray_start + shot_direction * remaining_range
		var query := PhysicsRayQueryParameters2D.create(ray_start, ray_end, 2 | 8, excludes)
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			_add_tracer(ray_start, ray_end, weapon.blueprint.accent, weapon.get_stat(&"tracer_visibility"), 2.0)
			break

		var impact: Vector2 = hit.position
		var segment_length := ray_start.distance_to(impact)
		distance_travelled += segment_length
		remaining_range -= segment_length
		_add_tracer(ray_start, impact, weapon.blueprint.accent, weapon.get_stat(&"tracer_visibility"), 2.4)
		_add_pulse(impact, 11.0, weapon.blueprint.accent, 0.13)
		var collider: Object = hit.collider

		if collider is CombatEnemy:
			hit_something = true
			var enemy := collider as CombatEnemy
			# The collision point is on the outer body shape; measure ray alignment with
			# the inner weak point instead of comparing that surface point to the center.
			var weakpoint := absf((enemy.global_position - impact).cross(shot_direction)) <= enemy.radius * 0.34
			var packet := _make_weapon_packet(shooter, weapon, enemy, distance_travelled, weakpoint, 1.0)
			packet["source_position"] = origin
			_deal_to_enemy(enemy, weapon, packet, impact, true)
			receiver_hits += 1
			excludes.append(enemy.get_rid())
			if receiver_hits >= max_receiver_hits:
				break
			ray_start = impact + shot_direction * 3.0
			remaining_range -= 3.0
			continue

		if collider is WorldProp:
			hit_something = true
			var prop_packet := _make_raw_packet(shooter, weapon, weapon.get_stat(&"damage"), false)
			(collider as WorldProp).receive_world_hit(prop_packet, shooter)
			break

		if ricochets_left > 0:
			var normal: Vector2 = hit.normal
			var incidence := absf(shot_direction.dot(normal))
			if incidence >= weapon.get_stat(&"ricochet_angle_tolerance"):
				ricochets_left -= 1
				shot_direction = shot_direction.bounce(normal).normalized()
				ray_start = impact + shot_direction * 3.0
				remaining_range -= 3.0
				continue
		break
	return hit_something


func fire_projectile(shooter: CombatPlayer, weapon: WeaponRuntime, origin: Vector2, direction: Vector2, spread_multiplier: float = 1.0) -> void:
	var projectile := ProjectileDelivery.new()
	add_child(projectile)
	var shot_direction := _spread_direction(direction, weapon.current_spread_deg * spread_multiplier)
	projectile.configure(self, shooter, weapon, origin, shot_direction)


func tick_beam(shooter: CombatPlayer, weapon: WeaponRuntime, origin: Vector2, direction: Vector2) -> bool:
	var ray_end := origin + direction * weapon.get_stat(&"range")
	var excludes: Array[RID] = [shooter.get_rid()]
	var query := PhysicsRayQueryParameters2D.create(origin, ray_end, 2 | 8, excludes)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	var visual_end := ray_end
	var first_target: CombatEnemy = null
	if not hit.is_empty():
		visual_end = hit.position
		if hit.collider is CombatEnemy:
			first_target = hit.collider as CombatEnemy
		elif hit.collider is WorldProp:
			var prop_packet := _make_raw_packet(shooter, weapon, weapon.get_stat(&"damage"), false)
			(hit.collider as WorldProp).receive_world_hit(prop_packet, shooter)

	_add_tracer(origin, visual_end, weapon.blueprint.accent, 0.15, weapon.get_stat(&"beam_width"))
	if first_target == null:
		weapon.beam_contact_time = maxf(0.0, weapon.beam_contact_time - 0.18)
		return false

	var ramp := 1.0 + minf(
		weapon.get_stat(&"beam_max_ramp") - 1.0,
		weapon.beam_contact_time * weapon.get_stat(&"beam_ramp_per_second")
	)
	var distance := origin.distance_to(first_target.global_position)
	var first_packet := _make_weapon_packet(shooter, weapon, first_target, distance, false, ramp)
	first_packet["source_position"] = origin
	_deal_to_enemy(first_target, weapon, first_packet, visual_end, true)

	var hit_ids: Dictionary = {first_target.get_instance_id(): true}
	var chain_origin := first_target.global_position
	var chain_damage_scale := 0.72
	for chain_index: int in range(weapon.stat_int(&"chain_count")):
		var chained := find_nearest_enemy(chain_origin, weapon.get_stat(&"chain_range"), hit_ids)
		if chained == null:
			break
		hit_ids[chained.get_instance_id()] = true
		_add_tracer(chain_origin, chained.global_position, weapon.blueprint.accent.lightened(0.12), 0.15, maxf(2.0, weapon.get_stat(&"beam_width") * 0.65))
		var chain_packet := _make_weapon_packet(shooter, weapon, chained, origin.distance_to(chained.global_position), false, ramp * chain_damage_scale)
		chain_packet["source_position"] = chain_origin
		_deal_to_enemy(chained, weapon, chain_packet, chained.global_position, true)
		chain_origin = chained.global_position
		chain_damage_scale *= 0.78
	return true


func resolve_projectile_collision(projectile: ProjectileDelivery, collision: KinematicCollision2D) -> void:
	if not is_instance_valid(projectile) or projectile.has_meta("finished"):
		return
	var collider: Object = collision.get_collider()
	if collider is CombatEnemy:
		var enemy := collider as CombatEnemy
		if projectile.hit_ids.has(enemy.get_instance_id()):
			projectile.pass_through(enemy)
			return
		projectile.hit_ids[enemy.get_instance_id()] = true
		var packet := _make_weapon_packet(
			projectile.shooter,
			projectile.weapon,
			enemy,
			projectile.distance_travelled,
			false,
			projectile.damage_scale
		)
		packet["source_position"] = projectile.global_position - projectile.direction * 18.0
		_deal_to_enemy(enemy, projectile.weapon, packet, collision.get_position(), true)
		if projectile.pierces_left > 0:
			projectile.pierces_left -= 1
			projectile.pass_through(enemy)
		else:
			finish_projectile(projectile, true)
		return

	if collider is WorldProp:
		var prop_packet := _make_raw_packet(projectile.shooter, projectile.weapon, projectile.weapon.get_stat(&"damage") * projectile.damage_scale, false)
		(collider as WorldProp).receive_world_hit(prop_packet, projectile.shooter)
		finish_projectile(projectile, true)
		return

	if projectile.bounces_left > 0:
		projectile.bounces_left -= 1
		projectile.reflect(collision.get_normal())
	else:
		finish_projectile(projectile, true)


func finish_projectile(projectile: ProjectileDelivery, terminal: bool) -> void:
	if not is_instance_valid(projectile) or projectile.has_meta("finished"):
		return
	projectile.set_meta("finished", true)
	var impact_position := projectile.global_position
	var weapon := projectile.weapon
	var source := projectile.shooter
	var explosion_radius := weapon.get_stat(&"explosion_radius") * (0.42 if projectile.is_fragment else 1.0)
	if explosion_radius > 1.0:
		_apply_area_damage(source, weapon, impact_position, explosion_radius, projectile.damage_scale * 0.58, projectile.hit_ids)
		_add_pulse(impact_position, explosion_radius, weapon.blueprint.accent, 0.34)
	else:
		_add_pulse(impact_position, 14.0, weapon.blueprint.accent, 0.16)

	if not projectile.is_fragment:
		_spawn_impact_fields(source, weapon, impact_position)
		var fragments := weapon.stat_int(&"fragmentation_count")
		if fragments > 0:
			for index: int in range(fragments):
				var fragment := ProjectileDelivery.new()
				add_child(fragment)
				var angle := float(index) / float(fragments) * TAU + rng.randf_range(-0.2, 0.2)
				fragment.configure(self, source, weapon, impact_position, Vector2.from_angle(angle), 0.24, true)
	projectile.queue_free()


func _apply_area_damage(source: Node, weapon: WeaponRuntime, center: Vector2, radius: float, scale: float, excluded: Dictionary = {}) -> void:
	for enemy: Node in get_tree().get_nodes_in_group("damageable_enemies"):
		if not enemy is CombatEnemy or enemy.dead or excluded.has(enemy.get_instance_id()):
			continue
		var distance: float = center.distance_to(enemy.global_position)
		if distance > radius + enemy.radius:
			continue
		var falloff := lerpf(1.0, 0.45, clampf(distance / maxf(1.0, radius), 0.0, 1.0))
		var packet := _make_weapon_packet(source, weapon, enemy, distance, false, scale * falloff)
		packet["source_position"] = center
		_deal_to_enemy(enemy, weapon, packet, enemy.global_position, true)
		enemy.add_impulse(center.direction_to(enemy.global_position) * weapon.get_stat(&"stagger_damage") * 4.0)


func _spawn_impact_fields(source: Node, weapon: WeaponRuntime, position: Vector2) -> void:
	for effect: CombatEffectSpec in weapon.all_effects():
		if effect.lane != CombatEffectSpec.Lane.IMPACT or effect.trigger != CombatEffectSpec.Trigger.ON_HIT:
			continue
		if rng.randf() > effect.chance:
			continue
		var field := ImpactField.new()
		add_child(field)
		field.configure(self, source, weapon, effect, position)


func resolve_field_tick(field: ImpactField) -> void:
	if not is_instance_valid(field.shooter) or field.effect == null:
		return
	var receiver_count := 0
	for enemy: Node in get_tree().get_nodes_in_group("damageable_enemies"):
		if not enemy is CombatEnemy or enemy.dead:
			continue
		var distance: float = field.global_position.distance_to(enemy.global_position)
		if distance > field.effect.radius + enemy.radius:
			continue
		receiver_count += 1
		var tick_damage := field.weapon.get_stat(&"damage") * 0.035
		if field.effect.effect_id == &"gravity_well":
			tick_damage = field.effect.magnitude / field.tick_rate
			enemy.add_impulse(enemy.global_position.direction_to(field.global_position) * 55.0)
		elif field.effect.effect_id == &"slow_field":
			var slow := CombatEffectSpec.create(&"slow", CombatEffectSpec.Lane.RECEIVER, CombatEffectSpec.Trigger.ON_FIELD_TICK, field.effect.magnitude, 0.42, 1, 1.0, 0.0, &"frost", "Slow")
			enemy.apply_status(slow, field.shooter)
		var packet := _make_raw_packet(field.shooter, field.weapon, tick_damage, false)
		packet["source_position"] = field.global_position
		packet["armor_penetration"] = field.weapon.get_stat(&"armor_penetration") * 0.5
		_deal_to_enemy(enemy, field.weapon, packet, enemy.global_position, false)

	if receiver_count > 0:
		for effect: CombatEffectSpec in field.weapon.all_effects():
			if effect.lane == CombatEffectSpec.Lane.EMITTER and effect.trigger == CombatEffectSpec.Trigger.ON_FIELD_TICK:
				field.shooter.apply_emitter_effect(effect, field.weapon)


func explode_world_prop(position: Vector2, radius: float, damage: float, source: Node) -> void:
	_add_pulse(position, radius, Color("ff6a55"), 0.42)
	for enemy: Node in get_tree().get_nodes_in_group("damageable_enemies"):
		if not enemy is CombatEnemy or enemy.dead:
			continue
		var distance: float = position.distance_to(enemy.global_position)
		if distance > radius + enemy.radius:
			continue
		var scale := lerpf(1.0, 0.3, clampf(distance / radius, 0.0, 1.0))
		var packet := {
			"damage": damage * scale,
			"damage_type": &"fire",
			"armor_penetration": 25.0,
			"shield_bypass": 0.12,
			"stagger_damage": 42.0,
			"resistance_penetration": 0.0,
			"source": source,
			"source_position": position,
		}
		var result: Dictionary = enemy.receive_damage(packet)
		spawn_damage_number(enemy.global_position, float(result.actual_damage), Color("ff936b"), false)
		enemy.add_impulse(position.direction_to(enemy.global_position) * 290.0)

	if is_instance_valid(player):
		var player_distance := position.distance_to(player.global_position)
		if player_distance <= radius:
			player.take_damage(damage * 0.34 * (1.0 - player_distance / radius), position)

	# Nearby props can chain-react, demonstrating world-to-world interaction.
	for prop: Node in get_tree().get_nodes_in_group("world_props"):
		if not prop is WorldProp or prop.dead or prop.global_position.distance_to(position) < 1.0:
			continue
		if prop.global_position.distance_to(position) <= radius * 0.9:
			prop.receive_world_hit({"damage": damage * 0.8}, source)


func _deal_to_enemy(enemy: CombatEnemy, weapon: WeaponRuntime, packet: Dictionary, impact_position: Vector2, trigger_weapon_effects: bool) -> Dictionary:
	var result := enemy.receive_damage(packet)
	var critical := bool(packet.get("critical", false))
	var number_color := Color("fff17a") if critical else weapon.blueprint.accent
	spawn_damage_number(impact_position, float(result.actual_damage), number_color, critical)

	if trigger_weapon_effects:
		if not result.killed:
			for effect: CombatEffectSpec in weapon.all_effects():
				if effect.trigger == CombatEffectSpec.Trigger.ON_HIT and rng.randf() <= effect.chance:
					if effect.lane == CombatEffectSpec.Lane.RECEIVER:
						_apply_receiver_effect(enemy, effect, packet)
					elif effect.lane == CombatEffectSpec.Lane.EMITTER and is_instance_valid(packet.source):
						packet.source.apply_emitter_effect(effect, weapon)
		else:
			for effect: CombatEffectSpec in weapon.all_effects():
				if effect.lane == CombatEffectSpec.Lane.EMITTER and effect.trigger == CombatEffectSpec.Trigger.ON_KILL and rng.randf() <= effect.chance:
					if is_instance_valid(packet.source):
						packet.source.apply_emitter_effect(effect, weapon)
	return result


func _apply_receiver_effect(enemy: CombatEnemy, effect: CombatEffectSpec, packet: Dictionary) -> void:
	match effect.effect_id:
		&"knockback":
			enemy.add_impulse(Vector2(packet.get("source_position", Vector2.ZERO)).direction_to(enemy.global_position) * effect.magnitude)
		&"pull":
			enemy.add_impulse(enemy.global_position.direction_to(Vector2(packet.get("source_position", Vector2.ZERO))) * effect.magnitude)
		_:
			enemy.apply_status(effect, packet.get("source", null))


func _make_weapon_packet(source: Node, weapon: WeaponRuntime, target: CombatEnemy, distance: float, weakpoint: bool, scale: float) -> Dictionary:
	var falloff := 1.0
	var falloff_start := weapon.get_stat(&"falloff_start")
	var maximum_range := maxf(falloff_start + 1.0, weapon.get_stat(&"range"))
	if distance > falloff_start:
		var t := clampf((distance - falloff_start) / (maximum_range - falloff_start), 0.0, 1.0)
		falloff = lerpf(1.0, weapon.get_stat(&"falloff_end_multiplier"), t)
	var critical := weakpoint or rng.randf() <= weapon.get_stat(&"crit_chance")
	var damage := weapon.get_stat(&"damage") * scale * falloff
	if critical:
		damage *= weapon.get_stat(&"weakpoint_multiplier") if weakpoint else weapon.get_stat(&"crit_multiplier")
	damage *= weapon.conditional_damage_multiplier(target, distance)
	return {
		"damage": damage,
		"damage_type": weapon.blueprint.damage_type,
		"armor_penetration": weapon.get_stat(&"armor_penetration"),
		"shield_bypass": weapon.get_stat(&"shield_bypass"),
		"stagger_damage": weapon.get_stat(&"stagger_damage") * scale,
		"resistance_penetration": weapon.get_stat(&"resistance_penetration"),
		"critical": critical,
		"weakpoint": weakpoint,
		"source": source,
	}


func _make_raw_packet(source: Node, weapon: WeaponRuntime, damage: float, critical: bool) -> Dictionary:
	return {
		"damage": damage,
		"damage_type": weapon.blueprint.damage_type,
		"armor_penetration": weapon.get_stat(&"armor_penetration"),
		"shield_bypass": weapon.get_stat(&"shield_bypass"),
		"stagger_damage": weapon.get_stat(&"stagger_damage"),
		"resistance_penetration": weapon.get_stat(&"resistance_penetration"),
		"critical": critical,
		"source": source,
	}


func find_nearest_enemy(position: Vector2, maximum_distance: float, excluded: Dictionary = {}) -> CombatEnemy:
	var nearest: CombatEnemy = null
	var nearest_distance := maximum_distance
	for enemy: Node in get_tree().get_nodes_in_group("damageable_enemies"):
		if not enemy is CombatEnemy or enemy.dead or excluded.has(enemy.get_instance_id()):
			continue
		var distance: float = position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest


func spawn_damage_number(position: Vector2, amount: float, color: Color, critical: bool) -> void:
	if amount <= 0.05:
		return
	damage_numbers.append({
		"position": position + Vector2(rng.randf_range(-7.0, 7.0), -13.0),
		"text": ("%d!" if critical else "%d") % int(round(amount)),
		"color": color,
		"life": 0.68,
		"total": 0.68,
		"critical": critical,
	})
	queue_redraw()


func _spread_direction(direction: Vector2, spread_degrees: float) -> Vector2:
	return direction.rotated(deg_to_rad(rng.randf_range(-spread_degrees, spread_degrees))).normalized()


func _add_tracer(from: Vector2, to: Vector2, color: Color, lifetime: float, width: float) -> void:
	tracers.append({"from": from, "to": to, "color": color, "life": lifetime, "total": lifetime, "width": width})
	queue_redraw()


func _add_pulse(position: Vector2, radius: float, color: Color, lifetime: float) -> void:
	pulses.append({"position": position, "radius": radius, "color": color, "life": lifetime, "total": lifetime})
	queue_redraw()


func _draw() -> void:
	for tracer: Dictionary in tracers:
		var ratio := clampf(float(tracer.life) / maxf(0.01, float(tracer.total)), 0.0, 1.0)
		var color: Color = tracer.color
		draw_line(tracer.from, tracer.to, Color(color, ratio * 0.18), float(tracer.width) * 2.8)
		draw_line(tracer.from, tracer.to, Color(color, ratio * 0.95), float(tracer.width))
	for pulse: Dictionary in pulses:
		var progress := 1.0 - clampf(float(pulse.life) / maxf(0.01, float(pulse.total)), 0.0, 1.0)
		var color: Color = pulse.color
		draw_circle(pulse.position, float(pulse.radius) * progress, Color(color, 0.10 * (1.0 - progress)))
		draw_arc(pulse.position, float(pulse.radius) * progress, 0.0, TAU, 48, Color(color, 0.8 * (1.0 - progress)), 2.5)
	var font := ThemeDB.fallback_font
	for number: Dictionary in damage_numbers:
		var ratio := clampf(float(number.life) / float(number.total), 0.0, 1.0)
		var color: Color = number.color
		var font_size := 19 if bool(number.critical) else 15
		draw_string(font, number.position, String(number.text), HORIZONTAL_ALIGNMENT_CENTER, 44.0, font_size, Color(color, ratio))
