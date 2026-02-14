@tool
extends MeshInstance3D

const size = 256

@export_tool_button("Generate") var generate = update_mesh

@export_category("Mesh Details")
#@export_range(4, 256, 4) var size := 256:
	#set(new_val):
		#size = new_val

@export_range(4, 256, 4) var resolution := 128:
	set(new_val):
		resolution = new_val

@export_range(1.0, 256.0, 1.0) var height := 64:
	set(new_val):
		height = new_val

@export var height_map : FastNoiseLite:
	set(new_val):
		height_map = new_val

@export_category("Colors")
@export var sand_color := Color.from_rgba8(172, 99, 29, 255):
	set(new_val):
		sand_color = new_val

@export var grass_color := Color.from_rgba8(0, 75, 0, 255):
	set(new_val):
		grass_color = new_val

@export var snow_color := Color.from_rgba8(248, 248, 255, 255):
	set(new_val):
		snow_color = new_val

@export var rock_color := Color.from_rgba8(68, 68, 68, 255):
	set(new_val):
		rock_color = new_val

@export_category("Color Settings")
@export var color_mix : FastNoiseLite:
	set(new_val):
		color_mix = new_val

@export_range(-size, size, 1.0) var sand_full := 0:
	set(new_val):
		sand_full = new_val

@export_range(-size, size, 1.0) var sand_max := 10:
	set(new_val):
		sand_max = new_val

@export_range(-size, size, 1.0) var snow_min := 30:
	set(new_val):
		snow_min = new_val

@export_range(-size, size, 1.0) var snow_full := 40:
	set(new_val):
		snow_full = new_val

@export_range(0.0, 1.0, 0.01) var rock_min := 0.3:
	set(new_val):
		rock_min = new_val

@export_range(0.0, 1.0, 0.01) var rock_full := 0.5:
	set(new_val):
		rock_full = new_val

var plane : PlaneMesh
var plane_arrays
var vertex_array : PackedVector3Array
var index_array : PackedInt32Array
var normal_array : PackedVector3Array
var tangent_array : PackedFloat32Array
var color_array : PackedColorArray

func update_mesh():
	print("CALLED")
	plane = PlaneMesh.new()
	plane.subdivide_depth = resolution
	plane.subdivide_width = resolution
	plane.size = Vector2(size, size)
	
	plane_arrays = plane.get_mesh_arrays()
	vertex_array = plane_arrays[ArrayMesh.ARRAY_VERTEX]
	index_array = plane_arrays[ArrayMesh.ARRAY_INDEX]
	normal_array = plane_arrays[ArrayMesh.ARRAY_NORMAL]
	tangent_array = plane_arrays[ArrayMesh.ARRAY_TANGENT]
	color_array.resize(vertex_array.size())
	
	
	for i in range(0, vertex_array.size()):
		var vertex := global_transform * vertex_array[i]
		var tangent := Vector3.RIGHT
		
		if height_map:
			#Use pow 4 and cell noise to get mountain and flat inbetween
			#Use -1 * abs for mountain ranges 
			#perlin for basic
			vertex.y = pow(height_map.get_noise_2d(vertex.x, vertex.z) * height, 4)
			vertex_array[i] = vertex
	
	for i in range(0, index_array.size(), 3):
		var i0 = index_array[i]
		var i1 = index_array[i + 1]
		var i2 = index_array[i + 2]
		
		var A = vertex_array[i0]
		var B = vertex_array[i1]
		var C = vertex_array[i2]
		
		var edge1 = C - A
		var edge2 = B - A
		
		var normal = edge1.cross(edge2)
		
		normal_array[i0] += normal
		normal_array[i0] = normal_array[i0].normalized()
		normal_array[i1] += normal
		normal_array[i1] = normal_array[i1].normalized()
		normal_array[i2] += normal
		normal_array[i2] = normal_array[i2].normalized()
		
		get_tangent(i0)
		get_tangent(i1)
		get_tangent(i2)
		
		get_color(i0)
		get_color(i1)
		get_color(i2)
	
	plane_arrays[ArrayMesh.ARRAY_COLOR] = color_array
	
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane_arrays)
	mesh = array_mesh
	
	var material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, material)

func get_color(i : int):
	var steepness := 1.0 - normal_array[i].dot(Vector3.UP)
	
	var sand_weight : float = clamp(-1 * ((vertex_array[i].y - sand_max) / (sand_max - sand_full)), 0.0, 1.0)
	var snow_weight : float = clamp((vertex_array[i].y - snow_min) / (snow_full - snow_min), 0.0, 1.0)
	var rock_weight : float = clamp((steepness - rock_min) / (rock_full - rock_min), 0.0, 1.0)
	var grass_weight : float = clamp(1.0 - sand_weight - snow_weight - rock_weight, 0.0, 1.0)
	
	var vertex = vertex_array[i] * global_transform
	
	if sand_weight != 0.0 and sand_weight != 1.0:
		sand_weight = clamp(sand_weight + color_mix.get_noise_2d(vertex.x, vertex.z), 0.0, 1.0)
	elif snow_weight != 0.0 and snow_weight != 1.0:
		snow_weight = clamp(snow_weight + color_mix.get_noise_2d(vertex.x, vertex.z), 0.0, 1.0)
	elif rock_weight != 0.0 and rock_weight != 1.0:
		rock_weight = clamp(rock_weight + color_mix.get_noise_2d(vertex.x, vertex.z), 0.0, 1.0)
	
	var total_weight := sand_weight + snow_weight + grass_weight + rock_weight
	
	color_array[i] = (sand_color * sand_weight + grass_color * grass_weight + snow_color * snow_weight + rock_color * rock_weight) / total_weight


func get_tangent(i : int):
	var tangent := normal_array[i].cross(Vector3.UP)
	
	tangent_array[4 * i] = tangent.x
	tangent_array[4 * i + 1] = tangent.y
	tangent_array[4 * i + 2] = tangent.z
