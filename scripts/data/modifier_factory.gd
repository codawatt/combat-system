class_name ModifierFactory
extends RefCounted

## Curated MVP pool. The runtime representation is generic; these are just examples.


static func roll_choices(weapon: WeaponRuntime, rng: RandomNumberGenerator, count: int = 3) -> Array[ModifierSpec]:
	var candidates: Array[ModifierSpec] = []
	for modifier: ModifierSpec in _build_pool():
		if modifier.applies_to(weapon.blueprint.delivery) and not weapon.modifier_names.has(modifier.display_name):
			candidates.append(modifier)
	var choices: Array[ModifierSpec] = []
	while choices.size() < count and not candidates.is_empty():
		var index := rng.randi_range(0, candidates.size() - 1)
		choices.append(candidates[index])
		candidates.remove_at(index)
	return choices


static func _build_pool() -> Array[ModifierSpec]:
	var pool: Array[ModifierSpec] = []
	pool.append(_stat_mod(&"calibrated_frame", "Calibrated Frame", "+18% base damage.", ModifierSpec.Rarity.COMMON, -1, {&"damage": 1.18}))
	pool.append(_stat_mod(&"expanded_feed", "Expanded Feed", "+40% magazine capacity and +12% reload time.", ModifierSpec.Rarity.COMMON, -1, {&"magazine_size": 1.4, &"reload_time": 1.12}))
	pool.append(_stat_mod(&"hollow_matrix", "Hollow Matrix", "+10% critical chance and +0.35 critical multiplier.", ModifierSpec.Rarity.RARE, -1, {}, {&"crit_chance": 0.10, &"crit_multiplier": 0.35}))
	pool.append(_conditional(&"opening_argument", "Opening Argument", "+48% damage against full-health receivers.", ModifierSpec.Rarity.RARE, -1, &"target_full_health", 0.0, 1.48))
	pool.append(_conditional(&"cull_protocol", "Cull Protocol", "+42% damage against receivers below 30% health.", ModifierSpec.Rarity.RARE, -1, &"target_low_health", 0.30, 1.42))
	pool.append(_conditional(&"far_field", "Far-Field Optics", "+38% damage beyond 430 px.", ModifierSpec.Rarity.COMMON, -1, &"distance_over", 430.0, 1.38))
	pool.append(_conditional(&"breach_range", "Breach Doctrine", "+32% damage inside 155 px.", ModifierSpec.Rarity.COMMON, -1, &"distance_under", 155.0, 1.32))

	var thermite := _effect_mod(&"thermite", "Thermite Infusion", "Hits apply a high-damage Burn for 3 seconds.", ModifierSpec.Rarity.RARE, -1)
	thermite.added_effects.append(CombatEffectSpec.create(&"burn", CombatEffectSpec.Lane.RECEIVER, CombatEffectSpec.Trigger.ON_HIT, 5.0, 3.0, 1, 1.0, 0.0, &"fire", "Burn"))
	pool.append(thermite)

	var corrosion := _effect_mod(&"corrosive", "Corrosive Solvent", "Hits reduce armor hardness; repeated hits stack.", ModifierSpec.Rarity.RARE, -1)
	corrosion.added_effects.append(CombatEffectSpec.create(&"corrosion", CombatEffectSpec.Lane.RECEIVER, CombatEffectSpec.Trigger.ON_HIT, 0.09, 4.0, 1, 1.0, 0.0, &"corrosion", "Corrosion"))
	pool.append(corrosion)

	var adrenal := _effect_mod(&"adrenal", "Adrenal Relay", "Kills grant +35% movement speed for 3 seconds.", ModifierSpec.Rarity.RARE, -1)
	adrenal.added_effects.append(CombatEffectSpec.create(&"speed_on_kill", CombatEffectSpec.Lane.EMITTER, CombatEffectSpec.Trigger.ON_KILL, 0.35, 3.0, 1, 1.0, 0.0, &"kinetic", "Adrenal surge"))
	pool.append(adrenal)

	var reclaimer := _effect_mod(&"reclaimer", "Reclaimer Loop", "Kills refund 24% of the magazine (or vent beam heat).", ModifierSpec.Rarity.COMMON, -1)
	reclaimer.added_effects.append(CombatEffectSpec.create(&"ammo_refund_on_kill", CombatEffectSpec.Lane.EMITTER, CombatEffectSpec.Trigger.ON_KILL, 0.24, 0.0, 1, 1.0, 0.0, &"kinetic", "Ammo refund"))
	pool.append(reclaimer)

	var aegis := _effect_mod(&"aegis_tap", "Aegis Tap", "Hits restore 1.8 shield.", ModifierSpec.Rarity.EXOTIC, -1)
	aegis.added_effects.append(CombatEffectSpec.create(&"shield_on_hit", CombatEffectSpec.Lane.EMITTER, CombatEffectSpec.Trigger.ON_HIT, 1.8, 0.0, 1, 1.0, 0.0, &"shock", "Shield siphon"))
	pool.append(aegis)

	# Hitscan identity.
	pool.append(_stat_mod(&"phase_bore", "Phase Bore", "Penetrate +2 receivers and gain +28 armor penetration.", ModifierSpec.Rarity.EXOTIC, WeaponBlueprint.Delivery.HITSCAN, {}, {&"maximum_hits_per_shot": 2.0, &"armor_penetration": 28.0}))
	pool.append(_stat_mod(&"ricochet_geometry", "Ricochet Geometry", "Shots reflect twice from arena walls.", ModifierSpec.Rarity.RARE, WeaponBlueprint.Delivery.HITSCAN, {}, {&"ricochet_count": 2.0}))
	pool.append(_stat_mod(&"needle_sight", "Needle Sight", "Tighter initial spread and +35% weak-point multiplier.", ModifierSpec.Rarity.RARE, WeaponBlueprint.Delivery.HITSCAN, {&"initial_spread_deg": 0.55, &"weakpoint_multiplier": 1.35}))

	# Projectile identity.
	pool.append(_stat_mod(&"seeker_fins", "Seeker Fins", "Projectiles acquire nearby targets and turn in flight.", ModifierSpec.Rarity.RARE, WeaponBlueprint.Delivery.PROJECTILE, {}, {&"homing_strength": 1.0, &"projectile_turn_rate": 3.8}))
	pool.append(_stat_mod(&"high_yield", "High-Yield Core", "+45% explosion radius and +12% damage.", ModifierSpec.Rarity.COMMON, WeaponBlueprint.Delivery.PROJECTILE, {&"explosion_radius": 1.45, &"damage": 1.12}))
	pool.append(_stat_mod(&"cluster_seed", "Cluster Seed", "Terminal impacts release 5 seeking fragments.", ModifierSpec.Rarity.EXOTIC, WeaponBlueprint.Delivery.PROJECTILE, {}, {&"fragmentation_count": 5.0}))
	var singularity := _effect_mod(&"singularity", "Pocket Singularity", "Impacts also create a damaging gravity well.", ModifierSpec.Rarity.EXOTIC, WeaponBlueprint.Delivery.PROJECTILE)
	singularity.added_effects.append(CombatEffectSpec.create(&"gravity_well", CombatEffectSpec.Lane.IMPACT, CombatEffectSpec.Trigger.ON_HIT, 7.0, 2.7, 1, 1.0, 132.0, &"gravity", "Gravity well"))
	pool.append(singularity)

	# Beam identity.
	pool.append(_stat_mod(&"prism_splitter", "Prism Splitter", "+2 beam chains and +55 px chain range.", ModifierSpec.Rarity.EXOTIC, WeaponBlueprint.Delivery.BEAM, {}, {&"chain_count": 2.0, &"chain_range": 55.0}))
	pool.append(_stat_mod(&"cold_sink", "Cryogenic Sink", "+42% heat dissipation and +20 heat capacity.", ModifierSpec.Rarity.COMMON, WeaponBlueprint.Delivery.BEAM, {&"heat_dissipation": 1.42}, {&"heat_threshold": 20.0}))
	pool.append(_stat_mod(&"contact_focus", "Contact Focus", "Damage ramps 70% faster and reaches a higher cap.", ModifierSpec.Rarity.RARE, WeaponBlueprint.Delivery.BEAM, {&"beam_ramp_per_second": 1.7}, {&"beam_max_ramp": 0.55}))
	var frost := _effect_mod(&"cryo_arc", "Cryo Arc", "Beam ticks build Frostbite; five stacks freeze.", ModifierSpec.Rarity.RARE, WeaponBlueprint.Delivery.BEAM)
	frost.added_effects.append(CombatEffectSpec.create(&"frost", CombatEffectSpec.Lane.RECEIVER, CombatEffectSpec.Trigger.ON_HIT, 0.09, 3.0, 1, 1.0, 0.0, &"frost", "Frostbite"))
	pool.append(frost)

	return pool


