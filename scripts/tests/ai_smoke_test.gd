extends SceneTree

func _initialize() -> void:
	var board := CSPGenerator.generate_map(8, 8, 6, 4, 42)
	board.units = [
		{"id": 1, "team": 0, "pos": Vector2i(0, 2), "hp": 30, "max_hp": 30, "atk": 10, "move_pts": 3, "range": 1},
		{"id": 2, "team": 0, "pos": Vector2i(0, 5), "hp": 30, "max_hp": 30, "atk": 10, "move_pts": 3, "range": 1},
		{"id": 3, "team": 1, "pos": Vector2i(7, 2), "hp": 30, "max_hp": 30, "atk": 10, "move_pts": 3, "range": 1},
		{"id": 4, "team": 1, "pos": Vector2i(7, 5), "hp": 30, "max_hp": 30, "atk": 10, "move_pts": 3, "range": 1},
	]

	for mode: String in ["astar", "ucs", "greedy"]:
		var res: Dictionary = Pathfinder.find_path(board, Vector2i(0, 2), Vector2i(7, 2), mode, 1)
		print("Mode=%s found=%s cost=%d nodes=%d len=%d" % [
			mode,
			str(res["found"]),
			res["cost"],
			res["nodes_expanded"],
			res["path"].size()
		])

	var minimax := MinimaxAI.new()
	minimax.ai_team = 1
	minimax.max_depth = 2
	var ai_out: Dictionary = minimax.choose_action(
		board,
		GameRules.get_legal_actions,
		GameRules.apply_action,
		func(s: BoardState) -> float: return GameRules.evaluate(s, 1),
		GameRules.is_terminal
	)
	print("Minimax action=%s score=%.2f nodes=%d" % [
		str(ai_out["action"]),
		ai_out["score"],
		ai_out["nodes"]
	])

	quit()
