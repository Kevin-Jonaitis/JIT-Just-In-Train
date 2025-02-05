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
	assert(!junction.name.contains("-"), "This will break pathfinding name parsing if we have a '-' in the name")
	return junction
