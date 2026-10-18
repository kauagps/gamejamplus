class_name CatalogoItens
extends RefCounted

# =====================================================================
# CATÁLOGO DE ITENS — fonte única de verdade
#
# Para adicionar um item novo:
#   1) desenhe/escolha a arte e coloque em assets/items/
#   2) adicione UMA linha aqui embaixo
#   3) adicione o nome também no @export_enum do scripts/Item.gd
#      (é o que faz aparecer o dropdown no Inspector)
#
# "sprite" = imagem que aparece no CHÃO (Item.tscn)
# "icone"  = imagem que aparece no HUD (slot do inventário)
# Se for a mesma imagem, use o mesmo caminho nos dois.
# =====================================================================
const ITENS: Dictionary = {
	"madeira": {
		"sprite": preload("res://assets/items/W_Idle.png"),
		"icone": preload("res://assets/items/W_Idle.png"),
	},
	"comida": {
		"sprite": preload("res://assets/items/M_Idle.png"),
		"icone": preload("res://assets/items/M_Idle.png"),
	},
	"pedra": {
		"sprite": preload("res://assets/items/pedra.png"),
		"icone": preload("res://assets/items/pedra.png"),
	},
}

# Todos os nomes cadastrados (útil pra debug/validação)
static func nomes() -> Array:
	return ITENS.keys()

# Imagem do item no chão
static func sprite(nome: String) -> Texture2D:
	if ITENS.has(nome):
		return ITENS[nome]["sprite"]
	return null

# Imagem do item no HUD
static func icone(nome: String) -> Texture2D:
	if ITENS.has(nome):
		return ITENS[nome]["icone"]
	return null
