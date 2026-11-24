-- Kangaskhan
-- If this card is Normal or Special Summoned: Inflict 500 damage to your opponent, and if you do, draw 1 card.
-- You can only activate this effect of "Kangaskhan" once per turn.
-- Once per turn (Quick Effect): You can change this card to face-down Defense Position.
-- If this card is destroyed by battle or by your opponent's card effect: Add 1 Level 4 or lower Pokemon monster from
-- your Deck to your hand.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_DAMAGE+CATEGORY_DRAW)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e1:SetCode(EVENT_SUMMON_SUCCESS)
	e1:SetCountLimit(1,id)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_DAMAGE,nil,0,1-tp,500)
		Duel.SetOperationInfo(0,CATEGORY_DRAW,nil,0,tp,1)
	end)
	e1:SetOperation(function(e,tp)
		if Duel.Damage(1-tp,500,REASON_EFFECT)>0 then Duel.Draw(tp,1,REASON_EFFECT) end
	end)
	c:RegisterEffect(e1)
	local e2=e1:Clone() e2:SetCode(EVENT_SPSUMMON_SUCCESS) c:RegisterEffect(e2)
	-- Hide in the pouch
	local e3=Effect.CreateEffect(c)
	e3:SetDescription(aux.Stringid(id,1))
	e3:SetCategory(CATEGORY_POSITION)
	e3:SetType(EFFECT_TYPE_QUICK_O)
	e3:SetCode(EVENT_FREE_CHAIN)
	e3:SetRange(LOCATION_MZONE)
	e3:SetHintTiming(0,TIMINGS_CHECK_MONSTER)
	e3:SetCountLimit(1)
	e3:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return e:GetHandler():IsCanTurnSet() end
		Duel.SetOperationInfo(0,CATEGORY_POSITION,e:GetHandler(),1,0,0)
	end)
	e3:SetOperation(function(e)
		local c=e:GetHandler()
		if c:IsRelateToEffect(e) and c:IsFaceup() then Duel.ChangePosition(c,POS_FACEDOWN_DEFENSE) end
	end)
	c:RegisterEffect(e3)
	-- Destroyed: search
	local e4=Effect.CreateEffect(c)
	e4:SetCategory(CATEGORY_TOHAND+CATEGORY_SEARCH)
	e4:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e4:SetProperty(EFFECT_FLAG_DELAY)
	e4:SetCode(EVENT_DESTROYED)
	e4:SetCondition(function(e,tp,eg,ep,ev,re,r,rp)
		local c=e:GetHandler()
		return c:IsReason(REASON_BATTLE) or (c:IsReason(REASON_EFFECT) and rp==1-tp)
	end)
	e4:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_TOHAND,nil,1,tp,LOCATION_DECK)
	end)
	e4:SetOperation(function(e,tp)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATOHAND)
		local g=Duel.SelectMatchingCard(tp,s.thfilter,tp,LOCATION_DECK,0,1,1,nil)
		if #g>0 then Duel.SendtoHand(g,nil,REASON_EFFECT) Duel.ConfirmCards(1-tp,g) end
	end)
	c:RegisterEffect(e4)
end
function s.thfilter(c) return c:IsSetCard(SET_POKEMON) and c:IsMonster() and c:IsLevelBelow(4) and c:IsAbleToHand() end
