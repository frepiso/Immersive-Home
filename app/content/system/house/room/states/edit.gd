extends RoomState

const wall_corner_scene = preload ("../wall_corner.tscn")
const wall_edge_scene = preload ("../wall_edge.tscn")
const RoomState = preload ("./room_state.gd")

var moving = null
var deleting: bool = false
var floor_corner: StaticBody3D = null
var height_corner: StaticBody3D = null
var height_edge: StaticBody3D = null

func _on_enter():
	var room_store = Store.house.get_room(room.name)

	if room_store == null:
		return

	create_from_corners(room_store.corners, room_store.height)

	var ceiling_shape = WorldBoundaryShape3D.new()
	ceiling_shape.plane = Plane(Vector3.DOWN, 0)
	
	room.room_ceiling.get_node("CollisionShape3D").shape = ceiling_shape
	room.room_floor.get_node("CollisionShape3D").shape = WorldBoundaryShape3D.new()
	
	room.room_ceiling.get_node("Clickable").on_click.connect(_on_click_ceiling)
	room.room_floor.get_node("Clickable").on_click.connect(_on_click_floor)

func _on_leave():
	update_store()
	clear()

	room.room_ceiling.get_node("CollisionShape3D").disabled = true
	room.room_floor.get_node("CollisionShape3D").disabled = true

	room.room_ceiling.get_node("Clickable").on_click.disconnect(_on_click_ceiling)
	room.room_floor.get_node("Clickable").on_click.disconnect(_on_click_floor)

func create_from_corners(corners, height):
	clear()

	if corners.size() > 0:
		add_floor_corner(room.to_local(Vector3(corners[0].x, 0, corners[0].y)))
		add_height_corner(room.to_local(Vector3(corners[0].x, 0, corners[0].y)))
		room.room_ceiling.position.y = height
		height_edge.align_to_corners(floor_corner.position, floor_corner.position + Vector3.UP * room.room_ceiling.position.y)

		for i in range(1, corners.size()):
			add_corner(room.to_local(Vector3(corners[i].x, 0, corners[i].y)))

	room.room_ceiling.get_node("CollisionShape3D").disabled = (floor_corner == null&&height_corner == null)
	room.room_floor.get_node("CollisionShape3D").disabled = false

func get_corner(index: int) -> MeshInstance3D:
	return room.wall_corners.get_child(index % room.wall_corners.get_child_count())

func get_edge(index: int) -> MeshInstance3D:
	return room.wall_edges.get_child(index % room.wall_edges.get_child_count())

func remove_corner(index: int):
	get_corner(index).queue_free()
	get_edge(index).queue_free()

func clear():
	for child in room.wall_corners.get_children():
		room.wall_corners.remove_child(child)
		child.queue_free()

	for child in room.wall_edges.get_children():
		room.wall_edges.remove_child(child)
		child.queue_free()
	
	if floor_corner != null:
		room.remove_child(floor_corner)
		floor_corner.queue_free()
		floor_corner = null
		room.remove_child(height_edge)
		height_edge.queue_free()
		height_edge = null

func _on_click_floor(event):
	if floor_corner != null&&height_corner != null:
		return

	add_floor_corner(event.ray.get_collision_point())
	add_height_corner(event.ray.get_collision_point())
	room.room_ceiling.get_node("CollisionShape3D").disabled = false

func _on_click_ceiling(event):
	if floor_corner == null||height_corner == null||event.target != room.room_ceiling:
		return

	var pos = event.ray.get_collision_point()
	pos.y = 0

	add_corner(pos)

func add_floor_corner(position: Vector3):
	floor_corner = wall_corner_scene.instantiate()
	floor_corner.position = position

	height_edge = wall_edge_scene.instantiate()
	height_edge.align_to_corners(position, position + Vector3.UP * room.room_ceiling.position.y)

	floor_corner.get_node("Clickable").on_grab_down.connect(func(event):
		if !is_active()||moving != null:
			return

		moving=event.target
	)

	floor_corner.get_node("Clickable").on_grab_move.connect(func(event):
		if moving == null:
			return

		var moving_index=height_corner.get_index()
		var direction=- event.ray.global_transform.basis.z
		var new_position=room.room_floor.get_node("CollisionShape3D").shape.plane.intersects_ray(event.ray.global_position, direction)

		if new_position == null:
			return

		moving.position=new_position

		height_edge.align_to_corners(new_position, new_position + Vector3.UP * room.room_ceiling.global_position.y)

		get_corner(moving_index).position.x=new_position.x
		get_corner(moving_index).position.z=new_position.z

		if room.wall_edges.get_child_count() == 0:
			return

		get_edge(moving_index).align_to_corners(new_position, get_corner(moving_index + 1).position)
		get_edge(moving_index - 1).align_to_corners(get_corner(moving_index - 1).position, new_position)
	)

	floor_corner.get_node("Clickable").on_grab_up.connect(func(_event):
		moving=null
	)
	
	room.add_child(floor_corner)
	room.add_child(height_edge)

