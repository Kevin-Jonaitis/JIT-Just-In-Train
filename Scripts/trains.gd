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


# TODO: Put this somewhere more appropriate
# Given an old track that's being split into 2 new tracks, update the train stops on the old track
func update_train_stops(old_track: Track, new_track_a: Track, new_track_b: Track) -> void:
	for train: Train in trains:
		for stop_index: int in range(train.get_stops().size()):
			var virtual_node : StopNode = train.get_stops()[stop_index].stop_option[0].front_of_train # Just check one, all stops should be on the same train track
			# We only need to get one "StopNode" in a Stop to regenerate the whole Stop(hopefully! This'll probably cause a bug later on with trains being placed in reverse)
			if (virtual_node.track.uuid == old_track.uuid):
				var potential_point: TrackPointInfo = get_point_info_on_new_tracks(virtual_node.get_vector_pos(), new_track_a, new_track_b)
				if (potential_point):
					var stop: Stop = Stop.create_stop_for_point(potential_point, train, train.get_stops()[stop_index].is_placed_forward())
					assert(stop != null, "We should be able to create a stop here always")
					#train.get_stops()[stop_index] = stop
					train.replace_stop_at_index(stop, stop_index)
					pass

# TODO: Put this somewhere more appropriate
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
