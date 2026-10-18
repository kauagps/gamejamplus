class_name CartaoHistoria
extends CanvasLayer

# =====================================================================
# CARTÃO DE HISTÓRIA — a "tela de texto" das viradas de dia.
#
# Ele é irmão da Vinheta:
#
#     Main.dormir():
#         await vinheta.fechar()                 # a tela escurece
#         await cartao.mostrar("Durante a madrugada, ...")   # espera o E
#         await vinheta.abrir()                  # amanhece
#
# Detalhe que importa: ele vive numa CanvasLayer com layer MAIOR que a da
# vinheta (100). Se fosse na HUD (layer 1), o texto apareceria ATRÁS do
# preto — a vinheta tapa a tela inteira quando está fechada.
#
# O "mostrar" pode ser ESPERADO (await): ele só termina quando o jogador
# aperta E. É isso que segura a escuridão o tempo que ele quiser ler.
# =====================================================================

@onready var caixa: PanelContainer = $Caixa
@onready var texto: Label = $Caixa/Coluna/Texto
@onready var aviso: Label = $Caixa/Coluna/Aviso

var _tween_aviso: Tween = null


func _ready() -> void:
	# Nasce escondido: só aparece quando a Main chama o mostrar()
	caixa.visible = false


## Mostra o cartão no meio da tela e SÓ TERMINA quando o jogador aperta E.
##
## Chame isto com o jogador travado (Main: jogador.em_cena = true), senão o
## mesmo toque de E que fecha o cartão também seria lido pelo mundo.
func mostrar(texto_da_historia: String) -> void:
	texto.text = texto_da_historia
	caixa.visible = true

	# Entra suave: a escuridão já está ali, o texto é que "surge"
	caixa.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(caixa, "modulate:a", 1.0, 0.6)
	await tween.finished

	# O aviso piscando é o que ENSINA o jogador que tem que apertar E
	aviso.visible = true
	aviso.modulate.a = 1.0
	_tween_aviso = create_tween().set_loops()
	_tween_aviso.tween_property(aviso, "modulate:a", 0.2, 0.6)
	_tween_aviso.tween_property(aviso, "modulate:a", 1.0, 0.6)

	# Se o E já estava APERTADO quando o cartão apareceu (ex: o jogador
	# segurou o E do abrigo), ele precisa soltar e apertar de novo — senão
	# o cartão fecharia sozinho no primeiro frame, sem ninguém ler.
	while Input.is_action_pressed("interagir"):
		await get_tree().process_frame

	# ...e é aqui que a história espera: nada acontece até um E de verdade.
	while not Input.is_action_pressed("interagir"):
		await get_tree().process_frame

	if _tween_aviso != null:
		_tween_aviso.kill()
	aviso.visible = false
	caixa.visible = false