func add_height_corner(position: Vector3):
	height_corner = wall_corner_scene.instantiate()
	height_corner.position.x = position.x
	height_corner.position.z = position.z

	height_corner.get_node("Clickable").on_grab_down.connect(func(event):
		if !is_active()||moving != null:
			return

		moving=event.target
	)

	height_corner.get_node("Clickable").on_grab_move.connect(func(event):
		if moving == null:
			return

		var direction=- event.ray.global_transform.basis.z
		var plane_direction=direction
		plane_direction.y=0
		plane_direction=plane_direction.normalized() * - 1

		var plane=Plane(plane_direction, moving.position)

		var new_position=plane.intersects_ray(event.ray.global_position, direction)

		if new_position == null:
			return

		room.room_ceiling.position.y=new_position.y
		height_edge.align_to_corners(floor_corner.position, floor_corner.position + Vector3.UP * room.room_ceiling.position.y)
		
	)

	height_corner.get_node("Clickable").on_grab_up.connect(func(_event):
		moving=null
	)

	room.wall_corners.add_child(height_corner)

func add_corner(position: Vector3, index: int=- 1):
	var corner = wall_corner_scene.instantiate()
	corner.position.x = position.x
	corner.position.z = position.z
	
	corner.get_node("Clickable").on_grab_down.connect(func(event):
		if !is_active()||moving != null:
			return

		moving=event.target
	)

	corner.get_node("Clickable").on_grab_move.connect(func(event):
		if moving == null:
			return

		var moving_index=moving.get_index()
		var direction=- event.ray.global_transform.basis.z
		var ceiling_plane=Plane(Vector3.DOWN, room.room_ceiling.global_position)
		var new_position=ceiling_plane.intersects_ray(event.ray.global_position, direction)

		if new_position == null:
			deleting=true

			new_position=event.ray.global_position + direction

			get_corner(moving_index).global_position=new_position

			if room.wall_edges.get_child_count() == 0:
				return

			get_edge(moving_index).align_to_corners(get_corner(moving_index - 1).position, get_corner(moving_index + 1).position)
			get_edge(moving_index - 1).transform=get_edge(moving_index).transform

			return

		deleting=false

		new_position.y=0

		moving.position=new_position

		if room.wall_edges.get_child_count() == 0:
			return

		get_edge(moving_index).align_to_corners(new_position, get_corner(moving_index + 1).position)
		get_edge(moving_index - 1).align_to_corners(get_corner(moving_index - 1).position, new_position)
	)

	corner.get_node("Clickable").on_grab_up.connect(func(_event):
		if deleting:
			var moving_index=moving.get_index()
			remove_corner(moving_index)

		moving=null
		deleting=false
	)
	
	room.wall_corners.add_child(corner)
	room.wall_corners.move_child(corner, index)

	var num_corners = room.wall_corners.get_child_count()

	if num_corners > 1:
		add_edge(position, get_corner(index + 1).position, index)

	if num_corners > 2:
		if num_corners != room.wall_edges.get_child_count():
			add_edge(get_corner( - 2).position, get_corner( - 1).position, -2)
		else:
			get_edge(index - 1).align_to_corners(get_corner(index - 1).position, position)

func add_edge(from_pos: Vector3, to_pos: Vector3, index: int=- 1):
	var edge: StaticBody3D = wall_edge_scene.instantiate()
	edge.align_to_corners(from_pos, to_pos)

	edge.get_node("Clickable").on_press_down.connect(func(event):
		var point=event.ray.get_collision_point()
		point.y=0
		add_corner(point, edge.get_index() + 1)
	)

	room.wall_edges.add_child(edge)
	room.wall_edges.move_child(edge, index)
	return edge

func update_store():
	var store_room = Store.house.get_room(room.name)

	if store_room == null:
		return

	var corners = []

	for corner in room.wall_corners.get_children():
		corners.append(Vector2(corner.global_position.x, corner.global_position.z))

	store_room.corners = corners
	store_room.height = room.room_ceiling.position.y

	# Manually update the array
	Store.house.state.rooms = Store.house.state.rooms

	Store.house.save_local()
