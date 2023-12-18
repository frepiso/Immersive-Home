extends Node3D

@onready var wall_corners = $Ceiling/WallCorners
@onready var wall_edges = $Ceiling/WallEdges
@onready var wall_mesh = $WallMesh
@onready var wall_collisions = $WallCollisions

@onready var room_floor = $Floor
@onready var room_ceiling = $Ceiling

@onready var state_machine = $StateMachine

var editable: bool = false:
	set(value):
		if value:
			state_machine.change_to("Edit")
		else:
			state_machine.change_to("View")

func get_corner(index: int) -> MeshInstance3D:
	return wall_corners.get_child(index % wall_corners.get_child_count())

func get_edge(index: int) -> MeshInstance3D:
	return wall_edges.get_child(index % wall_edges.get_child_count())


func _save():
	return {
		"corners": wall_corners.get_children().map(func(corner): return corner.position),
	}

func _load(data):
	await ready
	return

	state_machine.change_to("Edit")

	for corner in data["corners"]:
		state_machine.current_state.add_corner(corner)

	state_machine.change_to("View")
