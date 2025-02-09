extends VirtualNode

# Used for pathfinding
# Internal node used in a junction
class_name JunctionNode


var junction: Junction
# Wether this junction is connected at the start or end POINT INDEX of the track
var connected_at_start_of_track: bool

func _init(junction_: Junction, track_: Track, is_entry: bool, connected_at_start_: bool) -> void:
	self.name = generate_name(junction_, track_, is_entry)
	self.track = track_
	self.junction = junction_
	self.connected_at_start_of_track = connected_at_start_

#<junction_name>-<track-name>-<entry/exit/null>
static func generate_name(junction_: Junction, track_: Track, is_entry: bool) -> String:
	if is_entry:
		return str(junction_.name, "-", track_.name, "-entry")
	else:
		return str(junction_.name, "-", track_.name, "-exit")

func create_node_in_opposite_direction() -> JunctionNode:
	var opposite_node: JunctionNode = JunctionNode.new(junction, track, not is_entry_node(), connected_at_start_of_track)
	return opposite_node

func get_entry_node() -> JunctionNode:
	assert(self.is_exit_node(), "What are you doing getting an entry node on NOT an exit node??")
	var entry_node: JunctionNode = junction.virtual_nodes.get(generate_name(junction, track, true))
	assert(entry_node.is_entry_node(), "This should be an exit node")
	return entry_node

func get_exit_node() -> JunctionNode:
	assert(self.is_entry_node(), "What are you doing getting an exit node on NOT an entry node??")
	var exit_node: JunctionNode = junction.virtual_nodes.get(generate_name(junction, track, false))
	assert(!exit_node.is_entry_node(), "This should be an exit node")
	return exit_node

func get_point_index() -> int:
	if connected_at_start_of_track:
		return 0
	else:
		return track.get_points().size() - 1

func is_connected_at_start() -> bool:
	return connected_at_start_of_track 

func is_entry_node() -> bool:
	return name.ends_with("-entry")

func is_exit_node() -> bool:
	return name.ends_with("-exit")



func get_reverse_edges(train: Train) -> Array[Edge]:
	if (!self.is_exit_node()):
		return []

	var edges: Array[Edge] = []
	# var length: float = train.length
	# var out_node: JunctionNode = get_junction_node(connection.track, false)
	# var in_node: JunctionNode = get_junction_node(connection.track, false)
	var results : Array[Path] = generate_path_of_length_from_start(self, train, train.length)

	if (results.size() == 0):
		print("No reverse path found at junction: " + name + "for train: " + train.name)
		return []
	for path : Path in results:
		assert(path.nodes.size() >= 2, "Path should have at least 2 nodes: starting node and turnaround node")
		assert(path.nodes[-1] is StopNode, "Last node should be a stop node that's a returnaround node")
		assert(path.nodes[0] is JunctionNode, "First node should be our junction node")
		var full_path: Path = generate_path_with_reverse_nodes_added(path)
		var nodes_without_start : Array[VirtualNode] = full_path.nodes.duplicate()
		nodes_without_start.erase(0)
		var entry_node: JunctionNode = get_entry_node()

		# Use the OLD path length, because we don't use the turn-around length
		var edge: Edge = Edge.new(entry_node, path.length, nodes_without_start)
		edges.append(edge)
	return edges


func get_distance_from_front_track() -> float:
	if (connected_at_start_of_track):
		return 0
	else:
		return track.get_length()

# Used to construct paths for Stops

# # TODO: finish
# func get_path_up_to_last_junctuion(train: Train) -> Array[Path]:
# 	var paths: Array[Path] = []

# 	var results : Array[Path] = generate_path_of_length_from_start(self, train, train.length)


# 	for path : Path in results:
# 		assert(path.nodes.size() > 2, "Path should have at least 2 nodes: starting node and turnaround node")
# 		assert(path.nodes[-1] is StopNode, "Last node should be a stop node that's a returnaround node")
# 		assert(path.nodes[0] is JunctionNode, "First node should be our junction node")
# 		# var full_path: Path = generate_path_with_reverse_nodes_added(path)
# 		var nodes_without_start : Array[VirtualNode] = full_path.nodes.duplicate()
# 		nodes_without_start.erase(0)
# 		var entry_node: JunctionNode = get_entry_node()

# 		# Use the OLD path length, because we don't use the turn-around length
# 		var edge: Edge = Edge.new(entry_node, path.length, nodes_without_start)
# 		edges.append(edge)
# 	return paths

