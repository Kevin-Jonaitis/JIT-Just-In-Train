extends Object

class_name Pathfinder

static var A_STAR: AStar2DCustom = AStar2DCustom.new()

func _init() -> void:
	assert(false, "This class only has static functions, don't instantiate it!")


# Note that "forward" and "backward" only really apply to the starting position of the train
# We can't know what the "forward" and "backward" direction is of any intermediate stops
static func find_path_with_movement(
	train: Train) -> Schedule:
	var stops: Array[Stop] = train.get_stops().duplicate() # Duplicate since we don't want to affect the underlying object
	if (stops.size() <= 1):
		return null
	if (train.can_reverse):
		if (train.should_loop):
			stops.append(stops[0])
		return find_path(train, stops)
	else: # Can only go forwards
		# only allow the forward node as the first stopz
		stops[0] = Stop.new_Stop([stops[0].get_forward_positions()])
		# If we want to connect it back to the start, we add the first node
		if (train.should_loop):
			stops.append(stops[0]) # This will automatically already have only the forward node
		return find_path(train, stops)

static func find_path(train: Train, stops: Array[Stop]) -> Schedule:
	var dynamnic_programming: Dictionary = {}
	var added_connections: Array[Array] = connect_reverse_nodes_for_train(train)
	find_path_between_set_nodes(train, stops, dynamnic_programming)
	var schedule: Schedule = calculate_running_best_path(dynamnic_programming, stops, train)
	remove_reverse_connections(added_connections)

	return schedule

# We only remove the reverse connections from the astar graph
# and it's corresponding cost graph, as we don't need to reclaculate them each a* run
static func remove_reverse_connections(added_connections: Array[Array]) -> void:
	for connection: Array[VirtualNode] in added_connections:
		Graph.remove_reverse_connection_from_astar(connection[0], connection[1])


static func find_path_between_set_nodes(train: Train, stops: Array[Stop], dynamnic_programming: Dictionary) -> void:
	for i: int in range(stops.size() - 1):
		var current_stop: Stop = stops[i]
		var next_stop: Stop = stops[i + 1]
		for start_position: Stop.TrainPosition in current_stop.stop_option:
			for end_node: StopNode in next_stop.get_front_stops():
				var path: Path = new_astar_runner(start_position, end_node, train)
				print("connected calls for set of stops", Graph.PROFILING_COUNT)
				Graph.PROFILING_COUNT = 0
				if (path != null):
					add_to_dp_map(end_node, dynamnic_programming, RunningPath.new([path]))


static func add_stop_node_connection_to_graph(node: StopNode) -> Array[VirtualNode]:
	var junction_node: JunctionNode

	# Add start to end of track
	if (node.is_forward()):
		junction_node = node.track.end_junction.get_junction_node(node.track, false, false)
	else:
		junction_node = node.track.start_junction.get_junction_node(node.track, true, false)
	Graph.add_edge(node, junction_node, 
	VirtualNode.calculate_distance_between_two_connectable_nodes(node, junction_node))

	return [node, junction_node]

class TempPointsAndConnections:
	var points: Array[VirtualNode] = []
	var connections: Array[Array]  = [] # tuple of start and end VirtualNode

	# func _init(points_: Array[VirtualNode], connections_: Array[Array]) -> void:
	# 	self.points = points_
	# 	self.connections = connections_


static func new_astar_runner(start_position: Stop.TrainPosition, end: StopNode, train: Train) -> Path:
	var temp_data: TempPointsAndConnections = connect_stop_nodes_to_graph(start_position, end, train)
	# Graph.debug_print_astar_network()
	var path: PackedInt64Array = calcualte_path(start_position, end)
	var possible_path: Path
	if (path == null || path.size() == 0):
		possible_path = null
	else:
		possible_path = convert_path_to_virtual_nodes(path, train)

	# We need to remove the stops _after_ we construct the path so we can do name lookups in the graph
	# for reconstruction
	remove_temp_stop_connections(temp_data)
	return possible_path

static func calcualte_path(start_position: Stop.TrainPosition, end: StopNode) -> PackedInt64Array:
	return A_STAR.get_id_path(start_position.front_of_train.identifier, end.identifier)


# This can potenetially be really slow, as we have to add a connection for every exit node in the graph
# It runs O(n) where n is the number of nodes in the graph
static func connect_reverse_nodes_for_train(train: Train) -> Array[Array]:
	var added_connections: Array[Array] = []
	var dict: Dictionary = Graph.get_turnaround_loops_for_train(train)
	for key: String in dict.keys():
		var edge: Edge = dict[key]
		Graph.add_reverse_connection_to_astar(Graph._nodes[key], edge.to_node, edge.cost)
		added_connections.append([Graph._nodes[key], edge.to_node])

	return added_connections

