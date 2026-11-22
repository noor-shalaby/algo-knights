extends Node2D

@onready var board_view: BoardView = $BoardView
@onready var turn_label: Label = %TurnLabel
@onready var algo_option: OptionButton = %AlgoOption
@onready var new_map_button: Button = %NewMapButton
@onready var end_turn_button: Button = %EndTurnButton
@onready var stats_label: Label = %StatsLabel

var state: BoardState
var minimax := MinimaxAI.new()
var selected_unit_id: int = -1
var is_busy: bool = false

var _search_mode: String = "astar"
var _last_path_info: String = "Path: -"
var _last_ai_info: String = "AI: -"

func _ready() -> void:
	algo_option.clear()
	algo_option.add_item("A*", 0)
	algo_option.add_item("UCS", 1)
	algo_option.add_item("Greedy", 2)

	algo_option.item_selected.connect(_on_algo_selected)
	new_map_button.pressed.connect(_start_new_match)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	board_view.tile_clicked.connect(_on_tile_clicked)

	_start_new_match()

func _start_new_match() -> void:
	is_busy = false
	selected_unit_id = -1
	_last_path_info = "Path: -"
	_last_ai_info = "AI: -"

	state = CSPGenerator.generate_map(8, 8, 8, 6)
	state.units = _create_initial_units(state)
	state.current_team = 0

	board_view.render_terrain(state)
	_center_board()
	board_view.rebuild_units(state)
	board_view.clear_highlights()
	_refresh_ui()

func _center_board() -> void:
	var tile_px: int = 16
	var board_px_size := Vector2(state.width * tile_px, state.height * tile_px)
	var viewport_size := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)
	board_view.position = ((viewport_size - board_px_size) * 0.5).floor()

func _create_initial_units(board: BoardState) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var left_cols: Array[int] = [0, 1]
	var right_cols: Array[int] = [max(0, board.width - 2), board.width - 1]

	var team0_spawns: Array[Vector2i] = _pick_random_tiles(board, left_cols, 2, rng, {})
	var used_tiles: Dictionary = {}
	for pos: Vector2i in team0_spawns:
		used_tiles[pos] = true

	var team1_spawns: Array[Vector2i] = _pick_random_tiles(board, right_cols, 2, rng, used_tiles)

	return [
		{
			"id": 1,
			"team": 0,
			"pos": team0_spawns[0],
			"hp": 30,
			"max_hp": 30,
			"atk": 10,
			"move_pts": 2,
			"range": 1,
		},
		{
			"id": 2,
			"team": 0,
			"pos": team0_spawns[1],
			"hp": 30,
			"max_hp": 30,
			"atk": 10,
			"move_pts": 2,
			"range": 1,
		},
		{
			"id": 3,
			"team": 1,
			"pos": team1_spawns[0],
			"hp": 30,
			"max_hp": 30,
			"atk": 10,
			"move_pts": 2,
			"range": 1,
		},
		{
			"id": 4,
			"team": 1,
			"pos": team1_spawns[1],
			"hp": 30,
			"max_hp": 30,
			"atk": 10,
			"move_pts": 2,
			"range": 1,
		},
	]

func _pick_random_tiles(
	board: BoardState,
	cols: Array[int],
	count: int,
	rng: RandomNumberGenerator,
	blocked: Dictionary
) -> Array[Vector2i]:
	var pool: Array[Vector2i] = []

	for x: int in cols:
		if x < 0 or x >= board.width:
			continue
		for y: int in range(board.height):
			var pos := Vector2i(x, y)
			if blocked.has(pos):
				continue
			if board.get_terrain_cost(pos) < 0:
				continue
			pool.append(pos)

	# Fisher-Yates shuffle
	for i: int in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp

	var chosen: Array[Vector2i] = []
	for i: int in range(min(count, pool.size())):
		chosen.append(pool[i])

	# Fallback if a map ever has too few walkable tiles in those columns
	while chosen.size() < count:
		for y: int in range(board.height):
			for x: int in range(board.width):
				var fallback := Vector2i(x, y)
				if not blocked.has(fallback) and not chosen.has(fallback) and board.get_terrain_cost(fallback) >= 0:
					chosen.append(fallback)
					if chosen.size() >= count:
						break
			if chosen.size() >= count:
				break

	return chosen

