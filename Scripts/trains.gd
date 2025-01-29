extends Node2D

class_name Trains

var trains : Array[Train]:
	get:
		var result : Array[Train] = []
		for child: Node in get_children():
			if (child is Train and (child as Train).is_placed):
				result.append(child)
		return result			

var drawableFunctionsToCallLater: Array[Callable] = []

func _on_train_placed(train: Train) -> void:
	add_child(train)

# Given an old track that's being split into 2 new tracks, update the train stops on the old track
func update_train_stops(old_track: Track, new_track_a: Track, new_track_b: Track) -> void:
	for train: Train in trains:
		for stop_index: int in range(train.get_stop_options().size()):
			var virtual_node : StopNode = train.get_stop_options()[stop_index].stop_option[0]
			if (virtual_node.track.uuid == old_track.uuid):
				var potential_point: TrackPointInfo = get_point_info_on_new_tracks(virtual_node.get_position(), new_track_a, new_track_b)
				if (potential_point):
					train.get_stop_options()[stop_index] = train.create_stop_option(potential_point)

			
func get_point_info_on_new_tracks(old_point: Vector2, new_track_a: Track, new_track_b: Track) -> TrackPointInfo:
	var track_a_points: Array[Vector2] = new_track_a.dubins_path.shortest_path.get_points()
	var track_b_points: Array[Vector2] = new_track_b.dubins_path.shortest_path.get_points()
	for point_index: int in range(track_a_points.size()):
		if (old_point.distance_to(track_a_points[point_index]) < Utils.EPSILON):
			return new_track_a.get_point_info_at_index(point_index)
	for point_index: int in range(track_b_points.size()):
		if (old_point.distance_to(track_b_points[point_index]) < Utils.EPSILON):
			return new_track_b.get_point_info_at_index(point_index)
		
	return null

func _draw() -> void:
	for callable: Callable in drawableFunctionsToCallLater:
		callable.call()
	drawableFunctionsToCallLater.clear()
