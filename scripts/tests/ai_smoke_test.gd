extends SceneTree

func _initialize() -> void:
	var state := CSPGenerator.generate_map(8, 8, 8, 6)
	var spawn_a: Vector2i = state.get_meta("spawn_a", Vector2i(0, 0))
	var spawn_b: Vector2i = state.get_meta("spawn_b", Vector2i(7, 7))

	state.units = [
		{"id": 1, "team": 0, "pos": spawn_a, "hp": 30, "move_pts": 3, "atk": 10, "range": 1},
		{"id": 2, "team": 1, "pos": spawn_b, "hp": 30, "move_pts": 3, "atk": 10, "range": 1},
	]

	var path_res := Pathfinder.find_path(state, spawn_a, spawn_b, "astar")
	print("A* path found: ", path_res["found"], " | cost: ", path_res["cost"], " | expanded: ", path_res["nodes_expanded"])

	var ai := MinimaxAI.new()
	ai.max_depth = 3
	ai.ai_team = 1
	var decision := ai.choose_action(
		state,
		GameRules.get_legal_actions,
		GameRules.apply_action,
		GameRules.evaluate,
		GameRules.is_terminal
	)
	print("AI chose: ", decision["action"], " | score: ", decision["score"], " | nodes: ", decision["nodes"])
	quit()
