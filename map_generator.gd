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
@onready var cam : CamController = $Camera2D
@onready var map_bounds: Control = $MapBounds

@export var margin = 40
@export var min_distance = 120
@export var num_locations = 20
@export var max_attempts_per_location = 50

@export var distortion_subdivisions = 2
@export var noise : FastNoiseLite = FastNoiseLite.new()

@onready var sample_label: Label = $SampleLabel

@export var lod = 2
@export var show_paths = true

func _ready() -> void:
	randomize()
	noise = FastNoiseLite.new()
	noise.frequency = 0.01
	cam.onZoom.connect(lod_update)
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

func update_ui():
	for zone in locations.get_children():
		if zone is Line2D:
			zone.visible = lod < 4 and show_paths
		elif zone is Node2D:
			zone.get_node("Name").visible = lod < 4
			zone.get_node("POIs").visible = lod >= 4
			zone.get_node("POIs").get_node("POI Path").visible = show_paths

func generate():
	noise.seed = randi()
	await make_locations()
	name_locations()
	await make_borders()
	discard_outer_locations()
	distort_borders()
	create_zone_path()
	add_poi()
	await get_tree().process_frame
	update_ui()

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
			#line.default_color.a = 0.5 
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
		#line.default_color.a = 0.5
		zone.add_child(line)
		line.global_position = Vector2.ZERO
		
		if zone.has_node("Poly"):
			zone.get_node("Poly").visible = false
		simple_border.visible = false

func create_zone_path():
	if locations.has_node("GlobalPath"):
		locations.get_node("GlobalPath").queue_free()

	var valid_zones : Array[Node2D] = []
	for zone in locations.get_children():
		if not zone is Line2D and not zone.is_queued_for_deletion():
			valid_zones.append(zone)
	if valid_zones.is_empty():
		return
	var ordered_zones = find_path(valid_zones)
	
	for i in range(ordered_zones.size()):
		locations.move_child(ordered_zones[i], i)
	
	var path_points = PackedVector2Array()
	for zone in ordered_zones:
		path_points.append(zone.position)
	
	var line : Line2D = LINE_PREFAB.instantiate()
	line.name = "GlobalPath"
	line.points = path_points
	line.default_color = Color.DIM_GRAY
	locations.add_child(line)

func add_poi():
	var previous_end_point : Vector2 = Vector2.ZERO
	
	var zones : Array[Node2D] = []
	for child in locations.get_children():
		if not child is Line2D and not child.is_queued_for_deletion():
			zones.append(child)

	for i in range(zones.size()):
		var zone = zones[i]
		var next_zone = zones[i+1] if i < zones.size() - 1 else null
		
		var poly_points : PackedVector2Array
		if zone.has_node("DistortPoly"):
			poly_points = zone.get_node("DistortPoly").polygon
		elif zone.has_node("Poly"):
			poly_points = zone.get_node("Poly").polygon
		else:
			continue
		
		var num_poi = 10
		var points_in_zone = get_random_points_in_polygon(poly_points, num_poi)
		
		var start_point : Vector2
		if i == 0:
			start_point = points_in_zone[0]
			points_in_zone.remove_at(0)
		else:
			start_point = previous_end_point

		var end_point : Vector2
		if next_zone:
			end_point = find_best_end_point(points_in_zone, next_zone)
			points_in_zone.remove_at(points_in_zone.find(end_point))
		else:
			end_point = points_in_zone[points_in_zone.size() - 1]
			points_in_zone.remove_at(points_in_zone.size() - 1)
		
		previous_end_point = end_point
		var path_points = find_path_between(start_point, end_point, points_in_zone)
		
		var poi_container = Node2D.new()
		poi_container.name = "POIs"
		zone.add_child(poi_container)
		
		for pos in path_points:
			var node = add_poi_icon()
			node.position = pos - zone.position
			var s = 0.15
			node.scale = Vector2(s, s)
			poi_container.add_child(node)
			
		var line : Line2D = LINE_PREFAB.instantiate()
		line.name = "POI Path"
		var local_points = PackedVector2Array()
		for p in path_points:
			local_points.append(p - zone.position)
		line.points = local_points
		line.width = 2.0
		line.default_color = Color.DIM_GRAY
		poi_container.add_child(line)

