class_name Item

extends Area2D

# O dropdown vem da lista do @export_enum (evita erro de digitação,
# já que toda a lógica compara itens por NOME)
@export_enum("madeira", "comida", "pedra") var nome_do_item: String = "madeira"

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# O sprite vem do catalálogo pelo NOME (fonte única de verdade).
	# Assim não precisamos de uma cena/script por item: é só duplicar o
	# nó Item.tscn na Main e trocar o Nome do Item no Inspector.
	var textura: Texture2D = CatalogoItens.sprite(nome_do_item)
	if textura:
		sprite.texture = textura
	else:
		push_warning("Item: o item '%s' não está no CatalogoItens!" % nome_do_item)

func esconder() -> void: 
	set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	queue_free()
