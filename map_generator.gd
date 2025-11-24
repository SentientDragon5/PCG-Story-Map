extends Node2D

# update to be weighted
const places : Array[String] = [
	"Forest",
	"Field",
	"Lake",
	"Desert",
	"Village"
]

const emotions : Array[String] = [
	"Joy",
	"Sadness",
	"Terror",
	"Indifference",
	"Mystery"
]

const LINE_PREFAB = preload("res://art/Sprites/line_2d.tscn")
const AREA_LABEL_PREFAB = preload("res://art/Sprites/area_label.tscn")

const emotion_colors : Array[Color] = [
	Color.DARK_ORANGE,
	Color.DARK_BLUE,
	Color.DARK_RED,
	Color.DIM_GRAY,
	Color.REBECCA_PURPLE
]
@onready var locations: Node2D = $Locations
@onready var cam: Camera2D = $Camera2D
@onready var map_bounds: Control = $MapBounds

@export var margin = 40
@export var min_distance = 120
@export var num_locations = 20
@export var max_attempts_per_location = 50

@export var distortion_subdivisions = 2
@export var noise : FastNoiseLite = FastNoiseLite.new()

@onready var sample_label: Label = $SampleLabel

var tree_walked : Array[Label] = []

func _ready() -> void:
	randomize()
	noise = FastNoiseLite.new()
	noise.frequency = 0.01
	generate()
	
func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("regenerate"):
		generate()

func _process(_delta: float) -> void:
	var mouse_pos = get_local_mouse_position()
	sample_label.position = mouse_pos + Vector2(15, 15)
	
	var closest_zone = get_closest_zone(mouse_pos)
	if closest_zone:
		sample_label.text = closest_zone.name
	else:
		sample_label.text = "..."

func generate():
	noise.seed = randi()
	await make_locations()
	name_locations()
	await make_borders()
	discard_outer_locations()
	distort_borders()

# loosely based of https://editor.p5js.org/Cacarisse/sketches/vBSru9PBF
# Poisson Scatter
func make_locations():
	for c in locations.get_children():
		c.queue_free()
	await get_tree().process_frame
	
	for i in range(num_locations):
		for j in range(max_attempts_per_location):
			var candidate_pos = Vector2(
				randf_range(margin, map_bounds.size.x - margin),
				randf_range(margin, map_bounds.size.y - margin)
			) + map_bounds.global_position
			
			var ok = true
			for c in locations.get_children():
				if candidate_pos.distance_to(c.position) < min_distance:
					ok = false
					break
			
			if ok:
				var location = Node2D.new()
				
				location.name = "Location " + str(i)
				location.position = candidate_pos
				locations.add_child(location)
				break

func name_locations():
	for location in locations.get_children():
		var label = AREA_LABEL_PREFAB.instantiate()
		var emotion_index = randi() % emotions.size()
		
		location.name = places.pick_random() + " of " + emotions[emotion_index]
		
		label.name = "Name"
		label.set_anchors_preset(Control.PRESET_CENTER)
		label.text = location.name
		label.modulate = emotion_colors[emotion_index]
		location.add_child(label)

func make_borders():
	await get_tree().process_frame
	
	var base_poly = PackedVector2Array([
		map_bounds.position,
		Vector2(map_bounds.position.x + map_bounds.size.x, map_bounds.position.y),
		map_bounds.position + map_bounds.size,
		Vector2(map_bounds.position.x, map_bounds.position.y + map_bounds.size.y)
	])

	for zone in locations.get_children():
		var current_cell_polys = [base_poly] 
		for neighbor in locations.get_children():
			if zone == neighbor: continue
			var p1 = zone.position
			var p2 = neighbor.position
			var diff = p2 - p1
			var midpoint = (p1 + p2) / 2.0
			var normal = diff.normalized()
			var tangent = Vector2(-normal.y, normal.x)
			
			var huge_dist = 20000.0
			var clipper = PackedVector2Array([
				midpoint + tangent * huge_dist,
				midpoint - tangent * huge_dist,
				midpoint - tangent * huge_dist + normal * huge_dist,
				midpoint + tangent * huge_dist + normal * huge_dist
			])
			
			if not current_cell_polys.is_empty():
				current_cell_polys = Geometry2D.clip_polygons(current_cell_polys[0], clipper)
			else:
				break
		
		#var points = starConvexPoints(current_cell_polys[0])
		var points = current_cell_polys[0]
		current_cell_polys = Geometry2D.offset_polygon(points, 0.1)
		
		if not current_cell_polys.is_empty():
			var final_points = current_cell_polys[0]
			#final_points = starConvexPoints(final_points)
			#final_points.append(final_points[0])
			
			var poly = Polygon2D.new()
			poly.name = "Poly"# + str(current_cell_polys.size())
			poly.polygon = final_points
			
			var zone_color = zone.get_node("Name").modulate
			poly.color = zone_color
			poly.color.a = 0.3
			
			zone.add_child(poly)
			poly.global_position = Vector2.ZERO
			
			var line : Line2D = LINE_PREFAB.instantiate()
			line.name = "Border"
			line.points = final_points
			#line.width = 4.0
			line.default_color = Color.BLACK;
			line.closed = true;
			#line.default_color = zone.modulate
			line.default_color.a = 0.5 
			zone.add_child(line)
			line.global_position = Vector2.ZERO

