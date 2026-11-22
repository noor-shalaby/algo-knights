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
	var ai_units: Array[Dictionary] = []
	var enemy_units: Array[Dictionary] = []

	for u: Dictionary in state.units:
		if u["hp"] <= 0:
			continue
		if u["team"] == ai_team:
			ai_units.append(u)
		else:
			enemy_units.append(u)

	if enemy_units.is_empty():
		return 10000.0
	if ai_units.is_empty():
		return -10000.0

	var score: float = 0.0

	# 1. Core material strength (HP + ATK)
	for u: Dictionary in ai_units:
		score += float(u["hp"]) * 10.0 + float(u["atk"]) * 15.0
	for e: Dictionary in enemy_units:
		score -= float(e["hp"]) * 10.0 + float(e["atk"]) * 15.0

	# 2. Focus-fire / finishing reward on weakened enemies
	for e: Dictionary in enemy_units:
		var max_hp: float = float(max(1, e.get("max_hp", e["hp"])))
		var missing_ratio: float = clampf(1.0 - (float(e["hp"]) / max_hp), 0.0, 1.0)
		score += missing_ratio * 22.0

	# 3. Advance toward nearest enemy + light caution only when critically low HP
	for u: Dictionary in ai_units:
		var pos: Vector2i = u["pos"]
		var min_dist: int = 999999
		var adjacent_threats: int = 0

		for e: Dictionary in enemy_units:
			var e_pos: Vector2i = e["pos"]
			var dist: int = abs(pos.x - e_pos.x) + abs(pos.y - e_pos.y)
			if dist < min_dist:
				min_dist = dist
			var atk_range: int = e.get("range", 1)
			if dist <= atk_range + e.get("move_pts", 2):
				adjacent_threats += 1

		score -= float(min_dist) * 3.5

		var max_hp: float = float(max(1, u.get("max_hp", u["hp"])))
		var hp_ratio: float = clampf(float(u["hp"]) / max_hp, 0.0, 1.0)
		if adjacent_threats > 0 and hp_ratio < 0.35:
			score -= float(adjacent_threats) * (1.0 - hp_ratio) * 5.0

	return score
