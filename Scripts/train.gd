extends Sprite2D

class_name Train

signal stops_changed(stops: Array[Stop])



@onready var area2d : Area2D = $Area2D

const TRAIN_COLLISION_LAYER = 8

class Stop:
	var forward_stop: VirtualNode
	var backward_stop: VirtualNode

	func _init(nodes: Array[VirtualNode]):
		for node in nodes:
			if "forward" in node.name:
				forward_stop = node
			elif "backward" in node.name:
				backward_stop = node

# Used to differentiate from the "temp" train
var is_placed = false

#Could be tracks, could be Stations
var stops: Array[Stop] = []:
	set(value):
		stops = value
		emit_signal("stops_changed", stops)


func add_stop(stop_point: TrackPointInfo) -> void:
	Stop.new(stop_point.track.add_temp_virtual_node(stop_point.point_index, self))
	stops.append(stop_point)
	emit_signal("stops_changed", stops)

func remove_stop(stop_index: int) -> void:
	var stop = stops[stop_index]
	stop.track.remove_temp_virtual_node(stops[stop_index].point_index, self)
	stops.remove_at(stop_index)
	emit_signal("stops_changed", stops)
