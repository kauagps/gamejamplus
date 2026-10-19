class_name Menu
extends Control

# =====================================================================
# MENU INICIAL — a primeira coisa que o jogo mostra.
#
# Ele é uma CENA PRÓPRIA e é a cena principal do projeto (project.godot,
# run/main_scene). O JOGAR troca pra cenas/Main.tscn e o "voltar ao menu"
# da pausa troca de volta pra cá — por isso cada partida nasce DO ZERO:
# a cutscene do avião e a abertura do dia 1 tocam de novo.
#
# A ARTE (assets/ui) é uma sheet por estado, lado a lado — a mesma ideia
# das sheets do HUD (assets/ui/ui.tres), só que aqui quem fatia é o próprio
# TextureButton: cada botão tem dois AtlasTexture, o normal (escuro) e o
# hover (claro, com a setinha ▶ dentro do quadro).
#
# O título são 4 quadros de sangue escorrendo (assets/ui/titulo.tres), com
# loop = false: toca uma vez e para no último, com as gotas no chão.
# =====================================================================

const CENA_DO_JOGO: String = "res://cenas/Main.tscn"

# O nome da animação dentro de assets/ui/titulo.tres (o sangue escorrendo).
const NOME_DA_ANIMACAO_DO_TITULO: String = "escorrendo"

# A que altura da tela (em pixels) o TOPO da arte do título fica, e a altura
# de UM quadro da sheet (527x102 — ver titulo.tres). O centro do título é
# calculado a partir disso.
const TOPO_DO_TITULO: float = 60.0
const ALTURA_DO_QUADRO: float = 102.0

@onready var titulo: AnimatedSprite2D = $Titulo


func _ready() -> void:
	_centralizar_o_titulo()

	# Os botões têm âncora (o Godot reposiciona sozinho em qualquer
	# resolução), mas o título é Node2D e não tem: se a janela mudar de
	# tamanho, ele precisa ser recentrado na mão.
	get_tree().root.size_changed.connect(_centralizar_o_titulo)

	# Igual à cutscene do avião (Cutscene.gd faz quadros.play()): quem manda
	# tocar é o código. A propriedade `autoplay` do nó existe, mas deixar as
	# duas ligadas é pedir pra ninguém saber quem começou a animação.
	titulo.play(NOME_DA_ANIMACAO_DO_TITULO)


# O AnimatedSprite2D desenha centrado na própria position, então o centro do
# quadro vai pro meio da tela na horizontal e em TOPO_DO_TITULO + meia altura
# na vertical — assim o topo da arte encosta exatamente em TOPO_DO_TITULO.
func _centralizar_o_titulo() -> void:
	var tela: Vector2 = get_viewport_rect().size
	var altura_desenhada: float = ALTURA_DO_QUADRO * titulo.scale.y
	titulo.position = Vector2(tela.x * 0.5, TOPO_DO_TITULO + altura_desenhada * 0.5)


# =====================================================================
# OS BOTÕES (ligados no Menu.tscn, aba Node > Signals)
# =====================================================================
func _on_jogar_pressed() -> void:
	# O Status é AUTOLOAD: ele NÃO morre quando a cena é trocada. Sem este
	# reiniciar, a segunda partida nasceria com a fome e a sanidade que
	# sobraram da primeira — é o mesmo cuidado que o game_over tem antes de
	# recomeçar (ver Status.reiniciar).
	Status.reiniciar()
	get_tree().change_scene_to_file(CENA_DO_JOGO)


func _on_sair_pressed() -> void:
	get_tree().quit()
