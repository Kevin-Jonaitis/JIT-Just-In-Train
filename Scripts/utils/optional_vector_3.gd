extends RefCounted

# We create this class so we can return a nullable object
class_name OptionalVector3

var value: Vector3

func _init(value_: Vector3) -> void:
	self.value = value_


static func print(test_value: OptionalVector3) -> void:
	print("MOUSE POSITION: ", str(test_value.value) if test_value else "null")
