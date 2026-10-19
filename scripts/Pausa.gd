class_name Pausa
extends CanvasLayer

# =====================================================================
# PAUSA — o menuzinho do Esc.
#
# Ele é irmão do GameOver: vive numa CanvasLayer acima de tudo (layer 130,
# mais que a vinheta, o cartão, a cutscene de terror e o game over) e nasce
# escondido. Quem ABRE é a Main (dona do fluxo do jogo); quem fecha é ele
# mesmo — com Esc de novo, ou clicando em "Retomar o jogo".
#
# A PAUSA É DE VERDADE: get_tree().paused = true congela o jogo inteiro de
# uma vez — o timer do dia, a física, as ovelhas e até a fome e a sanidade,
# que correm no _process do Autoload Status. Sem isso, abrir o menu de noite
# seria uma forma de perder o jogo parado, vendo a sanidade escorrer.
#
# É por isso que o nó é PROCESS_MODE_WHEN_PAUSED (ver Pausa.tscn): pausado,
# ele é um dos ÚNICOS que continuam rodando — senão ninguém leria o Esc nem
# o clique nos botões, e a pausa viraria uma tela sem saída.
# =====================================================================

# Quem decide o que fazer com isso é a Main (dona do fluxo): aqui a gente só
# avisa que o jogador pediu pra voltar. Mesma ideia do dormir_solicitado do
# Player (call down, signal up).
signal voltar_ao_menu_solicitado

# O frame em que a pausa abriu. O Esc que ABRE não pode fechar no mesmo
# frame: os dois leem o mesmo Input no mesmo process. É exatamente o cuidado
# que o _atualizar_dialogo, na Main, tem com o E da conversa.
var _frame_do_esc: int = -1


func _ready() -> void:
	# Nasce fechado INTEIRO: `visible` na CanvasLayer esconde o Escurecer e a
	# Caixa de uma vez. Cuidado que já custou uma gameplay escura: esconder só
	# a Caixa deixava o Escurecer (um ColorRect de tela cheia) ligado por cima
	# do jogo desde o primeiro frame — uma máscara de 78% de preto no jogo
	# todo. A camada é a dona dos dois: quem manda nela, manda em tudo.
	visible = false


## Abre o menu e congela o jogo. Chamado pela Main, de dentro do _process.
func abrir() -> void:
	if visible:
		return  # dois Esc no mesmo frame não abrem duas vezes

	_frame_do_esc = Engine.get_process_frames()
	visible = true
	get_tree().paused = true


## Fecha o menu e devolve o jogo. Chamado pelo Esc, pelo botão "Retomar" e
## pelo "Voltar ao menu" — que precisa da árvore DESPAUSADA antes da troca de
## cena, porque o `paused` é do SceneTree e não da cena: se ficasse ligado, o
## menu inicial nasceria congelado.
func fechar() -> void:
	if not visible:
		return

	visible = false
	get_tree().paused = false


func _process(_delta: float) -> void:
	if not visible:
		return
	if Engine.get_process_frames() == _frame_do_esc:
		return  # este Esc é o que acabou de abrir o menu

	if Input.is_action_just_pressed("ui_cancel"):
		fechar()


# =====================================================================
# OS BOTÕES (ligados no Pausa.tscn, aba Node > Signals)
# =====================================================================
func _on_retomar_pressed() -> void:
	fechar()


func _on_voltar_ao_menu_pressed() -> void:
	fechar()
	voltar_ao_menu_solicitado.emit()
