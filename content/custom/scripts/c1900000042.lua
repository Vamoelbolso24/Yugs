-- Weather Condition - Sandstorm (Continuous Spell)
-- Destroy this card during your 5th End Phase after its activation.
-- Rock monsters gain 1500 DEF.
-- During the Standby Phase: Each player that doesn't control a Rock monster loses 500 LP.
-- PATTERN: "destroy during your Nth End Phase" = a turn counter on the card (see Pokemon.AddWeatherActivation).
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddWeatherActivation(c)   -- activation + "destroy during your 5th End Phase" (custom_utility.lua)
	-- Rock monsters (both players') gain 1500 DEF
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD)
	e2:SetCode(EFFECT_UPDATE_DEFENSE)
	e2:SetRange(LOCATION_SZONE)
	e2:SetTargetRange(LOCATION_MZONE,LOCATION_MZONE)
	e2:SetTarget(function(e,c) return c:IsRace(RACE_ROCK) end)
	e2:SetValue(1500)
	c:RegisterEffect(e2)
	-- Each Standby Phase (both players' turns): lose 500 LP if you have no Rock monster
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_F)   -- mandatory, it shows as an activation
	e3:SetCode(EVENT_PHASE+PHASE_STANDBY)
	e3:SetRange(LOCATION_SZONE)
	e3:SetCountLimit(1)
	e3:SetCondition(function(e,tp) return s.norock(0) or s.norock(1) end)
	e3:SetOperation(s.lpop)
	c:RegisterEffect(e3)
end
function s.norock(p)
	return not Duel.IsExistingMatchingCard(aux.FaceupFilter(Card.IsRace,RACE_ROCK),p,LOCATION_MZONE,0,1,nil)
end
function s.lpop(e,tp)
	if not e:GetHandler():IsRelateToEffect(e) then return end
	for p=0,1 do
		if s.norock(p) then Duel.SetLP(p,Duel.GetLP(p)-500) end   -- "lose LP" (not damage)
	end
end