func _on_algo_selected(index: int) -> void:
	match index:
		0:
			_search_mode = "astar"
		1:
			_search_mode = "ucs"
		2:
			_search_mode = "greedy"
	_refresh_ui()

func _on_end_turn_pressed() -> void:
	if is_busy or state.current_team != 0 or GameRules.is_terminal(state):
		return
	selected_unit_id = -1
	board_view.clear_highlights()
	state.current_team = 1
	_refresh_ui()
	await _run_ai_turn()

func _on_tile_clicked(grid_pos: Vector2i) -> void:
	if is_busy or state.current_team != 0 or GameRules.is_terminal(state):
		return

	var clicked_unit: Dictionary = _get_unit_at(grid_pos)

	# Select or deselect a living friendly unit
	if not clicked_unit.is_empty() and clicked_unit["team"] == 0 and clicked_unit["hp"] > 0:
		if clicked_unit["id"] == selected_unit_id:
			selected_unit_id = -1
			board_view.clear_highlights()
			_refresh_ui()
			return

		selected_unit_id = clicked_unit["id"]
		_show_unit_options(clicked_unit)
		_refresh_ui()
		return

	# Resolve move or move-then-attack for the currently selected unit
	if selected_unit_id != -1:
		var selected_unit: Dictionary = _get_unit_by_id(selected_unit_id)
		if selected_unit.is_empty() or selected_unit["hp"] <= 0:
			selected_unit_id = -1
			board_view.clear_highlights()
			return

		var legal: Array[Dictionary] = GameRules.get_legal_actions(state, 0)
		var best_attack_act: Dictionary = {}
		var move_act: Dictionary = {}

		for act: Dictionary in legal:
			if act["unit_id"] != selected_unit_id:
				continue

			if act.has("target_id") and _get_unit_pos(act["target_id"]) == grid_pos:
				if best_attack_act.is_empty() or act.get("move_cost", 999) < best_attack_act.get("move_cost", 999):
					best_attack_act = act
			elif not act.has("target_id") and act["move_to"] == grid_pos:
				move_act = act

		if not best_attack_act.is_empty():
			await _execute_player_action(selected_unit, best_attack_act)
			return

		if not move_act.is_empty():
			await _execute_player_action(selected_unit, move_act)
			return

	# Clicking empty or non-target tiles clears selection
	selected_unit_id = -1
	board_view.clear_highlights()
	_refresh_ui()

func _show_unit_options(unit: Dictionary) -> void:
	var moves: Array[Vector2i] = []
	var attacks: Array[Vector2i] = []

	for act: Dictionary in GameRules.get_legal_actions(state, 0):
		if act["unit_id"] != unit["id"]:
			continue
		if act.has("target_id"):
			var target_pos: Vector2i = _get_unit_pos(act["target_id"])
			if not attacks.has(target_pos):
				attacks.append(target_pos)
		elif not moves.has(act["move_to"]):
			moves.append(act["move_to"])

	board_view.highlight_moves(moves)
	board_view.highlight_attacks(attacks)

func _execute_player_action(unit: Dictionary, act: Dictionary) -> void:
	is_busy = true
	board_view.clear_highlights()

	var origin: Vector2i = unit["pos"]
	var dest: Vector2i = act["move_to"]
	var path_res: Dictionary = Pathfinder.find_path(state, origin, dest, _search_mode, unit["id"])

	if path_res["found"]:
		_last_path_info = "%s c:%d n:%d" % [_search_mode.to_upper(), path_res["cost"], path_res["nodes_expanded"]]
		board_view.highlight_path(path_res["path"])
	else:
		_last_path_info = "%s: no path" % _search_mode.to_upper()

	_refresh_ui()

	var u_view: UnitView = board_view.get_unit_view(unit["id"])
	if u_view != null:
		if path_res["found"] and path_res["path"].size() > 1:
			await u_view.move_along_path(path_res["path"], board_view.terrain_layer)
		if act.has("target_id"):
			await u_view.play_attack()

	await _resolve_action_and_sync(act)

	selected_unit_id = -1
	board_view.clear_highlights()
	_refresh_ui()

	if not GameRules.is_terminal(state) and state.current_team == 1:
		await _run_ai_turn()
	else:
		is_busy = false
		_refresh_ui()

