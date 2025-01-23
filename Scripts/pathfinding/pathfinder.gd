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


# For every pair of StopOptions, find the shortest path between them in either direction(forward or backward)
# Add the shortest path to the schedule for that segment
# Arugments allow optionally setting the direction of the first stop option
static func find_path(train: Train, start_forward: bool, start_backwards: bool) -> Schedule:
	var stop_options = train.get_stop_options()
	# key: virtual node, value: shortest path there
	#map nodea, nodeb, path

	var dp = {}
	var start_virtual_node
	var end_virtual_node
	
	var schedule : Schedule = Schedule.new()
	var last_end_node

	for i in range(stop_options.size() - 1):
		var start_nodes = []
		var end_nodes = []
		var current_stop_options : StopOption = stop_options[i]
		var next_stop_options : StopOption = stop_options[i + 1]
		if (i == 0):
			if (start_forward):
				start_nodes.append(stop_options[0].forward_stop)
			if (start_backwards):
				start_nodes.append(stop_options[0].backward_stop)
		else:
			start_nodes.append(current_stop_options.forward_stop)
			start_nodes.append(current_stop_options.backward_stop)

		end_nodes.append(next_stop_options.forward_stop)
		end_nodes.append(next_stop_options.backward_stop
		)
		var shortest_path_length: float = INF
		var shortest_path
		var shortest_path_start_node
		for start_node in start_nodes:
			for end_node in end_nodes:
				var path = find_path_between_nodes(start_node, end_node, train)
				if path.length < shortest_path_length:
					shortest_path_length = path.length
					shortest_path = path
					shortest_path_start_node = start_node
					schedule.add_path(path)
					schedule.stops.append(start_node)
					last_end_node = end_node
	if (last_end_node):
		schedule.stops.append(last_end_node)
	return schedule

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
static func find_path_between_nodes(start: VirtualNode, end: VirtualNode, train: Train) -> Path:
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

		for connected_node in current.get_connected_nodes(train):
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
