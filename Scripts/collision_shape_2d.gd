extends CollisionShape2D

class_name Junction_Collison_Shape

# Needs to be bigger than half the width of the track
const JUNCTION_RADIUS = 14

func _ready():
	shape.radius = JUNCTION_RADIUS
