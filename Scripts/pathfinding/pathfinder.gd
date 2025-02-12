extends Object

class_name Pathfinder

func _init() -> void:
	assert(false, "This class only has static functions, don't instantiate it!")


# Note that "forward" and "backward" only really apply to the starting position of the train
# We can't know what the "forward" and "backward" direction is of any intermediate stops
static func find_path_with_movement(
	train: Train, 
	should_loop: bool
) -> Schedule:
	var stops: Array[Stop] = train.get_stops().duplicate() # Duplicate since we don't want to affect the underlying object
	if (stops.size() <= 1):
		return null
	if (train.can_reverse):
		if (should_loop):
			stops.append(stops[0])
		return find_path(train, stops, should_loop)
	else: # Can only go forwards
		# only allow the forward node as the first stopz
		stops[0] = Stop.new_Stop([stops[0].get_forward_positions()])
		# If we want to connect it back to the start, we add the first node
		if (should_loop):
			stops.append(stops[0]) # This will automatically already have only the forward node
		return find_path(train, stops, should_loop)
	# elif (can_move_backwards):
	# 	# only allow the backward node as the first and last stop
	# 	stops[0] = Stop.new_Stop([stops[0].get_backward_positions()])
	# 	if (should_loop):
	# 		stops.append(stops[0]) # This will automatically already have only the backward node
	# 	return find_path(train, stops, should_loop, can_move_backwards)
	# else:
	# 	assert(false, "We should never get here")
	# 	return null

static func find_path(train: Train, stops: Array[Stop], is_loop: bool) -> Schedule:
	var dynamnic_programming: Dictionary = {}
	for i: int in range(stops.size() - 1):
		var current_stop: Stop = stops[i]
		var next_stop: Stop = stops[i + 1]
		for start_position: Stop.TrainPosition in current_stop.stop_option:
			for end_node: StopNode in next_stop.get_front_stops():
				var path: Path = find_path_between_nodes(start_position, end_node, train)
				if (path != null):
					add_to_dp_map(end_node, dynamnic_programming, RunningPath.new([path]))
	var schedule: Schedule = calculate_running_best_path(dynamnic_programming, stops, is_loop, train.can_reverse)
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
		if ((current_path.length == path.length && current_path.get_total_num_nodes() > path.get_total_num_nodes()) 
		||  current_path.length > path.length):
			dynamnic_programming[end_node.name] = path
	else:
		dynamnic_programming[end_node.name] = path

static func calculate_running_best_path(
	dynamnic_programming: Dictionary, 
	stops: Array[Stop],
	is_loop: bool, 
	can_move_backwards: bool
) -> Schedule:
	# Map<StopNode, RunningPath<Path>>
	#StopNode is the last node, and RunningPath is the series of Paths to get us to that node
	# We use a _different_ map here to keep the best running path
	var running_map: Dictionary = {}
	
	for i: int in range(stops.size() - 1):
		# Initalize the map
		if (i == 0): ## The first path has already been calculated, add it directly to the map
			for next_stop_option: StopNode in stops[1].get_front_stops():
				var next_stop_path: RunningPath = dynamnic_programming.get(next_stop_option.name)
				if (next_stop_path != null):
					add_to_dp_map(next_stop_path.get_last_stop(), running_map, next_stop_path)
			continue

		var current_stop_options: Array[StopNode] = stops[i].get_front_stops()
		var next_stop_options: Array[StopNode]  = stops[i + 1].get_front_stops()
		check_for_overlap(running_map, dynamnic_programming, current_stop_options, next_stop_options, can_move_backwards)

	var best_length: float = INF
	var best_path: RunningPath = null

	var final_paths: Array = \
	stops[-1].stop_option \
	.map(func(x: Stop.TrainPosition) -> StopNode: return x.front_of_train) \
	.map(func(x: StopNode) -> String: return x.name) \
	.map(func(name: String) -> RunningPath: return running_map.get(name)) \
	.filter(func(x: RunningPath) -> bool: return x != null)
	for path: RunningPath in final_paths:
		if (path.length < best_length):
			best_length = path.length
			best_path = path
	if (best_path == null):
		return null
			
	assert(best_path.paths.size() == max(1, stops.size() - 1), "We should have as many paths as we have stops -1")
	return Schedule.new(best_path.paths, is_loop)


