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
#
# "efeitos" (opcional) = o que acontece ao USAR o item no inventário
# (ex: { "fome": 50.0 } = comer e recuperar 50 de fome). Item sem
# "efeitos" é só material de construção — não dá pra usar.
#
# "solto" (opcional) = como o item fica quando é LARGADO no chão (tecla Q).
# Só é preciso quando a arte do chão não serve pra item largado — que é o
# caso da fruta (no chão ela é um arbusto de 64px; largada, uma frutinha).
# =====================================================================
const ITENS: Dictionary = {
	"madeira": {
		"sprite": preload("res://assets/items/W_Idle.png"),
		"icone": preload("res://assets/items/W_Idle.png"),
	},
	"comida": {
		"sprite": preload("res://assets/items/M_Idle.png"),
		"icone": preload("res://assets/items/M_Idle.png"),
		# "efeitos" = o que acontece ao USAR o item no inventário (clicar no slot).
		# Comer devolve fome. Repare no tamanho: a barra cai 100 por dia, então
		# 1 carne (50) = meio dia de comida.
		"efeitos": { "fome": 50.0 },
	},
	"pedra": {
		"sprite": preload("res://assets/items/pedra.png"),
		"icone": preload("res://assets/items/pedra.png"),
	},
	# Fruta: no chão ela NÃO é uma frutinha solta, e sim um ARBUSTO com
	# frutinhas (a mesma arte que se vê no mapa). Quem cuida da coleta é o
	# scripts/Arbustro.gd, que no fim troca a arte pelo arbusto comum.
	"fruta": {
		"sprite": preload("res://assets/mapa/arbustocomfruta.tres"),
		"icone": preload("res://assets/items/frutinha.tres"),
		# Largada no chão (Q) ela não pode virar um arbusto de 64px do nada:
		# cai a frutinha mesmo. O "zoom_sprite" existe porque o Item.tscn já
		# nasce escalado pras sheets de 128px — sem ele, os 12px da frutinha
		# viram 4 pixels na tela. Com 5x ela fica do tamanho dos outros itens
		# largados (madeira, pedra, carne).
		"solto": {
			"sprite": preload("res://assets/items/frutinha.tres"),
			"zoom_sprite": 5.0,
		},
		# Frutinha é lanche, não é o prato principal: recupera 1/5 do que a
		# carne recupera. Se quiser outro valor, é só mexer neste número.
		"efeitos": { "fome": 20.0 },
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

# O que acontece ao USAR o item (dicionário vazio = não dá pra usar)
static func efeitos(nome: String) -> Dictionary:
	if ITENS.has(nome) and ITENS[nome].has("efeitos"):
		return ITENS[nome]["efeitos"]
	return {}

# O item tem alguma utilidade dentro do inventário? (comer, curar...)
static func pode_usar(nome: String) -> bool:
	return not efeitos(nome).is_empty()

# Como o item fica LARGADO no chão (ver o comentário do topo).
# Dicionário vazio = "larga como o sprite do chão mesmo", que é o caso normal.
#   "sprite"      = textura do item largado (opcional)
#   "zoom_sprite" = multiplicador do sprite (opcional, padrão 1.0)
static func solto(nome: String) -> Dictionary:
	if ITENS.has(nome) and ITENS[nome].has("solto"):
		return ITENS[nome]["solto"]
	return {}
