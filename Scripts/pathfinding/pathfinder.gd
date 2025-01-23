extends Object

class_name Pathfinder

class PathfindingPreference:
	var choose_start_stop: bool
	var chose_end_stop: bool
	var start_forward: bool
	var end_forward: bool

	func _init(choose_start_stop: bool, chose_end_stop: bool, start_forward: bool, end_forward: bool):
		self.choose_start_stop = choose_start_stop
		self.chose_end_stop = chose_end_stop
		self.start_forward = start_forward
		self.end_forward = end_forward
		


func _init():
	assert(false, "This class only has static functions, don't instantiate it!")


# Note that "forward" and "backward" only really apply to the starting position of the train
# We can't know what the "forward" and "backward" direction is of any intermediate stops
static func find_path_with_movement(train: Train, can_move_forward: bool, can_move_backwards: bool, connect_to_start: bool) -> Schedule:
	var stop_options: Array[StopOption] = train.get_stop_options()
	if (can_move_forward && can_move_backwards):
		if (connect_to_start):
			stop_options.append(stop_options[0])
		return find_path(train.uuid, stop_options)
	elif (can_move_forward):
		# only allow the forward node as the first stop
		stop_options[0] = StopOption.new([stop_options[0].get_forward_node()])
		# If we want to connect it back to the start, we add the first node and 
		if (connect_to_start):
			stop_options.append(stop_options[0]) # This will automatically already have only the forward node
		return find_path(train.uuid, stop_options)
	elif (can_move_backwards):
		# only allow the backward node as the first and last stop
		stop_options[0] = StopOption.new([stop_options[0].get_backward_node()])
		if (connect_to_start):
			stop_options.append(stop_options[0]) # This will automatically already have only the backward node
		return find_path(train.uuid, stop_options)
	else:
		assert(false, "We should never get here")
		return null

static func find_path(train_uuid: String, stop_options: Array[StopOption]) -> Schedule:
	var dynamnic_programming = {}
	# var stop_options: Array[StopOption] = train.get_stop_options()
	for i in range(stop_options.size() - 1):
		var current_stop_options : StopOption = stop_options[i]
		var next_stop_options : StopOption = stop_options[i + 1]

		for start_node: StopNode in current_stop_options.stop_option:
				for end_node: StopNode in next_stop_options.stop_option:
					var path = find_path_between_nodes(start_node, end_node, train_uuid)
					add_to_dp_map(end_node, dynamnic_programming, path)
	var schedule = calculate_running_best_path(dynamnic_programming, stop_options)
	return schedule

#dynamnic_programming is a dictionary with key: StopNode, value: <Path or RunningPath, depending on caller>
static func add_to_dp_map(end_node: StopNode, dynamnic_programming: Dictionary, path):
	if (dynamnic_programming.has(end_node)):
		var current_path = dynamnic_programming[end_node]
		if (current_path.length > path.length):
			dynamnic_programming[end_node] = path
	else:
		dynamnic_programming[end_node] = path

	return dynamnic_programming

static func calculate_running_best_path(dynamnic_programming: Dictionary, stop_options: Array[StopOption]) -> Schedule:
	# Map<StopNode, Array<Path>>
	var running_best = {}
	for i in range(stop_options.size() - 1):
		if (i == 0): ## The first path has already been calculated
			continue



		## Ned to stop using two maps, this is incorrect. Use one map 
		# and store the updated path, keeping the update of RunningPath all the way through
		
		for current_stop_option in stop_options[i].stop_option:
			for next_stop_option in stop_options[i + 1].stop_option:
				var current_stop_path = dynamnic_programming[current_stop_option]
				var next_stop_path = dynamnic_programming[next_stop_option]
				check_if_overlap_and_add_to_map(running_best, current_stop_path, next_stop_path)

	var best_length : float = INF
	var best_path : RunningPath = null

	for path in running_best.values():
		if (path.length < best_length):
			best_length = path.length
			best_path = path
	return Schedule.new(best_path.paths)


class RunningPath:
	var paths: Array[Path]
	var length: float

	func _init(paths: Array[Path]):
		self.paths = paths
		for path in paths:
			self.length += path.length
		

static func check_if_overlap_and_add_to_map(dynamnic_programming: Dictionary, start_path, end_path):
	if (start_path.get_last_stop().name == end_path.get_first_stop().name):
		var running_path_list = RunningPath.new([start_path, end_path])
		add_to_dp_map(end_path.get_last_stop(), dynamnic_programming, running_path_list)

static func combine_paths(first_half: Path, second_half: Path):
	var first_half_nodes = first_half.nodes
	var second_half_nodes = second_half.nodes
	assert(first_half_nodes[-1].name == second_half.nodes[0].name, "Nodes should overlap")
	first_half_nodes.pop_back()	
	var combined_nodes = first_half_nodes + second_half_nodes
	var length = first_half.length + second_half.length
	return Path.new(combined_nodes, length)

static func get_node_position(node: VirtualNode) -> Vector2:
	if (node is StopNode):
		return node.get_position()
	elif (node is JunctionNode):
		return node.junction.position

	assert(false, "We should never get here")
	return Vector2.ZERO

static func heuristic(a: VirtualNode, b: VirtualNode) -> float:
	return get_node_position(a).distance_to(get_node_position(b))

# Copilot generated(it is A* as requested, and looks like code from A* algorithm wiki page)
static func find_path_between_nodes(start: VirtualNode, end: VirtualNode, train_uuid: String) -> Path:
	var open_set: PriorityQueue = PriorityQueue.new()
	var came_from = {}
	var g_score = {}
	var f_score = {}
	var visited = {}

	g_score[start.name] = 0.0
	f_score[start.name] = heuristic(start, end)
	open_set.insert(start, f_score[start.name])

	while not open_set.is_empty():
		var current: VirtualNode = open_set.extract_min()
		if current == end:
			return reconstruct_path(came_from, current)

		if visited.has(current.name):
			continue
		visited[current.name] = true

		for connected_node in current.get_connected_nodes(train_uuid):
			var neighbor = connected_node.virtual_node
			var cost_to_neighbor = connected_node.cost
			if visited.has(neighbor.name):
				continue
			var tentative_g = g_score[current.name] + cost_to_neighbor
			if tentative_g < g_score.get(neighbor.name, INF):
				came_from[neighbor.name] = current
				g_score[neighbor.name] = tentative_g
				f_score[neighbor.name] = tentative_g + heuristic(neighbor, end)
				open_set.insert(neighbor, f_score[neighbor.name])

	# No path found
	return Path.new([], INF)

static func reconstruct_path(came_from: Dictionary, current: VirtualNode) -> Path:
	var length: float = 0
	var path_nodes : Array[VirtualNode] = [current]
	while came_from.has(current.name):
		var prev = came_from[current.name]
		var cost_segment = prev.get_node_and_cost(current.name).cost
		length += cost_segment
		path_nodes.insert(0, prev)
		current = prev
	return Path.new(path_nodes, length)
