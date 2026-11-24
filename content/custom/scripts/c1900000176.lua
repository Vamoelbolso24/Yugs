-- Weezing
-- Evolution Summon from "Koffing" (hard once per turn).
-- Once per turn: You can place 1 Poison Counter on up to 2 monsters on the field.
-- If this card is destroyed and sent to the GY: Inflict 1000 damage to your opponent.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000175)   -- from Koffing
	Pokemon.AddPoisonTwo(c,0)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_DAMAGE)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e1:SetCode(EVENT_TO_GRAVE)
	e1:SetCondition(function(e) local c=e:GetHandler() return c:IsReason(REASON_DESTROY) and c:IsPreviousLocation(LOCATION_ONFIELD) end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_DAMAGE,nil,0,1-tp,1000)
	end)
	e1:SetOperation(function(e,tp) Duel.Damage(1-tp,1000,REASON_EFFECT) end)
	c:RegisterEffect(e1)
end
s.listed_names={1900000175}
