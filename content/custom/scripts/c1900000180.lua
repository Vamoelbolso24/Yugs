-- Tangela (Flip)
-- FLIP: You can add 1 Level 4 or lower Plant Pokemon monster from your Deck to your hand.
-- While "Sunny Day" is on the field, your opponent cannot target Plant Pokemon monsters you control with card effects.
-- During your Standby Phase: Gain 500 LP.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_TOHAND+CATEGORY_SEARCH)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_FLIP+EFFECT_TYPE_TRIGGER_O)
	e1:SetProperty(EFFECT_FLAG_DELAY)
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
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD)
	e2:SetCode(EFFECT_CANNOT_BE_EFFECT_TARGET)
	e2:SetRange(LOCATION_MZONE)
	e2:SetTargetRange(LOCATION_MZONE,0)
	e2:SetCondition(function() return Pokemon.IsOnField(CARD_SUNNY_DAY) end)
	e2:SetTarget(function(e,tc) return tc:IsSetCard(SET_POKEMON) and tc:IsRace(RACE_PLANT) end)
	e2:SetValue(aux.tgoval)
	c:RegisterEffect(e2)
	Pokemon.AddStandbyRecover(c,500)
end
s.listed_names={CARD_SUNNY_DAY}
function s.thfilter(c) return c:IsSetCard(SET_POKEMON) and c:IsMonster() and c:IsRace(RACE_PLANT) and c:IsLevelBelow(4) and c:IsAbleToHand() end
