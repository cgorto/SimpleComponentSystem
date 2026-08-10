@icon("res://addons/simple_component_system/icons/entity.svg")
class_name Entity3D
extends Node3D
## [Entity], but [Node3D]-rooted. See [Entity] for the API.

## Emitted after a component is attached via the API. See [Entity].
signal component_added(component: Node)

## Emitted after a component is detached via the API. See [Entity].
signal component_removed(component: Node)

func get_component(type: Variant) -> Node:
	return Component.of(self, type)

func get_components(type: Variant) -> Array[Node]:
	return Component.all(self, type)

func has_component(type: Variant) -> bool:
	return Component.has(self, type)

func add_component(type: Variant) -> Node:
	return Component.attach(self, type)

func remove_component(type: Variant) -> bool:
	return Component.detach(self, type)
