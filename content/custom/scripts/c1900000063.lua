-- Vileplume
-- Evolution Summon from "Gloom" (hard once per turn).
-- If "Weather Condition - Sunny Day" is on the field, this card gains 500 ATK, also it can attack all
-- monsters your opponent controls, once each.
-- During each Standby Phase: Gain 800 LP, or 1200 LP instead if "Weather Condition - Sunny Day" is on the field.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000062)   -- from Gloom
	Pokemon.EnablePoisonRule()                 -- its text reminds the Poison rule, so switch it on

	local sunny=function() return Pokemon.IsOnField(CARD_SUNNY_DAY) end
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCode(EFFECT_UPDATE_ATTACK)
	e1:SetCondition(sunny)
	e1:SetValue(500)
	c:RegisterEffect(e1)
	local e2=e1:Clone()
	e2:SetCode(EFFECT_ATTACK_ALL)
	e2:SetValue(1)
	c:RegisterEffect(e2)
	-- Each Standby Phase (yours and your opponent's): gain LP
	local e3=Effect.CreateEffect(c)
	e3:SetCategory(CATEGORY_RECOVER)
	e3:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_F)
	e3:SetCode(EVENT_PHASE+PHASE_STANDBY)
	e3:SetRange(LOCATION_MZONE)
	e3:SetCountLimit(1)
	e3:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_RECOVER,nil,0,tp,800)
	end)
	e3:SetOperation(function(e,tp)
		Duel.Recover(tp,sunny() and 1200 or 800,REASON_EFFECT)
	end)
	c:RegisterEffect(e3)
end
s.listed_names={1900000062,CARD_SUNNY_DAY}