func _run_ai_turn() -> void:
	is_busy = true
	_refresh_ui()

	await get_tree().create_timer(0.25).timeout

	minimax.ai_team = 1
	minimax.max_depth = 3
	var ai_res: Dictionary = minimax.choose_action(
		state,
		GameRules.get_legal_actions,
		GameRules.apply_action,
		func(s: BoardState) -> float: return GameRules.evaluate(s, 1),
		GameRules.is_terminal
	)

	var act: Dictionary = ai_res.get("action", {})
	_last_ai_info = "MM s:%.1f n:%d" % [ai_res.get("score", 0.0), ai_res.get("nodes", 0)]

	if act.is_empty():
		state.current_team = 0
		is_busy = false
		_refresh_ui()
		return

	var unit: Dictionary = _get_unit_by_id(act["unit_id"])
	if not unit.is_empty() and unit["hp"] > 0:
		var path_res: Dictionary = Pathfinder.find_path(state, unit["pos"], act["move_to"], _search_mode, unit["id"])
		if path_res["found"]:
			_last_path_info = "%s c:%d n:%d" % [_search_mode.to_upper(), path_res["cost"], path_res["nodes_expanded"]]
			board_view.highlight_path(path_res["path"])

		_refresh_ui()

		var u_view: UnitView = board_view.get_unit_view(unit["id"])
		if u_view != null:
			if path_res["found"] and path_res["path"].size() > 1:
				await u_view.move_along_path(path_res["path"], board_view.terrain_layer)
			if act.has("target_id"):
				await u_view.play_attack()

	await _resolve_action_and_sync(act)

	board_view.clear_highlights()
	is_busy = false
	_refresh_ui()

func _resolve_action_and_sync(act: Dictionary) -> void:
	var target_id: int = act.get("target_id", -1)
	GameRules.apply_action(state, act)

	if target_id != -1:
		var target_data: Dictionary = _get_unit_by_id(target_id)
		var target_view: UnitView = board_view.get_unit_view(target_id)
		if not target_data.is_empty() and target_view != null:
			target_view.hp_bar.value = max(0, target_data["hp"])
			if target_data["hp"] > 0:
				await target_view.play_hit_impact(1.5, 0.14)
			else:
				await target_view.play_hit_impact(2.0, 0.12)
				await target_view.play_die()

	board_view.sync_units(state)

func _get_unit_at(pos: Vector2i) -> Dictionary:
	for u: Dictionary in state.units:
		if u["hp"] > 0 and u["pos"] == pos:
			return u
	return {}

func _get_unit_by_id(unit_id: int) -> Dictionary:
	for u: Dictionary in state.units:
		if u["id"] == unit_id:
			return u
	return {}

func _get_unit_pos(unit_id: int) -> Vector2i:
	var u: Dictionary = _get_unit_by_id(unit_id)
	return u.get("pos", Vector2i(-1, -1))

func _refresh_ui() -> void:
	if GameRules.is_terminal(state):
		var winner: int = GameRules.get_winner(state)
		turn_label.text = "P0 Wins!" if winner == 0 else ("AI Wins!" if winner == 1 else "Draw!")
		end_turn_button.disabled = true
	else:
		turn_label.text = "P0 Turn" if state.current_team == 0 else "AI Turn"
		end_turn_button.disabled = is_busy or state.current_team != 0

	stats_label.text = "%s\n%s" % [_last_path_info, _last_ai_info]
