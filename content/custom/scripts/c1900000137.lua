-- Magneton
-- Evolution Summon from "Magnemite" (hard once per turn).
-- Your opponent cannot Special Summon Machine monsters.
-- Negate the effects of face-up Machine monsters your opponent controls.
-- The first time this card would be destroyed by battle each turn, it is not.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000136)   -- from Magnemite
	Pokemon.AddNoMachineSummon(c)
	Pokemon.AddBattleSurvive(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_DISABLE)
	e1:SetRange(LOCATION_MZONE)
	e1:SetTargetRange(0,LOCATION_MZONE)
	e1:SetTarget(function(e,tc) return tc:IsFaceup() and tc:IsRace(RACE_MACHINE) end)
	c:RegisterEffect(e1)
end
s.listed_names={1900000136}
