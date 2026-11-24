-- Exeggutor
-- Evolution Summon from "Exeggcute" (hard once per turn).
-- (This card is also treated as a Spellcaster monster.)
-- While "Sunny Day" is on the field, this card gains these effects:
-- * During your opponent's turn, when they activate a Spell card (Quick Effect): You can discard 1 card; negate the
--   activation, and if you do, destroy it.
-- * (Quick Effect): You can destroy this card, and if you do, destroy 1 card on the field.
-- You can only use each effect of "Exeggutor" once per turn.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000163)   -- from Exeggcute
	Pokemon.AddExtraRace(c,RACE_SPELLCASTER)
	local sunny=function() return Pokemon.IsOnField(CARD_SUNNY_DAY) end
	-- Negate a Spell
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_NEGATE+CATEGORY_DESTROY)
	e1:SetType(EFFECT_TYPE_QUICK_O)
	e1:SetCode(EVENT_CHAINING)
	e1:SetRange(LOCATION_MZONE)
	e1:SetProperty(EFFECT_FLAG_DAMAGE_STEP+EFFECT_FLAG_DAMAGE_CAL)
	e1:SetCountLimit(1,id)
	e1:SetCondition(function(e,tp,eg,ep,ev,re,r,rp)
		return sunny() and Duel.IsTurnPlayer(1-tp) and rp==1-tp and re:IsHasType(EFFECT_TYPE_ACTIVATE)
			and re:IsActiveType(TYPE_SPELL) and Duel.IsChainNegatable(ev)
	end)
	e1:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(Card.IsDiscardable,tp,LOCATION_HAND,0,1,nil) end
		Duel.DiscardHand(tp,Card.IsDiscardable,1,1,REASON_COST|REASON_DISCARD)
	end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_NEGATE,eg,1,0,0)
		if re:GetHandler():IsRelateToEffect(re) then Duel.SetOperationInfo(0,CATEGORY_DESTROY,eg,1,0,0) end
	end)
	e1:SetOperation(function(e,tp,eg,ep,ev,re,r,rp)
		if Duel.NegateActivation(ev) and re:GetHandler():IsRelateToEffect(re) then Duel.Destroy(eg,REASON_EFFECT) end
	end)
	c:RegisterEffect(e1)
	-- Destroy itself and 1 card
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,1))
	e2:SetCategory(CATEGORY_DESTROY)
	e2:SetType(EFFECT_TYPE_QUICK_O)
	e2:SetCode(EVENT_FREE_CHAIN)
	e2:SetRange(LOCATION_MZONE)
	e2:SetHintTiming(0,TIMINGS_CHECK_MONSTER|TIMING_END_PHASE)
	e2:SetCountLimit(1,{id,1})
	e2:SetCondition(sunny)
	e2:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		local c=e:GetHandler()
		if chk==0 then return Duel.IsExistingMatchingCard(nil,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,1,c) end
		Duel.SetOperationInfo(0,CATEGORY_DESTROY,c,1,0,0)
	end)
	e2:SetOperation(function(e,tp)
		local c=e:GetHandler()
		if not (c:IsRelateToEffect(e) and Duel.Destroy(c,REASON_EFFECT)>0) then return end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_DESTROY)
		local g=Duel.SelectMatchingCard(tp,nil,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,1,1,nil)
		if #g>0 then Duel.HintSelection(g) Duel.Destroy(g,REASON_EFFECT) end
	end)
	c:RegisterEffect(e2)
end
s.listed_names={1900000163,CARD_SUNNY_DAY}
