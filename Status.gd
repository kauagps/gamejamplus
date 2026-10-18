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
