-- Grimer
-- Once per turn, if you draw a monster for your normal draw in your Draw Phase: You can reveal it; place it on
-- the bottom of the Deck, then draw 1 card.
-- Once per turn: You can target 1 monster your opponent controls; toss a coin and call it, and if you call it
-- right, place 1 Poison Counter on it.
-- If this card is targeted for an attack: Toss a coin and call it, and if you call it right, negate the attack.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.EnablePoisonRule()
	-- Redraw (like Repel, c1900000117.lua)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_DRAW)
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
	e1:SetCode(EVENT_DRAW)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCountLimit(1)
	e1:SetCondition(function(e,tp,eg,ep,ev,re,r)
		return ep==tp and r==REASON_RULE and Duel.GetCurrentPhase()==PHASE_DRAW and eg:IsExists(Card.IsMonster,1,nil)
	end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsPlayerCanDraw(tp,1) end
		Duel.SetTargetCard(eg:Filter(Card.IsMonster,nil):GetFirst())
		Duel.SetOperationInfo(0,CATEGORY_DRAW,nil,0,tp,1)
	end)
	e1:SetOperation(function(e,tp)
		local tc=Duel.GetFirstTarget()
		if not (tc and tc:IsLocation(LOCATION_HAND)) then return end
		Duel.ConfirmCards(1-tp,tc)
		Duel.ShuffleHand(tp)
		if Duel.SendtoDeck(tc,nil,SEQ_DECKBOTTOM,REASON_EFFECT)>0 and tc:IsLocation(LOCATION_DECK) then
			Duel.Draw(tp,1,REASON_EFFECT)
		end
	end)
	c:RegisterEffect(e1)
	-- Coin: Poison Counter
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,1))
	e2:SetCategory(CATEGORY_COUNTER+CATEGORY_COIN)
	e2:SetType(EFFECT_TYPE_IGNITION)
	e2:SetRange(LOCATION_MZONE)
	e2:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e2:SetCountLimit(1)
	e2:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
		if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(1-tp) and s.pfilter(chkc) end
		if chk==0 then return Duel.IsExistingTarget(s.pfilter,tp,0,LOCATION_MZONE,1,nil) end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_COUNTER)
		Duel.SelectTarget(tp,s.pfilter,tp,0,LOCATION_MZONE,1,1,nil)
		Duel.SetOperationInfo(0,CATEGORY_COIN,nil,0,tp,1)
	end)
	e2:SetOperation(function(e,tp)
		local tc=Duel.GetFirstTarget()
		if Duel.CallCoin(tp) and tc and tc:IsRelateToEffect(e) and tc:IsFaceup() then tc:AddCounter(COUNTER_POISON,1) end
	end)
	c:RegisterEffect(e2)
	-- Coin: negate an attack on it (mandatory)
	local e3=Effect.CreateEffect(c)
	e3:SetCategory(CATEGORY_COIN)
	e3:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e3:SetCode(EVENT_BE_BATTLE_TARGET)
	e3:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_COIN,nil,0,tp,1)
	end)
	e3:SetOperation(function(e,tp) if Duel.CallCoin(tp) then Duel.NegateAttack() end end)
	c:RegisterEffect(e3)
end
s.toss_coin=true
function s.pfilter(c) return c:IsFaceup() and c:IsCanAddCounter(COUNTER_POISON,1) end
