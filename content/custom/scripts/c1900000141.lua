-- Dodrio (Gemini)
-- Evolution Summon from "Doduo" (hard once per turn).
-- Treated as a Normal Monster while face-up on the field or in the GY. While a Normal Monster on the field, you
-- can Normal Summon it to have it become an Effect Monster with this effect:
-- * It can make up to 3 attacks on monsters during each Battle Phase.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000140)   -- from Doduo
	Gemini.AddProcedure(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetCode(EFFECT_EXTRA_ATTACK_MONSTER)    -- extra attacks, only on monsters
	e1:SetCondition(Gemini.EffectStatusCondition)
	e1:SetValue(2)                              -- 1 normal attack + 2 more = 3
	c:RegisterEffect(e1)
end
s.listed_names={1900000140}
