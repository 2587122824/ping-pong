extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Variant = load("res://main.gd").new()
	root.add_child(game)
	await process_frame

	game._open_deck_view()
	assert(game.deck_view_panel.visible, "Opening the deck view should show the deck panel")
	assert(game.deck_view_summary.text.contains("12"), "The deck view should show the current deck size")
	assert(game.deck_view_rows.get_child_count() == 5, "The deck view should list each card currently in the deck")

	game.deck_view_panel.visible = false
	game._open_codex()
	assert(game.codex_panel.visible, "Opening the codex should show the codex panel")
	assert(game.codex_summary.text.contains("5 / 5"), "The codex should show all five implemented cards")
	assert(game.codex_rows.get_child_count() == 5, "The codex should list every implemented card")

	print("Collection smoke test passed")
	quit()
