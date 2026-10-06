class_name WeaponRuntime
extends RefCounted

## Mutable per-run state layered over an immutable WeaponBlueprint.

var blueprint: WeaponBlueprint
var stat_multipliers: Dictionary = {}
var stat_additions: Dictionary = {}
var extra_effects: Array[CombatEffectSpec] = []
var conditional_bonuses: Array[Dictionary] = []
var modifier_names: Array[String] = []

var ammo: int = 0
var cooldown: float = 0.0
var reload_remaining: float = 0.0
var heat: float = 0.0
var overheated: bool = false
var current_spread_deg: float = 0.0
var spread_recovery_delay: float = 0.0
var beam_tick_accumulator: float = 0.0
var beam_contact_time: float = 0.0
var is_firing: bool = false


func _init(source: WeaponBlueprint = null) -> void:
	blueprint = source
	if blueprint != null:
		ammo = int(get_stat(&"magazine_size"))
		current_spread_deg = get_stat(&"initial_spread_deg")


func get_stat(stat_name: StringName) -> float:
	if blueprint == null:
		return 0.0
	var base_value: Variant = blueprint.get(stat_name)
	if base_value == null:
		base_value = 0.0
	var added := float(stat_additions.get(stat_name, 0.0))
	var multiplied := float(stat_multipliers.get(stat_name, 1.0))
	return (float(base_value) + added) * multiplied


func stat_int(stat_name: StringName) -> int:
	return maxi(0, int(round(get_stat(stat_name))))


func all_effects() -> Array[CombatEffectSpec]:
	var result: Array[CombatEffectSpec] = []
	result.append_array(blueprint.effects)
	result.append_array(extra_effects)
	return result


func apply_modifier(modifier: ModifierSpec) -> void:
	for key: Variant in modifier.stat_multipliers:
		var stat_key := StringName(key)
		stat_multipliers[stat_key] = float(stat_multipliers.get(stat_key, 1.0)) * float(modifier.stat_multipliers[key])
	for key: Variant in modifier.stat_additions:
		var stat_key := StringName(key)
		stat_additions[stat_key] = float(stat_additions.get(stat_key, 0.0)) + float(modifier.stat_additions[key])
	for effect: CombatEffectSpec in modifier.added_effects:
		extra_effects.append(effect.duplicate_effect())
	for bonus: Dictionary in modifier.conditional_bonuses:
		conditional_bonuses.append(bonus.duplicate(true))
	modifier_names.append(modifier.display_name)
	var magazine := stat_int(&"magazine_size")
	if magazine > 0:
		ammo = mini(ammo, magazine)


func tick(delta: float, actively_firing: bool) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	is_firing = actively_firing

	if reload_remaining > 0.0:
		reload_remaining -= delta
		if reload_remaining <= 0.0:
			reload_remaining = 0.0
			ammo = stat_int(&"magazine_size")

	if blueprint.delivery == WeaponBlueprint.Delivery.BEAM:
		if actively_firing and not overheated:
			heat = minf(get_stat(&"heat_threshold"), heat + get_stat(&"heat_per_second") * delta)
			if heat >= get_stat(&"heat_threshold") - 0.01:
				overheated = true
		else:
			heat = maxf(0.0, heat - get_stat(&"heat_dissipation") * delta)
			beam_contact_time = maxf(0.0, beam_contact_time - delta * 2.0)
		if overheated and heat <= get_stat(&"heat_threshold") * 0.32:
			overheated = false

	if spread_recovery_delay > 0.0:
		spread_recovery_delay -= delta
	else:
		current_spread_deg = move_toward(
			current_spread_deg,
			get_stat(&"initial_spread_deg"),
			get_stat(&"spread_recovery_speed") * delta
		)


func can_fire() -> bool:
	if cooldown > 0.0 or reload_remaining > 0.0 or overheated:
		return false
	if blueprint.delivery == WeaponBlueprint.Delivery.BEAM:
		return true
	return ammo >= stat_int(&"ammo_per_shot")


func consume_discrete_shot() -> void:
	ammo = maxi(0, ammo - stat_int(&"ammo_per_shot"))
	cooldown = 1.0 / maxf(0.1, get_stat(&"fire_rate"))
	current_spread_deg = minf(
		get_stat(&"maximum_spread_deg"),
		current_spread_deg + get_stat(&"spread_per_shot_deg")
	)
	spread_recovery_delay = get_stat(&"spread_recovery_delay")


func begin_reload() -> bool:
	var magazine := stat_int(&"magazine_size")
	if blueprint.delivery == WeaponBlueprint.Delivery.BEAM or ammo >= magazine or reload_remaining > 0.0:
		return false
	reload_remaining = get_stat(&"reload_time")
	return true


func refill_rounds(amount: int) -> void:
	if blueprint.delivery == WeaponBlueprint.Delivery.BEAM:
		heat = maxf(0.0, heat - float(amount) * 4.0)
		return
	ammo = mini(stat_int(&"magazine_size"), ammo + amount)


func conditional_damage_multiplier(target: Node, distance: float) -> float:
	var multiplier := 1.0
	for bonus: Dictionary in conditional_bonuses:
		var condition := StringName(bonus.get("condition", &""))
		var threshold := float(bonus.get("threshold", 0.0))
		var qualifies := false
		match condition:
			&"target_full_health":
				qualifies = target.health >= target.max_health * 0.98
			&"target_low_health":
				qualifies = target.health / maxf(1.0, target.max_health) <= threshold
			&"distance_over":
				qualifies = distance >= threshold
			&"distance_under":
				qualifies = distance <= threshold
		if qualifies:
			multiplier *= float(bonus.get("multiplier", 1.0))
	return multiplier


func delivery_label() -> String:
	match blueprint.delivery:
		WeaponBlueprint.Delivery.PROJECTILE:
			return "PROJECTILE"
		WeaponBlueprint.Delivery.BEAM:
			return "BEAM"
		_:
			return "HITSCAN"

