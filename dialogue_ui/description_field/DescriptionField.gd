class_name DescriptionField, "res://dialogue_engine/assets/icons/icon_description_field.svg"
extends TypingLabel


func update_description(update:Dictionary):
	var new_description = update.get("message", "")
	
	if not new_description == "":
		type_text(new_description)
