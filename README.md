# AlgoKnights
Tactical turn-based strategy game utilizing multiple algorithms covered in the course of Artificial Intelligence in year 3 of Computer Science at the FCI TU.
<br>
We've no idea what the prizes for top 5 might be but we're aiming for top 1 anyway.

---

## Algorithms & Where They Are Used

* **Constraint Satisfaction Problem (CSP) Generation (`CSPGenerator`)**
  * **Where it's used:** Map and layout generation (`main.gd` -> `CSPGenerator.generate_map(...)`) across presets (`standard`, `chokepoint`, `dense_stress`) using a match seed, paired with seeded spawn tile picking (`_create_initial_units` / `_pick_random_tiles`).
* **A\* Search (`Pathfinder` — `"astar"`)**
  * **Where it's used:** Heuristic-guided pathfinding (`main.gd` -> `Pathfinder.find_path(...)`) for unit movement and move-then-attack actions, exposing `visited`, `frontier`, `path`, cost, and expanded node counts for board overlays and step-by-step replay (`_replay_search_expansion`).
* **Uniform Cost Search / UCS (`Pathfinder` — `"ucs"`)**
  * **Where it's used:** Cost-ordered pathfinding (`main.gd` -> `Pathfinder.find_path(...)`) when UCS is selected in the algorithm dropdown, expanding lowest movement cost first across terrain (`TERRAIN_PLAIN`, `TERRAIN_FOREST`, `TERRAIN_WALL`).
* **Greedy Best-First Search (`Pathfinder` — `"greedy"`)**
  * **Where it's used:** Heuristic-driven pathfinding (`main.gd` -> `Pathfinder.find_path(...)`) when Greedy is selected, prioritizing proximity to the destination and driving the same search overlay and live telemetry (`_last_path_info`).
* **Minimax Search (`MinimaxAI`)**
  * **Where it's used:** Adversarial decision-making during the AI turn (`main.gd` -> `_run_ai_turn()` -> `minimax.choose_action(...)`) over `GameRules.get_legal_actions`, `GameRules.apply_action`, `GameRules.evaluate`, and `GameRules.is_terminal` up to a selectable search depth.
* **Alpha-Beta Pruning (`MinimaxAI.use_alpha_beta`)**
  * **Where it's used:** Search tree pruning inside `MinimaxAI` (`main.gd` toggles via `%AlphaBetaToggle`), cutting unpromising branches while reporting nodes evaluated, pruned count, and leaf count in `%StatsLabel`.