func discard_outer_locations():
	var threshold = 1.0 
	var min_x = map_bounds.position.x
	var min_y = map_bounds.position.y
	var max_x = map_bounds.position.x + map_bounds.size.x
	var max_y = map_bounds.position.y + map_bounds.size.y

	for zone in locations.get_children():
		var border_line : Line2D = zone.get_node("Border")
			
		var is_outer = false
		for p in border_line.points:
			if (abs(p.x - min_x) < threshold or abs(p.y - min_y) < threshold or abs(p.x - max_x) < threshold or abs(p.y - max_y) < threshold):
				is_outer = true
				break
		if is_outer:
			zone.queue_free()
			#zone.name = "Ocean"
			#var label = zone.get_node("Name")
			#label.text = "Ocean"
			#label.modulate = Color.AQUA

func distort_borders():
	# for each location, get its Line2D Border and subdivide it
	for zone in locations.get_children():
		var simple_border : Line2D = zone.get_node("Border")
		
		# Subdivide
		var points = simple_border.points
		for i in range(distortion_subdivisions):
			var new_points = PackedVector2Array()
			var n = points.size()
			
			for j in range(n):
				var a = points[j]
				var b = points[(j + 1) % n] # wrap next
				var mid = (a + b) / 2.0
				
				new_points.append(a)
				new_points.append(mid)
			points = new_points
		
		# then offset the border by the sampled perlin noise at that location to perlin distort
		var distorted_points = PackedVector2Array()
		for i in range(points.size()):
			var pos = points[i]
			var angle = noise.get_noise_2d(pos.x,pos.y)
			var offset = Vector2(cos(angle * 2 * PI), sin(angle * 2 * PI)) * 10
			distorted_points.append(pos + offset)
			#var normal = Vector2.ZERO # normal at that point
		
		points = distorted_points
		
		var poly = Polygon2D.new()
		poly.name = "DistortPoly"
		poly.polygon = points
		
		var zone_color = zone.get_node("Name").modulate
		poly.color = zone_color
		poly.color.a = 0.3
		
		zone.add_child(poly)
		poly.global_position = Vector2.ZERO
		poly.visible = false
		
		var line : Line2D = LINE_PREFAB.instantiate()
		line.name = "DistortBorder"
		line.points = PackedVector2Array(points)
		#line.width = 4.0
		line.default_color = Color.BLACK
		line.closed = true
		line.default_color.a = 0.5
		zone.add_child(line)
		line.global_position = Vector2.ZERO
		
		if zone.has_node("Poly"):
			zone.get_node("Poly").visible = false
		simple_border.visible = false

func starConvexPoints(points : Array) -> Array:
	var center = Vector2.ZERO
	for p in points:
		center += p
	center /= points.size()
	
	points.sort_custom(func(a, b):
		return (a - center).angle() < (b - center).angle()
	)
	return points

func get_closest_zone(point: Vector2) -> Node2D:
	var min_dist_sq = INF
	var closest_zone: Node2D = null
	
	for zone in locations.get_children():
		var dist_sq = point.distance_squared_to(zone.position)
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			closest_zone = zone
	return closest_zone
