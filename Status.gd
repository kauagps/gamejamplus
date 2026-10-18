extends Node

#sinais para avisar a UI quando um valor muda
signal vida_alterada(valor_atual: float, valor_maximo: float)
signal fome_alterada(valor_atual: float, valor_maximo: float)
signal sanidade_alterada(valor_atual: float, valor_maximo: float)

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
	sanidade = clamp(sanidade + quantidade, 0.0, sanidade_maximo)
	sanidade_alterada.emit(sanidade, sanidade_maximo)


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

func _process(delta: float) -> void:
	if fome > 0.0:
		# Com o estômago cheio, quem sofre é a barriga
		if taxa_fome_por_segundo > 0.0:
			mudar_fome(-taxa_fome_por_segundo * delta)
		return

	# De barriga vazia, quem sofre é a cabeça
	if taxa_sanidade_com_fome_zero > 0.0 and sanidade > 0.0:
		mudar_sanidade(-taxa_sanidade_com_fome_zero * delta)
