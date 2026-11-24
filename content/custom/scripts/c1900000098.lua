-- Poliwag
-- Cannot be destroyed by battle with WATER monsters.
-- While "Rain Dance" is on the field, this card can make a second attack during each Battle Phase.
-- FIXED: SetCondition used s.dircon, but the function was named s.sandcon, so the condition was nil
-- and the second attack was always on (both are now s.rainycon). The Rain Dance ID had an extra 0.

local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetCode(EFFECT_EXTRA_ATTACK)
	e1:SetCondition(s.rainycon)
	e1:SetValue(1)
	c:RegisterEffect(e1)
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetCode(EFFECT_INDESTRUCTABLE_BATTLE)
	e2:SetValue(s.batfilter)
	c:RegisterEffect(e2)
end
s.listed_names={1900000102}
-- Is a face-up "Rain Dance" anywhere on the field (either player's side)?
function s.rainycon(e)
	return Pokemon.IsOnField(1900000102)
end
function s.batfilter(e,c)
	return c:IsAttribute(ATTRIBUTE_WATER)
end
