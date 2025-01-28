extends Object

class_name Pathfinder

class PathfindingPreference:
	var choose_start_stop: bool
	var chose_end_stop: bool
	var start_forward: bool
	var end_forward: bool

	func _init(
		p_choose_start_stop: bool, 
		p_chose_end_stop: bool, 
		p_start_forward: bool, 
		p_end_forward: bool
	) -> void:
		self.choose_start_stop = p_choose_start_stop
		self.chose_end_stop = p_chose_end_stop
		self.start_forward = p_start_forward
		self.end_forward = p_end_forward
		


func _init() -> void:
	assert(false, "This class only has static functions, don't instantiate it!")


# Note that "forward" and "backward" only really apply to the starting position of the train
# We can't know what the "forward" and "backward" direction is of any intermediate stops
static func find_path_with_movement(
	train: Train, 
	can_move_forward: bool, 
	can_move_backwards: bool, 
	connect_to_start: bool
) -> Schedule:
	var stop_options: Array[StopOption] = train.get_stop_options()
	if (stop_options.size() == 0):
		return null
	if (can_move_forward and can_move_backwards):
		if (connect_to_start):
			stop_options.append(stop_options[0])
		return find_path(train.name, stop_options)
	elif (can_move_forward):
		# only allow the forward node as the first stop
		stop_options[0] = StopOption.new([stop_options[0].get_forward_node()])
		# If we want to connect it back to the start, we add the first node and 
		if (connect_to_start):
			stop_options.append(stop_options[0]) # This will automatically already have only the forward node
		return find_path(train.name, stop_options)
	elif (can_move_backwards):
		# only allow the backward node as the first and last stop
		stop_options[0] = StopOption.new([stop_options[0].get_backward_node()])
		if (connect_to_start):
			stop_options.append(stop_options[0]) # This will automatically already have only the backward node
		return find_path(train.name, stop_options)
	else:
		assert(false, "We should never get here")
		return null

static func find_path(train_uuid: String, stop_options: Array[StopOption]) -> Schedule:
	var dynamnic_programming: Dictionary = {}
	for i: int in range(stop_options.size() - 1):
		var current_stop_options: StopOption = stop_options[i]
		var next_stop_options: StopOption = stop_options[i + 1]

		for start_node: StopNode in current_stop_options.stop_option:
			for end_node: StopNode in next_stop_options.stop_option:
				var path: Path = find_path_between_nodes(start_node, end_node, train_uuid)
				if (path != null):
					add_to_dp_map(end_node, dynamnic_programming, RunningPath.new([path]))
	var schedule: Schedule = calculate_running_best_path(dynamnic_programming, stop_options)
	return schedule

#dynamnic_programming is a dictionary with key: StopNode, value: <Path or RunningPath, depending on caller>

# First the map will be dp<StopNode, Path> then it'll transform into dp<StopNode, RunningPath>
static func add_to_dp_map(
	end_node: StopNode, 
	dynamnic_programming: Dictionary, 
	path: RunningPath
) -> void:

	if (dynamnic_programming.has(end_node.name)):
		var current_path: RunningPath = dynamnic_programming[end_node.name]
		if (current_path.length > path.length):
			dynamnic_programming[end_node.name] = path
	else:
		dynamnic_programming[end_node.name] = path

static func calculate_running_best_path(
	dynamnic_programming: Dictionary, 
	stop_options: Array[StopOption]
) -> Schedule:
	var running_map: Dictionary = {}
	# Map<StopNode, Array<Path>>
	for i: int in range(stop_options.size() - 1):
		# Initalize the map
		if (i == 0): ## The first path has already been calculated, add it directly to the map
			for next_stop_option: StopNode in stop_options[1].stop_option:
				var next_stop_path: RunningPath = dynamnic_programming.get(next_stop_option.name)
				if (next_stop_path != null):
					add_to_dp_map(next_stop_path.get_last_stop(), running_map, next_stop_path)
			continue
		
		for current_stop_option: StopNode in stop_options[i].stop_option:
			for next_stop_option: StopNode in stop_options[i + 1].stop_option:
				# Types could be RunningPath | Path | null
				var current_stop_path: RunningPath = running_map.get(current_stop_option.name)
				var next_stop_path: RunningPath = dynamnic_programming.get(next_stop_option.name)
				check_if_overlap_and_add_to_map(running_map, current_stop_path, next_stop_path)

	var best_length: float = INF
	var best_path: RunningPath = null

	var final_paths: Array = \
	stop_options[-1].stop_option \
	.map(func(x: StopNode) -> String: return x.name) \
	.map(func(name: String) -> RunningPath: return running_map.get(name)) \
	.filter(func(x: RunningPath) -> bool: return x != null)
	for path: RunningPath in final_paths:
		if (path.length < best_length):
			best_length = path.length
			best_path = path
	if (best_path == null):
		return null
	#var take_one = (best_path.paths.size()
	#var take_two = 
	assert(best_path.paths.size() == max(1, stop_options.size() - 1), "We should have as many paths as we have stops")
	return Schedule.new(best_path.paths)


