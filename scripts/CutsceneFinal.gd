class_name CutsceneFinal
extends CanvasLayer

# =====================================================================
# CUTSCENE FINAL — o barco saindo da ilha (o fecho da demo)
#
# Irmã da Cutscene do avião (scripts/Cutscene.gd): mesma receita —
#   1) "Quadros" é um AnimatedSprite2D com os 20 quadros de 1920x1080 da
#      sheet do barco (assets/mapa/barcosaindo-01..20.png), rodando a
#      2 QUADROS POR SEGUNDO. A velocidade mora no SpriteFrames
#      (assets/mapa/barcosaindo.tres): dá pra mudar no editor, sem código;
#   2) "Som" toca o OndasOceano.mp3 junto (bus "Ambiente": o calar() da
#      Main cala o som do MUNDO, e o mar não é do mundo... é da cena);
#   3) a duração é a da ANIMAÇÃO — nada de tempo chutado no código. A Main
#      faz await mostrar() e espera o sinal animation_finished.
#
# O que ela faz de diferente da do avião: ela ENTRA e SAI em preto, porque
# o jogo está VIVO quando ela começa (na abertura, o mundo já nascia de
# olhos fechados). A sequência do mostrar():
#
#   preto .... o mundo escurece por baixo do "Preto" (a arte ainda escondida)
#   revela ... o mar aparece e o som do mar sobe junto
#   navega ... os 20 quadros (o barco cruzando o mar, com a esteira atrás)
#   preto .... escurece de novo e o som morre JUNTO (mar cortado seco é feio)
#
# O "Fundo" (cor do mar de verdade, medida na arte) existe por um caso real:
# a janela pode ser mais larga que 16:9 (barra de título, monitor estranho).
# O stretch "expand" então deixa o canvas mais largo que os 1920 da arte, e
# sem o Fundo o MUNDO apareceria numa faixa na borda — aconteceu na sonda.
# Ele só liga na revelação: antes disso quem manda na tela é o mundo de
# verdade, escurecendo.
#
# E fica por aí, com a tela preta: quem aparece depois é o CARTÃO do FIM
# (CartaoHistoria, camada 110) e quem manda no fluxo é a Main.
# Regra do projeto: call down, signal up.
# =====================================================================


## Volume do mar. O OndasOceano tem pico alto: nasce abaixo do 0 pra
## conversar com o que o ouvido do jogador já conhece (o vento vive em -4).
@export_range(-40.0, 6.0, 0.5) var volume_db: float = -6.0

## O mundo -> preto quando a cena entra: ela nasce no MEIO do jogo, e um
## corte seco de tela entregaria que tudo parou de repente.
@export_range(0.1, 2.0, 0.05) var duracao_do_escurecer: float = 0.5

## O preto -> mar da revelação (o som sobe mais devagar que isto).
@export_range(0.1, 2.0, 0.05) var duracao_da_revelacao: float = 0.6

## Quanto o som do mar leva pra subir e pra descer. Mais lento que a
## imagem de propósito: o ouvido aceita a cena chegando antes do som.
@export_range(0.1, 4.0, 0.05) var duracao_do_fade_do_som: float = 1.4

## O escurecimento final (aqui o som morre no MESMO tempo: é a cortina)
@export_range(0.1, 3.0, 0.05) var duracao_do_fade: float = 0.9

@onready var quadros: AnimatedSprite2D = $Quadros
@onready var preto: ColorRect = $Preto
@onready var som: AudioStreamPlayer = $Som
@onready var fundo: ColorRect = $Fundo


func _ready() -> void:
	# Nasce fora de cena: quem liga é o mostrar(). Sem isso, ela apareceria
	# por um frame por cima do mundo antes de a Main pedir.
	visible = false
	preto.color.a = 0.0
	fundo.visible = false
	quadros.visible = false


## Roda a cutscene inteira e SÓ TERMINA quando ela acabar.
##
## Chame com o mundo parado e o jogador travado (Main: em_cena = true +
## _parar_o_mundo()), senão o John anda e a fome corre durante a travessia.
## Ela devolve a tela PRETA de propósito: o cartão do FIM aparece nela.
func mostrar() -> void:
	visible = true
	preto.color.a = 0.0
	quadros.visible = false

	# O mar já começa a subir baixinho; quem sobe mesmo é na revelação.
	som.volume_db = -60.0
	som.play()

	# 1) O mundo escurece por baixo (a arte ainda não está na tela)
	var escurece: Tween = create_tween()
	escurece.tween_property(preto, "color:a", 1.0, duracao_do_escurecer)
	await escurece.finished

	# 2) O mar entra por baixo do preto, com o som subindo junto. O Fundo
	#    (cor do mar) cobre a sobra da janela que a arte não alcança.
	fundo.visible = true
	quadros.visible = true
	quadros.play()
	var revela: Tween = create_tween()
	revela.set_parallel(true)
	revela.tween_property(preto, "color:a", 0.0, duracao_da_revelacao)
	revela.tween_property(som, "volume_db", volume_db, duracao_do_fade_do_som)
	await revela.finished

	# 3) A travessia — quem manda na duração é a ANIMAÇÃO
	await quadros.animation_finished

	# 4) A cortina: escurece e o mar morre junto
	var fim: Tween = create_tween()
	fim.set_parallel(true)
	fim.tween_property(preto, "color:a", 1.0, duracao_do_fade)
	fim.tween_property(som, "volume_db", -60.0, duracao_do_fade)
	await fim.finished
	som.stop()
	# (não esconde nem limpa o preto: o cartão da Main aparece EM CIMA)


func _exit_tree() -> void:
	# Fecha o som se a cena morrer no meio (ex: sair do jogo). Mesmo cuidado
	# dos outros nós de áudio do projeto: nada de playback vazando no exit.
	if som != null and som.playing:
		som.stop()
