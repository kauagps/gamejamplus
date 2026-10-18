class_name Cutscene
extends CanvasLayer

# =====================================================================
# CUTSCENE DE ABERTURA — o avião caindo (o prólogo, antes de tudo)
#
# Ela é filha da Main, como a Vinheta e o Cartão, e vive numa CanvasLayer
# ACIMA da vinheta (105 > 100). Isso não é capricho: o jogo nasce com a
# vinheta fechada (tela preta) e a cutscene é justamente o que aparece POR
# CIMA desse preto. Continua abaixo do Cartão (110) e do Game Over (120),
# que são coisas do fim do jogo.
#
# Como ela funciona:
#   1) "Quadros" é um AnimatedSprite2D com os 15 quadros de 1920x1080 da
#      sheet do avião (assets/mapa/aviaocaindo-01..15.png), rodando a
#      2 QUADROS POR SEGUNDO — essa velocidade mora no SpriteFrames
#      (assets/mapa/aviaocaindo.tres), não aqui, pra dar pra ajustar no
#      editor sem mexer em código;
#   2) "Som" toca o AviaoVoando.mp3 junto com o primeiro quadro;
#   3) quando a ANIMAÇÃO acaba, a tela escurece e a cena sai de cena.
#
# A DURAÇÃO da cena é a duração da ANIMAÇÃO: 15 quadros a 2 por segundo =
# 7,5s. Não existe tempo nenhum escrito no código: a Main espera o sinal
# "animation_finished". Se amanhã a sheet tiver 30 quadros, a cena cresce
# sozinha (e o som, que tem 33,6s, continua sendo cortado no fim).
#
# Quem manda é a Main (dona do fluxo): await cutscene.mostrar().
# Regra do projeto: call down, signal up.
# =====================================================================


## Volume do som do avião. O arquivo é um motor: deixar em 0 dB fica
## estourando em cima da ambiência depois, então ele nasce um pouco abaixo.
@export_range(-40.0, 6.0, 0.5) var volume_db: float = -4.0

## O escurecimento final. Ele também derruba o som junto: cortar motor seco
## fica feio, e o som original (33,6s) é bem mais longo que a animação.
@export_range(0.1, 3.0, 0.05) var duracao_do_fade: float = 0.9

@onready var quadros: AnimatedSprite2D = $Quadros
@onready var som: AudioStreamPlayer = $Som
@onready var preto: ColorRect = $Preto


func _ready() -> void:
	# Nasce fora de cena: quem liga é o mostrar(). Sem isso, a cutscene
	# apareceria por um frame por cima do mundo antes da Main pedir.
	visible = false
	preto.color.a = 0.0


## Roda a cutscene inteira e SÓ TERMINA quando ela acabar.
##
## Chame com o mundo parado e o jogador travado (Main: em_cena = true +
## _parar_o_mundo()), senão o John anda e a fome corre durante o prólogo —
## que é justamente o que a Main faz antes de chamar isto.
func mostrar() -> void:
	visible = true
	preto.color.a = 0.0

	som.volume_db = volume_db
	som.play()
	quadros.play()

	# Espera a ANIMAÇÃO, não um tempo chutado: é ela que manda na duração.
	await quadros.animation_finished

	# O avião terminou de cair (o último quadro é ele em parafuso). Escurece
	# e derruba o som junto, senão o motor continuaria berrando no escuro.
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(preto, "color:a", 1.0, duracao_do_fade)
	tween.tween_property(som, "volume_db", -60.0, duracao_do_fade)
	await tween.finished

	som.stop()
	visible = false


func _exit_tree() -> void:
	# Fecha o som se a cena morrer no meio (ex: sair do jogo). Mesmo cuidado
	# dos outros nós de áudio do projeto: nada de playback vazando no exit.
	if som != null and som.playing:
		som.stop()
