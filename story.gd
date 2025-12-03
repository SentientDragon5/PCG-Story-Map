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
var element_names = [
	"lock", "combat", "puzzle", "parkour",
	"chest", "key", "item",
	"landmark", "village",
	"escort", "fetch"
]
var element_weights = PackedFloat32Array([
	0.25, 0.25, 0.25, 0.25,
	1.0, 0.0, 0.0,
	0.8, 0.2,
	0.5, 0.5
])

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
	"verdant": Color.DARK_GREEN,
	"lustrous": Color.ORANGE_RED,
	"prismatic": Color.DARK_ORCHID,
	"pale": Color.DIM_GRAY,
	"sanguine": Color.DARK_RED,
	"verdigris": Color.TEAL,
	"sapphire": Color.ROYAL_BLUE,
	"ruby": Color.CRIMSON,
	"dark": Color.DARK_SLATE_GRAY,
	"antiquitus": Color.DARK_SLATE_BLUE
}
var current_colors

var story = []

var min_story_blocks:
	get:
		var a = $"../CanvasLayer/FoldableContainer/VBoxContainer/POIContainer/POIMinSpinBox".value
		var b = $"../CanvasLayer/FoldableContainer/VBoxContainer/POIContainer/POIMaxSpinBox".value
		return min(a, b)
var max_story_blocks:
	get:
		var a = $"../CanvasLayer/FoldableContainer/VBoxContainer/POIContainer/POIMinSpinBox".value
		var b = $"../CanvasLayer/FoldableContainer/VBoxContainer/POIContainer/POIMaxSpinBox".value
		return max(a, b)

var areas
var id = 0

var biomeRng : RandomNumberGenerator:
	get:
		return $"..".biomeRng
var storyBlockRng : RandomNumberGenerator:
	get:
		return $"..".storyBlockRng
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
	for i in range(areas_count):
		# add area
		var area = {}
		var color = current_colors[biomeRng.randf_range(0,current_colors.size())]
		current_colors.erase(color)
		var biome = current_biomes[biomeRng.randf_range(0,current_biomes.size())]
		#current_biomes.erase(biome)
		# Were nil ^
		#  "area " + str(i) + " " + 
		area["name"] = color + " " + biome
		area["color"] = color_map[color]
		area["story"] = get_area_story()
		story.append(area)
	
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
		array.insert(storyBlockRng.randi_range(0,index), constrained + str(id))
	id += 1
	return array

func get_area_story() -> Array:
	var c_story = []
	var blocks_count = storyBlockRng.randi_range(min_story_blocks, max_story_blocks)
	while c_story.size() < blocks_count:
		var chunk = element_names[storyBlockRng.rand_weighted(element_weights)]
		c_story = insert_element(chunk, c_story)
		#c_story.append(chunk)
	return c_story
