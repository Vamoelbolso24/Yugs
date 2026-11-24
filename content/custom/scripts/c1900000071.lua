-- Venonat
-- If this card is Normal or Special Summoned: You can look at the top 4 cards of your opponent's Deck,
-- then return them to the top of the Deck in the same order.
-- PATTERN: look at cards secretly = Duel.ConfirmCards(tp, cards). Only tp sees them (and the game shows
-- them only to that player). Nothing moves, so they are already "back in the same order".
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e1:SetProperty(EFFECT_FLAG_DELAY)
	e1:SetCode(EVENT_SUMMON_SUCCESS)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.GetFieldGroupCount(tp,0,LOCATION_DECK)>0 end
	end)
	e1:SetOperation(function(e,tp)
		local g=Duel.GetDecktopGroup(1-tp,4)
		if #g>0 then Duel.ConfirmCards(tp,g) end
	end)
	c:RegisterEffect(e1)
	local e2=e1:Clone()
	e2:SetCode(EVENT_SPSUMMON_SUCCESS)
	c:RegisterEffect(e2)
end
