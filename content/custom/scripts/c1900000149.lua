-- Gastly
-- Cannot be targeted for an attack by Warrior or non-Effect monsters.
-- Once per turn, if you have 2000 or more LP: You can activate 1 of these effects:
-- * Pay half your LP, then target 1 face-up Spell/Trap your opponent controls; its effect becomes "During your
--   Standby Phase: Lose 1000 LP" (even if this card leaves the field).
-- * Pay 1500 LP, then target 1 monster your opponent controls; place 1 Curse Counter on it.
-- If a monster has 2 or more Curse Counters, immediately send it to the GY, also it cannot activate its effects in
-- the GY and your opponent cannot target it with card effects (even if this card leaves the field).
-- (The "its effect becomes..." part is Pokemon.CurseSpellTrap and the Curse Counter rule is Pokemon.EnableCurseRule,
-- both in custom_utility.lua.)
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.EnableCurseRule()
	-- Warriors and non-Effect monsters can't attack it
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCode(EFFECT_CANNOT_BE_BATTLE_TARGET)
	e1:SetValue(function(e,ac) return ac:IsRace(RACE_WARRIOR) or not ac:IsType(TYPE_EFFECT) end)
	c:RegisterEffect(e1)
	-- Choose 1 of 2 effects
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_IGNITION)
	e2:SetRange(LOCATION_MZONE)
	e2:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e2:SetCountLimit(1)
	e2:SetCondition(function(e,tp) return Duel.GetLP(tp)>=2000 end)
	e2:SetCost(s.cost)
	e2:SetTarget(s.target)
	e2:SetOperation(s.operation)
	c:RegisterEffect(e2)
end
function s.stfilter(c) return c:IsFaceup() and c:IsSpellTrap() end
function s.mfilter(c) return c:IsFaceup() and c:IsCanAddCounter(COUNTER_CURSE,1) end
-- which choices are possible: 1 = Spell/Trap, 2 = Curse Counter
function s.choices(tp)
	local t={}
	if Duel.IsExistingTarget(s.stfilter,tp,0,LOCATION_ONFIELD,1,nil) then table.insert(t,1) end
	if Duel.CheckLPCost(tp,1500) and Duel.IsExistingTarget(s.mfilter,tp,0,LOCATION_MZONE,1,nil) then table.insert(t,2) end
	return t
end
-- The choice is made in the cost (so the right LP is paid), then remembered in the label.
function s.cost(e,tp,eg,ep,ev,re,r,rp,chk)
	local t=s.choices(tp)
	if chk==0 then return #t>0 end
	local descs={}
	for _,v in ipairs(t) do table.insert(descs,aux.Stringid(id,v-1)) end   -- Prompt 1 / Prompt 2
	local pick=t[Duel.SelectOption(tp,table.unpack(descs))+1]
	e:SetLabel(pick)
	if pick==1 then Duel.PayLPCost(tp,math.floor(Duel.GetLP(tp)/2)) else Duel.PayLPCost(tp,1500) end
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then
		if e:GetLabel()==1 then return chkc:IsOnField() and chkc:IsControler(1-tp) and s.stfilter(chkc) end
		return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(1-tp) and s.mfilter(chkc)
	end
	if chk==0 then return true end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TARGET)
	if e:GetLabel()==1 then
		Duel.SelectTarget(tp,s.stfilter,tp,0,LOCATION_ONFIELD,1,1,nil)
	else
		Duel.SelectTarget(tp,s.mfilter,tp,0,LOCATION_MZONE,1,1,nil)
		Duel.SetOperationInfo(0,CATEGORY_COUNTER,nil,1,0,COUNTER_CURSE)
	end
end
function s.operation(e,tp)
	local tc=Duel.GetFirstTarget()
	if not (tc and tc:IsRelateToEffect(e) and tc:IsFaceup()) then return end
	if e:GetLabel()==1 then
		Pokemon.CurseSpellTrap(e:GetHandler(),tc,1000,aux.Stringid(id,2))
	else
		tc:AddCounter(COUNTER_CURSE,1)
	end
end
s.counter_place_list={COUNTER_CURSE}