static func _base(id: StringName, title: String, text: String, rarity: ModifierSpec.Rarity, delivery: int) -> ModifierSpec:
	var modifier := ModifierSpec.new()
	modifier.modifier_id = id
	modifier.display_name = title
	modifier.description = text
	modifier.rarity = rarity
	modifier.delivery_filter = delivery
	return modifier


static func _stat_mod(
		id: StringName,
		title: String,
		text: String,
		rarity: ModifierSpec.Rarity,
		delivery: int,
		multipliers: Dictionary = {},
		additions: Dictionary = {}) -> ModifierSpec:
	var modifier := _base(id, title, text, rarity, delivery)
	modifier.stat_multipliers = multipliers
	modifier.stat_additions = additions
	return modifier


static func _effect_mod(id: StringName, title: String, text: String, rarity: ModifierSpec.Rarity, delivery: int) -> ModifierSpec:
	return _base(id, title, text, rarity, delivery)


static func _conditional(
		id: StringName,
		title: String,
		text: String,
		rarity: ModifierSpec.Rarity,
		delivery: int,
		condition: StringName,
		threshold: float,
		multiplier: float) -> ModifierSpec:
	var modifier := _base(id, title, text, rarity, delivery)
	modifier.conditional_bonuses.append({
		"condition": condition,
		"threshold": threshold,
		"multiplier": multiplier,
	})
	return modifier

