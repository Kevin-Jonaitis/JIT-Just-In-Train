extends RefCounted

class_name Stop

# Should have a forward and backward node
#The first positions in the train should be for the "front" of the train, and the other one's should be for the
# "back" of the train
var stop_option: Array[TrainPosition]


class TrainPosition:
	var front_of_train: StopNode
	var back_of_train: StopNode # Where the front of the train stops for the stop point

	func _init(front: StopNode, back: StopNode) -> void:
		self.front_of_train = front
		self.back_of_train = back	

func _init(stop_option_: Array[TrainPosition]) -> void:
	self.stop_option = stop_option_
	assert(stop_option_.size() == 2, "We should have two nodes")


# It's placed forward if it's first stops are forward-facing
func is_placed_forward() -> bool:
	return stop_option[0].front_of_train.is_forward()

func get_front_stops() -> Array[StopNode]:
	return stop_option.map(func(x: TrainPosition) -> StopNode: return x.front_of_train)

## TODO: Need to fix simple case where train isn't across any junctions
## TODO: clear out "stop node", and leave only junction nodes.

# Right now, when placing a train, it'll always face whatever "forward" is on the track(increasing in point index)
# the train_placed_forward flag says if we are facing opposite that direction
static func create_stop_for_point(stop_point: TrackPointInfo, train: Train, train_placed_forward: bool) -> Stop:
	var point_index_one: int  = stop_point.point_index
	var alternative_starting_position: float
	var train_length : float = train.length
	var current_point_distance: float = stop_point.track.get_distance_to_point(stop_point.point_index)
	if train_placed_forward:
		alternative_starting_position = current_point_distance - train_length
	else:
		alternative_starting_position  = current_point_distance + train_length
	if (alternative_starting_position < 0 || alternative_starting_position > stop_point.track.length):
		assert(false, "We can't build a stop here")
		return null

	var point_index_two : int = stop_point.track.get_approx_point_index_at_offset(alternative_starting_position)

	return Stop.new(generate_train_position(point_index_one, point_index_two, stop_point.track, train, train_placed_forward))

static func generate_train_position(point_index_one: int, point_index_two: int, track: Track, train: Train, train_facing_foward: bool) -> Array[TrainPosition]:
	var front_of_train: StopNode = StopNode.new(track, point_index_one, train_facing_foward, train)
	var back_of_train: StopNode = StopNode.new(track, point_index_two, train_facing_foward, train, true) # Is reverse node

	var position_one : TrainPosition = TrainPosition.new(front_of_train, back_of_train)

	var front_of_train_reverse: StopNode = StopNode.new(track, point_index_two, !train_facing_foward, train)
	var back_of_train_reverse: StopNode = StopNode.new(track, point_index_one, !train_facing_foward, train, true) # Is reverse node


	var position_two : TrainPosition = TrainPosition.new(front_of_train_reverse, back_of_train_reverse)
	return [position_one, position_two]

# TODO: Fix these so we don't actually need them

## A train should always be placed from the forward back.
# It doesn't make sense for a train to only be able to go "backwards", as you won't place a train this way
func get_forward_positions() -> TrainPosition:
	return stop_option[0]

func get_backward_positions() -> TrainPosition:
	return stop_option[1]
