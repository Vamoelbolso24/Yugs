-- Weather Condition - Rain Dance (Continuous Spell)
-- This card's name is also treated as "Umi" while face-up on the field.
-- Destroy this card during your 5th End Phase after its activation.
-- WATER monsters gain 300 ATK, also FIRE monsters lose 300 ATK.
-- PATTERN: "also treated as <card>" = EFFECT_ADD_CODE (like the real "A Legendary Ocean").
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddWeatherActivation(c)
	-- Also "Umi" while face-up
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e1:SetCode(EFFECT_ADD_CODE)
	e1:SetRange(LOCATION_SZONE)
	e1:SetValue(CARD_UMI)
	c:RegisterEffect(e1)
	-- WATER +300, FIRE -300 (both players' monsters)
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD)
	e2:SetCode(EFFECT_UPDATE_ATTACK)
	e2:SetRange(LOCATION_SZONE)
	e2:SetTargetRange(LOCATION_MZONE,LOCATION_MZONE)
	e2:SetTarget(function(e,c) return c:IsAttribute(ATTRIBUTE_WATER) end)
	e2:SetValue(300)
	c:RegisterEffect(e2)
	local e3=e2:Clone()
	e3:SetTarget(function(e,c) return c:IsAttribute(ATTRIBUTE_FIRE) end)
	e3:SetValue(-300)
	c:RegisterEffect(e3)
end
s.listed_names={CARD_UMI}
