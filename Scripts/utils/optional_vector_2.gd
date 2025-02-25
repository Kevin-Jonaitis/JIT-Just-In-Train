extends RefCounted

# We create this class so we can return a nullable object
class_name OptionalVector2

var value: Vector2

func _init(value_: Vector2) -> void:
	self.value = value_


static func print(test_value: OptionalVector2) -> void:
	print("MOUSE POSITION: ", str(test_value.value) if test_value else "null")
