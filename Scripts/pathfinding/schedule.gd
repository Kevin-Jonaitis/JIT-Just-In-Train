extends RefCounted

class_name Schedule

# path between each pair of stops
var paths: Array[Path]
var stops: Array[StopNode]:

	get:
		var stops_temp : Array[StopNode] = []
		for path : Path in paths:
			stops_temp.append(path.nodes[0])
		# Append last stop of last node
		stops_temp.append(paths[-1].nodes[-1])
		return stops_temp
	set(value):
		assert(false, "Cannot set stops") 

func _init(stops_path_: Array[Path]) -> void:
	self.paths = stops_path_


func get_path(stop_index: int) -> Path:
	return paths[stop_index]


func get_updated_progress(progress: Progress, new_progress: float) -> Progress:
	var current_path_index: int = progress.path_index
	var path: Path = paths[current_path_index]
	var results: Path.PathLocation = path.get_new_position(progress.track_segment_index, progress.track_segment_progress, new_progress)

	while (results.overshoot):
		current_path_index += 1
		if (current_path_index == paths.size()): # We overshot the whole schedule
			var overshoot_progress: Progress = Progress.new()
			overshoot_progress.set_overshoot(results.overshoot)
			return overshoot_progress
		path = paths[current_path_index]
		progress = Progress.new()
		progress.path_index = current_path_index
		new_progress = results.overshoot
		results = path.get_new_position(progress.track_segment_index, progress.track_segment_progress, new_progress)

	assert(progress.overshoot == 0, "Overshoot should be 0")

	var new_location: Progress = Progress.new()
	new_location.position = results.position
	new_location.path_index = current_path_index
	new_location.track_segment_index = results.track_segment_index
	new_location.track_segment_progress = results.track_segment_progress
	return new_location


func add_path(path: Path) -> void:
	paths.append(path)

func get_start_node() -> StopNode:
	if (stops.size() == 0):
		return null
	return stops[0]

func get_end_node() -> StopNode:
	if (stops.size() == 0):
		return null
	return stops[-1]
