class_name GameOver
extends CanvasLayer

# =====================================================================
# GAME OVER — a tela final, quando a sanidade do John apaga de vez.
#
# Ele é irmão do CartaoHistoria:
#   - vive numa CanvasLayer acima de tudo (layer 120: mais que a vinheta,
#     que é 100, e mais que o cartão da madrugada, que é 110)
#   - tem um `mostrar()` que SÓ TERMINA quando o jogador aperta E
#   - quem manda aparecer é a Main (dona do fluxo do jogo)
#
# Os textos de baixo são provisórios: troque à vontade no Main.tscn.
#
# Detalhe que veio do cartão da madrugada e vale repetir: se o E já estava
# APERTADO quando a cabeça apagou (ex: o jogador estava segurando o E pra
# pegar um item), ele precisa SOLTAR e apertar de novo — senão a tela final
# passaria sozinha no primeiro frame e ninguém leria o GAME OVER.
# =====================================================================

@onready var caixa: PanelContainer = $Caixa
@onready var aviso: Label = $Caixa/Coluna/Aviso

var _tween_aviso: Tween = null


func _ready() -> void:
	# Nasce escondido: só aparece quando a Main chama o mostrar()
	caixa.visible = false


## Mostra o GAME OVER e SÓ TERMINA quando o jogador aperta E.
## O Main espera (await) por isto pra recomeçar o jogo.
func mostrar() -> void:
	caixa.visible = true

	# Surge devagar: aqui não é um susto, é uma constatação
	caixa.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(caixa, "modulate:a", 1.0, 0.9)
	await tween.finished

	# O aviso piscando é o que ensina o que fazer agora
	aviso.visible = true
	aviso.modulate.a = 1.0
	_tween_aviso = create_tween().set_loops()
	_tween_aviso.tween_property(aviso, "modulate:a", 0.15, 0.7)
	_tween_aviso.tween_property(aviso, "modulate:a", 1.0, 0.7)

	# Se o E já estava apertado, espera soltar (ver o comentário do topo)
	while Input.is_action_pressed("interagir"):
		await get_tree().process_frame

	# ...e é aqui que o jogo espera: nada continua até um E de verdade
	while not Input.is_action_pressed("interagir"):
		await get_tree().process_frame

	if _tween_aviso != null:
		_tween_aviso.kill()
	aviso.visible = false
	caixa.visible = false
