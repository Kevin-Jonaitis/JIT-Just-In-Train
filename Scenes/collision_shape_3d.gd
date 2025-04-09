extends CollisionShape3D

# Needs to be bigger than half the width of the track
const JUNCTION_RADIUS: float = 1.5

func _ready() -> void:
	var sphere: SphereShape3D  = SphereShape3D.new()
	sphere.radius = JUNCTION_RADIUS
	shape = sphere
