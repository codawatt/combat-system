class_name CombatEffectSpec
extends Resource

## Effects are intentionally separated from the weapon that delivers them.
## A modifier can add the same effect without changing delivery code.

enum Lane {
	EMITTER,
	RECEIVER,
	IMPACT,
	ENVIRONMENT,
}

enum Trigger {
	ON_HIT,
	ON_KILL,
	ON_FIELD_TICK,
	WHILE_FIRING,
}

var effect_id: StringName = &""
var lane: Lane = Lane.RECEIVER
var trigger: Trigger = Trigger.ON_HIT
var magnitude: float = 0.0
var duration: float = 0.0
var stacks: int = 1
var chance: float = 1.0
var radius: float = 0.0
var damage_type: StringName = &"kinetic"
var label: String = ""


static func create(
		id: StringName,
		lane_value: Lane,
		trigger_value: Trigger,
		magnitude_value: float,
		duration_value: float = 0.0,
		stacks_value: int = 1,
		chance_value: float = 1.0,
		radius_value: float = 0.0,
		type_value: StringName = &"kinetic",
		label_value: String = "") -> CombatEffectSpec:
	var effect := CombatEffectSpec.new()
	effect.effect_id = id
	effect.lane = lane_value
	effect.trigger = trigger_value
	effect.magnitude = magnitude_value
	effect.duration = duration_value
	effect.stacks = stacks_value
	effect.chance = chance_value
	effect.radius = radius_value
	effect.damage_type = type_value
	effect.label = label_value if not label_value.is_empty() else String(id).capitalize()
	return effect


func duplicate_effect() -> CombatEffectSpec:
	return create(effect_id, lane, trigger, magnitude, duration, stacks, chance, radius, damage_type, label)

