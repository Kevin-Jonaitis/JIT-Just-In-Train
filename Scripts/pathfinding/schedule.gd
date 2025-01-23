extends RefCounted

class_name Schedule

# path between each pair of stops
var stops_path: Array[Path]
var stops: Array[VirtualNode]

# func _init():
	# self.stops = stops
	# self.schedule = schedule

func add_path(path: Path):
	stops_path.append(path)
