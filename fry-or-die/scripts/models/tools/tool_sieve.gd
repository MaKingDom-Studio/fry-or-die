## Сито: позволяет хватать ингредиенты по небольшой области.
class_name ToolSieve
extends ToolModel

@export var grab_radius := 85.0


func get_grab_radius() -> float:
	return grab_radius
