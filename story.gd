extends Node2D

var elements = [
	"obstacle",
	"reward",
	"respite",
	"quest"
]

var element_types = [
	["lock", "combat", "puzzle", "parkour"],
	["tool", "ability", "lore", "collectable", "key"],
	["landmark"],
	["key", "escort", "fetch"]
]

var add_constraints = {
	"reward" : "obstacle",
	"lock" : "key",
	"fetch" : "collectable",
	"escort" : "combat"
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
var current_colors

var story = []

@export var min_story_blocks = 5
@export var max_story_blocks = 10

@export var min_areas = 2
@export var max_areas = 5

var areas_count
var areas

var id = 0

func get_obstacle():
	return "obstacle"
	
func _ready() -> void:
	generate()
	
func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("regenerate"):
		generate()
	
func generate():
	# reset
	story.clear()
	for c in $VBoxContainer.get_children():
		c.queue_free()
	current_colors = colors.duplicate()
	current_biomes = biomes.duplicate()
	id = 0
	
	# start
	story.append("start")
	areas_count = randi_range(min_areas, max_areas)
	for i in range(areas_count):
		var area = {}
		if i == 0:
			area["name"] = "tutorial"
			area["story"] = ["obstacle"]
		else:
			var color = current_colors.pick_random()
			current_colors.erase(color)
			var biome = current_biomes.pick_random()
			current_biomes.erase(biome)
			area["name"] = "area " + str(i) + " " + color + " " + biome
			area["story"] = get_area_story()
		story.append(area)
	story.append("end")
	
	print(story)
	
	for c in story:
		var label = Label.new()
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
					sub_label.text = d
					hbox.add_child(sub_label)

func insert_element(element : String, array : Array) -> Array:
	var index = array.size()
	array.append(element + str(id))
	if element in add_constraints:
		var constrained = add_constraints[element]
		array.insert(randi_range(0,index), constrained + str(id))
	id += 1
	return array

func get_area_story() -> Array:
	var c_story = []
	var blocks_count = randi_range(min_story_blocks, max_story_blocks)
	for i in range(blocks_count):
		var chunk = elements.pick_random()
		c_story = insert_element(chunk, c_story)
		#c_story.append(chunk)
	return c_story