#region Helper Functions
func add_poi_icon(icon : String = "tower") -> Node2D:
	var tscn : PackedScene= load("res://art/Sprites/" + icon + ".tscn")
	return tscn.instantiate()

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

func get_polygon_area(points: PackedVector2Array) -> float:
	var area = 0.0
	var num_points = points.size()
	if num_points < 3:
		return 0.0
		
	for i in range(num_points):
		var p1 = points[i]
		var p2 = points[(i + 1) % num_points]
		area += (p1.x * p2.y) - (p2.x * p1.y)
	return abs(area) / 2.0

func get_poly_bounding_box(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()

	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF
	
	for p in points:
		min_x = min(min_x, p.x)
		max_x = max(max_x, p.x)
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

func get_random_points_in_polygon(polygon: PackedVector2Array, num_points : int = 10) -> PackedVector2Array:
	var bounds = get_poly_bounding_box(polygon)
	var max_attempts = 100
	var points = []
	for i in range(max_attempts):
		var rand_point = Vector2(
			randf_range(bounds.position.x, bounds.end.x),
			randf_range(bounds.position.y, bounds.end.y)
		)
		if Geometry2D.is_point_in_polygon(rand_point, polygon):
			var too_close = false
			var min_dist = 10
			for p :Vector2 in points:
				if rand_point.distance_to(p) < min_dist:
					too_close = true
					break
			if too_close:
				continue
			points.append(rand_point)
			if points.size() >= num_points:
				break
	return PackedVector2Array(points)

func find_path(nodes: Array[Node2D]) -> Array[Node2D]:
	if nodes.size() < 2:
		return nodes
		
	var unvisited = nodes.duplicate()
	var ordered_nodes : Array[Node2D] = []
	
	var start_index = 0
	var min_score = INF
	
	for i in range(unvisited.size()):
		var p = unvisited[i].position
		var score = p.x + p.y 
		if score < min_score:
			min_score = score
			start_index = i
			
	var current_node = unvisited.pop_at(start_index)
	ordered_nodes.append(current_node)
	
	while not unvisited.is_empty():
		var closest_dist_sq = INF
		var closest_index = -1
		
		for i in range(unvisited.size()):
			var d = current_node.position.distance_squared_to(unvisited[i].position)
			if d < closest_dist_sq:
				closest_dist_sq = d
				closest_index = i
		
		current_node = unvisited.pop_at(closest_index)
		ordered_nodes.append(current_node)
	
	# will probably need validation to ensure no crisscrossing
	return ordered_nodes
	
func find_path_between(start: Vector2, end: Vector2, points: PackedVector2Array) -> PackedVector2Array:
	var path = PackedVector2Array()
	path.append(start)
	
	var unvisited = points.duplicate()
	var current_pos = start
	
	while not unvisited.is_empty():
		var closest_dist_sq = INF
		var closest_index = -1
		
		for i in range(unvisited.size()):
			var d = current_pos.distance_squared_to(unvisited[i])
			if d < closest_dist_sq:
				closest_dist_sq = d
				closest_index = i
		current_pos = unvisited[closest_index]
		path.append(current_pos)
		unvisited.remove_at(closest_index)
	path.append(end)
	return path

func find_best_end_point(candidates: PackedVector2Array, next_zone: Node2D) -> Vector2:
	var border_line : Line2D = next_zone.get_node_or_null("DistortBorder")
	if not border_line:
		border_line = next_zone.get_node_or_null("Border")
	if not border_line or candidates.is_empty():
		return candidates[candidates.size() - 1]
		
	var border_points = border_line.points
	
	var best_p = candidates[0]
	var min_dist = INF
	
	for p in candidates:
		for bp in border_points:
			var global_bp = bp + next_zone.position
			var d = p.distance_squared_to(global_bp)
			if d < min_dist:
				min_dist = d
				best_p = p
	return best_p
#endregion

#region ui callbacks
func _on_poi_spin_box_value_changed(value: float) -> void:
	update_ui()

func _on_areas_spin_box_value_changed(value: float) -> void:
	num_locations = value
	update_ui()

func _on_regenerate_button_pressed() -> void:
	generate()

func _on_show_paths_toggled(toggled_on: bool) -> void:
	show_paths = not toggled_on
	update_ui()
	
func lod_update(zoomIndex : int):
	lod = zoomIndex
	update_ui()
#endregion
