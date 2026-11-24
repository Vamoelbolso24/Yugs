-- Raichu
-- Evolution Summon from "Pikachu" (hard once per turn).
-- All WATER monsters your opponent controls lose 500 ATK/DEF.
-- This card can attack all WATER monsters your opponent controls, once each.
-- Negate the effects of WATER Flip monsters your opponent controls.
-- PATTERN: continuous effects on the opponent's monsters = EFFECT_TYPE_FIELD, SetTargetRange(0,LOCATION_MZONE).
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000034)   -- from Pikachu

	-- -500 ATK / DEF
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_UPDATE_ATTACK)
	e1:SetRange(LOCATION_MZONE)
	e1:SetTargetRange(0,LOCATION_MZONE)
	e1:SetTarget(function(e,c) return c:IsFaceup() and c:IsAttribute(ATTRIBUTE_WATER) end)
	e1:SetValue(-500)
	c:RegisterEffect(e1)
	local e2=e1:Clone()
	e2:SetCode(EFFECT_UPDATE_DEFENSE)
	c:RegisterEffect(e2)
	-- Attack every WATER monster once each
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_SINGLE)
	e3:SetCode(EFFECT_ATTACK_ALL)
	e3:SetValue(function(e,c) return c:IsAttribute(ATTRIBUTE_WATER) end)
	c:RegisterEffect(e3)
	-- Negate WATER Flip monsters
	local e4=Effect.CreateEffect(c)
	e4:SetType(EFFECT_TYPE_FIELD)
	e4:SetCode(EFFECT_DISABLE)
	e4:SetRange(LOCATION_MZONE)
	e4:SetTargetRange(0,LOCATION_MZONE)
	e4:SetTarget(function(e,c) return c:IsAttribute(ATTRIBUTE_WATER) and c:IsType(TYPE_FLIP) end)
	c:RegisterEffect(e4)
end
s.listed_names={1900000034}   -- mentions Pikachu (so Thunder Stone can find it)
