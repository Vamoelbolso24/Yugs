-- Oddish
-- You can target 1 monster your opponent controls; place 1 Poison Counter on it.
-- (During each Standby Phase, each player takes 300 damage for each Poison Counter on cards they control.)
-- You can only activate this effect of "Oddish" once per turn.
-- (Made from Ekans: the "3 times per turn" flag became "once per turn" with <1.)
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.EnablePoisonRule()   -- switches on the Poison Counter damage rule (custom_utility.lua)

	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_COUNTER)
	e1:SetType(EFFECT_TYPE_IGNITION)
	e1:SetRange(LOCATION_MZONE)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)                                          
	e1:SetCondition(function(e,tp) return Duel.GetFlagEffect(tp,id)<1 end)   -- hard: Once per turn for "Oddish"
	e1:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.RegisterFlagEffect(tp,id,RESET_PHASE|PHASE_END,0,1)  -- count this use
	end)
	e1:SetTarget(s.target)
	e1:SetOperation(s.operation)
	c:RegisterEffect(e1)
end
function s.filter(c)
	return c:IsCanAddCounter(COUNTER_POISON,1)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(1-tp) and s.filter(chkc) end
	if chk==0 then return Duel.IsExistingTarget(s.filter,tp,0,LOCATION_MZONE,1,nil) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_COUNTER)
	local g=Duel.SelectTarget(tp,s.filter,tp,0,LOCATION_MZONE,1,1,nil)
	Duel.SetOperationInfo(0,CATEGORY_COUNTER,g,1,COUNTER_POISON,1)
end
function s.operation(e,tp,eg,ep,ev,re,r,rp)
	local tc=Duel.GetFirstTarget()
	if tc and tc:IsRelateToEffect(e) then tc:AddCounter(COUNTER_POISON,1) end
end
