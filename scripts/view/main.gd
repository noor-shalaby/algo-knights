extends Node2D

@onready var board_view: BoardView = $BoardView
@onready var turn_label: Label = %TurnLabel
@onready var end_turn_button: Button = %EndTurnButton
@onready var algo_option: OptionButton = %AlgoOption
@onready var new_map_button: Button = %NewMapButton
@onready var stats_label: Label = %StatsLabel

var state: BoardState
var ai: MinimaxAI = MinimaxAI.new()
var selected_unit_id: int = -1
var is_busy: bool = false

func _ready() -> void:
	ai.max_depth = 3
	ai.ai_team = 1

	algo_option.clear()
	algo_option.add_item("astar")
	algo_option.add_item("ucs")
	algo_option.add_item("greedy")

	board_view.tile_clicked.connect(_on_tile_clicked)
	new_map_button.pressed.connect(_start_new_match)
	end_turn_button.pressed.connect(_end_player_turn)

	_start_new_match()

func _get_search_mode() -> String:
	return algo_option.get_item_text(algo_option.selected)

func _start_new_match() -> void:
	is_busy = false
	selected_unit_id = -1

	state = CSPGenerator.generate_map(8, 8, 8, 6)
	var spawn_a: Vector2i = state.get_meta("spawn_a", Vector2i(0, 0))
	var spawn_b: Vector2i = state.get_meta("spawn_b", Vector2i(7, 7))

	state.units = [
		{"id": 1, "team": 0, "pos": spawn_a, "hp": 30, "max_hp": 30, "atk": 10},
		{"id": 2, "team": 0, "pos": _find_adjacent_open(state, spawn_a), "hp": 25, "max_hp": 25, "atk": 8},
		{"id": 3, "team": 1, "pos": spawn_b, "hp": 30, "max_hp": 30, "atk": 10},
		{"id": 4, "team": 1, "pos": _find_adjacent_open(state, spawn_b), "hp": 25, "max_hp": 25, "atk": 8},
	]

	board_view.render_terrain(state)
	var board_px_size := Vector2(state.width * 16, state.height * 16)
	var viewport_size := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)
	board_view.position = (viewport_size - board_px_size) * 0.5
	board_view.rebuild_units(state)
	board_view.clear_overlays()
	_refresh_turn_ui()

func _find_adjacent_open(board: BoardState, origin: Vector2i) -> Vector2i:
	for d in Pathfinder.DIRS:
		var candidate: Vector2i = origin + d
		if board.is_inside(candidate) and board.get_terrain_cost(candidate) > 0 and board.get_unit_at(candidate).is_empty():
			return candidate
	return origin

func _on_tile_clicked(grid_pos: Vector2i) -> void:
	if is_busy or state.current_team != 0 or GameRules.is_terminal(state):
		return
	if not state.is_inside(grid_pos):
		return

	var clicked_unit: Dictionary = state.get_unit_at(grid_pos)

	# Select a friendly unit
	if not clicked_unit.is_empty() and clicked_unit["team"] == 0:
		selected_unit_id = clicked_unit["id"]
		_show_unit_options(clicked_unit)
		return

	# Execute move or attack for currently selected unit
	if selected_unit_id != -1:
		var unit: Dictionary = _get_unit_by_id(selected_unit_id)
		if unit.is_empty() or unit["hp"] <= 0:
			return

		var actions: Array[Dictionary] = GameRules.get_legal_actions(state, 0)
		for act in actions:
			if act["unit_id"] != selected_unit_id:
				continue

			var is_attack_click: bool = act.has("target_id") and _get_unit_pos(act["target_id"]) == grid_pos
			var is_move_click: bool = not act.has("target_id") and act["move_to"] == grid_pos

			if is_attack_click or is_move_click:
				await _execute_player_action(unit, act)
				return

func _show_unit_options(unit: Dictionary) -> void:
	board_view.clear_overlays()
	var moves: Array[Vector2i] = []
	var attacks: Array[Vector2i] = []
	var mode: String = _get_search_mode()
	var last_stats := {}

	for act in GameRules.get_legal_actions(state, 0):
		if act["unit_id"] != unit["id"]:
			continue
		if act.has("target_id"):
			attacks.append(_get_unit_pos(act["target_id"]))
		else:
			moves.append(act["move_to"])
			last_stats = Pathfinder.find_path(state, unit["pos"], act["move_to"], mode)

	board_view.highlight_moves(moves)
	board_view.highlight_attacks(attacks)

	if not last_stats.is_empty():
		stats_label.text = "Path (%s) | cost: %d | expanded: %d" % [
			mode, last_stats["cost"], last_stats["nodes_expanded"]
		]

func _execute_player_action(unit: Dictionary, act: Dictionary) -> void:
	is_busy = true
	board_view.clear_overlays()

	var mode: String = _get_search_mode()
	var path_res: Dictionary = Pathfinder.find_path(state, unit["pos"], act["move_to"], mode)
	var u_view: UnitView = board_view.get_unit_view(unit["id"])
	if u_view != null and path_res["found"]:
		await u_view.move_along_path(path_res["path"], board_view.terrain_layer)

	GameRules.apply_action(state, act)
	board_view.sync_units(state)
	selected_unit_id = -1

	if GameRules.is_terminal(state):
		turn_label.text = "Match Over!"
		is_busy = false
		return

	# After player acts, pass turn to AI
	state.current_team = 1
	_refresh_turn_ui()
	await _run_ai_turn()

func _end_player_turn() -> void:
	if is_busy or state.current_team != 0 or GameRules.is_terminal(state):
		return
	selected_unit_id = -1
	board_view.clear_overlays()
	state.current_team = 1
	_refresh_turn_ui()
	await _run_ai_turn()

func _run_ai_turn() -> void:
	is_busy = true
	turn_label.text = "AI Thinking..."
	await get_tree().process_frame

	var decision: Dictionary = ai.choose_action(
		state,
		GameRules.get_legal_actions,
		GameRules.apply_action,
		GameRules.evaluate,
		GameRules.is_terminal
	)

	var chosen_act: Dictionary = decision["action"]
	stats_label.text = "Minimax | score: %.1f | nodes: %d" % [decision["score"], decision["nodes"]]

	if not chosen_act.is_empty():
		var actor: Dictionary = _get_unit_by_id(chosen_act["unit_id"])
		if not actor.is_empty():
			var path_res: Dictionary = Pathfinder.find_path(state, actor["pos"], chosen_act["move_to"], _get_search_mode())
			var u_view: UnitView = board_view.get_unit_view(actor["id"])
			if u_view != null and path_res["found"]:
				board_view.highlight_path(path_res["path"])
				await u_view.move_along_path(path_res["path"], board_view.terrain_layer)

		GameRules.apply_action(state, chosen_act)
		board_view.sync_units(state)
		board_view.clear_overlays()

	if GameRules.is_terminal(state):
		turn_label.text = "Match Over!"
		is_busy = false
		return

	state.current_team = 0
	is_busy = false
	_refresh_turn_ui()

func _refresh_turn_ui() -> void:
	if state.current_team == 0:
		turn_label.text = "Player Turn (Team 0)"
	else:
		turn_label.text = "AI Turn (Team 1)"

func _get_unit_by_id(uid: int) -> Dictionary:
	for u in state.units:
		if u["id"] == uid:
			return u
	return {}

func _get_unit_pos(uid: int) -> Vector2i:
	var u := _get_unit_by_id(uid)
	return u.get("pos", Vector2i(-1, -1))
