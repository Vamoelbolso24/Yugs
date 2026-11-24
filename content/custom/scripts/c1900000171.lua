-- Hitmonlee
-- If you control a "Hitmon" monster, except "Hitmonlee", you can Special Summon this card (from your hand).
-- If a "Hitmon" monster you control attacks a Defense Position monster, inflict piercing battle damage.
local s,id=GetID()
function s.initial_effect(c)
	-- Special Summon from the hand (built-in, no limit)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_SPSUMMON_PROC)
	e1:SetProperty(EFFECT_FLAG_UNCOPYABLE)
	e1:SetRange(LOCATION_HAND)
	e1:SetCondition(function(e,c)
		if c==nil then return true end
		local tp=c:GetControler()
		return Duel.GetLocationCount(tp,LOCATION_MZONE)>0
			and Duel.IsExistingMatchingCard(function(tc) return tc:IsFaceup() and tc:IsSetCard(SET_HITMON) and not tc:IsCode(id) end,tp,LOCATION_MZONE,0,1,nil)
	end)
	c:RegisterEffect(e1)
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD)
	e2:SetRange(LOCATION_MZONE)
	e2:SetTargetRange(LOCATION_MZONE,0)
	e2:SetTarget(function(e,tc) return tc:IsSetCard(SET_HITMON) end)
	e2:SetCode(EFFECT_PIERCE)
	c:RegisterEffect(e2)
end
s.listed_series={SET_HITMON}