static func convert_path_to_virtual_nodes(path: PackedInt64Array, train: Train) -> Path:
	var virtual_nodes: Array[VirtualNode] = []
	for i: int in range(path.size()):
		# Check if we go through a reverse node by checking if the previous and next node are the same
		if (i < path.size() - 1 && JunctionNode.deduce_if_loopback_edge(path[i], path[i + 1])):
			# This could be cleaner, we do a double lookup here and in the "deduce" call
			var current_node: VirtualNode = Graph.map_identifier_to_node(path[i])
			var next_node: VirtualNode = Graph.map_identifier_to_node(path[i + 1])
			virtual_nodes.append(current_node)
			virtual_nodes.append_array(Graph.get_turnaround_loop_for_train_at_node(train, current_node).intermediate_nodes)
			virtual_nodes.append(next_node)
			i += 1 # Skip the next node
		else:
			var node: VirtualNode = Graph.map_identifier_to_node(path[i])
			virtual_nodes.append(node)
	return Path.new(virtual_nodes)


static func remove_temp_stop_connections(temp_data: TempPointsAndConnections) -> void:
	for connection: Array[VirtualNode] in temp_data.connections:
		Graph.remove_edge(connection[0], connection[1])
	for point: VirtualNode in temp_data.points:
		Graph.remove_node(point)

# Make all the (temp) connections for stop nodes
static func connect_stop_nodes_to_graph(start_position: Stop.TrainPosition, end_node: StopNode, train: Train) -> TempPointsAndConnections:
	var temp_data: TempPointsAndConnections = TempPointsAndConnections.new()
	# var added_connections: Array[Array]	= []
	var start: StopNode = start_position.front_of_train

	# Add points
	temp_data.points.append(start_position.front_of_train)
	Graph.add_node(start_position.front_of_train)
	if (train.can_reverse):
		temp_data.points.append(start_position.back_of_train)
		Graph.add_node(start_position.back_of_train)
	temp_data.points.append(end_node)
	Graph.add_node(end_node)
	
	# Add connection front train -> junction
	temp_data.connections.append(add_stop_node_connection_to_graph(start_position.front_of_train))
	
	# Add the connecetion front train -> reverse train
	if (train.can_reverse):
		Graph.add_edge(start, start_position.back_of_train, Edge.COST_TO_REVERSE)
		temp_data.connections.append([start, start_position.back_of_train])

	# Add the connection reverse train -> junction
	if (train.can_reverse):
		temp_data.connections.append(add_stop_node_connection_to_graph(start_position.back_of_train))

	# Add connection of junction -> end node
	var junction_node: JunctionNode
	if (end_node.is_forward()):
		junction_node = end_node.track.start_junction.get_junction_node(end_node.track, true, false)
	else:
		junction_node = end_node.track.end_junction.get_junction_node(end_node.track, false, false)

	Graph.add_edge(junction_node, end_node, 
	VirtualNode.calculate_distance_between_two_connectable_nodes(junction_node, end_node))
	temp_data.connections.append([junction_node, end_node])

	# Add (possible) connection start -> end node
	var start_to_end : Edge = connect_possible_stop_nodes(start_position.front_of_train, end_node)
	if (start_to_end != null):
		Graph.add_edge(start_position.front_of_train, end_node, start_to_end.cost)
		temp_data.connections.append([start_position.front_of_train, end_node])
	
	# Add (possible) connection reverse -> end node
	var reverse_to_end : Edge = connect_possible_stop_nodes(start_position.back_of_train, end_node)
	if (reverse_to_end != null):
		Graph.add_edge(start_position.back_of_train, end_node, reverse_to_end.cost)
		temp_data.connections.append([start_position.back_of_train, end_node])

	return temp_data


static func connect_possible_stop_nodes(current: StopNode, end_node: StopNode) -> Edge:
	if current.track == end_node.track:
		if (current.is_forward() && end_node.is_forward()):
			if current.get_track_position() < end_node.get_track_position():
				var distance: float = end_node.get_track_position() - current.get_track_position() 
				return Edge.new(end_node, distance)
		elif (!current.is_forward() && !end_node.is_forward()):
			if current.get_track_position() > end_node.get_track_position():
				var distance: float = current.get_track_position() - end_node.get_track_position()
				return Edge.new(end_node, distance)		
	return null



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
	train: Train
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
		check_for_overlap(running_map, dynamnic_programming, current_stop_options, next_stop_options, train.can_reverse)

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
	return Schedule.new(best_path.paths, train.should_loop)


