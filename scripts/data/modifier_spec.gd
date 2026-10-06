class_name ModifierSpec
extends Resource

## A loot card can change numbers, add behavior, and/or add a scaling condition.

enum Rarity {
	COMMON,
	RARE,
	EXOTIC,
}

var modifier_id: StringName = &"modifier"
var display_name: String = "Modifier"
var description: String = ""
var rarity: Rarity = Rarity.COMMON
var delivery_filter: int = -1
var stat_multipliers: Dictionary = {}
var stat_additions: Dictionary = {}
var added_effects: Array[CombatEffectSpec] = []
var conditional_bonuses: Array[Dictionary] = []


func applies_to(delivery: WeaponBlueprint.Delivery) -> bool:
	return delivery_filter < 0 or delivery_filter == int(delivery)


func rarity_name() -> String:
	match rarity:
		Rarity.RARE:
			return "RARE"
		Rarity.EXOTIC:
			return "EXOTIC"
		_:
			return "COMMON"


func rarity_color() -> Color:
	match rarity:
		Rarity.RARE:
			return Color("6bdcff")
		Rarity.EXOTIC:
			return Color("ff72c6")
		_:
			return Color("a8ffb8")

