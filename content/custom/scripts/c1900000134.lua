-- Haze (Normal Spell)
-- Discard 1 card; destroy all Equip Spells on the field, also remove all counters on the field, except Poison
-- Counters and Burn Counters. You cannot conduct your Battle Phase the turn you activate this card.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_DESTROY)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCost(s.cost)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		local eq=Duel.GetMatchingGroup(s.eqfilter,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,e:GetHandler())
		if chk==0 then return #eq>0 or Duel.IsExistingMatchingCard(Card.HasCounters,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,1,nil) end
		Duel.SetOperationInfo(0,CATEGORY_DESTROY,eq,#eq,0,0)
	end)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
function s.eqfilter(c) return c:IsFaceup() and c:IsType(TYPE_EQUIP) and c:IsSpell() end
function s.cost(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.GetActivityCount(tp,ACTIVITY_BATTLE_PHASE)==0
		and Duel.IsExistingMatchingCard(Card.IsDiscardable,tp,LOCATION_HAND,0,1,e:GetHandler()) end
	Duel.DiscardHand(tp,Card.IsDiscardable,1,1,REASON_COST|REASON_DISCARD)
	-- no Battle Phase this turn
	local e1=Effect.CreateEffect(e:GetHandler())
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetProperty(EFFECT_FLAG_PLAYER_TARGET+EFFECT_FLAG_OATH)
	e1:SetCode(EFFECT_CANNOT_BP)
	e1:SetTargetRange(1,0)
	e1:SetReset(RESET_PHASE|PHASE_END)
	Duel.RegisterEffect(e1,tp)
end
function s.activate(e,tp)
	-- remove counters first (keeping Poison and Burn), then destroy the Equip Spells
	for tc in Duel.GetMatchingGroup(Card.HasCounters,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil):Iter() do
		local poison,burn=tc:GetCounter(COUNTER_POISON),tc:GetCounter(COUNTER_BURN)
		tc:RemoveAllCounters()
		if poison>0 then tc:AddCounter(COUNTER_POISON,poison) end
		if burn>0 then tc:AddCounter(COUNTER_BURN,burn) end
	end
	local eq=Duel.GetMatchingGroup(s.eqfilter,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,e:GetHandler())
	if #eq>0 then Duel.Destroy(eq,REASON_EFFECT) end
end
