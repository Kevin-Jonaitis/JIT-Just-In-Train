extends RefCounted

class_name Schedule

# path between each pair of stops
var segments: Array[Path]
var stops: Array[VirtualNode]

# func _init():
	# self.stops = stops
	# self.schedule = schedule

func add_path(path: Path):
	segments.append(path)
	
func set_stops(stops: Array[VirtualNode]):
	self.stops = stops
