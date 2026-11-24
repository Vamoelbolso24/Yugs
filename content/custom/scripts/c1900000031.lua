-- Route 1 (Field Spell)
-- All Normal WIND Winged Beast and Normal EARTH Beast monsters gain 300 ATK, and if they attack a
-- Defense Position monster, inflict piercing battle damage.
-- If such a monster declares an attack, the defending player cannot activate Spell/Trap Cards
-- until the end of the Damage Step.
-- PATTERN: a Field Spell's continuous effects = EFFECT_TYPE_FIELD effects with SetRange(LOCATION_FZONE).
local s,id=GetID()
function s.initial_effect(c)
	-- Activate (put it on the field)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	c:RegisterEffect(e1)
	-- +300 ATK to every matching monster (both players')
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD)
	e2:SetCode(EFFECT_UPDATE_ATTACK)
	e2:SetRange(LOCATION_FZONE)
	e2:SetTargetRange(LOCATION_MZONE,LOCATION_MZONE)   -- (my monsters, opponent's monsters)
	e2:SetTarget(function(e,c) return s.filter(c) end)
	e2:SetValue(300)
	c:RegisterEffect(e2)
	-- Piercing for the same monsters
	local e3=e2:Clone()
	e3:SetCode(EFFECT_PIERCE)
	e3:SetValue(1)
	c:RegisterEffect(e3)
	-- Spell/Trap lock: when ANY matching monster attacks, the DEFENDING player is locked.
	-- EFFECT_CANNOT_ACTIVATE with SetTargetRange(me,opponent) picks which player it hits,
	-- so we make two copies: one locks the opponent (when my monster attacks),
	-- the other locks me (when the opponent's monster attacks).
	local e4=Effect.CreateEffect(c)
	e4:SetType(EFFECT_TYPE_FIELD)
	e4:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
	e4:SetCode(EFFECT_CANNOT_ACTIVATE)
	e4:SetRange(LOCATION_FZONE)
	e4:SetTargetRange(0,1)   -- locks my opponent...
	e4:SetValue(function(e,re,tp) return re:IsHasType(EFFECT_TYPE_ACTIVATE) end)
	e4:SetCondition(function(e) return s.attacking(e:GetHandlerPlayer()) end)   -- ...while MY monster attacks
	c:RegisterEffect(e4)
	local e5=e4:Clone()
	e5:SetTargetRange(1,0)   -- locks me...
	e5:SetCondition(function(e) return s.attacking(1-e:GetHandlerPlayer()) end)   -- ...while the OPPONENT's monster attacks
	c:RegisterEffect(e5)
end
-- true if a matching monster controlled by player p is currently attacking
function s.attacking(p)
	local a=Duel.GetAttacker()
	return a and a:IsControler(p) and s.filter(a)
end
function s.filter(c)
	return c:IsFaceup() and c:IsType(TYPE_NORMAL)
		and ((c:IsAttribute(ATTRIBUTE_WIND) and c:IsRace(RACE_WINGEDBEAST)) or (c:IsAttribute(ATTRIBUTE_EARTH) and c:IsRace(RACE_BEAST)))
end
