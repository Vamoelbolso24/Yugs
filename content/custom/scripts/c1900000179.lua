-- Chansey
-- You can Normal Summon this card in face-up Defense Position.
-- During your Standby Phase: Gain 1000 LP.
-- If this card is attacked by a Warrior monster, before damage calculation: Destroy this card.
-- (Quick Effect): You can activate only 1 of these effects of "Chansey" per turn, and only once that turn:
-- 1. Declare 1 kind of Counter; remove all Counters of that kind from cards you control.
-- 2. Target 1 monster you control; the first time it would be destroyed by battle or card effect this turn, it is not.
-- 3. Return this card to the hand; Special Summon 1 Level 4 or lower Pokemon monster from your hand.
local s,id=GetID()
function s.initial_effect(c)
	-- Normal Summon in face-up Defense Position (asked right after the Summon)
	local e0=Effect.CreateEffect(c)
	e0:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
	e0:SetCode(EVENT_SUMMON_SUCCESS)
	e0:SetOperation(function(e,tp)
		local c=e:GetHandler()
		if c:IsAttackPos() and Duel.SelectYesNo(tp,aux.Stringid(id,3)) then Duel.ChangePosition(c,POS_FACEUP_DEFENSE) end
	end)
	c:RegisterEffect(e0)
	Pokemon.AddStandbyRecover(c,1000)
	-- Attacked by a Warrior: destroyed before damage calculation
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_DESTROY)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e1:SetCode(EVENT_BATTLE_CONFIRM)                  -- "before damage calculation"
	e1:SetCondition(function(e)
		local a=Duel.GetAttacker()
		return Duel.GetAttackTarget()==e:GetHandler() and a and a:IsRace(RACE_WARRIOR)
	end)
	e1:SetOperation(function(e)
		local c=e:GetHandler()
		if c:IsRelateToEffect(e) then Duel.Destroy(c,REASON_EFFECT) end
	end)
	c:RegisterEffect(e1)
	-- 3 Quick Effects sharing one "once per turn"
	local base=Effect.CreateEffect(c)
	base:SetType(EFFECT_TYPE_QUICK_O)
	base:SetCode(EVENT_FREE_CHAIN)
	base:SetRange(LOCATION_MZONE)
	base:SetHintTiming(0,TIMINGS_CHECK_MONSTER|TIMING_END_PHASE)
	base:SetCountLimit(1,id)
	-- 1. remove Counters
	local e2=base:Clone()
	e2:SetDescription(aux.Stringid(id,0))
	e2:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		local list=s.present(tp)
		if chk==0 then return #list>0 end
		local descs={}
		for _,kind in ipairs(list) do table.insert(descs,Pokemon.CounterDesc(kind)) end   -- shows e.g. "Spell Counters"
		Duel.Hint(HINT_SELECTMSG,tp,aux.Stringid(id,0))
		e:SetLabel(list[Duel.SelectOption(tp,table.unpack(descs))+1])   -- the chosen kind
	end)
	e2:SetOperation(function(e,tp)
		local kind=e:GetLabel()
		for tc in Duel.GetMatchingGroup(function(x) return x:GetCounter(kind)>0 end,tp,LOCATION_ONFIELD,0,nil):Iter() do
			tc:RemoveCounter(tp,kind,tc:GetCounter(kind),REASON_EFFECT)
		end
	end)
	c:RegisterEffect(e2)
	-- 2. protect a monster once this turn
	local e3=base:Clone()
	e3:SetDescription(aux.Stringid(id,1))
	e3:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e3:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
		if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(tp) and chkc:IsFaceup() end
		if chk==0 then return Duel.IsExistingTarget(Card.IsFaceup,tp,LOCATION_MZONE,0,1,nil) end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TARGET)
		Duel.SelectTarget(tp,Card.IsFaceup,tp,LOCATION_MZONE,0,1,1,nil)
	end)
	e3:SetOperation(function(e)
		local tc=Duel.GetFirstTarget()
		if not (tc and tc:IsRelateToEffect(e) and tc:IsFaceup()) then return end
		local e4=Effect.CreateEffect(e:GetHandler())
		e4:SetType(EFFECT_TYPE_SINGLE)
		e4:SetProperty(EFFECT_FLAG_CLIENT_HINT)
		e4:SetDescription(aux.Stringid(id,1))
		e4:SetCode(EFFECT_INDESTRUCTABLE_COUNT)
		e4:SetCountLimit(1)
		e4:SetValue(function(ef,re,r) return (r&(REASON_BATTLE|REASON_EFFECT))~=0 end)
		e4:SetReset(RESETS_STANDARD_PHASE_END)
		tc:RegisterEffect(e4)
	end)
	c:RegisterEffect(e3)
	-- 3. return to hand, Special Summon a small Pokemon
	local e5=base:Clone()
	e5:SetDescription(aux.Stringid(id,2))
	e5:SetCategory(CATEGORY_SPECIAL_SUMMON)
	e5:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk)
		local c=e:GetHandler()
		if chk==0 then return c:IsAbleToHandAsCost() end
		Duel.SendtoHand(c,nil,REASON_COST)
	end)
	e5:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		-- Chansey leaves first, so its zone counts as free
		if chk==0 then return Duel.GetMZoneCount(tp,e:GetHandler())>0
			and Duel.IsExistingMatchingCard(s.spfilter,tp,LOCATION_HAND,0,1,e:GetHandler(),e,tp) end
		Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_HAND)
	end)
	e5:SetOperation(function(e,tp)
		if Duel.GetLocationCount(tp,LOCATION_MZONE)<=0 then return end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
		local g=Duel.SelectMatchingCard(tp,s.spfilter,tp,LOCATION_HAND,0,1,1,nil,e,tp)
		if #g>0 then Duel.SpecialSummon(g,0,tp,tp,false,false,POS_FACEUP) end
	end)
	c:RegisterEffect(e5)
end
function s.spfilter(c,e,tp) return c:IsSetCard(SET_POKEMON) and c:IsLevelBelow(4) and c:IsCanBeSpecialSummoned(e,0,tp,false,false) and not c:IsCode(id) end
-- every kind of Counter on cards you control right now (any Counter, official or custom, named or not)
function s.present(tp)
	local seen,t={},{}
	for tc in Duel.GetFieldGroup(tp,LOCATION_ONFIELD,0):Iter() do
		for kind,n in pairs(tc:GetAllCounters()) do
			if n>0 and not seen[kind] then seen[kind]=true table.insert(t,kind) end
		end
	end
	table.sort(t)
	return t
end
