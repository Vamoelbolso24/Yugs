-- Gloom
-- Evolution Summon from "Oddish" (hard once per turn).
-- During your Standby Phase: Gain 500 LP, or 1000 LP instead if "Weather Condition - Sunny Day" is on the field.
-- During the Main Phase: You can place 1 Poison Counter on a monster your opponent controls.
-- You can only activate this effect of "Gloom" once per turn.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000061)   -- from Oddish
	Pokemon.EnablePoisonRule()

	-- Standby Phase LP gain (mandatory)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_RECOVER)
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_F)
	e1:SetCode(EVENT_PHASE+PHASE_STANDBY)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCountLimit(1)
	e1:SetCondition(function(e,tp) return Duel.IsTurnPlayer(tp) end)   -- YOUR Standby Phase
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_RECOVER,nil,0,tp,500)
	end)
	e1:SetOperation(function(e,tp)
		-- the amount is decided when it resolves
		Duel.Recover(tp,Pokemon.IsOnField(CARD_SUNNY_DAY) and 1000 or 500,REASON_EFFECT)
	end)
	c:RegisterEffect(e1)
	-- Poison Counter (not a target: chosen when it resolves)
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,0))
	e2:SetCategory(CATEGORY_COUNTER)
	e2:SetType(EFFECT_TYPE_IGNITION)
	e2:SetRange(LOCATION_MZONE)
	e2:SetCountLimit(1,id)                     -- hard once per turn
	e2:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(s.pfilter,tp,0,LOCATION_MZONE,1,nil) end
		Duel.SetOperationInfo(0,CATEGORY_COUNTER,nil,1,0,COUNTER_POISON)
	end)
	e2:SetOperation(function(e,tp)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_COUNTER)
		local tc=Duel.SelectMatchingCard(tp,s.pfilter,tp,0,LOCATION_MZONE,1,1,nil):GetFirst()
		if tc then tc:AddCounter(COUNTER_POISON,1) end
	end)
	c:RegisterEffect(e2)
end
s.listed_names={1900000061,CARD_SUNNY_DAY}
function s.pfilter(c) return c:IsFaceup() and c:IsCanAddCounter(COUNTER_POISON,1) end
