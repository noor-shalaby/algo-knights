# AlgoKnights
Tactical turn-based strategy game utilizing multiple algorithms covered in the course of Artificial Intelligence in year 3 of Computer Science at the FCI TU.
<br><br>
We've no idea what the prizes for top 5 might be but we're aiming for top 1 anyway.

---

## Algorithms & What Each Is Used For

* **Constraint Satisfaction Problem (CSP) Generation (`CSPGenerator`)**
  * **Used for:** Building playable, balanced maps under layout constraints and presets (`standard`, `chokepoint`, `dense_stress`) from a seed so terrain and chokepoints stay fair and replayable.
* **A\* Search (`Pathfinder` — `"astar"`)**
  * **Used for:** Finding optimal paths across varied terrain costs while using a heuristic to head toward the target—balancing path cost and goal distance, with full search steps exposed for visualization.
* **Uniform Cost Search / UCS (`Pathfinder` — `"ucs"`)**
  * **Used for:** Finding the lowest-cost path purely by accumulated movement cost (ignoring goal heuristics), making it useful for comparing cost-only expansion against A\* and Greedy.
* **Greedy Best-First Search (`Pathfinder` — `"greedy"`)**
  * **Used for:** Racing toward the goal using only the heuristic estimate, trading guaranteed optimality for aggressive goal-directed expansion so you can see how shortcuts vs. terrain costs play out.
* **Minimax Search (`MinimaxAI`)**
  * **Used for:** Choosing the AI's tactical moves and attacks by looking ahead across possible future turns and evaluating board states to maximize its own advantage while anticipating player responses.
* **Alpha-Beta Pruning (`MinimaxAI.use_alpha_beta`)**
  * **Used for:** Speeding up Minimax at deeper search depths by skipping branches that cannot beat an already-found option, giving the exact same decision faster with live node, leaf, and pruned counts.
