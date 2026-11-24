-- Shiny Gyarados
-- When this card is Summoned: You can target 1 other Pokemon monster you control; add 1 monster from your Deck to
-- your hand whose name is mentioned in the targeted monster's text, but you cannot Special Summon monsters with that
-- name for the rest of this turn.
-- If this card destroys a monster by battle: You can discard 1 Pokemon monster; draw 2 cards.
-- You can only activate 1 "Shiny Gyarados" effect per turn, and only once that turn.
-- ("Mentioned in its text" = the targeted card's s.listed_names, the same thing the Stones use.)
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_TOHAND+CATEGORY_SEARCH)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET+EFFECT_FLAG_DELAY)
	e1:SetCode(EVENT_SUMMON_SUCCESS)
	e1:SetCountLimit(1,id)
	e1:SetTarget(s.thtg)
	e1:SetOperation(s.thop)
	c:RegisterEffect(e1)
	local e2=e1:Clone() e2:SetCode(EVENT_SPSUMMON_SUCCESS) c:RegisterEffect(e2)
	local e3=e1:Clone() e3:SetCode(EVENT_FLIP_SUMMON_SUCCESS) c:RegisterEffect(e3)
	local e4=Effect.CreateEffect(c)
	e4:SetDescription(aux.Stringid(id,1))
	e4:SetCategory(CATEGORY_DRAW)
	e4:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e4:SetCode(EVENT_BATTLE_DESTROYING)
	e4:SetCountLimit(1,id)
	e4:SetCondition(aux.bdcon)
	e4:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(s.dfilter,tp,LOCATION_HAND,0,1,nil) end
		Duel.DiscardHand(tp,s.dfilter,1,1,REASON_COST|REASON_DISCARD)
	end)
	e4:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsPlayerCanDraw(tp,2) end
		Duel.SetOperationInfo(0,CATEGORY_DRAW,nil,0,tp,2)
	end)
	e4:SetOperation(function(e,tp) Duel.Draw(tp,2,REASON_EFFECT) end)
	c:RegisterEffect(e4)
end
function s.dfilter(c) return c:IsSetCard(SET_POKEMON) and c:IsMonster() and c:IsDiscardable() end
-- a card in the Deck that tc mentions
function s.mentioned(sc,tc) return sc:IsMonster() and sc:IsAbleToHand() and tc.listed_names and tc:ListsCode(sc:GetCode()) end
function s.tgfilter(tc,tp)
	return tc:IsFaceup() and tc:IsSetCard(SET_POKEMON) and Duel.IsExistingMatchingCard(s.mentioned,tp,LOCATION_DECK,0,1,nil,tc)
end
function s.thtg(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	local c=e:GetHandler()
	if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(tp) and chkc~=c and s.tgfilter(chkc,tp) end
	if chk==0 then return Duel.IsExistingTarget(s.tgfilter,tp,LOCATION_MZONE,0,1,c,tp) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TARGET)
	Duel.SelectTarget(tp,s.tgfilter,tp,LOCATION_MZONE,0,1,1,c,tp)
	Duel.SetOperationInfo(0,CATEGORY_TOHAND,nil,1,tp,LOCATION_DECK)
end
function s.thop(e,tp)
	local tc=Duel.GetFirstTarget()
	if not (tc and tc:IsRelateToEffect(e)) then return end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATOHAND)
	local sc=Duel.SelectMatchingCard(tp,s.mentioned,tp,LOCATION_DECK,0,1,1,nil,tc):GetFirst()
	if not sc or Duel.SendtoHand(sc,nil,REASON_EFFECT)==0 then return end
	Duel.ConfirmCards(1-tp,sc)
	local code=sc:GetCode()
	local e1=Effect.CreateEffect(e:GetHandler())
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
	e1:SetCode(EFFECT_CANNOT_SPECIAL_SUMMON)
	e1:SetTargetRange(1,0)
	e1:SetTarget(function(ef,x) return x:IsCode(code) end)
	e1:SetReset(RESET_PHASE|PHASE_END)
	Duel.RegisterEffect(e1,tp)
end
