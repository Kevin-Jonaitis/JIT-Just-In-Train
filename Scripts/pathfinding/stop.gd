extends Node2D

class_name Stop

const stopPreloaded: PackedScene = preload("res://Scenes/stop.tscn")


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

@onready var stop_sprite: Sprite2D = $TrainSprite


func set_stop_visible(visible_: bool) -> void:
	stop_sprite.visible = visible_

# func _init(stop_option_: Array[TrainPosition]) -> void:
# 	self.stop_option = stop_option_
# 	assert(stop_option_.size() == 2, "We should have two nodes")

func get_forward_stop() -> TrainPosition:
	return stop_option[0]

func get_train() -> Train:
	assert(stop_option.size() > 0, "We should have at least one train position")
	return stop_option[0].front_of_train.train

# It's placed forward if it's first stops are forward-facing
func is_placed_forward() -> bool:
	return stop_option[0].front_of_train.is_forward()

func get_front_stops() -> Array[StopNode]:
	var array_to_return : Array[StopNode]
	array_to_return.assign(stop_option.map(func(x: TrainPosition) -> StopNode: return x.front_of_train))
	return array_to_return

func _ready() -> void: # Set the position of the stop when it actually enters the tree
	stop_sprite.position = stop_option[0].front_of_train.get_vector_pos()
	stop_sprite.rotation = stop_option[0].front_of_train.get_angle_of_point()
	stop_sprite.modulate = Color(0, 1, 0, 0.5)

static func new_Stop(stop_option_: Array[TrainPosition]) -> Stop:
	var stop: Stop = stopPreloaded.instantiate()
	stop.stop_option = stop_option_
	#assert(stop_option_.size() == 2, "We should have two nodes")
	# The first stop option should always have the train facing forward
	
	return stop

# Right now, when placing a train, it'll always face whatever "forward" is on the track(increasing in point index)
# the train_placed_forward flag says if we are facing opposite that direction
# Return null if we can't create a stop because the back would go off the track

# Our stops are placed at the MIDDLE of a cart, because that's the point at which a cart pivots around turns.
# However, we calcualte the FRONT of the front cart and the BACK of the BACK cart the prevent placing a stop that would
# have the train "hang over" the edge of a track
static func create_stop_for_point(middle_of_front_car: TrackPointInfo, train: Train, train_placed_forward: bool) -> Stop:
	var middle_of_front_car_track_pos: float = middle_of_front_car.track.get_distance_to_point(middle_of_front_car.point_index)
	var middle_of_back_car_distance: float
	var front_of_front_car: float
	var back_of_back_car: float
	var length_of_cart : float = train.cart_length
	var track_distance_to_middle_of_front_car: float = middle_of_front_car.track.get_distance_to_point(middle_of_front_car.point_index)
	if train_placed_forward:
		front_of_front_car = track_distance_to_middle_of_front_car + (length_of_cart / 2)
		back_of_back_car = front_of_front_car - train.length
		middle_of_back_car_distance = back_of_back_car + (length_of_cart / 2)
	else:
		front_of_front_car = track_distance_to_middle_of_front_car - (length_of_cart / 2)
		back_of_back_car  = front_of_front_car + train.length
		middle_of_back_car_distance = back_of_back_car + (length_of_cart / 2)
		

	# TODO: allow a stop to cross a track boundry if  there's only 1 "previous" track
	# Also TODO: we should have a "get_previous_node" function on stopnodes and junctionNodes to faciliate
	# the above
	if (front_of_front_car < 0 || front_of_front_car > middle_of_front_car.track.length ||
		back_of_back_car < 0 || back_of_back_car > middle_of_front_car.track.length):
		return null

	# var point_index_two : int = middle_of_front_car.track.get_approx_point_index_at_offset(middle_of_back_car_distance)

	var stop : Stop = Stop.new_Stop(generate_train_position(middle_of_front_car_track_pos, middle_of_back_car_distance, middle_of_front_car.track, train, train_placed_forward))
	assert(stop.get_front_stops()[0].get_vector_pos() == stop.get_front_stops()[1].get_vector_pos(), "Positions should be the same else things will look bad when the train stops at the station")
	return stop

static func generate_train_position(point_one_track_offset: float, point_two_track_offset: float, track: Track, train: Train, train_facing_foward: bool) -> Array[TrainPosition]:
	var front_of_train: StopNode = StopNode.new(track, point_one_track_offset, train_facing_foward, train)
	# Even though the stopnode is part of the train, we don't want it to
	# face the same way, since that'll make it seem like we can navigate there to "stop";
	# we don't really want that
	var back_of_train: StopNode = StopNode.new(track, point_two_track_offset, !train_facing_foward, train, true) # Is reverse node

	var position_one : TrainPosition = TrainPosition.new(front_of_train, back_of_train)

	var front_of_train_reverse: StopNode = StopNode.new(track, point_two_track_offset, !train_facing_foward, train)
	var back_of_train_reverse: StopNode = StopNode.new(track, point_one_track_offset, train_facing_foward, train, true) # Is reverse node


	var position_two : TrainPosition = TrainPosition.new(front_of_train_reverse, back_of_train_reverse)
	return [position_one, position_two]

# TODO: Fix these so we don't actually need them

## A train should always be placed from the forward back.
# It doesn't make sense for a train to only be able to go "backwards", as you won't place a train this way
func get_forward_positions() -> TrainPosition:
	return stop_option[0]

func get_backward_positions() -> TrainPosition:
	return stop_option[1]
