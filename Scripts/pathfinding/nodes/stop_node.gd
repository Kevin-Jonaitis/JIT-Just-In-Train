extends VirtualNode

# A stop, which typically happens on a track
# Used for pathfinding
class_name StopNode

# index of point on the track
var point_index: int
var train: Train

# Train should reverse after reaching this node
var is_reverse_node: bool = false
var forward : bool

#TODO: add track direction for points that need to be different depending on which side of the track trains are coming from
#(Example, a station where you want a long train to stop at a different spot depending on which way it's facing)

func _init(track_: Track, point_index_: int, forward_: bool, train_: Train, is_reverse_node: bool = false) -> void:
	self.name = generate_name(track_, point_index_, forward_, train_)
	self.track = track_
	self.point_index = point_index_
	self.train = train_
	self.forward = forward_
	self.is_reverse_node = is_reverse_node

# static func create_forward_and_backward_stops(track_: Track, point_index_: int, train_: Train) -> Array[StopNode]:
# 	var forward_stop: StopNode = StopNode.new(track_, point_index_, true, train_)
# 	var backward_stop: StopNode = StopNode.new(track_, point_index_, false, train_)
# 	return [forward_stop, backward_stop]

func get_position() -> Vector2:
	return track.dubins_path.shortest_path.get_point_at_index(point_index)

func is_forward() -> bool:
	return forward

static func generate_name(track_: Track, index_: int, forward: bool, train_: Train) -> String:
	var direction_str: String = "forward" if forward else "backward"
	return str("stop-", track_.name, "-", index_, "-", train_.name, "-", direction_str)


func create_node_in_opposite_direction() -> StopNode:
	var opposite_node: StopNode = StopNode.new(track, point_index, not is_forward(), train)
	return opposite_node

# I know, holding data in the string name is not the fastest or most secure, 
# but string parsing is a well-explored area and makes the code simpiler/more flexible
func get_point_index() -> int:
	return point_index
	# assert(name.begins_with("temp"), "This isn't a temp node, a bad call was made here")
	# var split = name.split("-")
	# return int(split[2])

# <stop>-<track-name>-<index>-<train>-<direction>
func get_track_name() -> String:
	return track.name
	# assert(name.begins_with("stop"), "This isn't a temp node, a bad call was made here")
	# var split = name.split("-")
	# return split[1]
