extends RefCounted

class_name  Schedule

# path between each pair of stops
var paths: Array[Path]
var is_loop: bool
var stops: Array[StopNode]:
	get:
		var stops_temp : Array[StopNode] = []
		for path : Path in paths:
			stops_temp.append(path.nodes[0])
		# Append last stop of last node
		stops_temp.append(paths[-1].nodes[-1])
		return stops_temp
	set(value):
		assert(false, "Cannot set stops")
		
func _init(stops_path_: Array[Path], is_loop_: bool) -> void:
	self.paths = stops_path_
	self.is_loop = is_loop_
	if (is_loop_):
		assert(VirtualNode.are_nodes_are_at_same_position(stops[0], stops[-1]), "A loop should have the same start and end stops")
		assert(stops_path_.size() > 1, "A loop should have at least 2 stops")

func get_path(stop_index: int) -> Path:
	return paths[stop_index]

# func add_path(path: Path) -> void:
# 	paths.append(path)

# func get_start_node() -> StopNode:
# 	if (stops.size() == 0):
# 		return null
# 	return stops[0]

# func get_end_node() -> StopNode:
# 	if (stops.size() == 0):
# 		return null
# 	return stops[-1]
