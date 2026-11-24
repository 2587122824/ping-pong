extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://formation_battle.tscn")
	assert(scene != null, "formation_battle.tscn should load")
	var battle: Variant = scene.instantiate()
	battle.auto_tick = false
	battle.auto_refresh = false
	battle.shuffle_on_reshuffle = false
	root.add_child(battle)
	await process_frame

	# 初始状态：每关只有 1 个敌方单位
	assert(String(battle.phase) == "deploy", "starts in deploy phase")
	assert(battle.player_stamina == 100, "stamina starts at 100")
	assert(battle.player_hand.size() == 5, "hand starts with 5")
	assert(battle.player_draw_pile.size() == 7, "rest of the 12-card deck in draw pile")
	assert(_count_side(battle, "enemy") == 1, "normal level has a single enemy unit")
	assert(battle._enemy_unit_limit() == 1, "level caps the enemy board at 1 unit")
	assert(not bool(battle.level_definitions["CH1-01"]["enemy_reinforce"]), "single enemy levels do not reinforce")
	assert(String(battle.board["enemy"][1][1].card_id) == "solo_bomber", "single enemy sits in the middle slot")
	assert(battle.board["enemy"][1][1].max_hp == 352, "enemy unit gets the character hp bonus")
	assert(_count_side(battle, "player") == 0, "player board starts empty")
	assert(battle._character_attack_bonus("player") == 1, "player character grants +1 attack")
	var player_char_name: Label = battle.character_views["player"]["name"]
	var enemy_char_name: Label = battle.character_views["enemy"]["name"]
	assert(player_char_name.text == "你", "player character card is shown")
	assert(enemy_char_name.text == "近战先遣官", "enemy character follows the level deck")

	# 五关全部是单体敌人
	for level_id in battle.LEVEL_ORDER:
		battle.level_id = level_id
		battle.restart_battle()
		assert(_count_side(battle, "enemy") == 1, "level %s fields exactly one enemy" % level_id)
		assert(battle._enemy_unit_limit() == 1, "level %s caps the enemy board at 1" % level_id)
	battle.level_id = "CH1-01"
	battle.restart_battle()

	# 部署扣费与占位
	assert(battle.try_deploy("van_001", 0, 0, 0), "deploy van_001")
	assert(battle.player_stamina == 95, "van_001 costs 5")
	assert(battle.board["player"][0][0] != null, "slot occupied after deploy")
	assert(String(battle.board["player"][0][0].card_id) == "van_001", "unit card id")
	assert(battle.board["player"][0][0].max_hp == 22, "player units get the character hp bonus")
	assert(battle.board["player"][0][0].damage == 5, "player units get the character attack bonus")
	assert(battle.player_hand.size() == 5, "hand refilled after deploy")
	assert(battle.player_discard.size() == 1, "played card went to discard")

	# 换阵
	var old_unit = battle.board["player"][0][0]
	assert(battle.try_deploy("van_002", 0, 0, 0), "swap van_002 into occupied slot")
	assert(not old_unit.alive, "old unit removed on swap")
	assert(String(battle.board["player"][0][0].card_id) == "van_002", "swapped unit card id")
	assert(battle.player_stamina == 90, "swap also pays cost")

	# 体力不足
	battle.player_stamina = 4
	assert(not battle.try_deploy("van_003", 0, 0, 1), "cannot deploy without stamina")
	assert(battle.board["player"][0][1] == null, "failed deploy leaves slot empty")
	assert(battle.player_stamina == 4, "failed deploy does not spend stamina")

	# 目标选择：从后排放的单位也能打到最前排
	_clear_boards(battle)
	var poke_back = battle._create_unit("van_001", "player", 0, 2)
	battle.board["player"][0][2] = poke_back
	var poke_enemy = battle._create_unit("van_001", "enemy", 0, 0)
	battle.board["enemy"][0][0] = poke_enemy
	battle.start_battle()
	battle.tick(0.1)
	assert(String(battle.phase) == "battle", "still fighting")
	assert(poke_enemy.hp == 17, "back-row unit hits the front-most living row")

	# 正对面第一排有人：优先打正对的
	_clear_boards(battle)
	var lane_enemy = battle._create_unit("van_001", "enemy", 1, 0)
	var other_enemy = battle._create_unit("van_001", "enemy", 0, 0)
	battle.board["enemy"][1][0] = lane_enemy
	battle.board["enemy"][0][0] = other_enemy
	var lane_player = battle._create_unit("van_001", "player", 1, 0)
	battle.board["player"][1][0] = lane_player
	battle.start_battle()
	battle.tick(0.1)
	assert(lane_enemy.hp == 17, "same-lane front enemy is hit first")
	assert(other_enemy.hp == 22, "upper-lane front enemy is not hit")

	# 正对面第一排为空：按排从上到下打最前排
	_clear_boards(battle)
	var order_enemy_a = battle._create_unit("van_001", "enemy", 0, 0)
	var order_enemy_b = battle._create_unit("van_001", "enemy", 1, 0)
	battle.board["enemy"][0][0] = order_enemy_a
	battle.board["enemy"][1][0] = order_enemy_b
	var far_player = battle._create_unit("van_001", "player", 2, 0)
	battle.board["player"][2][0] = far_player
	battle.start_battle()
	battle.tick(0.1)
	assert(order_enemy_a.hp == 17, "upper-lane front enemy is hit first when the opposite row is empty")
	assert(order_enemy_b.hp == 22, "mid-lane front enemy is not hit")

	# 本路前排为空：先按排从上到下打最前排
	_clear_boards(battle)
	var deep_enemy = battle._create_unit("van_001", "enemy", 1, 2)
	var shallow_enemy = battle._create_unit("van_001", "enemy", 0, 0)
	battle.board["enemy"][1][2] = deep_enemy
	battle.board["enemy"][0][0] = shallow_enemy
	var picker = battle._create_unit("van_001", "player", 1, 0)
	battle.board["player"][1][0] = picker
	battle.start_battle()
	battle.tick(0.1)
	assert(shallow_enemy.hp == 17, "front-most occupied row is attacked in lane order")
	assert(deep_enemy.hp == 22, "deep enemy in our lane is not hit while a front row exists")

	# 后排重型单位打得到
	_clear_boards(battle)
	var heavy_enemy = battle._create_unit("van_001", "enemy", 0, 0)
	battle.board["enemy"][0][0] = heavy_enemy
	var heavy = battle._create_unit("bas_001", "player", 0, 2)
	battle.board["player"][0][2] = heavy
	battle.start_battle()
	battle.tick(0.1)
	assert(heavy_enemy.hp == 11, "back-row heavy unit hits for 11")

	# 无射程限制：前排全空时，近战单位也能跨排打后排
	_clear_boards(battle)
	var deep_only = battle._create_unit("van_001", "enemy", 2, 1)
	battle.board["enemy"][2][1] = deep_only
	var reach = battle._create_unit("van_001", "player", 0, 0)
	battle.board["player"][0][0] = reach
	battle.start_battle()
	battle.tick(0.1)
	assert(deep_only.hp == 17, "melee unit reaches the next occupied row")

	# 嘲讽
	_clear_boards(battle)
	var taunt_guard = battle._create_unit("van_005", "player", 0, 0)
	battle.board["player"][0][0] = taunt_guard
	var taunt_player_other = battle._create_unit("van_001", "player", 0, 1)
	battle.board["player"][0][1] = taunt_player_other
	var taunt_attacker = battle._create_unit("van_001", "enemy", 0, 0)
	battle.board["enemy"][0][0] = taunt_attacker
	battle.start_battle()
	var taunt_target = battle._find_target(taunt_attacker)
	assert(taunt_target != null, "taunt attacker has a target")
	assert(String(taunt_target.card_id) == "van_005", "taunt unit is prioritized")

	# 穿透：无视嘲讽、优先打最后排
	_clear_boards(battle)
	battle.level_id = "CH1-E01"
	battle.restart_battle()
	_clear_boards(battle)
	var pierce_guard = battle._create_unit("van_005", "player", 0, 0)
	battle.board["player"][0][0] = pierce_guard
	var pierce_back = battle._create_unit("van_001", "player", 0, 2)
	battle.board["player"][0][2] = pierce_back
	var breaker = battle._create_unit("solo_sniper", "enemy", 0, 0)
	battle.board["enemy"][0][0] = breaker
	battle.start_battle()
	assert(breaker.ignore_taunt, "breaker ignores taunt")
	var breaker_target = battle._find_target(breaker)
	assert(breaker_target != null, "breaker has a target")
	assert(String(breaker_target.card_id) == "van_001", "breaker prefers the back row")

	# BOSS 蓄力：7 秒蓄力后一击 3 倍
	battle.level_id = "CH0-B01"
	battle.restart_battle()
	var boss = battle.board["enemy"][1][1]
	assert(String(boss.card_id) == "boss_referee", "boss is the custom referee unit")
	assert(boss.charge_interval == 7.0, "boss has 7s charge")
	assert(boss.phases.size() == 2, "boss carries two phase thresholds")
	assert(battle.try_deploy("van_005", 4, 0, 0), "deploy a defense unit in front of the boss")
	battle.start_battle()
	boss.charge_timer = 0.01
	battle.tick(0.1)
	assert(not boss.charge_ready, "charge consumed on attack")
	assert(battle.board["player"][0][0] == null, "charged hit deals 42 and kills the 33 hp defender")

	# BOSS 阶段：65% 破防、30% 压制
	battle.restart_battle()
	var boss_unit = battle._create_unit("boss_referee", "enemy", 1, 1)
	_clear_boards(battle)
	battle.board["enemy"][1][1] = boss_unit
	var phase_guard = battle._create_unit("van_005", "player", 1, 0)
	battle.board["player"][1][0] = phase_guard
	battle.start_battle()
	boss_unit.hp = int(boss_unit.max_hp * 0.6)
	battle.tick(0.05)
	assert(boss_unit.phase_index == 1, "boss enters phase 2 under 65% hp")
	assert(boss_unit.damage == 13 + 1 + 4, "phase 2 adds 4 damage")
	assert(is_equal_approx(boss_unit.interval, 2.1 * 0.85), "phase 2 speeds up the attack interval")
	assert(boss_unit.ignore_taunt, "phase 2 unlocks pierce")
	boss_unit.hp = int(boss_unit.max_hp * 0.29)
	battle.tick(0.05)
	assert(boss_unit.phase_index == 2, "boss enters phase 3 under 30% hp")
	assert(boss_unit.damage == 13 + 1 + 4 + 6, "phase 3 adds 6 more damage")
	assert(boss_unit.suppress_player_regen, "phase 3 suppresses player stamina regen")
	assert(boss_unit.charge_interval == 5.0, "phase 3 shortens the charge")

	# 支线压制：体力恢复减半
	battle.level_id = "CH1-S01"
	battle.restart_battle()
	var suppressor = battle.board["enemy"][1][1]
	assert(String(suppressor.card_id) == "solo_frost", "side suppressor is the frost solo unit")
	assert(suppressor.suppress_player_regen, "suppressor has regen suppression")
	assert(battle.try_deploy("van_001", 0, 0, 0), "deploy guard for suppression test")
	battle.start_battle()
	for unit in battle._all_units():
		unit.cooldown = 999.0
	battle.enemy_reinforce_timer = -9999.0
	battle.player_stamina = 0
	battle.player_stamina_timer = 0.0
	battle.tick(10.1)
	assert(battle.player_stamina == 10, "suppressed regen is 10 per 10s")

	# 体力恢复与上限
	battle.level_id = "CH1-01"
	battle.restart_battle()
	assert(battle.try_deploy("van_001", 0, 0, 0), "deploy guard for regen test")
	battle.start_battle()
	for unit in battle._all_units():
		unit.cooldown = 999.0
	battle.enemy_reinforce_timer = -9999.0
	battle.player_stamina = 0
	battle.player_stamina_timer = 0.0
	battle.tick(10.1)
	assert(battle.player_stamina == 20, "regen is 20 per 10s")
	battle.player_stamina = 90
	battle.player_stamina_timer = 0.0
	battle.tick(10.1)
	assert(battle.player_stamina == 100, "stamina caps at 100")

	# 资源单位
	battle.player_deck_id = "aero"
	battle.restart_battle()
	var resource_index: int = battle.player_hand.find("aero_005")
	assert(resource_index >= 0, "aero_005 is in opening hand")
	assert(battle.try_deploy("aero_005", resource_index, 1, 2), "deploy resource unit")
	battle.start_battle()
	for unit in battle._all_units():
		if unit.side == "enemy":
			unit.cooldown = 999.0
	battle.enemy_reinforce_timer = -9999.0
	battle.player_stamina = 0
	battle.player_stamina_timer = 0.0
	battle.tick(4.1)
	assert(battle.player_stamina == 13, "resource adds 5 on top of 2 per second regen")

	# 击破与空位
	battle.player_deck_id = "vanguard"
	battle.level_id = "CH1-01"
	battle.restart_battle()
	assert(battle.try_deploy("van_001", 0, 0, 0), "deploy killer")
	var enemy_front = battle.board["enemy"][1][1]
	enemy_front.hp = 1
	battle.start_battle()
	battle.tick(0.1)
	assert(battle.board["enemy"][1][1] == null, "dead unit leaves slot empty")
	assert(not enemy_front.alive, "dead unit is marked dead")

	# 亡语：同路第 1 条存活排承受 12 伤害，不跨路
	_clear_boards(battle)
	var bomber = battle._create_unit("van_061", "player", 1, 0)
	var bomber_victim = battle._create_unit("van_002", "enemy", 1, 1)
	var bomber_control = battle._create_unit("van_001", "enemy", 0, 0)
	battle.board["player"][1][0] = bomber
	battle.board["enemy"][1][1] = bomber_victim
	battle.board["enemy"][0][0] = bomber_control
	assert(bomber.deathrattle_damage == 12, "bomber carries a 12 damage deathrattle")
	battle._kill_unit(bomber)
	assert(battle.board["player"][1][0] == null, "bomber leaves its slot")
	assert(bomber_victim.hp == 10, "deathrattle hits the first same-lane living row")
	assert(bomber_control.hp == 22, "deathrattle does not cross lanes")

	# 前排清空后单位不移动，攻击按存活排继续
	battle.level_id = "CH1-01"
	battle.restart_battle()
	_clear_boards(battle)
	var hold_player_mid = battle._create_unit("van_001", "player", 1, 1)
	var hold_enemy_mid = battle._create_unit("van_001", "enemy", 1, 1)
	battle.board["player"][1][1] = hold_player_mid
	battle.board["enemy"][1][1] = hold_enemy_mid
	battle.start_battle()
	battle.enemy_reinforce_timer = -9999.0
	var hold_player_hp: int = hold_player_mid.hp
	var hold_enemy_hp: int = hold_enemy_mid.hp
	battle.tick(0.1)
	assert(battle.board["player"][1][1] == hold_player_mid, "player unit keeps its slot when the front row is empty")
	assert(battle.board["enemy"][1][1] == hold_enemy_mid, "enemy unit keeps its slot when the front row is empty")
	assert(hold_player_mid.row == 1, "player unit does not advance")
	assert(hold_enemy_mid.row == 1, "enemy unit does not advance")
	assert(hold_enemy_mid.hp < hold_enemy_hp, "player unit hits the enemy's front-most living row")
	assert(hold_player_mid.hp < hold_player_hp, "enemy unit hits our front-most living row")

	# 突然死亡：全场单位每 2 秒 -2
	battle.level_id = "CH1-01"
	battle.restart_battle()
	assert(battle.try_deploy("van_001", 0, 0, 0), "deploy unit for sudden death test")
	battle.start_battle()
	var player_front = battle.board["player"][0][0]
	var sudden_enemy = battle.board["enemy"][1][1]
	var player_hp_before: int = player_front.hp
	var enemy_hp_before: int = sudden_enemy.hp
	for unit in battle._all_units():
		unit.cooldown = 999.0
	battle.battle_time = 89.999
	battle.tick(0.1)
	assert(battle.sudden_death_active, "sudden death activates at 90s")
	assert(player_front.hp == player_hp_before, "activation itself deals no damage")
	battle.tick(2.1)
	assert(player_front.hp == player_hp_before - 2, "sudden death damages player units")
	assert(sudden_enemy.hp == enemy_hp_before - 2, "sudden death damages enemy units")

	# 手牌循环
	battle.player_deck_id = "vanguard"
	battle.level_id = "CH1-01"
	battle.restart_battle()
	var slots := [[0, 0], [0, 1], [0, 2], [1, 0], [1, 1]]
	for slot in slots:
		var card_id := String(battle.player_hand[0])
		assert(battle.try_deploy(card_id, 0, int(slot[0]), int(slot[1])), "cycle deploy")
	assert(battle.player_hand.size() == 5, "hand stays at 5")
	var total_cards: int = battle.player_hand.size() + battle.player_draw_pile.size() + battle.player_discard.size()
	assert(total_cards == 12, "twelve cards stay in the cycle")

	# 单体敌人：补位被关卡上限拦住
	battle.level_id = "CH1-01"
	battle.restart_battle()
	battle.start_battle()
	battle.enemy_stamina = 100
	battle._try_enemy_reinforce()
	assert(_count_side(battle, "enemy") == 1, "single enemy level never adds a second unit")
	assert(battle.enemy_stamina == 100, "blocked reinforcement spends no enemy stamina")

	# 调整阵型：移动与交换（仅布阵阶段）
	battle.level_id = "CH1-01"
	battle.restart_battle()
	var move_index: int = battle.player_hand.find("van_001")
	assert(battle.try_deploy("van_001", move_index, 0, 0), "deploy unit to move")
	var swap_index: int = battle.player_hand.find("van_002")
	assert(battle.try_deploy("van_002", swap_index, 1, 1), "deploy unit to swap")
	assert(battle.try_move_unit(0, 0, 2, 2), "move deployed unit to empty slot")
	assert(battle.board["player"][0][0] == null, "source slot cleared after move")
	assert(String(battle.board["player"][2][2].card_id) == "van_001", "unit moved to target slot")
	assert(battle.board["player"][2][2].lane == 2, "moved unit lane updated")
	assert(battle.board["player"][2][2].row == 2, "moved unit row updated")
	assert(battle.try_move_unit(2, 2, 1, 1), "move onto occupied slot swaps")
	assert(String(battle.board["player"][2][2].card_id) == "van_002", "swap moves other unit back")
	assert(String(battle.board["player"][1][1].card_id) == "van_001", "swap moves unit forward")
	battle.select_card(0)
	assert(battle.slot_views["player"][0][0].placeable, "player slots highlight when a card is selected")
	assert(not battle.slot_views["enemy"][0][0].placeable, "enemy slots never highlight")
	battle.select_card(0)
	assert(not battle.slot_views["player"][0][0].placeable, "highlight clears when selection is cancelled")
	battle.start_battle()
	assert(not battle.try_move_unit(1, 1, 0, 0), "cannot adjust formation after battle starts")
	assert(String(battle.board["player"][1][1].card_id) == "van_001", "blocked move leaves board unchanged")

	# 攻击顺序：从前往后排
	battle.restart_battle()
	var order_back: int = battle.player_hand.find("van_002")
	assert(battle.try_deploy("van_002", order_back, 0, 2), "deploy back-row unit first")
	var order_front: int = battle.player_hand.find("van_001")
	assert(battle.try_deploy("van_001", order_front, 0, 0), "deploy front-row unit second")
	var first_player_unit = null
	for unit in battle._all_units():
		if unit.side == "player":
			first_player_unit = unit
			break
	assert(first_player_unit != null, "player units exist for order test")
	assert(int(first_player_unit.row) == 0, "front-row unit acts before back-row unit")

	# 空场判胜：敌方空场 3 秒（单体关卡击杀即胜）
	battle.level_id = "CH1-01"
	battle.restart_battle()
	assert(battle.try_deploy("van_001", 0, 0, 0), "deploy guard for empty-enemy test")
	battle.start_battle()
	for lane in range(3):
		for row in range(3):
			battle.board["enemy"][lane][row] = null
	battle.enemy_reinforce_timer = -9999.0
	battle.tick(1.0)
	battle._refresh_dynamic_ui()
	assert(battle.empty_warning_panel.visible, "warning shows while enemy board is empty")
	assert(battle.empty_warning_title.text == "敌方场上无单位", "warning names the empty side")
	assert(battle.empty_warning_hint.text == "倒计时结束获胜", "warning states the win")
	assert(battle.empty_warning_count.text == "2.0", "warning counts down")
	battle.tick(1.9)
	assert(String(battle.phase) == "battle", "empty enemy board within 3s is not a win")
	battle.tick(0.2)
	assert(String(battle.phase) == "won", "empty enemy board for 3s wins")
	assert(String(battle.end_reason) == "敌方场上无单位超过 3 秒", "win records empty-field reason")
	battle._refresh_dynamic_ui()
	assert(not battle.empty_warning_panel.visible, "warning hides when the battle ends")

	# 空场判负：我方空场 3 秒
	battle.level_id = "CH0-01"
	battle.restart_battle()
	battle.start_battle()
	battle.tick(1.0)
	battle._refresh_dynamic_ui()
	assert(battle.empty_warning_panel.visible, "warning shows while player board is empty")
	assert(battle.empty_warning_title.text == "我方场上无单位", "warning names our empty side")
	assert(battle.empty_warning_hint.text == "倒计时结束判负", "warning states the loss")
	assert(battle.empty_warning_count.text == "2.0", "warning counts down for the player")
	battle.tick(1.9)
	assert(String(battle.phase) == "battle", "empty player board within 3s is not a loss")
	battle.tick(0.2)
	assert(String(battle.phase) == "lost", "empty player board for 3s loses")
	assert(String(battle.end_reason) == "场上无单位超过 3 秒", "loss records empty-field reason")
	battle._refresh_dynamic_ui()
	assert(not battle.empty_warning_panel.visible, "warning hides after the loss")

	# 空场计时在部署后归零
	battle.restart_battle()
	battle.start_battle()
	battle.tick(2.0)
	assert(battle.player_empty_timer > 1.9, "empty timer accumulates")
	assert(battle.try_deploy("van_001", 0, 0, 0), "deploy unit mid-battle")
	battle.tick(0.1)
	assert(battle.player_empty_timer == 0.0, "empty timer resets after deploy")
	assert(String(battle.phase) == "battle", "deployed side stays in battle")

	# 双方同时空场：按空场时间判定，同时空场则我方胜
	battle.level_id = "CH1-01"
	battle.restart_battle()
	battle.start_battle()
	for side in ["player", "enemy"]:
		for lane in range(3):
			for row in range(3):
				battle.board[side][lane][row] = null
	battle.enemy_reinforce_timer = -9999.0
	battle.tick(1.0)
	battle._refresh_dynamic_ui()
	assert(battle.empty_warning_title.text == "双方场上均无单位", "warning names the simultaneous empty")
	assert(battle.empty_warning_hint.text == "同时空场我方获胜", "warning explains the tie-break")
	battle.tick(2.1)
	assert(String(battle.phase) == "won", "simultaneous empty boards favor the player")

	# 体力归零不判负
	battle.level_id = "CH1-01"
	battle.restart_battle()
	assert(battle.try_deploy("van_001", 0, 0, 0), "deploy guard for zero-stamina test")
	battle.start_battle()
	battle.player_stamina = 0
	battle.tick(0.2)
	assert(String(battle.phase) == "battle", "zero stamina alone does not end the battle")

	# 失败后可立即重新布阵
	battle.level_id = "CH0-01"
	battle.restart_battle()
	battle.start_battle()
	battle.tick(3.1)
	assert(String(battle.phase) == "lost", "empty board loses the match")
	battle._refresh_dynamic_ui()
	assert(not battle.start_button.disabled, "start button stays enabled after a loss")
	battle.restart_battle()
	assert(String(battle.phase) == "deploy", "restart returns to deploy after a loss")
	var retry_index: int = battle.player_hand.find("van_001")
	assert(retry_index >= 0, "van_001 is in the post-restart hand")
	assert(battle.try_deploy("van_001", retry_index, 0, 0), "deploy works after restart")

	# 一键布阵：只填空位，保留已上阵单位
	battle.level_id = "CH1-01"
	battle.player_deck_id = "vanguard"
	battle.shuffle_on_reshuffle = true
	battle.restart_battle()
	var manual_index: int = battle.player_hand.find("van_005")
	assert(manual_index >= 0, "van_005 is in the opening hand")
	assert(battle.try_deploy("van_005", manual_index, 0, 0), "manual deploy before auto deploy")
	var manual_unit = battle.board["player"][0][0]
	var manual_hp: int = manual_unit.hp
	var manual_stamina: int = battle.player_stamina
	var auto_count: int = battle.auto_deploy_formation()
	assert(auto_count > 0, "auto deploy places units")
	assert(battle.board["player"][0][0] == manual_unit, "auto deploy keeps existing units")
	assert(manual_unit.hp == manual_hp, "auto deploy leaves existing units untouched")
	assert(_count_side(battle, "player") == 9, "auto deploy fills the player board")
	assert(battle.player_stamina < manual_stamina, "auto deploy spends stamina")
	assert(battle.player_hand.size() == 5, "auto deploy keeps the hand at 5")
	var auto_cards: int = battle.player_hand.size() + battle.player_draw_pile.size() + battle.player_discard.size()
	assert(auto_cards == 12, "auto deploy keeps the twelve-card cycle")
	assert(String(battle.phase) == "deploy", "auto deploy stays in the deploy phase")
	battle.start_battle()
	var battle_count: int = _count_side(battle, "player")
	var battle_stamina: int = battle.player_stamina
	assert(battle.auto_deploy_formation() == 0, "auto deploy is rejected during battle")
	assert(_count_side(battle, "player") == battle_count, "rejected auto deploy changes no units")
	assert(battle.player_stamina == battle_stamina, "rejected auto deploy spends no stamina")

	# 12 卡扩展机制接线
	battle.player_deck_id = "vanguard"
	battle.level_id = "CH1-01"
	battle.restart_battle()
	var messenger = battle._create_unit("van_056", "player", 0, 2)
	assert(messenger.resource_interval == 3.0, "per-card resource interval is wired")
	assert(messenger.resource_amount == 3, "per-card resource amount is wired")
	battle.player_stamina = 50
	battle._create_unit("aero_039", "player", 0, 0)
	assert(battle.player_stamina == 54, "deploy stamina is granted on creation")
	var moss = battle._create_unit("aero_029", "player", 1, 0)
	assert(moss.regen_amount == 2, "regen amount is wired")
	var battery = battle._create_unit("bas_010", "player", 0, 2)
	assert(battle._effective_damage(battery) == 12, "back-row bonus adds damage")
	var mortar = battle._create_unit("bas_012", "player", 0, 0)
	var healthy_target = battle._create_unit("van_005", "enemy", 0, 0)
	assert(battle._effective_damage(mortar, healthy_target) == 18, "healthy-target bonus adds damage")
	var siege_guard = battle._create_unit("van_005", "player", 0, 0)
	battle.board["player"][0][0] = siege_guard
	var siege = battle._create_unit("bas_013", "player", 0, 2)
	assert(battle._effective_damage(siege) == 20, "taunt-front bonus adds damage")

	# 光环叠加：同路前后相邻排的战术单位同时生效
	battle.restart_battle()
	_clear_boards(battle)
	var aura_mid = battle._create_unit("van_001", "player", 1, 1)
	var aura_front = battle._create_unit("van_006", "player", 1, 0)
	var aura_back = battle._create_unit("aero_048", "player", 1, 2)
	var aura_other_lane = battle._create_unit("aero_006", "player", 0, 0)
	var aura_isolated = battle._create_unit("van_001", "player", 2, 1)
	battle.board["player"][1][1] = aura_mid
	battle.board["player"][1][0] = aura_front
	battle.board["player"][1][2] = aura_back
	battle.board["player"][0][0] = aura_other_lane
	battle.board["player"][2][1] = aura_isolated
	assert(battle._tactic_bonus_for(aura_mid) == 6, "adjacent auras from both neighbouring rows stack")
	assert(battle._tactic_bonus_for(aura_isolated) == 0, "auras do not cross lanes")

	# 资源单位软上限：同方只有最早部署的 2 个产费
	battle.restart_battle()
	_clear_boards(battle)
	var res_first = battle._create_unit("aero_005", "player", 0, 2)
	var res_second = battle._create_unit("aero_034", "player", 1, 2)
	var res_third = battle._create_unit("aero_039", "player", 2, 2)
	battle.board["player"][0][2] = res_first
	battle.board["player"][1][2] = res_second
	battle.board["player"][2][2] = res_third
	# 双方各留一个前排单位，避免空场判负提前结束战斗
	var res_guard = battle._create_unit("van_005", "player", 0, 0)
	battle.board["player"][0][0] = res_guard
	var res_enemy = battle._create_unit("van_005", "enemy", 0, 0)
	battle.board["enemy"][0][0] = res_enemy
	battle.start_battle()
	for unit in battle._all_units():
		unit.cooldown = 999.0
	battle.enemy_reinforce_timer = -9999.0
	battle.player_stamina = 0
	battle.player_stamina_timer = 0.0
	battle.tick(4.1)
	assert(not res_first.resource_capped, "first resource unit keeps producing")
	assert(not res_second.resource_capped, "second resource unit keeps producing")
	assert(res_third.resource_capped, "third resource unit is capped")
	assert(battle.player_stamina == 19, "capped resource unit grants no stamina: %d" % battle.player_stamina)

	battle.queue_free()
	print("formation smoke ok")
	quit()


func _clear_boards(battle) -> void:
	for side in ["player", "enemy"]:
		for lane in range(3):
			for row in range(3):
				battle.board[side][lane][row] = null


func _count_side(battle, side: String) -> int:
	var count := 0
	for lane in range(3):
		for row in range(3):
			if battle.board[side][lane][row] != null:
				count += 1
	return count
