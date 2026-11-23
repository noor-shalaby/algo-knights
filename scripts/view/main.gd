extends Node2D

@onready var board_view: BoardView = $BoardView
@onready var turn_label: Label = %TurnLabel
@onready var end_turn_button: Button = %EndTurnButton
@onready var algo_option: OptionButton = %AlgoOption
@onready var new_map_button: Button = %NewMapButton
@onready var search_overlay_toggle: CheckButton = %SearchOverlayToggle
@onready var alpha_beta_toggle: CheckButton = %AlphaBetaToggle
@onready var depth_option: OptionButton = %DepthOption
@onready var seed_input: LineEdit = %SeedInput
@onready var preset_option: OptionButton = %PresetOption
@onready var seed_label: Label = %SeedLabel
@onready var stats_label: Label = %StatsLabel

const REPLAY_STEP_DELAY: float = 0.05

var state: BoardState
var minimax := MinimaxAI.new()
var selected_unit_id: int = -1
var is_busy: bool = false

var _current_seed: int = 0
var _map_preset: String = "standard"
var _replay_generation: int = 0

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

	if search_overlay_toggle != null:
		search_overlay_toggle.button_pressed = board_view.show_search_overlay
		search_overlay_toggle.toggled.connect(_on_search_overlay_toggled)

	if alpha_beta_toggle != null:
		alpha_beta_toggle.button_pressed = minimax.use_alpha_beta
		alpha_beta_toggle.toggled.connect(_on_alpha_beta_toggled)

	if depth_option != null:
		depth_option.clear()
		for d: int in [1, 2, 3, 4]:
			depth_option.add_item("Depth %d" % d, d)
		var default_idx: int = depth_option.get_item_index(minimax.max_depth)
		if default_idx >= 0:
			depth_option.select(default_idx)
		depth_option.item_selected.connect(_on_depth_selected)

	if preset_option != null:
		preset_option.clear()
		preset_option.add_item("Stndrd", 0)
		preset_option.add_item("Choke", 1)
		preset_option.add_item("Dense", 2)
		preset_option.item_selected.connect(_on_preset_selected)

	if seed_input != null:
		seed_input.text_submitted.connect(func(_new_text: String) -> void: _start_new_match())

	if seed_label != null:
		seed_label.mouse_filter = Control.MOUSE_FILTER_STOP
		seed_label.gui_input.connect(_on_seed_label_gui_input)

	_start_new_match()

func _resolve_seed() -> int:
	if seed_input != null:
		var raw: String = seed_input.text.strip_edges()
		if raw.is_valid_int():
			seed_input.text = ""
			return absi(raw.to_int())
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi()

func _unhandled_input(event: InputEvent) -> void:
	# Quick toggle ('V') to show/hide visited & frontier search overlay tiles
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V:
		var next_state: bool = not board_view.show_search_overlay
		board_view.set_search_overlay_enabled(next_state)
		if search_overlay_toggle != null:
			search_overlay_toggle.set_pressed_no_signal(next_state)
		_refresh_ui()

func _start_new_match() -> void:
	_replay_generation += 1
	is_busy = false
	selected_unit_id = -1
	_last_path_info = "Path: -"
	_last_ai_info = "AI: -"

	_current_seed = _resolve_seed()
	if seed_label != null:
		seed_label.text = " Seed: %d" % _current_seed
	if seed_input != null and seed_input.text.strip_edges().is_empty():
		seed_input.placeholder_text = "  Paste seed"

	state = CSPGenerator.generate_map(8, 8, 8, 6, _current_seed, _map_preset)
	state.units = _create_initial_units(state, _current_seed)
	state.current_team = 0

	if search_overlay_toggle != null:
		search_overlay_toggle.set_pressed_no_signal(board_view.show_search_overlay)

	board_view.render_terrain(state)
	_center_board()
	board_view.rebuild_units(state)
	board_view.clear_highlights()
	board_view.clear_search_overlay()
	_refresh_ui()

func _center_board() -> void:
	var tile_px: int = 16
	var board_px_size := Vector2(state.width * tile_px, state.height * tile_px)
	var viewport_size := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)
	board_view.position = ((viewport_size - board_px_size) * 0.5).floor()

func _create_initial_units(board: BoardState, seed_val: int = -1) -> Array:
	var rng := RandomNumberGenerator.new()
	if seed_val >= 0:
		rng.seed = seed_val
	else:
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

func _on_search_overlay_toggled(toggled_on: bool) -> void:
	board_view.set_search_overlay_enabled(toggled_on)
	_refresh_ui()

func _on_alpha_beta_toggled(toggled_on: bool) -> void:
	minimax.use_alpha_beta = toggled_on
	_refresh_ui()

func _on_depth_selected(index: int) -> void:
	if depth_option != null:
		minimax.max_depth = depth_option.get_item_id(index)
		_refresh_ui()

func _on_preset_selected(index: int) -> void:
	match index:
		1:
			_map_preset = "chokepoint"
		2:
			_map_preset = "dense_stress"
		_:
			_map_preset = "standard"
	_start_new_match()