class RunningPath:
	var paths: Array[Path]
	var length: float = 0.0

	func _init(paths_: Array[Path]) -> void:
		self.paths = paths_
		for path: Path in paths:
			self.length += path.length
	
	# The first and last nodes should be actual stops(so not junctions)

	func get_first_stop() -> StopNode:
		return paths[0].get_first_stop()

	func get_last_stop() -> StopNode:
		return paths[-1].get_last_stop()
		

static func check_if_overlap_and_add_to_map(
	dynamnic_programming: Dictionary, 
	start_path: RunningPath, 
	end_path: RunningPath
) -> void:
	if (start_path == null or end_path == null):
		return
	if (start_path.get_last_stop().name == end_path.get_first_stop().name):
		# Can run twice for each end_path
		var combined_array: Array[Path] = []
		combined_array.append_array(start_path.paths)
		combined_array.append_array(end_path.paths)
		var running_path_list: RunningPath = RunningPath.new(combined_array)
		add_to_dp_map(end_path.get_last_stop(), dynamnic_programming, running_path_list)

static func combine_paths(first_half: Path, second_half: Path) -> Path:
	var first_half_nodes: Array[VirtualNode] = first_half.nodes
	var second_half_nodes: Array[VirtualNode] = second_half.nodes
	assert(first_half_nodes[-1].name == second_half.nodes[0].name, "Nodes should overlap")
	first_half_nodes.pop_back()	
	var combined_nodes: Array[VirtualNode] = first_half_nodes + second_half_nodes
	var length: float = first_half.length + second_half.length
	return Path.new(combined_nodes, length)

static func get_node_position(node: VirtualNode) -> Vector2:
	if (node is StopNode):
		var node_cast : StopNode = node
		return node_cast.get_position()
	elif (node is JunctionNode):
		var node_cast : JunctionNode = node
		return node_cast.junction.position

	assert(false, "We should never get here")
	return Vector2.ZERO

static func heuristic(a: VirtualNode, b: VirtualNode) -> float:
	return get_node_position(a).distance_to(get_node_position(b))

# Copilot generated(it is A* as requested, and looks like code from A* algorithm wiki page)
static func find_path_between_nodes(
	start: VirtualNode, 
	end: VirtualNode, 
	train_uuid: String
) -> Path:
	var open_set: PriorityQueue = PriorityQueue.new()
	var came_from: Dictionary = {}
	var g_score: Dictionary = {}
	var f_score: Dictionary = {}
	var visited: Dictionary = {}

	g_score[start.name] = 0.0
	f_score[start.name] = heuristic(start, end)
	open_set.insert(start, f_score[start.name] as float)

	while not open_set.is_empty():
		var current: VirtualNode = open_set.extract_min()
		if current == end:
			return reconstruct_path(came_from, current)

		if visited.has(current.name):
			continue
		visited[current.name] = true

		for connected_node: NodeAndCost in current.get_connected_nodes(train_uuid):
			var neighbor: VirtualNode = connected_node.virtual_node
			var cost_to_neighbor: float = connected_node.cost
			if visited.has(neighbor.name):
				continue
			var tentative_g: float = g_score[current.name] + cost_to_neighbor
			if tentative_g < g_score.get(neighbor.name, INF):
				came_from[neighbor.name] = current
				g_score[neighbor.name] = tentative_g
				f_score[neighbor.name] = tentative_g + heuristic(neighbor, end)
				open_set.insert(neighbor, f_score[neighbor.name] as float)

	return null

static func reconstruct_path(
	came_from: Dictionary, 
	current: VirtualNode
) -> Path:
	var length: float = 0.0
	var path_nodes: Array[VirtualNode] = [current]
	while came_from.has(current.name):
		var prev: VirtualNode = came_from[current.name]
		var cost_segment: float = prev.get_node_and_cost(current.name).cost
		length += cost_segment
		path_nodes.insert(0, prev)
		current = prev
	return Path.new(path_nodes, length)
