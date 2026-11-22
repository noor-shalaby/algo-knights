class_name GameRules
extends RefCounted

static func get_legal_actions(state: BoardState, team: int) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	for u in state.units:
		if u["hp"] <= 0 or u["team"] != team:
			continue
		var origin: Vector2i = u["pos"]
		# Check orthogonal neighbors for simple move or attack
		for d in Pathfinder.DIRS:
			var target_pos: Vector2i = origin + d
			if not state.is_inside(target_pos) or state.get_terrain_cost(target_pos) < 0:
				continue
			var occupant: Dictionary = state.get_unit_at(target_pos)
			if occupant.is_empty():
				actions.append({"unit_id": u["id"], "move_to": target_pos})
			elif occupant["team"] != team:
				actions.append({"unit_id": u["id"], "move_to": origin, "target_id": occupant["id"]})
	return actions

static func apply_action(state: BoardState, act: Dictionary) -> void:
	for u in state.units:
		if u["id"] == act.get("unit_id", -1) and u["hp"] > 0:
			u["pos"] = act["move_to"]
			if act.has("target_id"):
				for enemy in state.units:
					if enemy["id"] == act["target_id"] and enemy["hp"] > 0:
						enemy["hp"] -= u["atk"]
						break
			break
	state.current_team = 1 - state.current_team

static func evaluate(state: BoardState, ai_team: int) -> float:
	var score := 0.0
	for u in state.units:
		if u["hp"] <= 0:
			continue
		var unit_val := float(u["hp"]) * 10.0 + float(u["atk"]) * 15.0
		if u["team"] == ai_team:
			score += unit_val
		else:
			score -= unit_val
	return score

static func is_terminal(state: BoardState) -> bool:
	var team0_alive := false
	var team1_alive := false
	for u in state.units:
		if u["hp"] > 0:
			if u["team"] == 0:
				team0_alive = true
			else:
				team1_alive = true
	return not (team0_alive and team1_alive)
