class_name Barco
extends StaticBody2D

# =====================================================================
# BARCO QUEBRADO — o objetivo final do jogo
#
# Estrutura da cena (a mesma do Abrigo, que é o molde de "coisa
# interagível" do projeto):
#
#   Barco (StaticBody2D, camada 1)   -> bloqueia o caminho, como a casa
#     CollisionShape2D               -> o casco (o "corpo" que empurra)
#     Sprite2D (offset negativo)     -> a arte, com a base batendo no nó
#     AreaBarco (Area2D, grupo "barco", monitoring = false)
#                                    -> é ELA que a AreaInteracao do Player
#                                       detecta; o Player sobe pro Barco
#                                       pelo get_parent() (igual ao NPC)
#
# Quem é dono de quê (pra não virar bagunça depois):
#   - o PLAYER sabe o que o jogador TEM (o inventário é dele)
#   - o BARCO sabe o que FALTA (necessário - entregue)
#   - a MAIN costura os dois quando o jogador aperta E (signal up)
#   - a HUD só desenha o painel que a Main manda mostrar (ela não decide nada)
#
# Ou seja: nada aqui mexe em inventário nem em tela.
# =====================================================================

# Quanto o barco precisa pra ficar pronto. Mexa aqui (ou no Inspector, que
# sai mais bonito pra quem não abre código) se quiser outros números.
@export var madeira_necessaria: int = 20
@export var pedra_necessaria: int = 10

# Quanto JÁ foi entregue. O que falta é a conta acima menos isto.
var madeira_entregue: int = 0
var pedra_entregue: int = 0

# Porta aberta pra quem quiser reagir na hora da entrega (som, faísca,
# animação de martelada...). Hoje ninguém escuta, e tudo bem.
signal material_alterado


func falta_madeira() -> int:
	return maxi(madeira_necessaria - madeira_entregue, 0)


func falta_pedra() -> int:
	return maxi(pedra_necessaria - pedra_entregue, 0)


func esta_pronto() -> bool:
	return falta_madeira() == 0 and falta_pedra() == 0


# Recebe o material que o jogador entregou. O excedente seria ignorado: a
# Main já manda no máximo o que falta, isto aqui é só cinto de segurança
# (o Barco não confia em quem chama).
func receber(madeiras: int, pedras: int) -> void:
	var usar_madeira: int = mini(madeiras, falta_madeira())
	var usar_pedra: int = mini(pedras, falta_pedra())
	if usar_madeira == 0 and usar_pedra == 0:
		return

	madeira_entregue += usar_madeira
	pedra_entregue += usar_pedra
	material_alterado.emit()
