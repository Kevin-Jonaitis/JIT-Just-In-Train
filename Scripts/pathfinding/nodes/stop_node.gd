extends VirtualNode

# A stop, which typically happens on a track
# Used for pathfinding
class_name StopNode

# index of point on the track
var point_index: int
var train: Train

func _init(track_: Track, point_index_: int, forward_: bool, train_: Train) -> void:
	self.name = generate_name(track_, point_index_, forward_, train_)
	self.track = track_
	self.point_index = point_index_
	self.train = train_

func get_position() -> Vector2:
	return track.dubins_path.shortest_path.get_point_at_index(point_index)

func is_forward() -> bool:
	return name.ends_with("forward")

static func generate_name(track_: Track, index_: int, forward: bool, train_: Train) -> String:
	var direction_str: String = "forward" if forward else "backward"
	return str("stop-", track_.name, "-", index_, "-", train_.name, "-", direction_str)


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
