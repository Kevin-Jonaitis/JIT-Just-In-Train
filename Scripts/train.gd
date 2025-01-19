extends Sprite2D

class_name Train

signal stops_changed(stops: Array[TrackPointInfo])

@onready var area2d : Area2D = $Area2D

const TRAIN_COLLISION_LAYER = 8

# Used to differentiate from the "temp" train
var is_placed = false

#Could be tracks, could be Stations
var stops: Array[TrackPointInfo] = []:
	set(value):
		stops = value
		emit_signal("stops_changed", stops)


func add_stop(stop: TrackPointInfo) -> void:
	stops.append(stop)
	emit_signal("stops_changed", stops)
