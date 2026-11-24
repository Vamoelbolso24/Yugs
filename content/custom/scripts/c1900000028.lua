-- Raticate
-- Evolution Summon from "Rattata" (hard once per turn).
-- If this card attacks, during damage calculation: Roll a six-sided die, and if the result is 6,
-- this card gains 1000 ATK until the end of the Damage Step.
-- PATTERN: "during damage calculation" = EVENT_PRE_DAMAGE_CALCULATE. No "You can" = mandatory (TRIGGER_F).
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000027)   -- from Rattata

	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_DICE+CATEGORY_ATKCHANGE)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e1:SetCode(EVENT_PRE_DAMAGE_CALCULATE)
	e1:SetCondition(function(e) return Duel.GetAttacker()==e:GetHandler() end)
	e1:SetOperation(s.operation)
	c:RegisterEffect(e1)
end
s.listed_names={1900000027}

function s.operation(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if Duel.TossDice(tp,1)==6 and c:IsRelateToBattle() and c:IsFaceup() then
		local e1=Effect.CreateEffect(c)
		e1:SetType(EFFECT_TYPE_SINGLE)
		e1:SetCode(EFFECT_UPDATE_ATTACK)
		e1:SetValue(1000)
		e1:SetReset(RESET_EVENT|RESETS_STANDARD|RESET_PHASE|PHASE_DAMAGE)   -- until the end of the Damage Step
		c:RegisterEffect(e1)
	end
end
