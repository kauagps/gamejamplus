extends Node

#sinais para avisar a UI quando um valor muda
signal vida_alterada(valor_atual: float, valor_maximo: float)
signal fome_alterada(valor_atual: float, valor_maximo: float)
signal sanidade_alterada(valor_atual: float, valor_maximo: float)

# Avisa UMA vez, no instante em que a cabeça apaga de vez (é o game over).
# É um SINAL porque quem decide o que fazer com isso é a Main (dona do
# fluxo): o medidor só conta, ele não sabe o que é "fim de jogo".
signal sanidade_zerada

# Fome acima desta fração da barra mantém a cabeça sã; abaixo dela, a
# cabeça afunda (devagar). Com a barriga vazia, afunda de vez.
# É fração (e não "60" cravado) pra continuar valendo se o máximo mudar.
const LIMITE_DE_FOME_PARA_SANIDADE: float = 0.6

#valores atuais
var vida: float = 100.0
var vida_maximo: float = 100.0

var fome: float = 100.0
var fome_maximo: float = 100.0

var sanidade: float = 100.0
var sanidade_maximo: float = 100.0

#Função mudar vida (ex: Status.mudar_vida(-10.0) tira 10 de vida)
func mudar_vida(quantidade: float) -> void:
	vida = clamp(vida + quantidade, 0.0, vida_maximo)
	vida_alterada.emit(vida, vida_maximo)

#Função mudar fome (ex: Status.mudar_fome(-5.0) tira 5 de fome)
func mudar_fome(quantidade: float) -> void:
	fome = clamp(fome + quantidade, 0.0, fome_maximo)
	fome_alterada.emit(fome, fome_maximo)

#Função mudar sanidade (ex: Status.mudar_sanidade(-5.0))
func mudar_sanidade(quantidade: float) -> void:
	var antes: float = sanidade
	sanidade = clamp(sanidade + quantidade, 0.0, sanidade_maximo)
	sanidade_alterada.emit(sanidade, sanidade_maximo)

	# Cruzar o zero é o fim do jogo: avisa quem estiver escutando. Como as
	# taxas somam frações pequenas a cada frame, isto dispara UMA vez, no
	# frame em que a barra encosta no zero (e não a cada frame depois dele).
	if antes > 0.0 and sanidade <= 0.0:
		sanidade_zerada.emit()


# =====================================================================
# DESGASTE NATURAL (a fome caindo com o tempo)
#
# Quem CALCULA as taxas é o Main, porque só ele sabe quanto dura um dia
# no jogo (TimerDiaNoite). Aqui a gente só APLICA, frame a frame.
# =====================================================================

# Quantos pontos de fome caem por segundo
var taxa_fome_por_segundo: float = 0.0

# Quantos pontos de sanidade caem por segundo QUANDO a fome está zerada
var taxa_sanidade_com_fome_zero: float = 0.0

func definir_taxas_de_desgaste(fome_por_segundo: float, sanidade_com_fome_zero_por_segundo: float) -> void:
	taxa_fome_por_segundo = fome_por_segundo
	taxa_sanidade_com_fome_zero = sanidade_com_fome_zero_por_segundo


# --- A SANIDADE ANDA JUNTO COM A FOME (o eixo da mecânica de sanidade) ---
# Duas taxas, separadas pelo LIMITE_DE_FOME_PARA_SANIDADE:
#   "boa"   -> fome ACIMA do limite: a cabeça se recupera sozinha
#   "baixa" -> fome abaixo do limite (mas ainda maior que zero): ela sente
# Com a fome ZERADA vale a taxa_sanidade_com_fome_zero, que é mais cruel.
var taxa_sanidade_fome_boa: float = 0.0
var taxa_sanidade_fome_baixa: float = 0.0

func definir_taxas_de_sanidade_por_fome(com_fome_boa_por_segundo: float, com_fome_baixa_por_segundo: float) -> void:
	taxa_sanidade_fome_boa = com_fome_boa_por_segundo
	taxa_sanidade_fome_baixa = com_fome_baixa_por_segundo


# Quantos pontos de sanidade caem por segundo DURANTE A NOITE.
# Diferente das outras taxas, esta o Main LIGA e DESLIGA: ela vale enquanto
# o sol estiver posto e acaba no instante em que o jogador dorme.
# É o "relógio" da noite — a noite não tem mais tempo próprio, então é a
# sanidade escorrendo que empurra o jogador pra cama.
var taxa_sanidade_noturna: float = 0.0

func definir_taxa_sanidade_noturna(por_segundo: float) -> void:
	taxa_sanidade_noturna = por_segundo

func _process(delta: float) -> void:
	# 1) A NOITE corrói a sanidade. Esta taxa é ligada/desligada pelo Main:
	#    vale enquanto o sol estiver posto e acaba quando o jogador dorme.
	if taxa_sanidade_noturna > 0.0 and sanidade > 0.0:
		mudar_sanidade(-taxa_sanidade_noturna * delta)

	# 2) A fome cai o tempo todo (de dia e de noite)
	if taxa_fome_por_segundo > 0.0 and fome > 0.0:
		mudar_fome(-taxa_fome_por_segundo * delta)

	# 3) E o NÍVEL da fome é que manda na cabeça:
	if fome > fome_maximo * LIMITE_DE_FOME_PARA_SANIDADE:
		# Bem alimentado: a cabeça se recupera sozinha (devagar).
		# O "sanidade < máximo" evita ficar chamando a toa com a barra cheia.
		if taxa_sanidade_fome_boa > 0.0 and sanidade < sanidade_maximo:
			mudar_sanidade(taxa_sanidade_fome_boa * delta)
	elif fome > 0.0:
		# Comendo pouco: já dá pra sentir a cabeça pesando
		if taxa_sanidade_fome_baixa > 0.0 and sanidade > 0.0:
			mudar_sanidade(-taxa_sanidade_fome_baixa * delta)
	else:
		# De barriga vazia, quem sofre é a cabeça (e não é pouco)
		if taxa_sanidade_com_fome_zero > 0.0 and sanidade > 0.0:
			mudar_sanidade(-taxa_sanidade_com_fome_zero * delta)


# =====================================================================
# REINICIAR (o game over recomeça o jogo do zero)
# =====================================================================
# Isto precisa existir porque o Status é um AUTOLOAD: ele NÃO morre quando a
# cena é recarregada (get_tree().reload_current_scene()). Sem esta limpeza,
# o John renasceria com a fome e a sanidade que tinha na hora da morte — e
# morreria de novo no primeiro frame.
func reiniciar() -> void:
	# Todas as taxas voltam a zero: quem liga o mundo de novo é o Main,
	# depois que a cena nova terminar de nascer.
	taxa_fome_por_segundo = 0.0
	taxa_sanidade_com_fome_zero = 0.0
	taxa_sanidade_fome_boa = 0.0
	taxa_sanidade_fome_baixa = 0.0
	taxa_sanidade_noturna = 0.0

	vida = vida_maximo
	fome = fome_maximo
	sanidade = sanidade_maximo

	# Avisa a UI (hoje a cena é trocada logo depois, mas isto mantém as
	# barras coerentes em qualquer outro uso do reiniciar)
	vida_alterada.emit(vida, vida_maximo)
	fome_alterada.emit(fome, fome_maximo)
	sanidade_alterada.emit(sanidade, sanidade_maximo)