func generate_path_with_reverse_nodes_added(path: Path) -> Path:
	var nodes: Array[VirtualNode] = path.nodes
	var new_nodes_to_add: Array[VirtualNode] = []
	for i: int in range(path.nodes.size() - 1, 0, -1):
		var node: VirtualNode = nodes[i]
		var newNode : VirtualNode = node.create_node_in_opposite_direction()
		new_nodes_to_add.append(newNode)
	return Path.new(path.nodes + new_nodes_to_add)


# possible connected stop node
# possible connected junction node
# possible connected reverse node
func get_connected_nodes(train: Train, fetch_junctions_only: bool = false) -> Array[Edge]:
	var sorted_stops: Array[StopNode] = sort_stop_nodes(train)
	var edges_to_return : Array[Edge] = []

	# Add all other possible junction nodes(internal and across the track)
	edges_to_return.assign(_connected_nodes.values() as Array[Edge])

	if (fetch_junctions_only):
		return edges_to_return

	# Add possible turnaround point
	edges_to_return.append_array(get_reverse_edges(train))

	# Add possible stop nodes
	if is_exit_node():
		if (sorted_stops.size() != 0):
			# assert(possible_stop_points[0].point_index <= possible_stop_points[-1].point_index, "These should be in ascending order")
			if (is_connected_at_start()): # We should use the forward nodes
				var forward_nodes : Array[StopNode] = sorted_stops.filter(func(node: StopNode) -> bool: return node.is_forward())
				for node : StopNode in forward_nodes:
					# Distance from "front" for junction node(self) is 0
					edges_to_return.append(Edge.new(node, node.get_distance_from_front_track()))
			else: # We should add the backwards nodes
				var backward_nodes : Array[StopNode] = sorted_stops.filter(func(node: StopNode) -> bool: return !node.is_forward())
				for node : StopNode in backward_nodes:
					# Distance from "front" for junction node(self) is track length
					edges_to_return.append(Edge.new(node, track.length - node.get_distance_from_front_track()))

	return edges_to_return

# We just need one turnaround point
func generate_path_of_length_from_start(start_node: VirtualNode, train: Train, remaining_length: float) -> Array[Path]:
	assert(remaining_length > 0, "This should never happen, how did we recurse below 0")
	var paths_to_return : Array[Path] = []
	# Only get connected nodes; don't bother getting reverse edges for connected
	# nodes as the train length will go down for each "further" intersection, and therefore
	# will never be long enough to reverse
	for edge : Edge in start_node.get_connected_nodes(train, true):
		var new_lenth: float = remaining_length - edge.cost
		if (new_lenth > 0):
			var further_paths: Array[Path] = generate_path_of_length_from_start(edge.virtual_node, train, new_lenth)
			var newPath: Path
			var path_first_half: Path
			if (edge.is_reverse_edge()):
				var reverse_path_nodes : Array[VirtualNode] = edge.intermediate_nodes.duplicate()
				reverse_path_nodes.insert(0, start_node)
				path_first_half = Path.new(reverse_path_nodes)
			else:
				path_first_half = Path.new([start_node, edge.virtual_node])
			
			for further_path : Path in further_paths:
				newPath = Path.join_seperate_path_arrays(path_first_half, further_path)
				if (newPath.length == remaining_length):
					paths_to_return.append(newPath)
				else:
					print("Ditching path because it's length doesn't match", newPath.length, remaining_length)
		elif new_lenth <= 0:
			if (edge.is_reverse_edge()):
				continue;

			assert(start_node is JunctionNode, "This should be a junction node")
			assert(edge.virtual_node is JunctionNode, "This should be a junction node")
			assert(edge.virtual_node.track.uuid == start_node.track.uuid, "If we're decreasing the length, we should always be on the same track")

			var overshoot_node: JunctionNode = edge.virtual_node

			var start_index: int = start_node.get_point_index()
			var end: int = overshoot_node.get_point_index()

			var is_increasing: bool = start_index < end
			var goal_point: int
			# This conversion won't be EXACTLY percise(may round up or down a few pixels), 
			# so we give the train an extra point index(whatever that is) space
			# to reverse, so when it actually does the reverse it's definetely clear of the junction
			# I'm sure this will cause me a lot of bugs and bite me in the ass
			if (is_increasing):	
				goal_point = start_node.track.get_approx_point_index_at_offset(remaining_length) + 1
			else:
				var track_length: float = start_node.track.get_length()
				goal_point = start_node.track.get_approx_point_index_at_offset(track_length - remaining_length) - 1

			var end_node: StopNode = StopNode.new(start_node.track, goal_point, is_increasing, train, true)

			paths_to_return.append(Path.new([start_node, end_node]))
	return paths_to_return
