-- Fossil Pkmn - Kabutops
-- Cannot be Normal Summoned/Set. Must first be Special Summoned (from your hand) by Tributing 1 "Kabuto" you control,
-- or by banishing 1 "Kabuto" from your GY. You can only Special Summon "Kabutops" once per turn this way.
-- Once per turn, if this card destroys a monster by battle while "Rain Dance" is on the field: This card can make a
-- second attack in a row.
-- If this card is sent from the field to the GY: You can target 1 of your banished "Fossil" cards; shuffle it into
-- the Deck, then draw 1 card.
local s,id=GetID()
s.listed_names={1900000212,CARD_RAIN_DANCE}
function s.initial_effect(c)
	Pokemon.AddFossilSummon(c,"evolve",nil,1,false,1900000212)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e1:SetCode(EVENT_BATTLE_DESTROYING)
	e1:SetCountLimit(1)
	e1:SetCondition(function(e,tp,eg,ep,ev,re,r,rp)
		return aux.bdcon(e,tp,eg,ep,ev,re,r,rp) and Pokemon.IsOnField(CARD_RAIN_DANCE) and e:GetHandler():CanChainAttack()
	end)
	e1:SetOperation(function(e) Duel.ChainAttack() end)
	c:RegisterEffect(e1)
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,1))
	e2:SetCategory(CATEGORY_TODECK+CATEGORY_DRAW)
	e2:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e2:SetProperty(EFFECT_FLAG_DELAY+EFFECT_FLAG_CARD_TARGET)
	e2:SetCode(EVENT_TO_GRAVE)
	e2:SetCondition(function(e) return e:GetHandler():IsPreviousLocation(LOCATION_ONFIELD) end)
	e2:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
		if chkc then return chkc:IsLocation(LOCATION_REMOVED) and chkc:IsControler(tp) and s.tdfilter(chkc) end
		if chk==0 then return Duel.IsPlayerCanDraw(tp,1) and Duel.IsExistingTarget(s.tdfilter,tp,LOCATION_REMOVED,0,1,nil) end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TODECK)
		local g=Duel.SelectTarget(tp,s.tdfilter,tp,LOCATION_REMOVED,0,1,1,nil)
		Duel.SetOperationInfo(0,CATEGORY_TODECK,g,1,0,0)
		Duel.SetOperationInfo(0,CATEGORY_DRAW,nil,0,tp,1)
	end)
	e2:SetOperation(function(e,tp)
		local tc=Duel.GetFirstTarget()
		if tc and tc:IsRelateToEffect(e) and Duel.SendtoDeck(tc,nil,SEQ_DECKSHUFFLE,REASON_EFFECT)>0
			and tc:IsLocation(LOCATION_DECK|LOCATION_EXTRA) then
			Duel.ShuffleDeck(tp)
			Duel.BreakEffect()
			Duel.Draw(tp,1,REASON_EFFECT)
		end
	end)
	c:RegisterEffect(e2)
end
function s.tdfilter(c) return c:IsFaceup() and c:IsSetCard(SET_FOSSIL) and c:IsAbleToDeck() end
