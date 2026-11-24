-- Lapras
-- Your opponent cannot activate cards or effects during the Battle Phase.
-- If this card is Normal or Special Summoned: You can shuffle all WATER monsters in your GY into the Deck, then if
-- you shuffled at least 3 monsters, draw 1 card.
-- During your Standby Phase: You can draw 1 card for each WATER monster your opponent controls.
-- During the End Phase of a turn in which you Summoned this card: Add 1 "Surf" from your Deck to your hand.
local s,id=GetID()
s.listed_names={CARD_SURF}
function s.initial_effect(c)
	-- No opponent activations in the Battle Phase
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
	e1:SetCode(EFFECT_CANNOT_ACTIVATE)
	e1:SetRange(LOCATION_MZONE)
	e1:SetTargetRange(0,1)
	e1:SetCondition(function() return Duel.IsBattlePhase() end)
	e1:SetValue(1)
	c:RegisterEffect(e1)
	-- Shuffle WATER monsters back, draw if 3+
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,0))
	e2:SetCategory(CATEGORY_TODECK+CATEGORY_DRAW)
	e2:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e2:SetProperty(EFFECT_FLAG_DELAY)
	e2:SetCode(EVENT_SUMMON_SUCCESS)
	e2:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		local g=Duel.GetMatchingGroup(s.tdfilter,tp,LOCATION_GRAVE,0,nil)
		if chk==0 then return #g>0 end
		Duel.SetOperationInfo(0,CATEGORY_TODECK,g,#g,0,0)
	end)
	e2:SetOperation(function(e,tp)
		local g=Duel.GetMatchingGroup(aux.NecroValleyFilter(s.tdfilter),tp,LOCATION_GRAVE,0,nil)
		if #g==0 or Duel.SendtoDeck(g,nil,SEQ_DECKSHUFFLE,REASON_EFFECT)==0 then return end
		local ct=Duel.GetOperatedGroup():FilterCount(Card.IsLocation,nil,LOCATION_DECK|LOCATION_EXTRA)
		if ct>=3 and Duel.IsPlayerCanDraw(tp,1) then
			Duel.BreakEffect()
			Duel.Draw(tp,1,REASON_EFFECT)
		end
	end)
	c:RegisterEffect(e2)
	local e2b=e2:Clone() e2b:SetCode(EVENT_SPSUMMON_SUCCESS) c:RegisterEffect(e2b)
	-- Standby: draw per opponent's WATER monster
	local e3=Effect.CreateEffect(c)
	e3:SetDescription(aux.Stringid(id,1))
	e3:SetCategory(CATEGORY_DRAW)
	e3:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
	e3:SetCode(EVENT_PHASE+PHASE_STANDBY)
	e3:SetRange(LOCATION_MZONE)
	e3:SetCountLimit(1)
	e3:SetCondition(function(e,tp) return Duel.IsTurnPlayer(tp) end)
	e3:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		local ct=Duel.GetMatchingGroupCount(s.oppwater,tp,0,LOCATION_MZONE,nil)
		if chk==0 then return ct>0 and Duel.IsPlayerCanDraw(tp,ct) end
		Duel.SetOperationInfo(0,CATEGORY_DRAW,nil,0,tp,ct)
	end)
	e3:SetOperation(function(e,tp)
		local ct=Duel.GetMatchingGroupCount(s.oppwater,tp,0,LOCATION_MZONE,nil)
		if ct>0 then Duel.Draw(tp,ct,REASON_EFFECT) end
	end)
	c:RegisterEffect(e3)
	-- Remember the turn it was Summoned...
	local e4=Effect.CreateEffect(c)
	e4:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
	e4:SetCode(EVENT_SUMMON_SUCCESS)
	e4:SetOperation(function(e) e:GetHandler():RegisterFlagEffect(id,RESET_EVENT|RESETS_STANDARD|RESET_PHASE|PHASE_END,0,1) end)
	c:RegisterEffect(e4)
	local e4b=e4:Clone() e4b:SetCode(EVENT_SPSUMMON_SUCCESS) c:RegisterEffect(e4b)
	local e4c=e4:Clone() e4c:SetCode(EVENT_FLIP_SUMMON_SUCCESS) c:RegisterEffect(e4c)
	-- ...and add "Surf" in that End Phase (mandatory)
	local e5=Effect.CreateEffect(c)
	e5:SetDescription(aux.Stringid(id,2))
	e5:SetCategory(CATEGORY_TOHAND+CATEGORY_SEARCH)
	e5:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_F)
	e5:SetCode(EVENT_PHASE+PHASE_END)
	e5:SetRange(LOCATION_MZONE)
	e5:SetCountLimit(1)
	e5:SetCondition(function(e) return e:GetHandler():GetFlagEffect(id)>0 end)
	e5:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_TOHAND,nil,1,tp,LOCATION_DECK)
	end)
	e5:SetOperation(function(e,tp)
		local g=Duel.SelectMatchingCard(tp,function(x) return x:IsCode(CARD_SURF) and x:IsAbleToHand() end,tp,LOCATION_DECK,0,1,1,nil)
		if #g>0 then Duel.SendtoHand(g,nil,REASON_EFFECT) Duel.ConfirmCards(1-tp,g) end
	end)
	c:RegisterEffect(e5)
end
function s.tdfilter(c) return c:IsMonster() and c:IsAttribute(ATTRIBUTE_WATER) and c:IsAbleToDeck() end
function s.oppwater(c) return c:IsFaceup() and c:IsAttribute(ATTRIBUTE_WATER) end
