class_name CombatHUD
extends CanvasLayer

signal loot_selected(index: int)
signal restart_requested

var player: CombatPlayer
var kills: int = 0
var enemy_count: int = 0
var run_time: float = 0.0
var log_lines: Array[String] = []
var loot_choices: Array[ModifierSpec] = []
var notification_time: float = 0.0
var damage_overlay_time: float = 0.0

var health_bar: ProgressBar
var shield_bar: ProgressBar
var status_label: Label
var objective_label: Label
var weapon_title: Label
var weapon_subtitle: Label
var ammo_label: Label
var resource_bar: ProgressBar
var stats_label: Label
var modifiers_label: Label
var log_label: Label
var notification_label: Label
var damage_overlay: ColorRect
var loot_overlay: Control
var loot_title: Label
var loot_buttons: Array[Button] = []
var death_overlay: Control
var death_label: Label
var crosshair: CombatCrosshair


func configure(player_ref: CombatPlayer) -> void:
	player = player_ref
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	crosshair.configure(player)
	add_log("SIMULATION ONLINE")
	add_log("Delivery lanes calibrated")


func _build_interface() -> void:
	var root := Control.new()
	root.name = "Interface"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	damage_overlay = ColorRect.new()
	damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_overlay.color = Color(0.55, 0.02, 0.08, 0.0)
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(damage_overlay)

	_build_status_panel(root)
	_build_help_panel(root)
	_build_weapon_panel(root)
	_build_log_panel(root)

	var header := Label.new()
	header.text = "COMBAT SYSTEMS LAB  /  LIVE FIRE MVP"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 15)
	header.add_theme_color_override("font_color", Color("7ce7ff"))
	header.set_anchors_preset(Control.PRESET_CENTER_TOP)
	header.position = Vector2(-260, 17)
	header.size = Vector2(520, 28)
	root.add_child(header)

	objective_label = Label.new()
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.add_theme_font_size_override("font_size", 13)
	objective_label.add_theme_color_override("font_color", Color("b8cce6"))
	objective_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	objective_label.position = Vector2(-320, 43)
	objective_label.size = Vector2(640, 24)
	root.add_child(objective_label)

	notification_label = Label.new()
	notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification_label.add_theme_font_size_override("font_size", 25)
	notification_label.add_theme_color_override("font_color", Color("8eeaff"))
	notification_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	notification_label.position = Vector2(-300, 88)
	notification_label.size = Vector2(600, 42)
	notification_label.modulate.a = 0.0
	root.add_child(notification_label)

	crosshair = CombatCrosshair.new()
	root.add_child(crosshair)
	_build_loot_overlay(root)
	_build_death_overlay(root)


func _build_status_panel(root: Control) -> void:
	var panel := _panel(Rect2(22, 20, 286, 142), Color(0.025, 0.07, 0.13, 0.93), Color("245071"))
	root.add_child(panel)
	var margin := _margin(14)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)

	var title := _label("EMITTER / AEGIS-01", 14, Color("7ce7ff"))
	box.add_child(title)
	health_bar = _bar(Color("ff5e7d"), 100.0)
	shield_bar = _bar(Color("55dfff"), 55.0)
	box.add_child(health_bar)
	box.add_child(shield_bar)
	status_label = _label("", 12, Color("c6d8ee"))
	box.add_child(status_label)


func _build_help_panel(root: Control) -> void:
	var panel := _panel(Rect2(972, 20, 286, 226), Color(0.025, 0.07, 0.13, 0.93), Color("245071"))
	root.add_child(panel)
	var margin := _margin(14)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	box.add_child(_label("CONTROL SCHEMA", 14, Color("7ce7ff")))
	var controls := _label("WASD   Move\nLMB       Fire / sustain\nRMB      Focus aim\n1–3        Delivery swap\nR            Reload\nSPACE   Kinetic dash", 12, Color("c7d7e9"))
	controls.add_theme_constant_override("line_spacing", 2)
	box.add_child(controls)
	box.add_child(_separator(Color("244e6c")))
	box.add_child(_label("DEFENSE READOUT", 12, Color("8ba9c8")))
	box.add_child(_label("CYAN shield · ORANGE armor\nPips: Burn / Corrode / Shock / Frost / Mark\nRed canisters chain-react.", 11, Color("9fb4cc")))


