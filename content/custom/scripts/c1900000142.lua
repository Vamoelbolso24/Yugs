-- Seel
-- While "Rain Dance" is on the field, this card cannot be targeted by your opponent's card effects.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCode(EFFECT_CANNOT_BE_EFFECT_TARGET)
	e1:SetCondition(function() return Pokemon.IsOnField(CARD_RAIN_DANCE) end)
	e1:SetValue(aux.tgoval)
	c:RegisterEffect(e1)
end
s.listed_names={CARD_RAIN_DANCE}
