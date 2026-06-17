class_name DiplomacyManager
extends Node

const RELATION_NEUTRAL := 0
const RELATION_ALLIED := 50
const RELATION_HOSTILE := -50


func can_offer_peace(relation_score: int, recent_attack: bool) -> bool:
	return relation_score >= RELATION_HOSTILE and not recent_attack


func can_form_alliance(relation_score: int, has_trade_agreement: bool) -> bool:
	return relation_score >= RELATION_ALLIED and has_trade_agreement


func peaceful_cell_resolution(cell, relation_score: int) -> Dictionary:
	var accepted: bool = relation_score >= 25 and cell != null and cell.owner_id != "bandits"
	return {
		"accepted": accepted,
		"cell_id": cell.id if cell != null else "",
		"reason": "local leaders accepted integration" if accepted else "local leaders refused integration",
	}
