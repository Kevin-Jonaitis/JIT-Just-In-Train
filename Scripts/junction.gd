extends Node2D

class_name Junction


var uuid: String = Utils.generate_uuid()
static var counter = 0

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


#Map<internal_node_id, internal_node_object>
var virtual_nodes: Dictionary = {}

const scene: PackedScene = preload("res://Scenes/junction.tscn")

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

	func _init(track_: Track, approach_from_angle_: float, connected_at_start_: bool):
		track = track_
		approach_from_angle = approach_from_angle_
		connected_at_start = connected_at_start_

# Just a helper class
class NewConnection:
	var track: Track 
	var angle: float
	var connected_at_start: bool

	func _init(track_: Track, connected_at_start_: bool):
		track = track_
		connected_at_start = connected_at_start_

		if (connected_at_start_):
			angle = Utils.normalize_angle_0_to_2_pi(track.get_angle_at_point_index(0) + PI)
		else:
			angle = track.get_angle_at_point_index(-1)

func add_connection(connection: NewConnection) -> void:
	# Check if the track is already connected
	
	var track_connection = null

	if (Utils.check_angle_matches(connection.angle, _angle)):
		track_connection = TrackConnection.new(connection.track, true, connection.connected_at_start)
	elif (Utils.check_angle_matches(connection.angle, _opposite_angle)):
		track_connection = TrackConnection.new(connection.track, false, connection.connected_at_start)
	else:
		assert(false, "Connection angle doesn't match junction angle or opposite angle")
		return
	
	for existing in lines:
		if existing.track.uuid == connection.track.uuid and Utils.check_angle_matches(existing.approach_from_angle,track_connection.approach_from_angle):
				assert(false, "Track is already connected to this junction at the same angle!!")
	
	if(connection.connected_at_start):
		connection.track.start_junction = self
	else:
		connection.track.end_junction = self

	lines.append(track_connection)


func remove_track(track: Track) -> void:
	for i in range(lines.size()):
		if lines[i].track.uuid == track.uuid:
			lines.remove_at(i)
			return

func get_outgoing_connections(track: Track) -> TrackConnection:
	var outgoing_conenctions = []
	var angle_dir
	# TODO: mini-optimization to not iterate over list twice
	for connection in lines:
		if connection.track.uuid == track.uuid:
			angle_dir = connection.approach_from_angle
			break;
	for connection in lines:
		if connection.approach_from_angle != angle_dir:
			outgoing_conenctions.append(connection)
	return outgoing_conenctions	

static func new_Junction(position_: Vector2, junctionsNode: Junctions, connection: NewConnection) -> Junction:
	var junction: Junction = scene.instantiate()
	junction.name = "Junction-" + str(counter)
	counter += 1
	junction._angle = Utils.normalize_angle_0_to_2_pi(connection.angle)
	junction._opposite_angle = Utils.normalize_angle_0_to_2_pi(connection.angle + PI)
	junction.add_connection(NewConnection.new(connection.track, connection.connected_at_start))
	junction.position = position_
	junctionsNode.add_child(junction)
	junction.queue_redraw()
	return junction

#func _draw() -> void:
	#print("THE POSITION", position)
	#draw_circle(Vector2.ZERO, 18, Color(1,0,0,0.3))
