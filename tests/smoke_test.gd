extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("SMOKE TEST: " + message)


func _run() -> void:
	var packed: PackedScene = load("res://main.tscn")
	_check(packed != null, "main scene loads")
	var game: Node = packed.instantiate()
	root.add_child(game)
	await physics_frame
	await physics_frame

	_check(game.player != null, "player emitter exists")
	_check(game.combat_system != null, "combat system exists")
	_check(game.player.arsenal.size() == 3, "three delivery categories are available")
	_check(game.player.arsenal[0].blueprint.delivery == WeaponBlueprint.Delivery.HITSCAN, "slot 1 is hitscan")
	_check(game.player.arsenal[1].blueprint.delivery == WeaponBlueprint.Delivery.PROJECTILE, "slot 2 is projectile")
	_check(game.player.arsenal[2].blueprint.delivery == WeaponBlueprint.Delivery.BEAM, "slot 3 is beam")

	var enemies: Array[Node] = get_nodes_in_group("damageable_enemies")
	_check(not enemies.is_empty(), "arena spawns defensive receivers")
	if not enemies.is_empty():
		var target: CombatEnemy = enemies[0]
		target.global_position = game.player.global_position + Vector2(130, 0)
		await physics_frame
		var before_hitscan := target.health + target.shield
		game.combat_system.fire_hitscan(game.player, game.player.arsenal[0], game.player.global_position + Vector2(22, 0), Vector2.RIGHT)
		_check(target.health + target.shield < before_hitscan, "hitscan resolves against a receiver")

		var shock := CombatEffectSpec.create(&"shock", CombatEffectSpec.Lane.RECEIVER, CombatEffectSpec.Trigger.ON_HIT, 1.0, 2.0)
		for _index: int in range(4):
			target.apply_status(shock, game.player)
		_check(target.stun_remaining > 0.0, "stack threshold triggers crowd control")

		var before_beam := target.health + target.shield
		game.combat_system.tick_beam(game.player, game.player.arsenal[2], game.player.global_position + Vector2(20, 0), Vector2.RIGHT)
		_check(target.health + target.shield < before_beam, "beam tick applies contact damage")

	var projectile_target := CombatEnemy.new()
	game.add_child(projectile_target)
	projectile_target.configure(game.player, &"skirmisher", 1.0)
	projectile_target.global_position = game.player.global_position + Vector2(185, 0)
	var projectile_before := projectile_target.health
	game.combat_system.fire_projectile(game.player, game.player.arsenal[1], game.player.global_position + Vector2(22, 0), Vector2.RIGHT)
	for _frame: int in range(40):
		await physics_frame
		if projectile_target.dead or projectile_target.health < projectile_before:
			break
	_check(projectile_target.dead or projectile_target.health < projectile_before, "projectile travels and collides")

	var test_rng := RandomNumberGenerator.new()
	test_rng.seed = 77
	var choices := ModifierFactory.roll_choices(game.player.arsenal[0], test_rng, 3)
	_check(choices.size() == 3, "loot generator returns three applicable choices")
	if not choices.is_empty():
		var modifier_count: int = game.player.arsenal[0].modifier_names.size()
		game.player.arsenal[0].apply_modifier(choices[0])
		_check(game.player.arsenal[0].modifier_names.size() == modifier_count + 1, "loot applies to weapon runtime")
		game.hud.show_loot(choices, game.player.arsenal[0])
		_check(game.hud.loot_overlay.visible, "loot cards render in the HUD")
		game.hud.hide_loot()

	var props: Array[Node] = get_nodes_in_group("world_props")
	_check(not props.is_empty(), "environment receivers are present")
	if not props.is_empty():
		var prop: WorldProp = props[0]
		prop.receive_world_hit({"damage": 1000.0}, game.player)
		_check(prop.dead, "world prop converts damage into an explosion event")

	if not projectile_target.dead:
		var slow_effect := CombatEffectSpec.create(&"slow_field", CombatEffectSpec.Lane.IMPACT, CombatEffectSpec.Trigger.ON_HIT, 0.4, 1.0, 1, 1.0, 100.0, &"frost")
		var field := ImpactField.new()
		game.combat_system.add_child(field)
		field.configure(game.combat_system, game.player, game.player.arsenal[1], slow_effect, projectile_target.global_position)
		game.combat_system.resolve_field_tick(field)
		_check(projectile_target.statuses.has(&"slow"), "impact field applies a receiver status")

	await process_frame

	if failures.is_empty():
		print("SMOKE TEST PASS: delivery, receiver, status, and loot paths are healthy")
		quit(0)
	else:
		print("SMOKE TEST FAIL: %d checks failed" % failures.size())
		quit(1)
