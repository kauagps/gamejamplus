class_name Arbustro
extends Item

# =====================================================================
# ARBUSTO COM FRUTINHAS — um "item do chão" que não morre quando é colhido.
#
# Ele É um Item: mesma área, mesmo grupo "item", mesmo E, mesma animação de
# coleta. A ÚNICA diferença é o que acontece no fim: em vez de sumir, ele
# troca de arte e vira o arbusto comum (arbustro.png), e sai do grupo
# "item" pra ninguém mais conseguir interagir com ele.
#
# É de propósito: reaproveitando o Item inteiro, não existe um segundo
# sistema de coleta pra dar manutenção. O Player não sabe a diferença.
#
# A arte vem do CatalogoItens pelo nome "fruta":
#   sprite = quadro 0 da arbustocomfruta-Sheet  (o arbusto cheio de frutas)
#   icone  = quadro 1, recortado               (a frutinha no inventário)
# =====================================================================

## O arbusto já colhido (mesma arte dos arbustos pintados no mapa)
const ARBUSTO_VAZIO: Texture2D = preload("res://assets/mapa/arbustro.png")

## Deslocamento do sprite pra BASE do arbusto cair exatamente no nó: é ali
## que ele "pisa" no chão, e é o ponto que o y_sort usa pra decidir quem
## fica na frente (jogador atrás / arbusto na frente).
## São DOIS números porque nas duas artes a base está em alturas diferentes
## da imagem: a fruta tem conteúdo até y=40 e o arbusto vazio até y=48.
const BASE_COM_FRUTA: float = -8.0
const BASE_VAZIA: float = -16.0


func _ready() -> void:
	super()  # o Item veste o sprite pelo catálogo (fonte única de verdade)
	sprite.offset = Vector2(0.0, BASE_COM_FRUTA)


# Chamado pelo Player.pegar_item quando a coleta dá certo.
# Sobrescreve o Item.esconder (que sumiria com o nó).
func esconder() -> void:
	sprite.texture = ARBUSTO_VAZIO
	sprite.offset = Vector2(0.0, BASE_VAZIA)

	# Fora do grupo: o Player só procura alvo de E no grupo "item",
	# então o arbusto colhido deixa de ser interagível sozinho.
	remove_from_group("item")
