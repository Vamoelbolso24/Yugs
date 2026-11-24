-- Legendary Bird Trio (Ritual Spell)
-- This card can be used to Ritual Summon "Articuno", "Zapdos" or "Moltres". You must also Tribute monsters from your
-- hand or field whose total Levels exactly equal the Level of the Ritual Monster.
-- During your End Phase, except the turn this card was sent to the GY: You can shuffle 2 of your banished Pokemon
-- monsters into the Deck; shuffle this card into the Deck, and if you do, draw 1 card.
local s,id=GetID()
s.listed_names={1900000219,1900000220,1900000221}
function s.initial_effect(c)
	Ritual.AddProcEqualCode(c,nil,nil,1900000219,1900000220,1900000221)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_TODECK+CATEGORY_DRAW)
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
	e1:SetCode(EVENT_PHASE+PHASE_END)
	e1:SetRange(LOCATION_GRAVE)
	e1:SetCountLimit(1)
	e1:SetCondition(function(e,tp) return Duel.IsTurnPlayer(tp) and aux.exccon(e) end)
	e1:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(s.cfilter,tp,LOCATION_REMOVED,0,2,nil) end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TODECK)
		local g=Duel.SelectMatchingCard(tp,s.cfilter,tp,LOCATION_REMOVED,0,2,2,nil)
		Duel.SendtoDeck(g,nil,SEQ_DECKSHUFFLE,REASON_COST)
	end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return e:GetHandler():IsAbleToDeck() and Duel.IsPlayerCanDraw(tp,1) end
		Duel.SetOperationInfo(0,CATEGORY_TODECK,e:GetHandler(),1,0,0)
		Duel.SetOperationInfo(0,CATEGORY_DRAW,nil,0,tp,1)
	end)
	e1:SetOperation(function(e,tp)
		local c=e:GetHandler()
		if c:IsRelateToEffect(e) and Duel.SendtoDeck(c,nil,SEQ_DECKSHUFFLE,REASON_EFFECT)>0 and c:IsLocation(LOCATION_DECK) then
			Duel.ShuffleDeck(tp)
			Duel.BreakEffect()
			Duel.Draw(tp,1,REASON_EFFECT)
		end
	end)
	c:RegisterEffect(e1)
end
function s.cfilter(c) return c:IsFaceup() and c:IsMonster() and c:IsSetCard(SET_POKEMON) and c:IsAbleToDeckAsCost() end
