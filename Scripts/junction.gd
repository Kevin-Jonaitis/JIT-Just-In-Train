extends Node2D

class_name Junction


var uuid: String = Utils.generate_uuid()
static var counter: int = 0

# Yeah this could be a map, but really there will be less than 10 connections
# and an array is so much easier to deal with
var lines: Array[TrackConnection]

# Do not use these directly, they're in calculations to determine which way
# the angle of the junction is going
# Use TrackConnection.approach_from_angle instead

# This angle (and opposite angle) represents the angle at which 
# ALL tracks are coming _into_ the junction. They will always come in at 180 degrees from 
# each other
var _angle: float
var _opposite_angle: float


#Map<internal_node_id, JunctionNode>
var virtual_nodes: Dictionary = {}

const scene: PackedScene = preload("res://Scenes/junction.tscn")


@onready var trains: Trains = get_node("/root/Trains")

# Cases:
# 1. You're adding a single connection to a brand-new junction because it's the end of a track
# 2. You're adding two connections to a brand new junction(placing a new track in the middle of an existing track)
# 3. You're adding a connection to an existing junction

# In all cases, a junction is always created with 1 track
# and is UPDATED to add one more track
class TrackConnection:
	var track: Track
	# Wether it approaches from angle or opposite angle going INTO the junction
	var approach_from_angle: bool
	var connected_at_start: bool

	func _init(track_: Track, approach_from_angle_: float, connected_at_start_: bool) -> void:
		track = track_
		approach_from_angle = approach_from_angle_
		connected_at_start = connected_at_start_

# Just a helper class
class NewConnection:
	var track: Track 
	var angle: float
	var connected_at_start: bool

	func _init(track_: Track, connected_at_start_: bool) -> void:
		track = track_
		connected_at_start = connected_at_start_

		if (connected_at_start_):
			angle = Utils.normalize_angle_0_to_2_pi(track.get_angle_at_point_index(0) + PI)
		else:
			angle = track.get_angle_at_point_index(-1)

func get_junction_node(track: Track, is_entry: bool) -> JunctionNode:
	var node_name: String = JunctionNode.generate_name(self, track, is_entry)
	if (virtual_nodes.has(node_name)):
		return virtual_nodes[node_name]
	else:
		assert(false, "Virtual node not found, this should never happen!")
		return null

func add_vritual_nodes_for_connection(connection_: TrackConnection) -> void:
	var entry_node: JunctionNode = JunctionNode.new(self, connection_.track, true, connection_.connected_at_start)
	var exit_node: JunctionNode = JunctionNode.new(self, connection_.track, false, connection_.connected_at_start)
	
	virtual_nodes[entry_node.name] =  entry_node
	virtual_nodes[exit_node.name] =  exit_node
	
	# You can only travel to nodes that are the opposite angle
	var approach_from_angle: float = connection_.approach_from_angle
	var approachable_connections: bool = !approach_from_angle

	for connection: TrackConnection in lines:
		if connection == connection_:
			continue
		if connection.approach_from_angle == approachable_connections:
			 # It's free to travel internally
			var connected_node_out: VirtualNode = get_junction_node(connection.track, false)
			entry_node.add_connected_node(connected_node_out, 0)
			var connected_node_in: VirtualNode = get_junction_node(connection.track, true)
			connected_node_in.add_connected_node(exit_node, 0)

func add_connection(connection: NewConnection) -> void:
	# Check if the track is already connected
	
	var track_connection: TrackConnection = null

	if (Utils.check_angle_matches(connection.angle, _angle)):
		track_connection = TrackConnection.new(connection.track, true, connection.connected_at_start)
	elif (Utils.check_angle_matches(connection.angle, _opposite_angle)):
		track_connection = TrackConnection.new(connection.track, false, connection.connected_at_start)
	else:
		assert(false, "Connection angle doesn't match junction angle or opposite angle")
		return
	
	for existing: TrackConnection in lines:
		if existing.track.uuid == connection.track.uuid and Utils.check_angle_matches(existing.approach_from_angle,track_connection.approach_from_angle):
				assert(false, "Track is already connected to this junction at the same angle!!")
	
	if(connection.connected_at_start):
		connection.track.start_junction = self
	else:
		connection.track.end_junction = self

	lines.append(track_connection)
	add_vritual_nodes_for_connection(track_connection)
	add_reverse_nodes_for_connection(track_connection)


