extends Node2D
class_name Story

var elements = [
	"obstacle",
	"reward",
	"respite",
	"quest"
]

var element_types = [
	["lock",0.25], ["combat",0.25], ["puzzle",0.25], ["parkour",0.25],
	["chest", 1.0], ["key",0.0], ["item",0.0],
	["landmark",0.8], ["village",0.2],
	["escort",0.5], ["fetch",0.5]
]

var add_constraints = {
	"reward" : ["combat", "puzzle", "parkour"],
	"lock" : ["key"],
	"fetch" : ["item"],
	"escort" : ["combat"]
}

var biomes = [
	"plateau",
	"fields",
	"wastes",
	"forest",
	"ridge",
	"jungle"
]
var current_biomes

var colors = [
	"verdant",
	"lustrous",
	"prismatic",
	"pale",
	"sanguine",
	"verdigris",
	"sapphire",
	"ruby",
	"dark",
	"antiquitus"
]
var color_map = {
	"verdant": Color.FOREST_GREEN,
	"lustrous": Color.GOLD,
	"prismatic": Color.AZURE,
	"pale": Color.LIGHT_GRAY,
	"sanguine": Color.DARK_RED,
	"verdigris": Color.TEAL,
	"sapphire": Color.ROYAL_BLUE,
	"ruby": Color.CRIMSON,
	"dark": Color.DARK_SLATE_GRAY,
	"antiquitus": Color.BURLYWOOD
}
var current_colors

var story = []

@export var min_story_blocks = 4
@export var max_story_blocks = 6

var areas

var id = 0

#func _ready() -> void:
	#generate()
	#
#func _unhandled_input(_event: InputEvent) -> void:
	#if Input.is_action_just_pressed("regenerate"):
		#generate()
	
func generate(areas_count: int):
	# reset
	story.clear()
	for c in $VBoxContainer.get_children():
		c.queue_free()
	current_colors = colors.duplicate()
	current_biomes = biomes.duplicate()
	id = 0
	
	# start
	story.append("start")
	for i in range(areas_count):
		# add area
		var area = {}
		var color = current_colors.pick_random()
		current_colors.erase(color)
		var biome = current_biomes.pick_random()
		current_biomes.erase(biome)
		# Were nil ^
		area["name"] = "area " + str(i)# + " " + color + " " + biome
		area["story"] = get_area_story()
		story.append(area)
	story.append("end")
	
	print(story)
	
	for c in story:
		var label = Label.new()
		label.modulate = Color.BLACK
		if c is String:
			label.text = c
		elif c is Dictionary:
			label.text = c["name"]
		$VBoxContainer.add_child(label)
		if c is Dictionary:
			var hbox = HBoxContainer.new()
			$VBoxContainer.add_child(hbox)
			
			for d in c["story"]:
				if d is String:
					var sub_label = Label.new()
					sub_label.modulate = Color.DIM_GRAY
					sub_label.text = d
					hbox.add_child(sub_label)

func insert_element(element : String, array : Array) -> Array:
	var index = array.size()
	array.append(element + str(id))
	if element in add_constraints:
		var constrained = add_constraints[element].pick_random()
		array.insert(randi_range(0,index), constrained + str(id))
	id += 1
	return array

# nested array of Array containting Array of string [0] and weight [1]
func pick_weighted_random(array : Array) -> String:
	var total_weight: float = 0.0
	for entry in array:
		total_weight += entry[1]
	var r: float = randf_range(0.0, total_weight)
	for entry in array:
		r -= entry[1]
		if r <= 0:
			return entry[0]
	return array.back()[0]

func get_area_story() -> Array:
	var c_story = []
	var blocks_count = randi_range(min_story_blocks, max_story_blocks)
	while c_story.size() < blocks_count:
		var chunk = pick_weighted_random(element_types)
		c_story = insert_element(chunk, c_story)
		#c_story.append(chunk)
	return c_story
