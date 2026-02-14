@tool
extends MeshInstance3D

const SIZE := 256.0

@export_tool_button("Generate Terrain") var generate_button = update_mesh


@export_range(4, 1024, 4) var resolution := 128:
	set(new_resolution):
		resolution = new_resolution
		call_deferred("update_mesh")

@export var noise : FastNoiseLite:
	set(new_noise):
		noise = new_noise
		update_mesh()
		if noise:
			noise.changed.connect(update_mesh)

@export_range(4.0, 256.0, 1.0) var height := 64.0:
	set(new_height):
		height = new_height
		update_mesh()

#Colors and Steepness settings
@export var sand_color := Color.from_rgba8(172, 99, 29, 255):
	set(new_color):
		sand_color = new_color
		update_mesh()

#@export_range(-256.0, 256.0, 4.0) var sand_height := -50:
	#set(new_height):
		#sand_height = new_height
		#update_mesh()

@export var grass_color := Color.from_rgba8(0, 75, 0, 255):
	set(new_color):
		grass_color = new_color
		update_mesh()


@export var rock_color := Color.from_rgba8(68, 68, 68, 255):
	set(new_color):
		rock_color = new_color
		update_mesh()

#@export_range(0.1, 1.0, 0.01) var rock_steepness := 1.0:
	#set(new_steepness):
		#rock_steepness = new_steepness
		#update_mesh()

@export var snow_color := Color.from_rgba8(248, 248, 255, 255):
	set(new_color):
		snow_color = new_color
		update_mesh()

#@export_range(-256.0, 256.0, 4.0) var snow_height := 50:
	#set(new_height):
		#snow_height = new_height
		#update_mesh()

@export_range(-256.0, 256.0, 1.0) var snow_min := 10:
	set(new_height):
		snow_min = new_height
		update_mesh()

@export_range(-256.0, 256.0, 1.0) var snow_full := 20:
	set(new_height):
		snow_full = new_height
		update_mesh()

@export_range(-256.0, 256.0, 1.0) var sand_full := -30:
	set(new_height):
		sand_full = new_height
		update_mesh()

@export_range(-256.0, 256.0, 1.0) var sand_max := -20:
	set(new_height):
		sand_max = new_height
		update_mesh()

@export_range(0, 1.0, .01) var rock_min := 0.15:
	set(new_height):
		rock_min = new_height
		update_mesh()

@export_range(0, 1.0, 0.01) var rock_max := 0.25:
	set(new_height):
		rock_max = new_height
		update_mesh()

@export var color_noise : FastNoiseLite:
	set(new_noise):
		color_noise = new_noise
		update_mesh()
		if color_noise:
			color_noise.changed.connect(update_mesh)


var last_position := Vector3.ZERO

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		if global_position != last_position:
			last_position = global_position
			update_mesh()


func get_height(x : float, y : float) -> float:
	return noise.get_noise_2d(x, y) * height

func get_normal(x : float, y : float) -> Vector3:
	var epsilon := SIZE / resolution
	var normal := Vector3(
		(get_height(x + epsilon, y) - get_height(x - epsilon, y)) / (2.0 * epsilon),
		(1.0),
		(get_height(x, y + epsilon) - get_height(x, y - epsilon)) / (2.0 * epsilon)
	)
	return normal.normalized()


func update_mesh():
	var plane := PlaneMesh.new()
	plane.subdivide_depth = resolution
	plane.subdivide_width = resolution
	plane.size = Vector2(SIZE, SIZE)
	
	var plane_arrays := plane.get_mesh_arrays()
	var vertex_array : PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_VERTEX]
	var index_array : PackedInt32Array = plane_arrays[ArrayMesh.ARRAY_INDEX]
	var normal_array : PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_NORMAL]
	var tangent_array : PackedFloat32Array = plane_arrays[ArrayMesh.ARRAY_TANGENT]
	var color_array : PackedColorArray
	color_array.resize(vertex_array.size())
	
	for i:int in vertex_array.size():
		var vertex := global_transform * vertex_array[i]
		var normal := Vector3.UP
		var tangent := Vector3.RIGHT
		
		if noise:
			#pow 2 for high peaks and constant lows
			#-1 * abs for mountain ranges
			vertex.y = pow(get_height(vertex.x, vertex.z), 4)
			#normal = get_normal(vertex_array[i].x, vertex_array[i].y)
			tangent = normal.cross(Vector3.UP)
		vertex_array[i] = vertex
		#normal_array[i] = normal
		tangent_array[4 * i] = tangent.x
		tangent_array[4 * i + 1] = tangent.y
		tangent_array[4 * i + 2] = tangent.z
		
		#if vertex.y >= sand_height and vertex.y <= snow_height:
			#color_array[i] = grass_color
		
		#if vertex.y > snow_height:
			#color_array[i] = Color.GHOST_WHITE
		#elif vertex.y < sand_height:
			#color_array[i] = Color.SANDY_BROWN
	
	for i in range(0, index_array.size(),3):
		var i0 = index_array[i]
		var i1 = index_array[i + 1]
		var i2 = index_array[i + 2]
		
		var A = vertex_array[i0]
		var B = vertex_array[i1]
		var C = vertex_array[i2]
		
		var edge1 = B - A
		var edge2 = C - A
		
		var normal = edge2.cross(edge1)
		
		normal_array[i0] += normal
		normal_array[i1] += normal
		normal_array[i2] += normal
	
	for i: int in normal_array.size():
		normal_array[i] = normal_array[i].normalized()
		var steepness = 1.0 - normal_array[i].dot(Vector3.UP)
		
		var sand_weight : float = clamp(-1 * ((vertex_array[i].y - sand_max) / (sand_max - sand_full)), 0.0, 1.0)
		var snow_weight : float = clamp((vertex_array[i].y - snow_min) / (snow_full - snow_min), 0.0, 1.0)
		var rock_weight : float = clamp((steepness - rock_min) / (rock_max - rock_min), 0.0, 1.0)
		var grass_weight : float = clamp(1.0 - sand_weight - snow_weight - rock_weight, 0.0, 1.0)
		
		var vertex = vertex_array[i] * global_transform
		
		if sand_weight != 0.0 and sand_weight != 1.0:
			sand_weight = clamp(sand_weight + color_noise.get_noise_2d(vertex.x, vertex.z), 0.0, 1.0)
		if snow_weight != 0.0 and snow_weight != 1.0:
			snow_weight + clamp(snow_weight + color_noise.get_noise_2d(vertex.x, vertex.z), 0.0, 1.0)
		#if grass_weight != 0.0 and grass_weight != 1.0:
			#grass_weight += color_noise.get_noise_2d(vertex.x, vertex.z)
		if rock_weight != 0.0 and rock_weight != 1.0:
			rock_weight = clamp(rock_weight + color_noise.get_noise_2d(vertex.x, vertex.z), 0.0, 1.0)
		
		var total_weight := sand_weight + snow_weight + grass_weight + rock_weight
		
		#if grass_weight >= 0.9:
			#grass_color.g += color_noise.get_noise_2d(vertex.x, vertex.z) * 5.0
		
		color_array[i] = (sand_color * (sand_weight / total_weight) + snow_color * (snow_weight / total_weight) + rock_color * (rock_weight / total_weight) + grass_color * (grass_weight / total_weight))
		
		#if steepness >= rock_steepness:
			#color_array[i] = (rock_color)
	
	
	plane_arrays[ArrayMesh.ARRAY_COLOR] = color_array
	
	
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane_arrays)
	mesh = array_mesh
	
	var material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, material)
