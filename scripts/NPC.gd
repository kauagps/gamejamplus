class_name NPC
extends StaticBody2D

# =====================================================================
# NPC — um personagem parado no mapa com quem dá pra conversar.
#
# O mesmo script serve pros três (criança, pai, rosa). O que muda de um
# pro outro são só estes campos, ajustados no Inspector de cada instância
# dentro da Main.tscn:
#
#   chave          = qual bloco de falas usar (o nome lá no Dialogos.gd)
#   nome_mostrado  = como o nome dele aparece na caixa de diálogo
#   frames         = o .tres do SpriteFrames (ex: assets/Player/rosa.tres)
#
# Por que "frames" em vez de já colocar o SpriteFrames no AnimatedSprite2D
# da cena: assim a instância sobrepõe UM campo do script, e não um nó lá
# dentro da cena. Fica bem mais fácil de trocar (e de ler no arquivo .tscn).
#
# Sobre a conversa (regra do projeto: call down, signal up):
#   o NPC não sabe nada sobre diálogo. Ele é só um alvo: a AreaConversa
#   entra no grupo "npc", o Player detecta e avisa a Main, e é a Main
#   (dona do dia_atual) que escolhe a fala e manda a HUD mostrar.
# =====================================================================


## A "chave" deste NPC no Dialogos.gd ("crianca", "pai" ou "rosa")
@export var chave: String = "crianca"

## O nome que aparece na caixa de diálogo
@export var nome_mostrado: String = "Criança"

## O SpriteFrames com a animação "parado" (2 quadros = respiração)
@export var frames: SpriteFrames

@onready var animacao: AnimatedSprite2D = $Animacao


func _ready() -> void:
	# A cena nasce sem SpriteFrames (cada instância tem o seu), então quem
	# toca a animação é este _ready, depois de receber os frames.
	if frames != null:
		animacao.sprite_frames = frames

	if animacao.sprite_frames != null and animacao.sprite_frames.has_animation("parado"):
		animacao.play("parado")
	else:
		push_warning("NPC '%s': sem SpriteFrames (ou sem a animação 'parado')." % chave)


## A imagem que a HUD usa como RETRATO na caixa de diálogo: é o próprio
## quadro 0 do sheet (uma AtlasTexture de 32x32), que a HUD amplia 4x.
## É a ideia de usar o sheet "como vetor": o mesmo desenho serve pro mapa
## e pro retrato, sem precisar de uma arte de retrato separada.
func retrato() -> Texture2D:
	if animacao.sprite_frames == null:
		return null
	if not animacao.sprite_frames.has_animation("parado"):
		return null
	return animacao.sprite_frames.get_frame_texture("parado", 0)