static func check_for_overlap(
	running_map: Dictionary,
	dynamnic_programming: Dictionary, 
	current_stop_options: Array[StopNode], 
	next_stop_options: Array[StopNode],
	can_move_backwards: bool
) -> void:
	#Check if we can move backwards
	if(!can_move_backwards): # Simple case, things need to match
		for current_stop_option: StopNode in current_stop_options:
			for next_stop_option: StopNode in next_stop_options:
				var start_path: RunningPath = running_map.get(current_stop_option.name)
				var end_path: RunningPath = dynamnic_programming.get(next_stop_option.name)
				if (start_path == null or end_path == null):
					continue
				if (start_path.get_last_stop().name == end_path.get_first_stop().name):
					# Can run twice for each end_path
					var combined_array: Array[Path] = []
					combined_array.append_array(start_path.paths)
					combined_array.append_array(end_path.paths)
					var running_path_list: RunningPath = RunningPath.new(combined_array)
					add_to_dp_map(end_path.get_last_stop(), dynamnic_programming, running_path_list)
	# We can move backwards, so the end of one path might not be the start of another(due to a reverse)
	# So make sure we line up nodes that might reverse
	else:
		var shortest_first: RunningPath = null
		var shortest_second: RunningPath = null
		for option: StopNode in current_stop_options:
			var test_path: RunningPath = running_map.get(option.name)
			if (test_path == null):
				continue
			if (shortest_first == null or (test_path.length < shortest_first.length)):
				shortest_first = test_path
		for option: StopNode in next_stop_options:
			var test_path: RunningPath = dynamnic_programming.get(option.name)
			if (test_path == null):
				continue
			if (shortest_second == null or (test_path.length < shortest_second.length)):
				shortest_second = test_path
		
		#Couldn't find a viable path
		if (shortest_first == null or shortest_second == null):
			return

		# If the nodes arn't the same between the two paths,
		# That means we did a reverse between the two paths. Set the reverse node
		if (shortest_first.get_last_stop().name != shortest_second.get_first_stop().name):
			shortest_first.get_last_stop().is_reverse_node = true # Set the last node as a reverse node
			
		var combined_array: Array[Path] = []
		combined_array.append_array(shortest_first.paths)
		combined_array.append_array(shortest_second.paths)
		var running_path_list: RunningPath = RunningPath.new(combined_array)
		add_to_dp_map(shortest_second.get_last_stop(), running_map, running_path_list)

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

	func get_total_num_nodes() -> int:
		var total: int = 0
		for path: Path in paths:
			total += path.nodes.size()
		return total
		

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

# static func combine_paths(first_half: Path, second_half: Path) -> Path:
# 	var first_half_nodes: Array[VirtualNode] = first_half.nodes
# 	var second_half_nodes: Array[VirtualNode] = second_half.nodes
# 	assert(first_half_nodes[-1].name == second_half.nodes[0].name, "Nodes should overlap")
# 	first_half_nodes.pop_back()	
# 	var combined_nodes: Array[VirtualNode] = first_half_nodes + second_half_nodes
# 	var length: float = first_half.length + second_half.length
# 	return Path.new(combined_nodes)

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
	start_position: Stop.TrainPosition, 
	end: StopNode, 
	train: Train) -> Path:
	var start: StopNode = start_position.front_of_train

	if (train.can_reverse):
		assert(start is StopNode, "This should be a stop node; otherwise adding a connection to a node will be permanent")
		assert(start_position.back_of_train.is_reverse_node, "Back of train should be a reverse node!!")
		start.add_connected_node(start_position.back_of_train, Edge.COST_TO_REVERSE)

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
		if current.name == end.name:
			return reconstruct_path(came_from, current)

		if visited.has(current.name):
			continue
		visited[current.name] = true
		var edges: Array[Edge] = current.get_connected_nodes(train)
		for edge: Edge in edges:
			var neighbor: VirtualNode = edge.virtual_node
			var cost_to_neighbor: float = edge.cost
			if visited.has(neighbor.name):
				continue
			var tentative_g: float = g_score[current.name] + cost_to_neighbor
			if tentative_g < g_score.get(neighbor.name, INF):
				came_from[neighbor.name] = { "node": current, "path": edge.intermediate_nodes }
				g_score[neighbor.name] = tentative_g
				f_score[neighbor.name] = tentative_g + heuristic(neighbor, end)
				open_set.insert(neighbor, f_score[neighbor.name] as float)

	return null

static func reconstruct_path(
	came_from: Dictionary, 
	current: VirtualNode
) -> Path:
	var path_nodes: Array[VirtualNode] = [current]
	while came_from.has(current.name):
		var prev: Dictionary = came_from[current.name]
		var prev_node: VirtualNode = prev.node
		var prev_path: Array[VirtualNode] = prev.path
		assert(prev_path != null, "Should always be defined, at the very least an empty array")
		if (prev_path.size() > 0):
			for i: int in range(prev_path.size() - 1, -1, -1):
				path_nodes.insert(0, prev_path[i])
		path_nodes.insert(0, prev_node)
		current = prev_node
	return Path.new(path_nodes)
