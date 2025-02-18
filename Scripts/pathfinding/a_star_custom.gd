extends AStar2D

class_name AStar2DCustom

# Inline everything to make it as fast as possible
func _compute_cost(a: int, b: int) -> float:
	return Graph.edges_to_cost_map[int(((a + b) * ((a + b) + 1)) / 2.0) + b]

