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

@export var margin = 60
@export var min_distance = 80
@export var num_locations = 30
@export var max_attempts_per_location = 50

@onready var sample_label: Label = $SampleLabel

var tree_walked : Array[Label] = []

func _ready() -> void:
	generate()
	
func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("regenerate"):
		generate()

func _process(_delta: float) -> void:
	var mouse_pos = get_local_mouse_position()
	sample_label.position = mouse_pos + Vector2(15, 15)
	
	var closest_zone = get_closest_zone(mouse_pos)
	if closest_zone:
		sample_label.text = closest_zone.text
	else:
		sample_label.text = "..."

func generate():
	await make_locations()
	name_locations()
	await make_borders()

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
		var label = Label.new()
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
		
		if not current_cell_polys.is_empty():
			var final_points = current_cell_polys[0]
			#final_points.append(final_points[0])
			
			var line = Line2D.new()
			line.name = "Bounds"
			line.points = final_points
			line.width = 4.0
			line.default_color = Color.BLACK;
			line.closed = true;
			#line.default_color = zone.modulate
			line.default_color.a = 0.5 
			zone.add_child(line)
			line.global_position = Vector2.ZERO

func get_closest_zone(point: Vector2) -> Label:
	var min_dist_sq = INF
	var closest_zone: Label = null
	
	for zone in locations.get_children():
		if not zone is Label:
			continue
		var dist_sq = point.distance_squared_to(zone.position)
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			closest_zone = zone
	return closest_zone
