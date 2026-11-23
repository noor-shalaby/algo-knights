class_name MinimaxAI
extends RefCounted

var ai_team: int = 1
var max_depth: int = 3
var use_alpha_beta: bool = true
var nodes_evaluated: int = 0
var pruned_branches: int = 0
var leaf_evaluations: int = 0

func choose_action(
	state: BoardState,
	legal_actions_fn: Callable,
	apply_fn: Callable,
	eval_fn: Callable,
	terminal_fn: Callable
) -> Dictionary:
	nodes_evaluated = 0
	pruned_branches = 0
	leaf_evaluations = 0

	var best_score: float = -INF
	var best_action: Dictionary = {}

	var actions: Array = legal_actions_fn.call(state, ai_team)
	if actions.is_empty():
		leaf_evaluations += 1
		return {
			"action": {},
			"score": _call_eval(eval_fn, state),
			"nodes": nodes_evaluated,
			"pruned": pruned_branches,
			"leaves": leaf_evaluations,
		}

	_order_actions(actions)

	var alpha: float = -INF
	var beta: float = INF

	for act: Dictionary in actions:
		var next_state: BoardState = state.clone()
		apply_fn.call(next_state, act)
		var score: float = _minimax(
			next_state,
			max_depth - 1,
			alpha,
			beta,
			false,
			legal_actions_fn,
			apply_fn,
			eval_fn,
			terminal_fn
		)
		if score > best_score:
			best_score = score
			best_action = act
		if use_alpha_beta:
			alpha = max(alpha, best_score)

	return {
		"action": best_action,
		"score": best_score,
		"nodes": nodes_evaluated,
		"pruned": pruned_branches,
		"leaves": leaf_evaluations,
	}

func _minimax(
	state: BoardState,
	depth: int,
	alpha: float,
	beta: float,
	maximizing: bool,
	legal_actions_fn: Callable,
	apply_fn: Callable,
	eval_fn: Callable,
	terminal_fn: Callable
) -> float:
	nodes_evaluated += 1

	if depth <= 0 or terminal_fn.call(state):
		leaf_evaluations += 1
		return _call_eval(eval_fn, state)

	var acting_team: int = ai_team if maximizing else (1 - ai_team)
	var actions: Array = legal_actions_fn.call(state, acting_team)
	if actions.is_empty():
		leaf_evaluations += 1
		return _call_eval(eval_fn, state)

	_order_actions(actions)
	var total_actions: int = actions.size()

	if maximizing:
		var value: float = -INF
		for i: int in range(total_actions):
			var act: Dictionary = actions[i]
			var next_state: BoardState = state.clone()
			apply_fn.call(next_state, act)
			var child_val: float = _minimax(
				next_state,
				depth - 1,
				alpha,
				beta,
				false,
				legal_actions_fn,
				apply_fn,
				eval_fn,
				terminal_fn
			)
			value = max(value, child_val)
			if use_alpha_beta:
				alpha = max(alpha, value)
				if alpha >= beta:
					pruned_branches += maxi(0, total_actions - 1 - i)
					break
		return value
	else:
		var value: float = INF
		for i: int in range(total_actions):
			var act: Dictionary = actions[i]
			var next_state: BoardState = state.clone()
			apply_fn.call(next_state, act)
			var child_val: float = _minimax(
				next_state,
				depth - 1,
				alpha,
				beta,
				true,
				legal_actions_fn,
				apply_fn,
				eval_fn,
				terminal_fn
			)
			value = min(value, child_val)
			if use_alpha_beta:
				beta = min(beta, value)
				if beta <= alpha:
					pruned_branches += maxi(0, total_actions - 1 - i)
					break
		return value

func _order_actions(actions: Array) -> void:
	# Prioritize attack actions first so alpha-beta prunes branches earlier
	actions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_atk: int = 1 if a.has("target_id") else 0
		var b_atk: int = 1 if b.has("target_id") else 0
		if a_atk != b_atk:
			return a_atk > b_atk
		return a.get("move_cost", 0) < b.get("move_cost", 0)
	)

func _call_eval(eval_fn: Callable, state: BoardState) -> float:
	if eval_fn.get_argument_count() >= 2:
		return float(eval_fn.call(state, ai_team))
	return float(eval_fn.call(state))
