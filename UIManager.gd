# UIManager.gd
extends Node

var interactable_bench: CraftingBench = null

func set_interactable_bench(bench: CraftingBench):
	interactable_bench = bench

func clear_interactable_bench():
	interactable_bench = null

func is_interactable() -> bool:
	return interactable_bench != null
