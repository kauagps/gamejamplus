class_name CutsceneTerror
extends CanvasLayer

# =====================================================================
# CUTSCENE DE TERROR — a virada da noite do DIA 2 pro DIA 3.
#
# Onde ela entra: dentro do dormir(), DEPOIS da vinheta fechar (tela preta) e
# NO LUGAR do cartão da madrugada daquela noite. Quando ela termina, o
# dormir() segue o fluxo normal e o dia 3 amanhece.
#
# A sequência (é um relâmpago, não um jump scare de música):
#
#   1) a tela já está preta (a vinheta do sono) e o nó "Preto" garante que
#      nada do mundo apareça por um frame;
#   2) o SOM começa no escuro. O estrondo.mp3 tem 0,5s de ronco crescendo
#      antes do estouro — foi medido com sonda (AudioEffectCapture) — e é
#      justamente esse aviso no breu que dá o medo;
#   3) no estouro: CLARÃO branco. O branco sobe rápido e desce mais devagar,
#      e é na descida que a IMAGEM aparece no lugar dele: um relâmpago
#      revelando a cena, não um corte seco;
#   4) a imagem fica parada o tempo combinado (dá pra ver o varal, a lua
#      mordida, o sorriso);
#   5) o SEGUNDO clarão fecha a cena — com um segundo estouro, mais baixo e
#      já sem o ronco (é susto, não aviso) — e tudo volta ao preto. Aí o
#      dormir() abre a pálpebra no dia 3.
#
# Todos os tempos e volumes são @export: afinar no Inspector não exige mexer
# em código. Regra do projeto: call down, signal up (a Main é a dona do fluxo).
# =====================================================================


## Onde, no arquivo, está o ESTOURO. Medido na sonda: o pico do estrondo.mp3
## é em 0,50s. É neste ponto que o clarão bate, por isso o primeiro play()
## começa em 0 (com o ronco) e o segundo já corta direto pro estouro.
@export_range(0.0, 1.5, 0.01) var estouro_em: float = 0.45

## O ronco antes do primeiro clarão (o arquivo tem ~0,45s de ronco crescente).
@export_range(0.0, 2.0, 0.05) var atraso_do_estouro: float = 0.45

## A forma do clarão: sobe num piscar e desce como um relâmpago apagando.
@export_range(0.01, 0.5, 0.01) var subida_do_clarao: float = 0.05
@export_range(0.05, 1.5, 0.01) var descida_do_clarao: float = 0.28

## Quanto tempo a imagem de terror fica na tela, parada.
@export_range(0.2, 6.0, 0.1) var duracao_da_imagem: float = 1.6

## Um respiro de preto depois do segundo clarão, antes de o dia amanhecer
## (é o silêncio depois do susto).
@export_range(0.0, 2.0, 0.05) var pausa_final: float = 0.25

## Volume do primeiro estouro e do segundo (o segundo é mais abafado).
@export_range(-40.0, 6.0, 0.5) var volume_db: float = -2.0
@export_range(-40.0, 6.0, 0.5) var volume_do_segundo_estouro_db: float = -9.0

@onready var imagem: TextureRect = $Imagem
@onready var branco: ColorRect = $Branco
@onready var estrondo: AudioStreamPlayer = $Estrondo


func _ready() -> void:
	# Nasce fora de cena e com a imagem escondida: quem liga é o mostrar().
	visible = false
	imagem.visible = false
	branco.color.a = 0.0


## Roda a cutscene inteira e SÓ TERMINA quando ela acabar.
##
## Chame com a tela JÁ PRETA (o dormir() fecha a vinheta antes) — a cena
## assume o preto a partir daí e devolve o preto no fim.
func mostrar() -> void:
	visible = true
	imagem.visible = false
	branco.color.a = 0.0

	# 1) O ronco começa no escuro.
	estrondo.volume_db = volume_db
	estrondo.play()
	await _esperar(atraso_do_estouro)

	# 2) O primeiro clarão revela a imagem: o branco sobe e, na descida, o
	#    que aparece atrás dele não é o preto — é a cena de terror.
	imagem.visible = true
	await _piscar_a_tela()

	# 3) A imagem fica parada. É o único momento em que o jogador vê algo.
	await _esperar(duracao_da_imagem)

	# 4) O segundo clarão fecha o dia. A imagem sai ANTES do clarão, senão
	#    ela reapareceria na descida do branco em vez de voltar o breu.
	imagem.visible = false
	estrondo.volume_db = volume_do_segundo_estouro_db
	estrondo.play(estouro_em)
	await _piscar_a_tela()

	# 5) O silêncio depois do susto: o estouro morre junto com a cena (senão
	#    ele vazaria por cima do vento da manhã nova).
	var tween: Tween = create_tween()
	tween.tween_property(estrondo, "volume_db", -45.0, pausa_final)
	await _esperar(pausa_final)

	estrondo.stop()
	visible = false


func _piscar_a_tela() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(branco, "color:a", 1.0, subida_do_clarao)
	tween.tween_property(branco, "color:a", 0.0, descida_do_clarao)
	await tween.finished


func _esperar(segundos: float) -> void:
	if segundos <= 0.0:
		return
	await get_tree().create_timer(segundos).timeout


func _exit_tree() -> void:
	# Fecha o som se a cena morrer no meio (ex: sair do jogo). Mesmo cuidado
	# dos outros nós de áudio do projeto: nada de playback vazando no exit.
	if estrondo != null and estrondo.playing:
		estrondo.stop()
