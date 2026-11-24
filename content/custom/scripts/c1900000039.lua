-- Light Ball (Equip Spell)
-- Equip only to a "Pikachu" monster. It gains ATK equal to its original ATK, also if it attacks a Defense
-- Position monster, inflict piercing battle damage. If the equipped monster would be destroyed, banished,
-- or returned to the hand or Deck by a card effect, you can banish this card instead.
-- PATTERN: Equip Spells = aux.AddEquipProcedure(c,nil,filter) + EFFECT_TYPE_EQUIP effects.
-- "...you can banish this card instead" = replacement effects (DESTROY_REPLACE / SEND_REPLACE).
local s,id=GetID()
function s.initial_effect(c)
	aux.AddEquipProcedure(c,nil,aux.FilterBoolFunction(Card.IsSetCard,SET_PIKACHU))
	-- ATK + its original ATK (= doubles it)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_EQUIP)
	e1:SetCode(EFFECT_UPDATE_ATTACK)
	e1:SetValue(function(e,ec) return ec:GetBaseAttack() end)
	c:RegisterEffect(e1)
	-- Piercing
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_EQUIP)
	e2:SetCode(EFFECT_PIERCE)
	c:RegisterEffect(e2)
	-- Instead of the monster being destroyed by a card effect
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_EQUIP+EFFECT_TYPE_CONTINUOUS)
	e3:SetCode(EFFECT_DESTROY_REPLACE)
	e3:SetTarget(s.desreptg)
	c:RegisterEffect(e3)
	-- Instead of the monster being banished or returned to the hand/Deck by a card effect
	local e4=Effect.CreateEffect(c)
	e4:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e4:SetCode(EFFECT_SEND_REPLACE)
	e4:SetRange(LOCATION_SZONE)
	e4:SetTarget(s.sendreptg)
	-- Which card was protected. (Light Ball has already left the field by the time this is asked,
	-- so the target function remembers the monster in the effect's "label object".)
	e4:SetValue(function(e,tc) return tc==e:GetLabelObject() end)
	c:RegisterEffect(e4)
end

function s.canReplace(c)
	return c:IsAbleToRemove() and not c:IsStatus(STATUS_DESTROY_CONFIRMED)
end
function s.desreptg(e,tp,eg,ep,ev,re,r,rp,chk)
	local c=e:GetHandler()
	local ec=c:GetEquipTarget()
	if chk==0 then return ec and ec:IsReason(REASON_EFFECT) and not ec:IsReason(REASON_REPLACE) and s.canReplace(c) end
	if Duel.SelectEffectYesNo(tp,c,96) then           -- "Use the effect of Light Ball?"
		Duel.Remove(c,POS_FACEUP,REASON_EFFECT+REASON_REPLACE)
		return true
	end
	return false
end
function s.sendreptg(e,tp,eg,ep,ev,re,r,rp,chk)
	local c=e:GetHandler()
	local ec=c:GetEquipTarget()
	if chk==0 then
		return ec and eg:IsContains(ec) and (r&REASON_EFFECT)~=0 and (r&REASON_REPLACE)==0
			and ec:GetDestination()&(LOCATION_HAND|LOCATION_DECK|LOCATION_EXTRA|LOCATION_REMOVED)~=0
			and s.canReplace(c)
	end
	e:SetLabelObject(ec)                           -- remember the protected monster (see SetValue above)
	if Duel.SelectEffectYesNo(tp,c,96) then
		Duel.Remove(c,POS_FACEUP,REASON_EFFECT+REASON_REPLACE)
		return true
	end
	return false
end
