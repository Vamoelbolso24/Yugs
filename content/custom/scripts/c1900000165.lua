-- Cubone (Flip)
-- FLIP: Add 1 "Marowak" monster from your Deck to your hand.
-- PATTERN: a Flip effect = EFFECT_TYPE_SINGLE+EFFECT_TYPE_FLIP (it happens when the card is flipped face-up).
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_TOHAND+CATEGORY_SEARCH)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_FLIP)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_TOHAND,nil,1,tp,LOCATION_DECK)
	end)
	e1:SetOperation(function(e,tp)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATOHAND)
		local g=Duel.SelectMatchingCard(tp,s.filter,tp,LOCATION_DECK,0,1,1,nil)
		if #g>0 then Duel.SendtoHand(g,nil,REASON_EFFECT) Duel.ConfirmCards(1-tp,g) end
	end)
	c:RegisterEffect(e1)
end
s.listed_series={SET_MAROWAK}
function s.filter(c) return c:IsSetCard(SET_MAROWAK) and c:IsMonster() and c:IsAbleToHand() end
