class_name LuzGlobal
extends CanvasModulate

# =====================================================================
# LUZ DO DIA — o "anoitecer procedural": o mapa vai mudando de cor
# conforme a hora, sem pulos.
#
# A ideia: em vez de trocar de cor de repente (branco -> azul), a cor é
# AMOSTRADA de um Gradient. Gradient é uma "régua de cores": você marca
# pontos nela (as paradas) e o Godot mistura uma cor na outra sozinho.
#
# O "momento do dia" vai de 0.0 a 1.0 e significa:
#
#     0.00  = amanhecer (o dia acaba de começar)
#     0.50  = anoitecer  (metade do ciclo)
#     1.00  = fim da noite (e volta a ser 0.00)
#
# Como cada parada é uma FRAÇÃO do ciclo, mudar o wait_time do
# TimerDiaNoite no Inspector estica o céu junto: nada aqui está em
# segundos, então não existe número pra reajustar em código.
#
# Quem sabe as horas é o Main (dono do TimerDiaNoite); este nó só
# transforma o número em cor (regra do projeto: call down, signal up).
#
# OBS 1: CanvasModulate MULTIPLICA as cores do que está na camada dele.
#        Branco (1,1,1) = não pinta nada. Por isso a "tarde normal" é
#        branco: não é uma cor, é a ausência de pintura.
# OBS 2: a HUD vive numa CanvasLayer própria, então ela NÃO escurece
#        junto com o mapa. Isso é intencional: às 3 da manhã o jogador
#        ainda precisa ler a barra de fome.
# =====================================================================


## A régua de cores do dia. Edite no Inspector: clique no Gradient pra
## abrir o editor e ARRASTE as paradas/cores com o mouse.
@export var gradiente: Gradient


func _ready() -> void:
	if gradiente == null:
		push_warning("LuzGlobal: nenhum gradiente definido, o mapa fica sem cor.")
		return

	# Nasce com a cor do amanhecer (senão o 1º frame do jogo pisca branco).
	# O Main já corrige no _process dele logo em seguida.
	definir_momento_do_dia(0.0)


## Pinta o mapa pra um instante do ciclo. O Main chama isso a cada frame.
## momento: 0.0 = amanhecer, 0.5 = anoitecer, 1.0 = fim da noite.
func definir_momento_do_dia(momento: float) -> void:
	if gradiente == null:
		return

	color = gradiente.sample(clampf(momento, 0.0, 1.0))
