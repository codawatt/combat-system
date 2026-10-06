class_name WeaponFactory
extends RefCounted


static func create_arsenal() -> Array[WeaponRuntime]:
	return [
		WeaponRuntime.new(_make_hitscan()),
		WeaponRuntime.new(_make_projectile()),
		WeaponRuntime.new(_make_beam()),
	]


static func _make_hitscan() -> WeaponBlueprint:
	var weapon := WeaponBlueprint.new()
	weapon.weapon_id = &"vector_rifle"
	weapon.weapon_name = "VEKTOR-9"
	weapon.subtitle = "Precision hitscan rifle"
	weapon.description = "Immediate kinetic fire. Stable first shots expose targets for follow-up damage."
	weapon.delivery = WeaponBlueprint.Delivery.HITSCAN
	weapon.accent = Color("62e8ff")
	weapon.damage = 15.0
	weapon.damage_type = &"kinetic"
	weapon.fire_rate = 8.5
	weapon.magazine_size = 30
	weapon.reload_time = 1.25
	weapon.range = 900.0
	weapon.falloff_start = 480.0
	weapon.falloff_end_multiplier = 0.62
	weapon.crit_chance = 0.08
	weapon.crit_multiplier = 1.75
	weapon.weakpoint_multiplier = 1.55
	weapon.initial_spread_deg = 0.35
	weapon.maximum_spread_deg = 5.2
	weapon.spread_per_shot_deg = 0.58
	weapon.spread_recovery_speed = 12.0
	weapon.armor_penetration = 12.0
	weapon.stagger_damage = 5.0
	weapon.maximum_hits_per_shot = 1
	weapon.effects = [
		CombatEffectSpec.create(&"mark", CombatEffectSpec.Lane.RECEIVER, CombatEffectSpec.Trigger.ON_HIT, 0.035, 2.5, 1, 1.0, 0.0, &"kinetic", "Expose"),
	]
	return weapon


static func _make_projectile() -> WeaponBlueprint:
	var weapon := WeaponBlueprint.new()
	weapon.weapon_id = &"grav_lance"
	weapon.weapon_name = "GRAV LANCE"
	weapon.subtitle = "Accelerating impact launcher"
	weapon.description = "A predictive projectile that accelerates, pulls receivers, and leaves a slow field."
	weapon.delivery = WeaponBlueprint.Delivery.PROJECTILE
	weapon.accent = Color("b07cff")
	weapon.damage = 46.0
	weapon.damage_type = &"plasma"
	weapon.fire_rate = 1.35
	weapon.magazine_size = 6
	weapon.reload_time = 1.75
	weapon.range = 780.0
	weapon.falloff_start = 700.0
	weapon.falloff_end_multiplier = 0.9
	weapon.crit_chance = 0.03
	weapon.initial_spread_deg = 0.6
	weapon.maximum_spread_deg = 3.0
	weapon.spread_per_shot_deg = 0.8
	weapon.projectile_speed = 390.0
	weapon.projectile_acceleration = 185.0
	weapon.projectile_size = 8.0
	weapon.projectile_lifetime = 2.2
	weapon.explosion_radius = 72.0
	weapon.armor_penetration = 28.0
	weapon.stagger_damage = 34.0
	weapon.firing_move_multiplier = 0.8
	weapon.effects = [
		CombatEffectSpec.create(&"pull", CombatEffectSpec.Lane.RECEIVER, CombatEffectSpec.Trigger.ON_HIT, 235.0, 0.0, 1, 1.0, 0.0, &"gravity", "Gravitic pull"),
		CombatEffectSpec.create(&"slow_field", CombatEffectSpec.Lane.IMPACT, CombatEffectSpec.Trigger.ON_HIT, 0.42, 3.2, 1, 1.0, 112.0, &"frost", "Inertial field"),
		CombatEffectSpec.create(&"speed_on_field_tick", CombatEffectSpec.Lane.EMITTER, CombatEffectSpec.Trigger.ON_FIELD_TICK, 0.12, 0.7, 1, 1.0, 0.0, &"gravity", "Field momentum"),
	]
	return weapon


static func _make_beam() -> WeaponBlueprint:
	var weapon := WeaponBlueprint.new()
	weapon.weapon_id = &"arc_welder"
	weapon.weapon_name = "ARC WELDER"
	weapon.subtitle = "Ramping chain beam"
	weapon.description = "Sustained contact ramps damage, chains to nearby targets, and builds Shock."
	weapon.delivery = WeaponBlueprint.Delivery.BEAM
	weapon.accent = Color("68ff9b")
	weapon.damage = 9.5
	weapon.damage_type = &"shock"
	weapon.fire_rate = 8.0
	weapon.magazine_size = 0
	weapon.range = 520.0
	weapon.falloff_start = 420.0
	weapon.falloff_end_multiplier = 0.8
	weapon.crit_chance = 0.02
	weapon.initial_spread_deg = 0.0
	weapon.maximum_spread_deg = 0.0
	weapon.beam_width = 7.0
	weapon.beam_tick_rate = 9.0
	weapon.beam_ramp_per_second = 0.34
	weapon.beam_max_ramp = 1.9
	weapon.chain_count = 2
	weapon.chain_range = 155.0
	weapon.heat_per_second = 31.0
	weapon.heat_threshold = 100.0
	weapon.heat_dissipation = 38.0
	weapon.shield_bypass = 0.14
	weapon.stagger_damage = 8.0
	weapon.firing_move_multiplier = 0.66
	weapon.effects = [
		CombatEffectSpec.create(&"shock", CombatEffectSpec.Lane.RECEIVER, CombatEffectSpec.Trigger.ON_HIT, 1.0, 3.0, 1, 1.0, 0.0, &"shock", "Shock stack"),
		CombatEffectSpec.create(&"shield_on_hit", CombatEffectSpec.Lane.EMITTER, CombatEffectSpec.Trigger.ON_HIT, 0.8, 0.0, 1, 1.0, 0.0, &"shock", "Capacitive shield"),
	]
	return weapon
