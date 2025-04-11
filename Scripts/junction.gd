extends Node3D
class_name Junction

var uuid: String = Utils.generate_unique_id()
static var counter: int = 0

# An array of "TrackConnection" objects describing which tracks connect to this Junction
var lines: Array[TrackConnection]

var _angle: float
var _opposite_angle: float

# Since we’re now using a global Graph, we remove:
# var virtual_nodes: Dictionary = {}

const scene: PackedScene = preload("res://Scenes/junction.tscn")

@onready var trains: Trains = get_tree().get_first_node_in_group("trains")

# ---------------------------------------------------------
# Classes for connections
# ---------------------------------------------------------
class TrackConnection:
	var track: Track3D
	# Wether it approaches from angle or opposite angle going INTO the junction
	var approach_from_angle: bool
	var connected_at_start: bool

	func _init(track_: Track3D, approach_from_angle_: bool, connected_at_start_: bool) -> void:
		track = track_
		approach_from_angle = approach_from_angle_
		connected_at_start = connected_at_start_

class NewConnection:
	var track: Track3D 
	var angle: float # Then angle facing AWAY from the track at the connection point
	var connected_at_start: bool

	func _init(track_: Track3D, connected_at_start_: bool) -> void:
		track = track_
		connected_at_start = connected_at_start_
		if connected_at_start_:
			angle = Utils.normalize_angle_0_to_2_pi(track.get_angle_at_point_index(0) + PI)
		else:
			angle = track.get_angle_at_point_index(-1)

# ---------------------------------------------------------
# Main logic
# ---------------------------------------------------------

func get_junction_node(track: Track3D, connected_at_start: bool, is_entry: bool) -> JunctionNode:
	# We no longer rely on local virtual_nodes; we look for the node in the global Graph.
	var node_name: String = JunctionNode.generate_name(self, track, connected_at_start, is_entry)
	if Graph._nodes.has(node_name):
		var node: VirtualNode = Graph._nodes[node_name]
		return node # Should be a JunctionNode or VirtualNode
	else:
		assert(false, "Virtual node not found in Graph. This should never happen!")
		return null

func add_vritual_nodes_for_connection(connection_: TrackConnection) -> void:
	# 1. Create two new JunctionNodes (subclass of VirtualNode).
	var entry_node: JunctionNode = JunctionNode.new(self, connection_.track, connection_.connected_at_start, true)
	var exit_node: JunctionNode  = JunctionNode.new(self, connection_.track, connection_.connected_at_start, false)

	# 2. Register them in the global Graph
	#    This adds them to graph.nodes, e.g. keyed by entry_node.name
	Graph.add_node(entry_node)
	Graph.add_node(exit_node)

	# 3. For any connections in "lines" that are opposite approach, create zero-cost edges
	var approach_from_angle: bool = connection_.approach_from_angle
	var approachable_connections: bool = !approach_from_angle

	for connection: TrackConnection in lines:
		if connection == connection_:
			continue
		if connection.approach_from_angle == approachable_connections:
			# "connected_node_out" is the 'exit' for that track
			var connected_node_out: JunctionNode = get_junction_node(connection.track, connection.connected_at_start, false)
			# create edge: entry_node -> connected_node_out
			Graph.add_edge(entry_node, connected_node_out, 0.0)

			var connected_node_in: JunctionNode = get_junction_node(connection.track,  connection.connected_at_start, true)
			# create edge: connected_node_in -> exit_node
			Graph.add_edge(connected_node_in, exit_node, 0.0)

func add_connection(connection: NewConnection) -> void:
	# 1. Determine if the new track approaches from the _angle or _opposite_angle
	var track_connection: TrackConnection = null	
	if Utils.check_angle_matches(connection.angle, _angle):
		track_connection = TrackConnection.new(connection.track, true, connection.connected_at_start)
	elif Utils.check_angle_matches(connection.angle, _opposite_angle):
		track_connection = TrackConnection.new(connection.track, false, connection.connected_at_start)
	else:
		assert(false, "Connection angle doesn't match junction angle or opposite angle")
		return

	# 2. Ensure no duplicate track/angle
	for existing: TrackConnection in lines:
		if (existing.track.uuid == connection.track.uuid &&
		existing.connected_at_start == connection.connected_at_start &&
		Utils.check_angle_matches(existing.approach_from_angle, track_connection.approach_from_angle)):
			assert(false, "Track is already connected to this junction at the same angle!!")

	# 3. Update track references
	if connection.connected_at_start:
		connection.track.start_junction = self
	else:
		connection.track.end_junction = self

	# 4. Add the connection to our "lines" array
	lines.append(track_connection)

	# 5. Create the new VirtualNodes (JunctionNodes) and edges
	add_vritual_nodes_for_connection(track_connection)

func remove_track_and_nodes(track: Track3D) -> void:
	# Remove from lines
	for i: int in range(lines.size()):
		if lines[i].track.uuid == track.uuid:
			lines.remove_at(i)
			break 
	# Now remove the associated VirtualNodes from the global Graph
	remove_virtual_nodes_and_references(track)


func remove_virtual_nodes_and_references(track: Track3D) -> void:
	if track.start_junction == self:
		var entry_node_name_start_track: String = JunctionNode.generate_name(self, track, true, true)
		var exit_node_name_start_track:  String = JunctionNode.generate_name(self, track, true, false)
		if (entry_node_name_start_track):
			remove_node_and_references(entry_node_name_start_track)
		if (exit_node_name_start_track):
			remove_node_and_references(exit_node_name_start_track)
	if track.end_junction == self:
		var entry_node_name_end_track: String = JunctionNode.generate_name(self, track, false, true)
		var exit_node_name_end_track:  String = JunctionNode.generate_name(self, track, false, false)
		if (entry_node_name_end_track):
			remove_node_and_references(entry_node_name_end_track)
		if (exit_node_name_end_track):
			remove_node_and_references(exit_node_name_end_track)

func remove_node_and_references(node_name: String) -> void:
	# 1. If the node exists in the global Graph, remove it from there.
	if Graph._nodes.has(node_name):
		var node_to_remove: VirtualNode = Graph._nodes[node_name]
		Graph.remove_node(node_to_remove)  # This will remove edges as well
		# The rest of the references (edges, etc.) are handled by the Graph’s remove_node logic

func get_outgoing_connections(track: Track3D) -> Array[TrackConnection]:
	var outgoing_connections: Array[TrackConnection] = []
	var angle_dir: bool
	# 1. Find the approach_from_angle for the track
	for connection: TrackConnection in lines:
		if connection.track.uuid == track.uuid:
			angle_dir = connection.approach_from_angle
			break
	# 2. Any connection that has a different approach_from_angle is "outgoing"
	for connection: TrackConnection in lines:
		if connection.approach_from_angle != angle_dir:
			outgoing_connections.append(connection)
	return outgoing_connections

static func new_Junction(position_: Vector2, junctionsNode: Junctions, connection: NewConnection) -> Junction:
	var junction: Junction = scene.instantiate()
	junction.name = "Junction_" + str(counter)
	counter += 1
	junction._angle = Utils.normalize_angle_0_to_2_pi(connection.angle)
	junction._opposite_angle = Utils.normalize_angle_0_to_2_pi(connection.angle + PI)
	junction.add_connection(NewConnection.new(connection.track, connection.connected_at_start))
	junction.position = Vector3(position_.x, 0, position_.y)
	junctionsNode.add_child(junction)
	# junction.queue_redraw()
	assert(!junction.name.contains("-"), "This will break pathfinding name parsing if we have a '-' in the name")
	return junction
