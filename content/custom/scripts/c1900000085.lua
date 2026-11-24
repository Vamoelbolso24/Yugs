-- Primeape
-- Evolution Summon from "Mankey" (hard once per turn).
-- Negate the effects of monsters destroyed by battle with this card.
-- PATTERN: at the end of damage calculation (EVENT_BATTLED) the monster it battled is already marked
-- "destroyed by battle"; negate it before it leaves, and keep the negation in the GY (RESETS_STANDARD_EXC_GRAVE),
-- so effects like "if this card is sent to the GY" can't be used.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000084)   -- from Mankey

	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
	e1:SetCode(EVENT_BATTLED)
	e1:SetOperation(function(e)
		local bc=e:GetHandler():GetBattleTarget()
		if not (bc and bc:IsStatus(STATUS_BATTLE_DESTROYED)) then return end
		for _,code in ipairs({EFFECT_DISABLE,EFFECT_DISABLE_EFFECT}) do
			local e2=Effect.CreateEffect(e:GetHandler())
			e2:SetType(EFFECT_TYPE_SINGLE)
			e2:SetCode(code)
			e2:SetReset(RESET_EVENT|RESETS_STANDARD_EXC_GRAVE)
			bc:RegisterEffect(e2)
		end
	end)
	c:RegisterEffect(e1)
end
s.listed_names={1900000084}
