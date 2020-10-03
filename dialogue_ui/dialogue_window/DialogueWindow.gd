class_name DialogueWindow, "res://dialogue_engine/assets/icons/icon_dialogue_window.svg"
extends GridContainer


signal parsed_descriptions


const NARRATOR = "Narrator"

# The id of the default speaker
# Most of the times, this will be the Player
# The speaker for each individual part in this dialogue can still be specified but this is the assumed default
export(String) var default_speaker = "Player"

# Array of everyone else who is always participating in the dialogue
# If someones joins later during the conversation, they do not belong here from the start
export(Array, String) var default_listeners = []

# Path in the file system to where all the dialogue options are stored
export(String, FILE, "*.json") var dialogue_options_file_path = "res://data/dialogues/dialogue_options.json"

# Whether the current dialogue options are already being shown while the dialogue message is still being spoken
export(bool) var quick_show_options = false


# References to the parts of this scene
onready var _speaker_name = $speaker_name
onready var _description_field = $description_field
onready var _dialogue_tree = $options_tree


# Dictionary for all the dialogue options available
var _dialogue_options: Dictionary

# The current dialogue tree the conversation is in at the moment
var _current_dialogue: Dictionary
# A stack of all the dialogue trees to manage returning to previous trees and opening new ones to your heart's content
var _current_tree_stack: Array
# The curent dialogue options available
var _current_options: Dictionary
# If this conversation has just been started
var _first_time = true




# Called when the node enters the scene tree for the first time.
func _ready():
	_dialogue_options = JSONHelper.load_json(dialogue_options_file_path)
	
	_dialogue_tree.connect("choice_made", self, "switch_tree")
	
	connect("parsed_descriptions", self, "parse_options")




# Handles switchting from conversation to conversation
func switch_dialogue(new_dialogue: Dictionary, new_tree = CONSTANTS.DEFAULT_TREE):
	_current_dialogue = new_dialogue
	# Pushes the new tree on the tree stack to be able to always return here after entering new trees
	_current_tree_stack.push_front(new_tree)
	
	parse_tree()



# Handles switching from tree to tree inside the same conversation
# This is also used to return to the same tree again after going through the entire text message of a dialogue option
#	by 'switching' to the same tree again
# This is done to create as few exceptions as possible when handling new or old dialogue information
func switch_tree(update: Dictionary):
	var new_tree = update.get("new_tree", "")
	
	if not new_tree == "" and not new_tree == _current_tree_stack.front():
		# Pushes the new tree on the tree stack to be able to always return here after entering new trees
		_current_tree_stack.push_front(new_tree)
	elif update.get("is_back_option", false):
		# Returns to the previous tree on the stack if a back option is selected
		_current_tree_stack.pop_front()
	
	parse_tree(update)



# Parses the new information from the new tree
func parse_tree(update: Dictionary = { }):
	var dialogue = _current_dialogue.get(_current_tree_stack.front(), { })
	
	# Get the message from the new tree
	var new_message:Array = update.get("message", [ ])
	# Get the gretting from the new tree if this is the first time this tree has been called
	var greeting_message:Array = dialogue["greeting"] if _first_time else [ ]
	# Get the message from the current conversation
	var message = dialogue["message"]
	
	_first_time = false 
	# Use the message from the current conversation if there is not custom information given
	new_message = (greeting_message + message) if new_message.empty() else new_message
	
	_current_options = update.get("options", dialogue.get("options", { }))
	# Type out the new information
	# Duplicate to not corrupt the actual message data
	parse_descriptions(new_message.duplicate())



# Show the message resulting from the dialogue option or tree switch
func parse_descriptions(descriptions: Array):
	# Remove the first element to be parsed and the rest to be parsed 'recursively' later
	var new_description:Dictionary = descriptions.pop_front()
	# Update the meta data of the message
	update_speaker(new_description.get("speaker", ""))
	update_description(new_description["text"])
	
	# Wait for the text being displayed fully before displaying the dialogue options or not
	if not quick_show_options:
		yield(_description_field, "finished_typing")
	
	# Create a CONTINUE_OPTION and add it as a dialogue option if the message is not over yet
	# Give the rest of the message as description info to the CONTINUE_OPTION
	# Not exactly, but basically recurse through the message array without returning
	if not descriptions.empty():
		var continue_info = DialogueOption.CONTINUE_JSON
		continue_info["success_messages"] = [descriptions]
		
		_dialogue_tree.add_option(CONSTANTS.CONTINUE_OPTION, continue_info)
	else:
		emit_signal("parsed_descriptions")



# Display the current speaker if there is one
func update_speaker(speaker):
	if not speaker == null:
		# If the speaker is an index for all-purpose dialogue, get the corresponding speaker
		if typeof(speaker) == TYPE_REAL:
			var participants = [NARRATOR, default_speaker] + default_listeners
			speaker = participants[min(int(speaker), participants.size() - 1)]
		
		if not _speaker_name.text == speaker + ":":
			_speaker_name.type_text("[right]<%s:>[/right]" % [speaker] if speaker.length() > 0 else "")
	else:
		_speaker_name.text = ""



func update_description(description):
	if not description == null:
		_description_field.update_description({ "message": description })



# Display the dialogue options under the description
func parse_options(options: Dictionary = _current_options):
	var has_option:Dictionary = { }
	
	for option_id in options.keys():
		var option_info: Dictionary = _dialogue_options.get(option_id, DialogueOption.CUSTOM_JSON)
		
		# Check for dialogue option types
		var type = option_info.get("type", option_id)
		has_option[type] = has_option.get(type, 0) + 1
		# Check for tree change
		for tree_change in options[option_id].keys():
			option_info[tree_change] = options[option_id][tree_change]
		
		_dialogue_tree.add_option(type, option_info)
	
	# Add an EXIT_OPTION if we are currently in a main tree to leave the conversation and there is currently no other EXIT_OPTION
	if not _current_dialogue[_current_tree_stack.front()].get("sub_tree", false):
		if not has_option.get(CONSTANTS.EXIT_OPTION, 0) > 0:
			_dialogue_tree.add_option(CONSTANTS.EXIT_OPTION)
	else:
		# Add a BACK_OPTION if we are currently in a subtree and there is no other BACK_OPTION
		if not has_option.get(CONSTANTS.BACK_OPTION, 0) > 0:
			_dialogue_tree.add_option(CONSTANTS.BACK_OPTION)
	
	_dialogue_tree.update_list_numbers()
