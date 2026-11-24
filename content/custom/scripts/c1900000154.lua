-- Onix
-- If this card is attacked by a WATER or Plant monster, at the start of the Damage Step: Destroy this card.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_DESTROY)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e1:SetCode(EVENT_BATTLE_START)               -- start of the Damage Step
	e1:SetCondition(function(e)
		local a=Duel.GetAttacker()
		return Duel.GetAttackTarget()==e:GetHandler() and a and (a:IsAttribute(ATTRIBUTE_WATER) or a:IsRace(RACE_PLANT))
	end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_DESTROY,e:GetHandler(),1,0,0)
	end)
	e1:SetOperation(function(e)
		local c=e:GetHandler()
		if c:IsRelateToEffect(e) then Duel.Destroy(c,REASON_EFFECT) end
	end)
	c:RegisterEffect(e1)
end
