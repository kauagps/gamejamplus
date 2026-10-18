class_name Item

extends Area2D

@export var nome_do_item: String = "madeira"

func esconder() -> void: 
	set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	queue_free()
	
