extends RefCounted

var card_id := ""
var display_name := ""
var side := "player"
var lane := 0
var row := 0
var role := "attack"
var max_hp := 1
var hp := 1
var damage := 0
var interval := 1.0
var aura_bonus := 0
var resource_amount := 0
var resource_interval := 4.0
var taunt := false
var ignore_taunt := false
var prefer_back := false
var charge_interval := 0.0
var charge_timer := 0.0
var charge_ready := false
var suppress_player_regen := false
var deathrattle_damage := 0
var regen_amount := 0
var regen_timer := 1.0
var back_row_bonus := 0
var healthy_bonus := 0
var taunt_front_bonus := 0
var cooldown := 0.0
var resource_timer := 4.0
var slow_timer := 0.0
var alive := true
var deploy_seq := 0
var resource_capped := false
var phases: Array = []
var phase_index := 0


func absolute_row() -> int:
	if side == "player":
		return 2 - row
	return 3 + row


func is_combat_unit() -> bool:
	return role != "tactic" and role != "resource"


func stats_text() -> String:
	if role == "resource":
		var suffix := "（未生效）" if resource_capped else ""
		return "体力 +%d / %.0fs%s" % [resource_amount, resource_interval, suffix]
	if role == "tactic":
		return "光环 +%d" % aura_bonus
	return "伤%d · %.1fs" % [damage, interval]


func status_text() -> String:
	var text := ""
	if taunt:
		text += "嘲"
	if slow_timer > 0.0:
		text += "缓"
	if charge_ready:
		text += "蓄"
	if suppress_player_regen:
		text += "压"
	if ignore_taunt:
		text += "破"
	if deathrattle_damage > 0:
		text += "亡"
	if regen_amount > 0:
		text += "愈"
	if resource_capped:
		text += "限"
	if phase_index > 0:
		text += "%d阶" % (phase_index + 1)
	return text


func role_color() -> Color:
	match role:
		"attack":
			return Color("#fb923c")
		"disrupt":
			return Color("#facc15")
		"defense":
			return Color("#60a5fa")
		"resource":
			return Color("#34d399")
		"tactic":
			return Color("#c084fc")
	return Color("#94a3b8")