func _on_seed_label_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		DisplayServer.clipboard_set(str(_current_seed))
		if seed_label != null:
			seed_label.text = "CP: %d" % _current_seed
			get_tree().create_timer(1.0).timeout.connect(func() -> void: if seed_label != null: seed_label.text = "Seed: %d" % _current_seed)

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

func _apply_path_visualization(origin: Vector2i, dest: Vector2i, unit_id: int) -> Dictionary:
	var path_res: Dictionary = Pathfinder.find_path(state, origin, dest, _search_mode, unit_id)
	var visited: Array = path_res.get("visited", [])
	var frontier: Array = path_res.get("frontier", [])

	if path_res.get("found", false):
		_last_path_info = "%s c:%d exp:%d vis:%d" % [
			_search_mode.to_upper(),
			path_res.get("cost", 0),
			path_res.get("nodes_expanded", 0),
			visited.size(),
		]
		board_view.highlight_search_data(visited, frontier)
		board_view.highlight_path(path_res.get("path", []))
	else:
		_last_path_info = "%s: no path (vis:%d)" % [_search_mode.to_upper(), visited.size()]
		board_view.highlight_search_data(visited, frontier)

	return path_res

func _replay_search_expansion(path_res: Dictionary) -> void:
	var visited: Array = path_res.get("visited", [])
	var frontier: Array = path_res.get("frontier", [])
	var found: bool = path_res.get("found", false)
	var cost: int = path_res.get("cost", 0)
	var total_expanded: int = path_res.get("nodes_expanded", visited.size())

	if not board_view.show_search_overlay or visited.is_empty():
		board_view.highlight_search_data(visited, frontier)
		if found:
			board_view.highlight_path(path_res.get("path", []))
		return

	_replay_generation += 1
	var gen: int = _replay_generation
	var revealed: Array[Vector2i] = []

	for i: int in range(visited.size()):
		if gen != _replay_generation:
			return
		var tile: Variant = visited[i]
		if tile is Vector2i:
			revealed.append(tile)
		var show_frontier: Array = frontier if i == visited.size() - 1 else []
		board_view.set_replay_step(revealed, show_frontier, tile if tile is Vector2i else Vector2i(-1, -1), tile is Vector2i)

		if found:
			_last_path_info = "%s c:%d step:%d/%d" % [
				_search_mode.to_upper(),
				cost,
				i + 1,
				max(1, total_expanded),
			]
		else:
			_last_path_info = "%s: searching step:%d/%d" % [
				_search_mode.to_upper(),
				i + 1,
				max(1, total_expanded),
			]
		_refresh_ui()
		await get_tree().create_timer(REPLAY_STEP_DELAY).timeout

	if gen != _replay_generation:
		return

	board_view.highlight_search_data(visited, frontier)
	if found:
		_last_path_info = "%s c:%d exp:%d vis:%d" % [
			_search_mode.to_upper(),
			cost,
			total_expanded,
			visited.size(),
		]
		board_view.highlight_path(path_res.get("path", []))
	else:
		_last_path_info = "%s: no path (vis:%d)" % [_search_mode.to_upper(), visited.size()]
	_refresh_ui()

func _execute_player_action(unit: Dictionary, act: Dictionary) -> void:
	is_busy = true
	board_view.clear_highlights()

	var origin: Vector2i = unit["pos"]
	var dest: Vector2i = act["move_to"]
	var path_res: Dictionary = _apply_path_visualization(origin, dest, unit["id"])

	_refresh_ui()
	await _replay_search_expansion(path_res)

	var u_view: UnitView = board_view.get_unit_view(unit["id"])
	if u_view != null:
		if path_res.get("found", false) and path_res["path"].size() > 1:
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
	var ai_res: Dictionary = minimax.choose_action(
		state,
		GameRules.get_legal_actions,
		GameRules.apply_action,
		func(s: BoardState) -> float: return GameRules.evaluate(s, 1),
		GameRules.is_terminal
	)

	var act: Dictionary = ai_res.get("action", {})
	var ab_tag: String = "AB" if minimax.use_alpha_beta else "NO-AB"
	_last_ai_info = "MM[%s] s:%.1f n:%d p:%d l:%d" % [
		ab_tag,
		ai_res.get("score", 0.0),
		ai_res.get("nodes", 0),
		ai_res.get("pruned", 0),
		ai_res.get("leaves", 0),
	]

	if act.is_empty():
		state.current_team = 0
		is_busy = false
		_refresh_ui()
		return

	var unit: Dictionary = _get_unit_by_id(act["unit_id"])
	var path_res: Dictionary = {}
	if not unit.is_empty() and unit["hp"] > 0:
		path_res = _apply_path_visualization(unit["pos"], act["move_to"], unit["id"])
		_refresh_ui()
		await _replay_search_expansion(path_res)

		var u_view: UnitView = board_view.get_unit_view(unit["id"])
		if u_view != null:
			if path_res.get("found", false) and path_res["path"].size() > 1:
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

	stats_label.text = "%s \n%s" % [_last_path_info, _last_ai_info]
