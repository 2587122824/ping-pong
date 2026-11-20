extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Variant = load("res://main.gd").new()
	root.add_child(game)
	await process_frame

	game._open_deck_view()
	assert(game.deck_view_panel.visible, "Opening the deck view should show the deck panel")
	assert(game.deck_view_summary.text.contains("6"), "The deck view should show the active deck size")
	assert(game.deck_view_rows.get_child_count() == 6, "The deck view should list all cards in the active deck")
	game._select_deck("badminton")
	assert(game.active_deck_id == "badminton" and game.player_deck.size() == 6, "The badminton deck should be selectable")
	assert(game.deck_view_summary.text.contains("羽毛球"), "The selected theme should be visible")
	game._select_deck("tennis")
	assert(game.player_deck.has("ten_main"), "The tennis deck should load its own themed cards")
	game._select_deck("table_tennis")

	game.deck_view_panel.visible = false
	game._open_codex()
	assert(game.codex_panel.visible, "Opening the codex should show the codex panel")
	assert(game.codex_summary.text.contains("18 / 18"), "The codex should show all eighteen themed cards")
	assert(game.codex_rows.get_child_count() == 18, "The codex should list every themed card")

	print("Collection smoke test passed")
	quit()
