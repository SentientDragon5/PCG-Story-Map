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

@export var margin = 60
@export var min_distance = 150
@export var num_locations = 10
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
	make_locations()
	make_borders()

# loosely based of https://editor.p5js.org/Cacarisse/sketches/vBSru9PBF
# Poisson Scatter
func make_locations():
	for c in locations.get_children():
		c.queue_free()

	var viewport_size = cam.get_viewport_rect().size
	
	for i in range(num_locations):
		for j in range(max_attempts_per_location):
			var candidate_pos = Vector2(
				randf_range(margin, viewport_size.x - margin),
				randf_range(margin, viewport_size.y - margin)
			) - viewport_size * 0.5
			
			var ok = true
			for c in locations.get_children():
				if candidate_pos.distance_to(c.position) < min_distance:
					ok = false
					break
			
			if ok:
				var zone = Label.new()
				zone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				var emotion_index = randi() % emotions.size()
				
				zone.text = places.pick_random() + " of " + emotions[emotion_index]
				zone.name = zone.text
				zone.modulate = emotion_colors[emotion_index]
				zone.position = candidate_pos
				
				locations.add_child(zone)
				break

func make_borders():
	var viewport_size = cam.get_viewport_rect().size
	var base_rect = Rect2(-viewport_size / 2, viewport_size)
	
	var base_poly = PackedVector2Array([
		base_rect.position,
		Vector2(base_rect.end.x, base_rect.position.y),
		base_rect.end,
		Vector2(base_rect.position.x, base_rect.end.y)
	])

	for zone in locations.get_children():
		if not zone is Label: continue
		var current_cell_polys = [base_poly] 
		for neighbor in locations.get_children():
			if zone == neighbor or not neighbor is Label: continue
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
			line.points = final_points
			line.width = 4.0
			line.default_color = Color.BLACK;
			line.closed = true;
			#line.default_color = zone.modulate
			line.default_color.a = 0.5 
			locations.add_child(line)
			locations.move_child(line, 0)

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
