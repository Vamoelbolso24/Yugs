-- Weather Condition - Sunny Day (Continuous Spell)
-- Destroy this card during your 5th End Phase after its activation.
-- FIRE monsters gain 300 ATK, also WATER monsters lose 300 ATK.
-- (Same countdown as Sandstorm: Pokemon.AddWeatherActivation in custom_utility.lua.)
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddWeatherActivation(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_UPDATE_ATTACK)
	e1:SetRange(LOCATION_SZONE)
	e1:SetTargetRange(LOCATION_MZONE,LOCATION_MZONE)   -- both players' monsters
	e1:SetTarget(function(e,c) return c:IsAttribute(ATTRIBUTE_FIRE) end)
	e1:SetValue(300)
	c:RegisterEffect(e1)
	local e2=e1:Clone()
	e2:SetTarget(function(e,c) return c:IsAttribute(ATTRIBUTE_WATER) end)
	e2:SetValue(-300)
	c:RegisterEffect(e2)
end
