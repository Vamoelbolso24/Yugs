-- Sandshrew
-- While "Weather Condition - Sandstorm" is on the field, this card cannot be targeted by your opponent's card effects
-- or for attacks, but does not prevent your opponent from attacking directly.
-- PATTERN: "cannot be targeted for attacks, but does not prevent direct attacks" = EFFECT_IGNORE_BATTLE_TARGET
-- (plain EFFECT_CANNOT_BE_BATTLE_TARGET would stop direct attacks too).
local s,id=GetID()
function s.initial_effect(c)
	-- Can't be targeted by the opponent's card effects
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCode(EFFECT_CANNOT_BE_EFFECT_TARGET)
	e1:SetCondition(s.sandcon)
	e1:SetValue(aux.tgoval)                -- aux.tgoval = "by your opponent's effects"
	c:RegisterEffect(e1)
	-- Can't be attacked (direct attacks still allowed)
	local e2=e1:Clone()
	e2:SetCode(EFFECT_IGNORE_BATTLE_TARGET)
	e2:SetValue(1)
	c:RegisterEffect(e2)
end
s.listed_names={CARD_SANDSTORM}
-- Is a face-up "Sandstorm" anywhere on the field (either player's side)?
function s.sandcon(e)
	return Pokemon.IsOnField(CARD_SANDSTORM)
end
