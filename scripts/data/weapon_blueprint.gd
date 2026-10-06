class_name WeaponBlueprint
extends Resource

## Immutable authoring data. WeaponRuntime owns ammo, heat, spread, and loot changes.

enum Delivery {
	HITSCAN,
	PROJECTILE,
	BEAM,
}

var weapon_id: StringName = &"weapon"
var weapon_name: String = "Weapon"
var subtitle: String = ""
var description: String = ""
var delivery: Delivery = Delivery.HITSCAN
var accent: Color = Color.WHITE

# Shared delivery and handling stats.
var damage: float = 10.0
var damage_type: StringName = &"kinetic"
var fire_rate: float = 5.0
var burst_count: int = 1
var burst_interval: float = 0.07
var magazine_size: int = 20
var ammo_per_shot: int = 1
var reload_time: float = 1.4
var range: float = 700.0
var falloff_start: float = 420.0
var falloff_end_multiplier: float = 0.55
var crit_chance: float = 0.05
var crit_multiplier: float = 1.6
var weakpoint_multiplier: float = 1.45
var initial_spread_deg: float = 0.5
var maximum_spread_deg: float = 5.0
var spread_per_shot_deg: float = 0.65
var spread_recovery_delay: float = 0.16
var spread_recovery_speed: float = 10.0
var moving_spread_multiplier: float = 1.45
var airborne_spread_multiplier: float = 1.0
var ads_spread_multiplier: float = 0.42
var recoil: float = 1.0
var move_speed_multiplier: float = 1.0
var firing_move_multiplier: float = 0.86
var aiming_move_multiplier: float = 0.72

# Defensive interaction.
var armor_penetration: float = 0.0
var shield_bypass: float = 0.0
var stagger_damage: float = 0.0
var resistance_penetration: float = 0.0

# Projectile delivery.
var projectile_speed: float = 420.0
var projectile_size: float = 7.0
var projectile_acceleration: float = 0.0
var projectile_gravity: float = 0.0
var projectile_lifetime: float = 2.0
var homing_strength: float = 0.0
var projectile_turn_rate: float = 0.0
var bounce_count: int = 0
var piercing_count: int = 0
var fragmentation_count: int = 0
var explosion_radius: float = 0.0

# Beam delivery.
var beam_width: float = 7.0
var beam_tick_rate: float = 8.0
var beam_ramp_per_second: float = 0.25
var beam_max_ramp: float = 1.8
var chain_count: int = 0
var chain_range: float = 150.0
var heat_per_second: float = 28.0
var heat_threshold: float = 100.0
var heat_dissipation: float = 35.0

# Hitscan delivery.
var ricochet_count: int = 0
var ricochet_angle_tolerance: float = 0.18
var maximum_hits_per_shot: int = 1
var tracer_visibility: float = 0.11

var effects: Array[CombatEffectSpec] = []

