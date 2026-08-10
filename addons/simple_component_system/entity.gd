@icon("res://addons/simple_component_system/icons/entity.svg")
class_name Entity
extends Node
## Sugar over the static [Component] API, any non-[Entity] node can
## house and use [Component]s.
## Use this (or [Entity2D] / [Entity3D]) when you want
## [code]thing.get_component(Damageable)[/code] reads.

## Emitted after [method add_component] / [method Component.attach] adds a
## component to this entity.
signal component_added(component: Node)

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
