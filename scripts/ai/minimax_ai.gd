class_name MinimaxAI
extends RefCounted

var max_depth: int = 3
var ai_team: int = 1
var nodes_evaluated: int = 0

func choose_action(state: BoardState, legal_actions_fn: Callable, apply_fn: Callable, eval_fn: Callable, terminal_fn: Callable) -> Dictionary:
	nodes_evaluated = 0
	var best_score: float = -INF
	var best_action: Dictionary = {}
	var actions: Array = legal_actions_fn.call(state, ai_team)
	_order_actions(actions)

	for act in actions:
		var next_state: BoardState = state.clone()
		apply_fn.call(next_state, act)
		var score := _minimax(next_state, max_depth - 1, -INF, INF, false, legal_actions_fn, apply_fn, eval_fn, terminal_fn)
		if score > best_score:
			best_score = score
			best_action = act

	return {"action": best_action, "score": best_score, "nodes": nodes_evaluated}

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
	if depth == 0 or terminal_fn.call(state):
		return eval_fn.call(state, ai_team)

	var team := ai_team if maximizing else (1 - ai_team)
	var actions: Array = legal_actions_fn.call(state, team)
	if actions.is_empty():
		return eval_fn.call(state, ai_team)

	_order_actions(actions)

	if maximizing:
		var value := -INF
		for act in actions:
			var nxt: BoardState = state.clone()
			apply_fn.call(nxt, act)
			value = max(value, _minimax(nxt, depth - 1, alpha, beta, false, legal_actions_fn, apply_fn, eval_fn, terminal_fn))
			alpha = max(alpha, value)
			if alpha >= beta:
				break # Beta cutoff
		return value
	else:
		var value := INF
		for act in actions:
			var nxt: BoardState = state.clone()
			apply_fn.call(nxt, act)
			value = min(value, _minimax(nxt, depth - 1, alpha, beta, true, legal_actions_fn, apply_fn, eval_fn, terminal_fn))
			beta = min(beta, value)
			if beta <= alpha:
				break # Alpha cutoff
		return value

func _order_actions(actions: Array) -> void:
	actions.sort_custom(func(a, b):
		var a_prio: int = 1 if a.has("target_id") else 0
		var b_prio: int = 1 if b.has("target_id") else 0
		return a_prio > b_prio
	)
