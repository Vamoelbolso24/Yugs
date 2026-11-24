-- Substitute (Equip Spell)
-- Pay 1500 LP: Equip this card to a Pokemon monster you control.
-- The equipped monster cannot be targeted by your opponent's card effects, also if it would be destroyed by
-- battle or by an opponent's card effect, you can destroy this card instead.
-- PATTERN: aux.AddEquipProcedure(c, 0 = your monsters, filter, nil, cost). Effects on the equipped monster
-- use EFFECT_TYPE_EQUIP. (Replacement like Light Ball, c1900000039.lua.)
local s,id=GetID()
function s.initial_effect(c)
	aux.AddEquipProcedure(c,0,aux.FilterBoolFunction(Card.IsSetCard,SET_POKEMON),nil,Cost.PayLP(1500))
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_EQUIP)
	e1:SetCode(EFFECT_CANNOT_BE_EFFECT_TARGET)
	e1:SetValue(aux.tgoval)                    -- your opponent's effects
	c:RegisterEffect(e1)
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_EQUIP+EFFECT_TYPE_CONTINUOUS)
	e2:SetCode(EFFECT_DESTROY_REPLACE)
	e2:SetTarget(s.reptg)
	e2:SetOperation(function(e) Duel.Destroy(e:GetHandler(),REASON_EFFECT|REASON_REPLACE) end)
	c:RegisterEffect(e2)
end
function s.reptg(e,tp,eg,ep,ev,re,r,rp,chk)
	local c=e:GetHandler()
	local tc=c:GetEquipTarget()
	if chk==0 then
		if not tc or tc:IsReason(REASON_REPLACE) or c:IsStatus(STATUS_DESTROY_CONFIRMED) then return false end
		return tc:IsReason(REASON_BATTLE) or (tc:IsReason(REASON_EFFECT) and rp==1-tp)
	end
	return Duel.SelectEffectYesNo(tp,c,96)    -- "destroy this card instead?"
end
