# res://Data/PersonagemData.gd
class_name PersonagemData extends Resource

@export var nome: String = ""
@export var hp_max: int = 100
@export var defesa: int = 10
@export var massa: String = "" # "Corpuda", "Fina"
@export var classe: String = "" # "Suporte", "Atirador", "Linha de Frente", "Destruidora"
@export var habilidades: Array[HabilidadeData] = []
@export var effects: Dictionary
