extends Node
class_name DialogueCharacters

var character_nodes:Dictionary

onready var character_jsons:Dictionary = FileHelper.list_files_in_directory(CONSTANTS.CHARACTERS_JSON, true, ".char", true) setget , get_character_jsons


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func register_character(character_id:String, character_node:DialogueCharacter):
	character_nodes[character_id] = character_node

func unregister_character(character_id:String):
	character_nodes.erase(character_id)


func get_character_jsons() -> Dictionary:
	return character_jsons
