-- Dugtrio
-- Evolution Summon from "Diglett" (hard once per turn).
-- If this card is Normal or Special Summoned: It gains 800 ATK until the end of this turn, also if it battles
-- a Defense Position monster this turn, inflict piercing battle damage to your opponent.
-- Cards your opponent controls or in their hand cannot be Tributed, also, while your opponent controls a
-- monster, they cannot banish cards from their GY.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000078)   -- from Diglett
	Pokemon.AddNoTributeLock(c)

	-- On Summon: +800 ATK and piercing until the end of the turn (mandatory)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_ATKCHANGE)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e1:SetCode(EVENT_SUMMON_SUCCESS)
	e1:SetOperation(function(e)
		local c=e:GetHandler()
		if not (c:IsRelateToEffect(e) and c:IsFaceup()) then return end
		local e2=Effect.CreateEffect(c)
		e2:SetType(EFFECT_TYPE_SINGLE)
		e2:SetCode(EFFECT_UPDATE_ATTACK)
		e2:SetValue(800)
		e2:SetReset(RESETS_STANDARD_PHASE_END)
		c:RegisterEffect(e2)
		local e3=e2:Clone()
		e3:SetCode(EFFECT_PIERCE)
		e3:SetValue(1)
		c:RegisterEffect(e3)
	end)
	c:RegisterEffect(e1)
	local e4=e1:Clone()
	e4:SetCode(EVENT_SPSUMMON_SUCCESS)
	c:RegisterEffect(e4)
	-- Opponent can't banish from their GY while they control a monster
	local e5=Effect.CreateEffect(c)
	e5:SetType(EFFECT_TYPE_FIELD)
	e5:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
	e5:SetCode(EFFECT_CANNOT_REMOVE)
	e5:SetRange(LOCATION_MZONE)
	e5:SetTargetRange(0,1)                   -- affects your opponent
	e5:SetCondition(function(e) return Duel.GetFieldGroupCount(1-e:GetHandlerPlayer(),LOCATION_MZONE,0)>0 end)
	e5:SetTarget(function(e,c) return c:IsLocation(LOCATION_GRAVE) and c:IsControler(1-e:GetHandlerPlayer()) end)
	c:RegisterEffect(e5)
end
s.listed_names={1900000078}
