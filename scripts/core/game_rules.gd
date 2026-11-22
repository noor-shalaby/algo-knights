class_name GameRules
extends RefCounted

static func get_legal_actions(state: BoardState, team: int) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []

	for u: Dictionary in state.units:
		if u["team"] != team or u["hp"] <= 0:
			continue

		var origin: Vector2i = u["pos"]
		var move_pts: int = u.get("move_pts", 2)
		var atk_range: int = u.get("range", 1)

		var reachable: Dictionary = Pathfinder.get_reachable_tiles(state, origin, move_pts, u["id"])

		for tile: Vector2i in reachable.keys():
			if tile != origin:
				actions.append({
					"unit_id": u["id"],
					"move_to": tile,
					"move_cost": reachable[tile],
				})

			for enemy: Dictionary in state.units:
				if enemy["team"] == team or enemy["hp"] <= 0:
					continue
				var dist: int = abs(tile.x - enemy["pos"].x) + abs(tile.y - enemy["pos"].y)
				if dist <= atk_range:
					actions.append({
						"unit_id": u["id"],
						"move_to": tile,
						"move_cost": reachable[tile],
						"target_id": enemy["id"],
					})

	return actions

static func apply_action(state: BoardState, act: Dictionary) -> void:
	var attacker: Dictionary = {}
	for u: Dictionary in state.units:
		if u["id"] == act["unit_id"]:
			attacker = u
			break

	if attacker.is_empty():
		return

	attacker["pos"] = act["move_to"]

	if act.has("target_id"):
		for enemy: Dictionary in state.units:
			if enemy["id"] == act["target_id"] and enemy["hp"] > 0:
				enemy["hp"] -= attacker["atk"]
				break

	state.current_team = 1 - state.current_team

static func is_terminal(state: BoardState) -> bool:
	var team0_alive: bool = false
	var team1_alive: bool = false

	for u: Dictionary in state.units:
		if u["hp"] > 0:
			if u["team"] == 0:
				team0_alive = true
			elif u["team"] == 1:
				team1_alive = true

	return not (team0_alive and team1_alive)

static func get_winner(state: BoardState) -> int:
	var team0_hp: int = 0
	var team1_hp: int = 0

	for u: Dictionary in state.units:
		if u["hp"] > 0:
			if u["team"] == 0:
				team0_hp += u["hp"]
			elif u["team"] == 1:
				team1_hp += u["hp"]

	if team0_hp > 0 and team1_hp <= 0:
		return 0
	if team1_hp > 0 and team0_hp <= 0:
		return 1
	return -1

static func evaluate(state: BoardState, ai_team: int = 1) -> float:
	var ai_score: float = 0.0
	var human_score: float = 0.0

	for u: Dictionary in state.units:
		if u["hp"] <= 0:
			continue
		var val: float = float(u["hp"]) * 10.0 + float(u["atk"]) * 15.0
		if u["team"] == ai_team:
			ai_score += val
		else:
			human_score += val

	return ai_score - human_score