func _build_weapon_panel(root: Control) -> void:
	var panel := _panel(Rect2(326, 568, 628, 134), Color(0.018, 0.055, 0.11, 0.96), Color("2a678d"))
	root.add_child(panel)
	var margin := _margin(14)
	panel.add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	margin.add_child(columns)

	var identity := VBoxContainer.new()
	identity.custom_minimum_size = Vector2(206, 0)
	identity.add_theme_constant_override("separation", 1)
	columns.add_child(identity)
	weapon_title = _label("", 21, Color.WHITE)
	weapon_subtitle = _label("", 11, Color("8fa9c4"))
	ammo_label = _label("", 19, Color.WHITE)
	resource_bar = _bar(Color("62e8ff"), 100.0)
	resource_bar.custom_minimum_size = Vector2(190, 8)
	identity.add_child(weapon_title)
	identity.add_child(weapon_subtitle)
	identity.add_child(ammo_label)
	identity.add_child(resource_bar)

	stats_label = _label("", 11, Color("c2d4e9"))
	stats_label.custom_minimum_size = Vector2(188, 0)
	columns.add_child(stats_label)
	modifiers_label = _label("", 11, Color("b8cbe2"))
	modifiers_label.custom_minimum_size = Vector2(184, 0)
	modifiers_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columns.add_child(modifiers_label)


func _build_log_panel(root: Control) -> void:
	var panel := _panel(Rect2(22, 536, 282, 166), Color(0.025, 0.07, 0.13, 0.91), Color("245071"))
	root.add_child(panel)
	var margin := _margin(13)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)
	box.add_child(_label("EVENT STREAM", 13, Color("7ce7ff")))
	log_label = _label("", 11, Color("a9bdd5"))
	log_label.add_theme_constant_override("line_spacing", 2)
	box.add_child(log_label)


