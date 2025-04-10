extends Node3D


func get_stops() -> Array[Stop]:
	var stops_temp : Array[Stop] = []
	for stop: Stop in $Stops.get_children():
		stops_temp.append(stop)
	return stops_temp 
