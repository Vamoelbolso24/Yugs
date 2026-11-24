-- Red's Pikachu
-- Cannot be Special Summoned. If this card attacks a Defense Position monster, inflict piercing
-- battle damage. If this card attacks, your opponent cannot activate Spell/Trap Cards until the
-- end of the Damage Step.
-- Can attack all monsters your opponent controls once each
local s,id=GetID()
function s.initial_effect(c)
	-- Cannot be Special Summoned
	local e1=Effect.CreateEffect(c)
	e1:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetCode(EFFECT_SPSUMMON_CONDITION)
	c:RegisterEffect(e1)
	-- Piercing damage
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetCode(EFFECT_PIERCE)
	c:RegisterEffect(e2)
	-- While this card is attacking, the opponent can't activate Spell/Trap Cards
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_FIELD)
	e3:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
	e3:SetCode(EFFECT_CANNOT_ACTIVATE)
	e3:SetRange(LOCATION_MZONE)
	e3:SetTargetRange(0,1)             -- (me, opponent): 0 = doesn't affect me, 1 = affects the opponent
	e3:SetValue(s.aclimit)             -- WHAT they can't activate
	e3:SetCondition(s.actcon)          -- WHEN the lock is on
	c:RegisterEffect(e3)
	-- Canattack all
	local e4=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetCode(EFFECT_ATTACK_ALL)
	e2:SetValue(1)
	c:RegisterEffect(e4)
	-- Negate effects
	local e5=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_FIELD)
	e3:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
	e3:SetCode(EFFECT_CANNOT_ACTIVATE)
	e3:SetRange(LOCATION_MZONE)
	e3:SetTargetRange(0,1)
	e3:SetValue(s.aclimit2)
	e3:SetCondition(s.actcon)
	c:RegisterEffect(e5)
end
-- What can't be activated: Spell/Trap cards being activated (not monster effects)
function s.aclimit(e,re,tp)
	return re:IsHasType(EFFECT_TYPE_ACTIVATE)
end
-- No monster effe
function s.aclimit2(e,re,tp)
	return re:IsMonsterEffect()
end
-- When: while this card is the attacking monster
function s.actcon(e)
	return Duel.GetAttacker()==e:GetHandler()
end