func _build_loot_overlay(root: Control) -> void:
	loot_overlay = Control.new()
	loot_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loot_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	loot_overlay.visible = false
	root.add_child(loot_overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.005, 0.012, 0.028, 0.88)
	loot_overlay.add_child(shade)

	var panel := _panel(Rect2(116, 118, 1048, 480), Color(0.025, 0.065, 0.12, 0.98), Color("58cdec"))
	loot_overlay.add_child(panel)
	var margin := _margin(22)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	loot_title = _label("CHOOSE A MODIFIER", 25, Color("8eeaff"))
	loot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(loot_title)
	var subtitle := _label("A modifier may alter delivery, handling, emitter, receiver, impact, or scaling conditions. Press 1 / 2 / 3.", 12, Color("9fb6cf"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 14)
	box.add_child(cards)
	for index: int in range(3):
		var button := Button.new()
		button.custom_minimum_size = Vector2(322, 325)
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_constant_override("outline_size", 2)
		button.pressed.connect(_select_loot.bind(index))
		cards.add_child(button)
		loot_buttons.append(button)


func _build_death_overlay(root: Control) -> void:
	death_overlay = Control.new()
	death_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	death_overlay.visible = false
	root.add_child(death_overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.04, 0.005, 0.02, 0.9)
	death_overlay.add_child(shade)
	var panel := _panel(Rect2(390, 220, 500, 260), Color(0.07, 0.025, 0.055, 0.98), Color("ff6685"))
	death_overlay.add_child(panel)
	var margin := _margin(28)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)
	var title := _label("EMITTER OFFLINE", 31, Color("ff7793"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	death_label = _label("", 15, Color("c7d2e3"))
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(death_label)
	var retry := _label("PRESS ENTER TO RESTART THE SIMULATION", 13, Color("8eeaff"))
	retry.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(retry)


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	if not get_tree().paused:
		run_time += delta
	notification_time = maxf(0.0, notification_time - delta)
	if notification_time > 0.0:
		notification_label.modulate.a = minf(1.0, notification_time * 3.0)
	else:
		notification_label.modulate.a = move_toward(notification_label.modulate.a, 0.0, delta * 4.0)
	damage_overlay_time = maxf(0.0, damage_overlay_time - delta)
	var danger_alpha := 0.0
	if player.health < player.max_health * 0.3:
		danger_alpha = 0.05 + sin(Time.get_ticks_msec() * 0.008) * 0.025
	if damage_overlay_time > 0.0:
		danger_alpha = maxf(danger_alpha, damage_overlay_time * 0.55)
	damage_overlay.color.a = danger_alpha
	_update_readouts()


func _update_readouts() -> void:
	health_bar.max_value = player.max_health
	health_bar.value = player.health
	health_bar.tooltip_text = "Health %.0f / %.0f" % [player.health, player.max_health]
	shield_bar.max_value = player.max_shield
	shield_bar.value = player.shield
	shield_bar.tooltip_text = "Shield %.0f / %.0f" % [player.shield, player.max_shield]
	var dash_text := "READY" if player.dash_cooldown <= 0.0 else "%.1fs" % player.dash_cooldown
	var buff_text := ""
	if player.buffs.has(&"speed"):
		buff_text = "  ·  MOMENTUM +%d%%" % int(float(player.buffs[&"speed"].magnitude) * 100.0)
	status_label.text = "HP %03d  ·  SH %03d  ·  DASH %s%s" % [int(player.health), int(player.shield), dash_text, buff_text]

	var next_loot := 5 - (kills % 5)
	objective_label.text = "ELIMINATIONS %02d   ·   HOSTILES %02d   ·   NEXT LOOT %d   ·   %02d:%02d" % [kills, enemy_count, next_loot, int(run_time) / 60, int(run_time) % 60]
	var weapon := player.current_weapon()
	weapon_title.text = "[%d]  %s" % [player.current_weapon_index + 1, weapon.blueprint.weapon_name]
	weapon_title.add_theme_color_override("font_color", weapon.blueprint.accent)
	weapon_subtitle.text = "%s  /  %s" % [weapon.delivery_label(), weapon.blueprint.subtitle.to_upper()]

	if weapon.blueprint.delivery == WeaponBlueprint.Delivery.BEAM:
		ammo_label.text = "HEAT  %03d%%  %s" % [int(weapon.heat / maxf(1.0, weapon.get_stat(&"heat_threshold")) * 100.0), "OVERHEAT" if weapon.overheated else ""]
		resource_bar.max_value = weapon.get_stat(&"heat_threshold")
		resource_bar.value = weapon.heat
		_set_bar_color(resource_bar, Color("ff6f79") if weapon.overheated else weapon.blueprint.accent)
	else:
		var reload_text := "  RELOADING %.1f" % weapon.reload_remaining if weapon.reload_remaining > 0.0 else ""
		ammo_label.text = "AMMO  %02d / %02d%s" % [weapon.ammo, weapon.stat_int(&"magazine_size"), reload_text]
		resource_bar.max_value = maxf(1.0, weapon.get_stat(&"magazine_size"))
		resource_bar.value = weapon.ammo
		_set_bar_color(resource_bar, weapon.blueprint.accent)

	stats_label.text = _weapon_stats(weapon)
	var modifier_text := "ACTIVE MODIFIERS\n"
	if weapon.modifier_names.is_empty():
		modifier_text += "No loot installed yet.\nEvery 5 kills: choose one."
	else:
		for name: String in weapon.modifier_names.slice(maxi(0, weapon.modifier_names.size() - 4)):
			modifier_text += "• %s\n" % name
	modifiers_label.text = modifier_text


func _weapon_stats(weapon: WeaponRuntime) -> String:
	var text := "DMG  %.1f\nRATE %.1f/s\nRANGE %d\n" % [weapon.get_stat(&"damage"), weapon.get_stat(&"fire_rate"), int(weapon.get_stat(&"range"))]
	match weapon.blueprint.delivery:
		WeaponBlueprint.Delivery.HITSCAN:
			text += "SPREAD %.1f°\nPEN %d  RICO %d" % [weapon.current_spread_deg, weapon.stat_int(&"maximum_hits_per_shot") - 1, weapon.stat_int(&"ricochet_count")]
		WeaponBlueprint.Delivery.PROJECTILE:
			text += "SPEED %d +%d/s\nBLAST %d  FRAG %d" % [int(weapon.get_stat(&"projectile_speed")), int(weapon.get_stat(&"projectile_acceleration")), int(weapon.get_stat(&"explosion_radius")), weapon.stat_int(&"fragmentation_count")]
		WeaponBlueprint.Delivery.BEAM:
			text += "RAMP ×%.2f\nCHAIN %d @ %d" % [weapon.get_stat(&"beam_max_ramp"), weapon.stat_int(&"chain_count"), int(weapon.get_stat(&"chain_range"))]
	return text


func update_world_state(kill_count: int, hostiles: int) -> void:
	kills = kill_count
	enemy_count = hostiles


func add_log(text: String) -> void:
	log_lines.push_front("› " + text)
	if log_lines.size() > 6:
		log_lines.resize(6)
	if is_instance_valid(log_label):
		log_label.text = "\n".join(log_lines)


func announce(text: String, color: Color = Color("8eeaff")) -> void:
	notification_label.text = text
	notification_label.add_theme_color_override("font_color", color)
	notification_label.modulate.a = 1.0
	notification_time = 1.25


func flash_damage(_amount: float) -> void:
	damage_overlay_time = 0.18


func show_loot(choices: Array[ModifierSpec], weapon: WeaponRuntime) -> void:
	loot_choices = choices
	loot_title.text = "CALIBRATE  /  %s" % weapon.blueprint.weapon_name
	for index: int in range(loot_buttons.size()):
		var button := loot_buttons[index]
		if index >= choices.size():
			button.visible = false
			continue
		button.visible = true
		var choice := choices[index]
		button.text = "%d    %s\n\n%s\n\n%s\n\n%s" % [index + 1, choice.rarity_name(), choice.display_name.to_upper(), choice.description, _modifier_lane(choice)]
		button.add_theme_color_override("font_color", choice.rarity_color())
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_stylebox_override("normal", _style(Color(0.025, 0.075, 0.14, 0.98), Color(choice.rarity_color(), 0.55), 2, 10))
		button.add_theme_stylebox_override("hover", _style(Color(0.05, 0.12, 0.20, 1.0), choice.rarity_color(), 3, 10))
	loot_overlay.visible = true
	crosshair.visible = false


func hide_loot() -> void:
	loot_overlay.visible = false
	crosshair.visible = true
	loot_choices.clear()


func show_game_over(final_kills: int) -> void:
	death_label.text = "The run ended after %d eliminations.\nYour weapon architecture resets on restart." % final_kills
	death_overlay.visible = true
	crosshair.visible = false


func _modifier_lane(modifier: ModifierSpec) -> String:
	if not modifier.added_effects.is_empty():
		var lanes: Array[String] = []
		for effect: CombatEffectSpec in modifier.added_effects:
			var lane_name: String = String(CombatEffectSpec.Lane.keys()[effect.lane])
			if not lanes.has(lane_name):
				lanes.append(lane_name)
		return "LANE  " + " + ".join(lanes)
	if not modifier.conditional_bonuses.is_empty():
		return "SCALING CONDITION"
	return "DELIVERY / HANDLING"


func _select_loot(index: int) -> void:
	if loot_overlay.visible and index >= 0 and index < loot_choices.size():
		loot_selected.emit(index)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if loot_overlay.visible:
			if event.physical_keycode == KEY_1:
				_select_loot(0)
			elif event.physical_keycode == KEY_2:
				_select_loot(1)
			elif event.physical_keycode == KEY_3:
				_select_loot(2)
		elif death_overlay.visible and event.physical_keycode == KEY_ENTER:
			restart_requested.emit()


func _panel(rect: Rect2, background: Color, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", _style(background, border, 2, 8))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style


func _margin(amount: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", amount)
	margin.add_theme_constant_override("margin_right", amount)
	margin.add_theme_constant_override("margin_top", amount)
	margin.add_theme_constant_override("margin_bottom", amount)
	return margin


func _label(text_value: String, size_value: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _bar(color: Color, maximum: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 11)
	bar.max_value = maximum
	bar.value = maximum
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _style(Color(0.01, 0.025, 0.055, 0.95), Color(0.10, 0.22, 0.34, 1.0), 1, 3))
	_set_bar_color(bar, color)
	return bar


func _set_bar_color(bar: ProgressBar, color: Color) -> void:
	bar.add_theme_stylebox_override("fill", _style(Color(color, 0.9), color.lightened(0.18), 1, 3))


func _separator(color: Color) -> HSeparator:
	var separator := HSeparator.new()
	separator.add_theme_color_override("separator", color)
	return separator
