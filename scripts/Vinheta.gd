class_name Vinheta
extends CanvasLayer

# =====================================================================
# VINHETA — a "pálpebra" do jogo: escurece a tela e abre de novo.
#
# Como isso funciona SEM shader e SEM arte nova:
#
#   1) O nó "Escuro" é um TextureRect que cobre a tela inteira.
#   2) A textura dele é um GradientTexture2D com preenchimento RADIAL:
#      um disco TRANSPARENTE no meio e PRETO fora dele.
#      (as paradas do gradiente ficam transparentes até a metade e só
#       escurecem no fim — é o que dá o degrade suave da borda)
#   3) O raio desse disco é o que a gente anima:
#        raio grande -> o disco cobre a tela -> nada escuro aparece
#        raio 0      -> tudo é "fora do disco" -> tela toda preta
#
# Ou seja: a vinheta não é uma imagem, é um CÍRCULO QUE ENCOLHE em volta
# da tela. Por isso o mesmo número (0.0 a 1.0) serve pros dois sentidos:
# deitar (0 -> 1, fecha) e acordar (1 -> 0, a vinheta inversa).
#
# Quem manda é o Main (dono do ciclo): vinheta.fechar() / vinheta.abrir().
# Regra do projeto: call down, signal up.
# =====================================================================


## Quanto tempo a tela leva pra fechar (deitar) e pra abrir (acordar).
## Estes dois números ficam no Inspector do nó, no Main.tscn.
@export var duracao_fechar: float = 0.8
@export var duracao_abrir: float = 1.0

## Raio do "buraco" transparente com a tela aberta, em pixels da textura.
## A textura tem 128x128 e o canto fica a ~90 pixels do centro, então
## 200 passa de longe dos cantos: neste valor NADA escuro aparece.
@export var raio_aberto: float = 200.0

@onready var textura: GradientTexture2D = $Escuro.texture as GradientTexture2D


func _ready() -> void:
	# Nasce com a tela limpa (senão o primeiro frame do jogo vem preto)
	_aplicar(0.0)


## Fecha a tela: a escuridão fecha em volta até cobrir tudo.
func fechar() -> void:
	await _animar(0.0, 1.0, duracao_fechar)


## Abre a tela: a vinheta inversa, a escuridão se abrindo do centro pra fora.
func abrir() -> void:
	await _animar(1.0, 0.0, duracao_abrir)


func _animar(de: float, para: float, duracao: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_method(_aplicar, de, para, duracao)
	await tween.finished


## progresso: 0.0 = tela limpa, 1.0 = tela toda preta
func _aplicar(progresso: float) -> void:
	if textura == null:
		return

	# O raio do gradiente radial É a distância entre fill_from e fill_to,
	# então mexer no fill_to é literalmente mexer no tamanho do buraco.
	var centro: Vector2 = Vector2(textura.width, textura.height) * 0.5
	var raio: float = lerpf(raio_aberto, 0.0, progresso)

	textura.fill_from = centro
	textura.fill_to = centro - Vector2(0.0, raio)
