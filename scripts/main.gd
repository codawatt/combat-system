extends Node2D

const ARENA_RECT := Rect2(34.0, 34.0, 1212.0, 652.0)

var arena: CombatArena
var combat_system: CombatSystem
var player: CombatPlayer
var hud: CombatHUD
var rng := RandomNumberGenerator.new()
var kills: int = 0
var spawn_timer: float = 0.0
var elapsed: float = 0.0
var loot_choices: Array[ModifierSpec] = []
var game_over: bool = false
var loot_open: bool = false


func _ready() -> void:
	rng.randomize()
	_build_world()
	_build_combatants()
	_build_interface()
	for _index: int in range(5):
		spawn_enemy()
	spawn_timer = 2.5
	hud.announce("LIVE FIRE AUTHORIZED", Color("77eaff"))
	DisplayServer.window_set_title("Combat Systems Lab — Godot 4 MVP")


func _build_world() -> void:
	arena = CombatArena.new()
	add_child(arena)
	_build_wall(Vector2(640, 27), Vector2(1240, 22))
	_build_wall(Vector2(640, 693), Vector2(1240, 22))
	_build_wall(Vector2(27, 360), Vector2(22, 688))
	_build_wall(Vector2(1253, 360), Vector2(22, 688))


func _build_wall(position_value: Vector2, size_value: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.position = position_value
	wall.collision_layer = 8
	wall.collision_mask = 0
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size_value
	shape_node.shape = shape
	wall.add_child(shape_node)
	add_child(wall)


func _build_combatants() -> void:
	combat_system = CombatSystem.new()
	combat_system.name = "CombatSystem"
	add_child(combat_system)
	player = CombatPlayer.new()
	player.name = "PlayerEmitter"
	player.global_position = Vector2(640, 360)
	add_child(player)
	player.configure(combat_system)
	combat_system.configure(player)
	player.notification.connect(_on_player_notification)
	player.damaged.connect(_on_player_damaged)
	player.player_died.connect(_on_player_died)
	player.weapon_changed.connect(_on_weapon_changed)
	_spawn_world_props()


func _build_interface() -> void:
	hud = CombatHUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.configure(player)
	hud.loot_selected.connect(_on_loot_selected)
	hud.restart_requested.connect(_restart)


func _spawn_world_props() -> void:
	for position_value: Vector2 in [
		Vector2(445, 235),
		Vector2(835, 485),
		Vector2(900, 210),
		Vector2(370, 505),
		Vector2(1030, 370),
	]:
		var prop := WorldProp.new()
		prop.global_position = position_value
		add_child(prop)
		prop.configure(combat_system)


func _process(delta: float) -> void:
	if game_over or loot_open:
		return
	elapsed += delta
	spawn_timer -= delta
	var hostiles := _living_enemy_count()
	var desired_hostiles := mini(12, 5 + kills / 4)
	if spawn_timer <= 0.0 and hostiles < desired_hostiles:
		spawn_enemy()
		spawn_timer = maxf(0.75, 2.25 - kills * 0.025)
	hud.update_world_state(kills, _living_enemy_count())


func spawn_enemy() -> void:
	if game_over:
		return
	var archetype := _roll_archetype()
	var enemy := CombatEnemy.new()
	enemy.name = String(archetype).capitalize()
	add_child(enemy)
	var difficulty := 1.0 + minf(0.85, kills * 0.018 + elapsed * 0.0012)
	enemy.configure(player, archetype, difficulty)
	enemy.global_position = _roll_spawn_position()
	enemy.died.connect(_on_enemy_died)


func _roll_archetype() -> StringName:
	var roll := rng.randf()
	if kills >= 8 and roll < 0.18:
		return &"bulwark"
	if kills >= 2 and roll < 0.50:
		return &"sentinel"
	return &"skirmisher"


func _roll_spawn_position() -> Vector2:
	var position_value := Vector2.ZERO
	for _attempt: int in range(20):
		match rng.randi_range(0, 3):
			0:
				position_value = Vector2(rng.randf_range(90.0, 1190.0), 78.0)
			1:
				position_value = Vector2(rng.randf_range(90.0, 1190.0), 642.0)
			2:
				position_value = Vector2(78.0, rng.randf_range(90.0, 630.0))
			_:
				position_value = Vector2(1202.0, rng.randf_range(90.0, 630.0))
		if position_value.distance_to(player.global_position) > 260.0:
			break
	return position_value


func _living_enemy_count() -> int:
	var count := 0
	for enemy: Node in get_tree().get_nodes_in_group("damageable_enemies"):
		if enemy is CombatEnemy and not enemy.dead:
			count += 1
	return count


func _on_enemy_died(enemy: CombatEnemy, _killer: Node, _packet: Dictionary) -> void:
	kills += 1
	hud.update_world_state(kills, maxi(0, _living_enemy_count() - 1))
	hud.add_log("%s neutralized" % enemy.enemy_name)
	if kills % 5 == 0:
		call_deferred("_offer_loot")


func _offer_loot() -> void:
	if game_over or loot_open:
		return
	var runtime := player.current_weapon()
	loot_choices = ModifierFactory.roll_choices(runtime, rng, 3)
	if loot_choices.is_empty():
		hud.add_log("Modifier pool exhausted for %s" % runtime.blueprint.weapon_name)
		return
	loot_open = true
	player.controls_enabled = false
	hud.show_loot(loot_choices, runtime)
	get_tree().paused = true


func _on_loot_selected(index: int) -> void:
	if not loot_open or index < 0 or index >= loot_choices.size():
		return
	var chosen := loot_choices[index]
	var runtime := player.current_weapon()
	runtime.apply_modifier(chosen)
	hud.hide_loot()
	hud.add_log("Installed: %s" % chosen.display_name)
	loot_choices.clear()
	loot_open = false
	get_tree().paused = false
	player.controls_enabled = true
	hud.announce(chosen.display_name.to_upper(), chosen.rarity_color())


func _on_player_notification(text: String, color: Color) -> void:
	if is_instance_valid(hud):
		hud.announce(text, color)


func _on_player_damaged(amount: float) -> void:
	if is_instance_valid(hud):
		hud.flash_damage(amount)


func _on_weapon_changed(_index: int, weapon: WeaponRuntime) -> void:
	if is_instance_valid(hud):
		hud.add_log("Delivery: %s" % weapon.delivery_label())


func _on_player_died() -> void:
	if game_over:
		return
	game_over = true
	player.controls_enabled = false
	hud.show_game_over(kills)
	get_tree().paused = true


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

