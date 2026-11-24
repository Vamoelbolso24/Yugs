-- Doduo (Gemini)
-- Treated as a Normal Monster while face-up on the field or in the GY. While a Normal Monster on the field, you
-- can Normal Summon it to have it become an Effect Monster with this effect:
-- * It can make a second attack during each Battle Phase.
-- (Gemini pattern: same as Fearow, c1900000030.lua.)
local s,id=GetID()
function s.initial_effect(c)
	Gemini.AddProcedure(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetCode(EFFECT_EXTRA_ATTACK)
	e1:SetCondition(Gemini.EffectStatusCondition)
	e1:SetValue(1)
	c:RegisterEffect(e1)
end
