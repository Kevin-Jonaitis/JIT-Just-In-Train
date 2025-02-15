extends VirtualNode

# A stop, which typically happens on a track
# Used for pathfinding
class_name StopNode

# position along the track from the front of the track
var track_pos: float
var train: Train

# Train should reverse after reaching this node
var is_reverse_node: bool = false
# Which direction the stop faces on the TRACK(i.e. if a track index points increase from left to right, 
# and this stop goes from right to left, 
# then this would be considered backward)
var forward : bool

func _init(track_: Track, track_pos_: float, forward_: bool, train_: Train, is_reverse_node_: bool = false) -> void:
	self.name = generate_name(track_, track_pos_, forward_, train_)
	self.track = track_
	self.track_pos = track_pos_
	self.train = train_
	self.forward = forward_
	self.is_reverse_node = is_reverse_node_

func get_position() -> Vector2:
	return track.dubins_path.shortest_path.get_point_at_offset(track_pos)

func get_angle_of_point() -> float:
	return track.dubins_path.shortest_path.get_angle_at_offset(track_pos)

func get_track_pos_name() -> String:
	return str(int(track_pos))

func is_forward() -> bool:
	return forward

static func generate_name(track_: Track, track_pos_: float, forward_: bool, train_: Train) -> String:
	
	var direction_str: String = "forward" if forward_ else "backward"
	var generated_name: String =  str("stop-", track_.name, "-", int(track_pos_), "-", train_.name, "-", direction_str)
	return generated_name


func create_node_in_opposite_direction() -> StopNode:
	var opposite_node: StopNode = StopNode.new(track, track_pos, not is_forward(), train)
	return opposite_node

# I know, holding data in the string name is not the fastest or most secure, 
# but string parsing is a well-explored area and makes the code simpiler/more flexible
func get_track_position() -> float:
	return track_pos

# <stop>-<track-name>-<index>-<train>-<direction>
func get_track_name() -> String:
	return track.name

func get_distance_from_front_track() -> float:
	return track_pos
