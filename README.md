# Combat Systems Lab

A playable Godot 4 MVP for a modular, procedural-loot combat architecture. It separates **delivery**, **handling**, **emitter**, **receiver**, **impact**, **environment**, **trigger**, and **scaling** concerns while keeping the game small enough to understand and extend.

Authored and smoke-tested with Godot **4.7.1 stable**. It uses only generated vector-style drawing and has no third-party asset dependencies.

## Run it

1. Extract this project.
2. Open `project.godot` in Godot 4.x.
3. Press **F6/F5** or click **Run Project**.

Controls:

| Input | Action |
| --- | --- |
| WASD | Move |
| Mouse | Aim |
| Left mouse | Fire / sustain beam |
| Right mouse | Focus aim (tighter spread, slower movement) |
| 1 / 2 / 3 | Select hitscan / projectile / beam |
| R | Reload |
| Space | Dash with brief invulnerability |
| 1 / 2 / 3 in loot screen | Install that modifier |

Every five eliminations, the simulation pauses and offers three modifiers for the currently equipped weapon. Red canisters are destructible and chain-react.

## Playable weapon identities

### 1. VEKTOR-9 — hitscan

- Instant ray delivery with range falloff.
- Moving, sustained-fire, and ADS spread behavior.
- Critical and central weak-point hits.
- `Expose` mark stacks increase follow-up damage.
- Loot can add receiver penetration, wall ricochet, and stronger weak points.

### 2. GRAV LANCE — projectile

- Visible accelerating projectile with collision and lifetime.
- Direct damage, armor penetration, stagger, and radial splash.
- Pulls the struck receiver.
- Creates a lingering inertial field that slows and damages receivers.
- Field damage grants the emitter a short movement buff.
- Loot can add homing, fragmentation, a larger blast, or a gravity well.

### 3. ARC WELDER — beam

- Sustained ray contact with per-target damage ramp.
- Heat, overheat lockout, and active dissipation.
- Chains to nearby receivers with diminishing damage.
- Builds Shock; four stacks interrupt the receiver.
- Returns a small amount of shield on contact.
- Loot can add beam chains, stronger ramping, better cooling, or Frostbite.

## Implemented system slice

| Layer | MVP implementation |
| --- | --- |
| Delivery | Hitscan, moving projectile, sustained beam |
| Handling | Fire rate, magazine, reload, heat, movement/aim penalties, spread growth/recovery, recoil |
| Emitter | Health/shields, dash, shield-on-hit, speed-on-kill/field tick, ammo-on-kill |
| Receiver | Health, regenerating shield, armor hardness, resistances, damage cap, stagger threshold |
| Receiver effects | Mark, Burn, Corrosion, Shock, Frostbite, Slow, pull, knockback |
| Impact | Explosion, inertial slow field, gravity well, fragments |
| Environment | Destructible explosive props and world-to-world chain reactions |
| Triggers | On hit, on kill, and on field tick |
| Scaling | Full-health, low-health, close-range, and long-range conditional damage |
| Loot | Applicable per-delivery pool with common, rare, and exotic cards |

Enemy archetypes expose different niches:

- **Skirmisher:** low defenses, high speed.
- **Sentinel:** regenerating shield and modest status resistance.
- **Bulwark:** high armor hardness, damage-per-hit cap, stagger and knockback resistance.

## Architecture

```text
WeaponBlueprint (immutable authoring data)
		+ ModifierSpec loot
		↓
WeaponRuntime (ammo, heat, spread, installed modifiers)
		↓
CombatSystem (delivery resolver and combat event router)
		├── CombatPlayer       emitter effects
		├── CombatEnemy        receiver defenses and statuses
		├── ImpactField        persistent impact events
		└── WorldProp          environment events
```

Important files:

| File | Responsibility |
| --- | --- |
| `scripts/data/weapon_blueprint.gd` | Base delivery and handling schema |
| `scripts/data/combat_effect_spec.gd` | Lane and trigger-neutral effect definition |
| `scripts/data/modifier_spec.gd` | Loot stat/effect/condition payload |
| `scripts/data/weapon_factory.gd` | Three authored weapon examples |
| `scripts/data/modifier_factory.gd` | Curated procedural-loot pool |
| `scripts/core/weapon_runtime.gd` | Per-run state and modifier composition |
| `scripts/systems/combat_system.gd` | Hitscan/projectile/beam resolution and effect routing |
| `scripts/actors/combat_enemy.gd` | Defense pipeline, AI, stacking status runtime |
| `scripts/actors/combat_player.gd` | Input, handling, emitter resources and buffs |
| `scripts/delivery/` | Projectile and impact-field world objects |
| `scripts/ui/combat_hud.gd` | Readable combat telemetry and loot choice UI |

## Extend it

### Add a weapon

Create another `WeaponBlueprint` in `weapon_factory.gd`, set a delivery category, tune its stats, and attach `CombatEffectSpec` entries. Return a `WeaponRuntime` for it from `create_arsenal()` and add a selection binding/UI slot.

### Add a receiver or emitter effect

1. Add an effect in `weapon_factory.gd` or `modifier_factory.gd`.
2. Route its `effect_id` in `_apply_receiver_effect()` in `combat_system.gd` or `apply_emitter_effect()` in `combat_player.gd`.
3. If it is time-based, add its runtime behavior in `combat_enemy.gd`.

The delivery implementations do not need to change.

### Add a loot modifier

Add a `ModifierSpec` to `_build_pool()` in `modifier_factory.gd`. A modifier can:

- multiply or add any numeric `WeaponBlueprint` property;
- add one or more effects;
- add conditional damage scaling;
- filter itself to one delivery category.

## Validation

Run the included deterministic smoke test from the project directory:

```bash
godot --headless --path . --script res://tests/smoke_test.gd
```

It exercises scene creation, all three delivery categories, defense damage, a status threshold, projectile collision, and loot application.

## MVP boundaries

This prototype deliberately does not include networking, save persistence, animation assets, audio, gamepad aim assist, inventory management, or a fully combinatorial loot balancer. The extension seams are present, but those production systems are outside this vertical slice.
