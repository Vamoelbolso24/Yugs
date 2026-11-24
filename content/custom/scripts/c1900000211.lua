-- Fossil Pkmn - Omastar
-- Cannot be Normal Summoned/Set. Must first be Special Summoned (from your hand) by Tributing 1 "Omanyte" you
-- control, or by banishing 1 "Omanyte" from your GY. You can only Special Summon "Omastar" once per turn this way.
-- Once per turn, while "Rain Dance" is on the field (Quick Effect): You can change this card's battle position.
-- If this card destroys a monster by battle while "Rain Dance" is on the field: You can add 1 "Fossil Pkmn" monster
-- from your Deck to your hand.
local s,id=GetID()
s.listed_names={1900000210,CARD_RAIN_DANCE}
function s.initial_effect(c)
	Pokemon.AddFossilSummon(c,"evolve",nil,1,false,1900000210)
	Pokemon.AddRainPositionChange(c,0)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,1))
	e1:SetCategory(CATEGORY_TOHAND+CATEGORY_SEARCH)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e1:SetCode(EVENT_BATTLE_DESTROYING)
	e1:SetCondition(function(e,tp,eg,ep,ev,re,r,rp) return aux.bdcon(e,tp,eg,ep,ev,re,r,rp) and Pokemon.IsOnField(CARD_RAIN_DANCE) end)
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
function s.thfilter(c) return c:IsSetCard(SET_FOSSIL_PKMN) and c:IsMonster() and c:IsAbleToHand() end
