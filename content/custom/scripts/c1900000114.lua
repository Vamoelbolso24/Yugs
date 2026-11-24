-- Victreebel
-- Evolution Summon from "Weepingbell" (hard once per turn).
-- Once per turn, except the turn this card was Summoned: You can make it gain 400 ATK, also it cannot declare an
-- attack this turn.
-- If "Sunny Day" is on the field, this card gains: If this card attacks a Defense Position monster, inflict
-- double piercing battle damage.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000113)   -- from Weepingbell

	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_ATKCHANGE)
	e1:SetType(EFFECT_TYPE_IGNITION)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCountLimit(1)
	e1:SetCondition(function(e) local c=e:GetHandler() return not (c:IsStatus(STATUS_SUMMON_TURN) or c:IsStatus(STATUS_SPSUMMON_TURN) or c:IsStatus(STATUS_FLIP_SUMMON_TURN)) end)
	e1:SetOperation(function(e)
		local c=e:GetHandler()
		if not (c:IsRelateToEffect(e) and c:IsFaceup()) then return end
		local e2=Effect.CreateEffect(c)
		e2:SetType(EFFECT_TYPE_SINGLE)
		e2:SetCode(EFFECT_UPDATE_ATTACK)
		e2:SetValue(400)
		e2:SetReset(RESET_EVENT|RESETS_STANDARD)  -- permanent
		c:RegisterEffect(e2)
		local e3=Effect.CreateEffect(c)
		e3:SetType(EFFECT_TYPE_SINGLE)
		e3:SetCode(EFFECT_CANNOT_ATTACK_ANNOUNCE)
		e3:SetReset(RESETS_STANDARD_PHASE_END)
		c:RegisterEffect(e3)
	end)
	c:RegisterEffect(e1)
	-- Sunny Day: piercing, doubled
	local sunny=function() return Pokemon.IsOnField(CARD_SUNNY_DAY) end
	local e4=Effect.CreateEffect(c)
	e4:SetType(EFFECT_TYPE_SINGLE)
	e4:SetCode(EFFECT_PIERCE)
	e4:SetCondition(sunny)
	c:RegisterEffect(e4)
	local e5=Effect.CreateEffect(c)
	e5:SetType(EFFECT_TYPE_SINGLE)
	e5:SetCode(EFFECT_CHANGE_BATTLE_DAMAGE)
	e5:SetCondition(function(e)
		local bc=Duel.GetAttackTarget()
		return sunny() and Duel.GetAttacker()==e:GetHandler() and bc and bc:IsDefensePos()
	end)
	e5:SetValue(aux.ChangeBattleDamage(1,DOUBLE_DAMAGE))   -- only the opponent's damage is doubled
	c:RegisterEffect(e5)
end
s.listed_names={1900000113,CARD_SUNNY_DAY}
