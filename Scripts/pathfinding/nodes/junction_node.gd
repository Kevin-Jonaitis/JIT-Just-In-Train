extends VirtualNode

# Used for pathfinding
# Internal node used in a junction
class_name JunctionNode


var junction: Junction
# Wether this junction is connected at the start or end POINT INDEX of the track
var connected_at_start_of_track: bool
var is_exit_node_bool: bool

func _init(junction_: Junction, track_: Track3D, connected_at_start_: bool, is_entry: bool) -> void:
	self.name = generate_name(junction_, track_, connected_at_start_, is_entry)
	self.track = track_
	self.junction = junction_
	self.connected_at_start_of_track = connected_at_start_
	self.identifier = Graph.map_name_to_number(name)
	self.is_exit_node_bool = name.ends_with("-exit")

#<junction_name>-<track-name>-<t_start/end)-<entry/exit/null>
static func generate_name(junction_: Junction, track_: Track3D, connected_at_start_: bool, is_entry: bool) -> String:
	var track_end : String
	# If this track loops back onto the same junction, we need to be able to differentiate
	# between the nodes that are at the start and end of the track
	if connected_at_start_: 
		track_end = "-t_str" 
	else:
		track_end = "-t_end"	
	if is_entry:
		return str(junction_.name, "-", track_.name, track_end + "-entry")
	else:
		return str(junction_.name, "-", track_.name, track_end + "-exit")

func create_node_in_opposite_direction() -> JunctionNode:
	var opposite_node: JunctionNode = JunctionNode.new(junction, track, connected_at_start_of_track, not is_entry_node())
	return opposite_node
	
func get_entry_node_same_track_side() -> JunctionNode:
	assert(self.is_exit_node(), "What are you doing getting an entry node on NOT an exit node??")
	var entry_node: JunctionNode = Graph._nodes.get(generate_name(junction, track, connected_at_start_of_track, true))
	assert(entry_node.is_entry_node(), "This should be an exit node")
	return entry_node

# func get_exit_node_same_track_side() -> JunctionNode:
# 	assert(self.is_entry_node(), "What are you doing getting an exit node on NOT an entry node??")
# 	var exit_node: JunctionNode = Graph._nodes.get(generate_name(junction, track, connected_at_start_of_track, true))
# 	assert(!exit_node.is_entry_node(), "This should be an exit node")
# 	return exit_node

func get_track_position() -> float:
	if connected_at_start_of_track:
		return 0
	else:
		return track.length

func is_entry_node() -> bool:
	return !is_exit_node_bool

func is_exit_node() -> bool:
	return is_exit_node_bool

# We can't rely on the position of this junction, as it might not placed on the map yet
# However, the start/end position of the track will have been calcualted already
func get_vector_pos() -> Vector2:
	if connected_at_start_of_track:
		return track.get_start_position()
	else:
		return track.get_end_position()

func get_distance_from_front_track() -> float:
	if (connected_at_start_of_track):
		return 0
	else:
		return track.get_length()


# We only get the FIRST valid reverse edge. This saves processing time, and anyways
# which reverse edge it takes would be artibrary anyways
func get_reverse_edge(train: Train) -> Edge:
	if (!self.is_exit_node()):
		return null

	var path : Path = generate_path_of_length_from_start(self, train, train.length)

	if (path == null):
		# print("No reverse path found at junction: " + name + " for train: " + train.name)
		return null
	assert(path.nodes.size() >= 2, "Path should have at least 2 nodes: starting node and turnaround node")
	assert(path.nodes[-1] is StopNode, "Last node should be a stop node that's a returnaround node")
	assert(path.nodes[0] is JunctionNode, "First node should be our junction node")
	var full_path: Path = generate_path_with_reverse_nodes_added(path)
	var nodes_without_start : Array[VirtualNode] = full_path.nodes.duplicate()
	nodes_without_start.remove_at(0)
	var entry_node: JunctionNode = get_entry_node_same_track_side()

	# Use the OLD path length, because we don't use the turn-around length
	var edge: Edge = Edge.new(entry_node, path.length, nodes_without_start, train)
	# edges.append(edge)
	return edge


func generate_path_with_reverse_nodes_added(path: Path) -> Path:
	var nodes: Array[VirtualNode] = path.nodes
	var new_nodes_to_add: Array[VirtualNode] = []
	for i: int in range(path.nodes.size() - 1, 0, -1):
		var node: VirtualNode = nodes[i]
		var newNode : VirtualNode = node.create_node_in_opposite_direction()
		new_nodes_to_add.append(newNode)
	return Path.new(path.nodes + new_nodes_to_add)

# We just need one turnaround point
func generate_path_of_length_from_start(start_node: VirtualNode, train: Train, remaining_length: float) -> Path:
	assert(remaining_length >= 0, "This should never happen, how did we recurse below 0")
	# Only get connected nodes; don't bother getting reverse edges for connected
	# nodes as the train length will go down for each "further" intersection, and therefore
	# will never be long enough to reverse	
	for edge : Edge in Graph.get_connected_edges(start_node, train, true):
		var new_lenth: float = remaining_length - edge.cost
		if (new_lenth > 0):
			var further_path: Path = generate_path_of_length_from_start(edge.to_node, train, new_lenth)
			var newPath: Path
			var path_first_half: Path
			if (edge.is_reverse_edge()):
				var reverse_path_nodes : Array[VirtualNode] = edge.intermediate_nodes.duplicate()
				reverse_path_nodes.insert(0, start_node)
				path_first_half = Path.new(reverse_path_nodes)
			else:
				path_first_half = Path.new([start_node, edge.to_node])
			
			# for further_path : Path in further_paths:
			if further_path != null:
				newPath = Path.join_seperate_path_arrays(path_first_half, further_path)
				if (Utils.is_equal_approx(newPath.length, remaining_length)):
					return newPath
				else:
					assert(false, "This should never happen, our path should be exactly remaining length")
					pass
				# print("Ditching path because it's length doesn't match", newPath.length, remaining_length)
		elif new_lenth <= 0:
			if (edge.is_reverse_edge()):
				continue;

			assert(start_node is JunctionNode, "This should be a junction node")
			assert(edge.to_node is JunctionNode, "This should be a junction node")
			assert(edge.to_node.track.uuid == start_node.track.uuid, "If we're decreasing the length, we should always be on the same track")

			var overshoot_node: JunctionNode = edge.to_node

			var start: float = start_node.get_track_position()
			var end: float = overshoot_node.get_track_position()

			var is_increasing: bool = start < end
			var goal_offset: float

			if (is_increasing):	
				goal_offset = remaining_length
			else:
				var track_length: float = start_node.track.get_length()
				goal_offset = track_length - remaining_length

			var end_node: StopNode = StopNode.new(start_node.track, goal_offset, is_increasing, train, true)

			return Path.new([start_node, end_node])
	return null
