extends Node2D

class_name Tracks


func _on_child_entered_tree(node: Node) -> void:
	
	if (node.temp): # We don't care about the user placement track
		return
	pass # Replace with function body.


func _on_child_exiting_tree(node: Node) -> void:
	if (node.temp): # We don't care about the user placement track
		return
	pass # Replace with function body.
