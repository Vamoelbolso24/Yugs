-- Pokemon Trainer - Fisherman (Normal Spell)
-- Discard 1 WATER monster; add 1 Level 4 or lower Fish Pokemon monster from your Deck to your hand.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_TOHAND+CATEGORY_SEARCH)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(s.dfilter,tp,LOCATION_HAND,0,1,nil) end
		Duel.DiscardHand(tp,s.dfilter,1,1,REASON_COST|REASON_DISCARD)
	end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(s.thfilter,tp,LOCATION_DECK,0,1,nil) end
		Duel.SetOperationInfo(0,CATEGORY_TOHAND,nil,1,tp,LOCATION_DECK)
	end)
	e1:SetOperation(function(e,tp)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATOHAND)
		local g=Duel.SelectMatchingCard(tp,s.thfilter,tp,LOCATION_DECK,0,1,1,nil)
		if #g>0 then Duel.SendtoHand(g,nil,REASON_EFFECT) Duel.ConfirmCards(1-tp,g) end
	end)
	c:RegisterEffect(e1)
end
function s.dfilter(c) return c:IsMonster() and c:IsAttribute(ATTRIBUTE_WATER) and c:IsDiscardable() end
function s.thfilter(c) return c:IsSetCard(SET_POKEMON) and c:IsMonster() and c:IsRace(RACE_FISH) and c:IsLevelBelow(4) and c:IsAbleToHand() end