func add_reverse_nodes_for_connection(connection: TrackConnection) -> void:
	for train : Train in trains.trains:
		var length: float = train.length
		var out_node: JunctionNode = get_junction_node(connection.track, false)
		var in_node: JunctionNode = get_junction_node(connection.track, false)
		var results : Array = generate_path_of_length_from_start(out_node, train, length)

		if (results.size() == 0):
			print("No reverse path found for connection: " + connection.track.name + " at junction: " + name)
			return
		for path : Path in results:
			assert(path.nodes.size() > 2, "Path should have at least 2 nodes: starting node and turnaround node")
			assert(path.nodes[-1] is StopNode, "Last node should be a stop node that's a returnaround node")
			assert(path.nodes[0] is JunctionNode, "First node should be our junction node")
			var full_path: Path = generate_path_with_reverse_nodes_added(path)

			var nodes_without_start : Array[VirtualNode] = full_path.nodes.duplicate()
			nodes_without_start.erase(0)
			# Use the OLD path length, because we don't use the turn-around length
			var edge: Edge = Edge.new(in_node, path.length, nodes_without_start)
			in_node.add_connected_reverse_node(out_node, edge)

func generate_path_with_reverse_nodes_added(path: Path) -> Path:
	var nodes: Array[VirtualNode] = path.nodes
	var new_nodes_to_add: Array[VirtualNode] = []
	for i: int in range(path.nodes.size() - 1, 0, -1):
		var node: VirtualNode = nodes[i]
		var newNode : VirtualNode = node.create_node_in_opposite_direction()
		new_nodes_to_add.append(newNode)
	return Path.new(path.nodes + new_nodes_to_add)

# Return type Array[Array[VirtuaNode]]
func generate_path_of_length_from_start(start_node: VirtualNode, train: Train, remaining_length: float) -> Array[Path]:
	assert(remaining_length > 0, "This should never happen, how did we recurse below 0")
	var paths_to_return : Array[Path] = []
	# verify length is correct
	for edge : Edge in start_node.get_connected_new(train.name):
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

			paths_to_return.append([start_node, end_node])
	return paths_to_return

func remove_track_and_nodes(track: Track) -> void:
	for i: int in range(lines.size()):
		if lines[i].track.uuid == track.uuid:
			lines.remove_at(i)
			return
	remove_virtual_nodes_and_references(track)

# Copilot 90% generated Yehaw
func remove_virtual_nodes_and_references(track: Track) -> void:
	var entry_node_name: String = JunctionNode.generate_name(self, track, true)
	var exit_node_name: String = JunctionNode.generate_name(self, track, false)

	remove_node_and_references(entry_node_name)
	remove_node_and_references(exit_node_name)

func remove_node_and_references(node_name: String) -> void:
	if (virtual_nodes.has(node_name)):
		virtual_nodes.erase(node_name)

	# Remove references to this track in other nodes
	for node: VirtualNode in virtual_nodes.values():
		node.erase_connected_node(node_name)


func get_outgoing_connections(track: Track) -> Array[TrackConnection]:
	var outgoing_conenctions: Array[TrackConnection] = []
	var angle_dir: bool
	# TODO: mini-optimization to not iterate over list twice
	for connection: TrackConnection in lines:
		if connection.track.uuid == track.uuid:
			angle_dir = connection.approach_from_angle
			break;
	for connection: TrackConnection in lines:
		if connection.approach_from_angle != angle_dir:
			outgoing_conenctions.append(connection)
	return outgoing_conenctions	

static func new_Junction(position_: Vector2, junctionsNode: Junctions, connection: NewConnection) -> Junction:
	var junction: Junction = scene.instantiate()
	junction.name = "Junction_" + str(counter)
	counter += 1
	junction._angle = Utils.normalize_angle_0_to_2_pi(connection.angle)
	junction._opposite_angle = Utils.normalize_angle_0_to_2_pi(connection.angle + PI)
	junction.add_connection(NewConnection.new(connection.track, connection.connected_at_start))
	junction.position = position_
	junctionsNode.add_child(junction)
	junction.queue_redraw()
	assert(!junction.name.contains("-"), "This will break pathfinding name parssing if we have a '-' in the name")
	return junction

#func _draw() -> void:
	#print("THE POSITION", position)
	#draw_circle(Vector2.ZERO, 18, Color(1,0,0,0.3))