static func check_for_overlap(
	running_map: Dictionary,
	dynamnic_programming: Dictionary, 
	current_stop_options: Array[StopNode], 
	next_stop_options: Array[StopNode],
	can_move_backwards: bool
) -> void:
	#Check if we can move backwards
	if(!can_move_backwards): # Simple case, things need to match exactly since we can't reverse at a stop
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
	# We can move backwards, so the end of one path might not be the start of another(due to a reverse at the stop`)
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
			assert(VirtualNode.are_nodes_are_at_same_position(shortest_first.get_last_stop(), 
			shortest_second.get_first_stop()), "Nodes should be at the same position")
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

static func get_node_position(node: VirtualNode) -> Vector2:
	if (node is StopNode):
		var node_cast : StopNode = node
		return node_cast.get_vector_pos()
	elif (node is JunctionNode):
		var node_cast : JunctionNode = node
		return node_cast.junction.position

	assert(false, "We should never get here")
	return Vector2.ZERO

static func heuristic(a: VirtualNode, b: VirtualNode) -> float:
	return get_node_position(a).distance_to(get_node_position(b))

static func possible_edge_to_end_node(current: VirtualNode, end_node: StopNode) -> Edge:
	if current.track == end_node.track:
		if current is StopNode:
			var current_cast: StopNode = current
			if (current_cast.is_forward() && end_node.is_forward()):
				if current_cast.get_track_position() < end_node.get_track_position():
					var distance: float = end_node.get_track_position() - current_cast.get_track_position() 
					return Edge.new(end_node, distance)
			elif (!current_cast.is_forward() && !end_node.is_forward()):
				if current.get_track_position() > end_node.get_track_position():
					var distance: float = current_cast.get_track_position() - end_node.get_track_position()
					return Edge.new(end_node, distance)		
		if current is JunctionNode:
			var current_cast: JunctionNode = current
			if (current_cast.is_exit_node()):
				if current_cast.connected_at_start_of_track && end_node.is_forward():
					return Edge.new(end_node, end_node.get_track_position())
				if !current_cast.connected_at_start_of_track && !end_node.is_forward():
					return Edge.new(end_node, current_cast.track.length - current_cast.get_track_position())
	return null

# If this is a stop node, get the junctions it'd be connected to
static func get_connected_junction_edges_for_stop_node(current: StopNode) -> Array[Edge]:
	var junction_node: JunctionNode
	if (current.is_forward()):
		junction_node = current.track.start_junction.get_junction_node(current.track, true, false)
	else:
		junction_node = current.track.end_junction.get_junction_node(current.track, false, false)
	
	var connected_edges: Array[Edge] = Graph.get_connected_edges(junction_node, current.train)
	return connected_edges

# Copilot generated(it is A* as requested, and looks like code from A* algorithm wiki page)
static func find_path_between_nodes(
	start_position: Stop.TrainPosition, 
	end: StopNode, 
	train: Train) -> Path:
	var start: StopNode = start_position.front_of_train
	var start_name: String = start.name

	print("Start node: ", start.name)
	print("End node: ", end.name)
	print("")


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
		var current_name: String = current.name
		print("Current: ", current_name, ", start: ", start.name, "m end: ", end.name)
		if current_name == end.name:
			return reconstruct_path(came_from, current)

		if visited.has(current_name):
			continue

		visited[current_name] = true
		# We do it all for you, buddy
		var edges: Array[Edge] = Graph.get_connected_edges(current, train)

		# Allow reversing at the start node
		if (current_name == start_name && train.can_reverse):
			assert(start is StopNode, "This should be a stop node; otherwise adding a connection to a node will be permanent")
			assert(start_position.back_of_train.is_reverse_node, "Back of train should be a reverse node!!")
			edges.append(Edge.new(start_position.back_of_train, Edge.COST_TO_REVERSE))
			edges.append_array(get_connected_junction_edges_for_stop_node(current as StopNode))
		if (current_name == start_position.back_of_train.name):
			edges.append_array(get_connected_junction_edges_for_stop_node(current as StopNode))

		# Add the end stop node edge if it's viable
		var possible_end_edge: Edge = possible_edge_to_end_node(current, end)
		if (possible_end_edge):
			edges.append(possible_end_edge)

		for edge: Edge in edges:
			var neighbor: VirtualNode = edge.to_node
			var cost_to_neighbor: float = edge.cost
			if visited.has(neighbor.name):
				continue
			var tentative_g: float = g_score[current_name] + cost_to_neighbor
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
