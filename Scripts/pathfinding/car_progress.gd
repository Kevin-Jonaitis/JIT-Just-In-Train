extends RefCounted

class_name CarProgress

var front_boogie: Progress
var back_boogie: Progress
var front: Progress
var center: Progress


func _init() -> void:
	front_boogie = Progress.new()
	back_boogie = Progress.new()
	front = Progress.new()
	center = Progress.new()
