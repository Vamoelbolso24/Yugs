-- Tentacool
-- If this card is Normal or Special Summoned: You can Special Summon any number of "Tentacool" and "Tentacruel"
-- from your hand.
-- Once per turn, if this card is targeted for an attack: You can send the top card of your Deck to the GY;
-- negate that attack.
-- Once per turn: You can target 1 monster your opponent controls; toss a coin and call it, and if you call it
-- right, place 1 Poison Counter on that monster. You can only use this effect of "Tentacool" up to thrice per turn.
-- (The "once per turn + up to 3 times" pattern is the same as Ekans, c1900000032.lua.)
local s,id=GetID()
local TENTACRUEL=1900000119
function s.initial_effect(c)
	Pokemon.EnablePoisonRule()
	-- Summon more Tentacool/Tentacruel from the hand
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_SPECIAL_SUMMON)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e1:SetProperty(EFFECT_FLAG_DELAY)
	e1:SetCode(EVENT_SUMMON_SUCCESS)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.GetLocationCount(tp,LOCATION_MZONE)>0
			and Duel.IsExistingMatchingCard(s.spfilter,tp,LOCATION_HAND,0,1,nil,e,tp) end
		Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_HAND)
	end)
	e1:SetOperation(function(e,tp)
		local ft=Duel.GetLocationCount(tp,LOCATION_MZONE)
		if ft<=0 then return end
		if Duel.IsPlayerAffectedByEffect(tp,CARD_BLUEEYES_SPIRIT) then ft=1 end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
		local g=Duel.SelectMatchingCard(tp,s.spfilter,tp,LOCATION_HAND,0,1,ft,nil,e,tp)   -- "any number"
		if #g>0 then Duel.SpecialSummon(g,0,tp,tp,false,false,POS_FACEUP) end
	end)
	c:RegisterEffect(e1)
	local e2=e1:Clone()
	e2:SetCode(EVENT_SPSUMMON_SUCCESS)
	c:RegisterEffect(e2)
	-- Negate an attack on it
	local e3=Effect.CreateEffect(c)
	e3:SetDescription(aux.Stringid(id,1))
	e3:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e3:SetCode(EVENT_BE_BATTLE_TARGET)
	e3:SetCountLimit(1)
	e3:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsPlayerCanDiscardDeckAsCost(tp,1) end
		Duel.DiscardDeck(tp,1,REASON_COST)
	end)
	e3:SetOperation(function() Duel.NegateAttack() end)
	c:RegisterEffect(e3)
	-- Coin toss: Poison Counter (each copy once per turn, all copies 3 times per turn)
	local e4=Effect.CreateEffect(c)
	e4:SetDescription(aux.Stringid(id,2))
	e4:SetCategory(CATEGORY_COUNTER+CATEGORY_COIN)
	e4:SetType(EFFECT_TYPE_IGNITION)
	e4:SetRange(LOCATION_MZONE)
	e4:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e4:SetCountLimit(1)
	e4:SetCondition(function(e,tp) return Duel.GetFlagEffect(tp,id)<3 end)
	e4:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.RegisterFlagEffect(tp,id,RESET_PHASE|PHASE_END,0,1)
	end)
	e4:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
		if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(1-tp) and s.pfilter(chkc) end
		if chk==0 then return Duel.IsExistingTarget(s.pfilter,tp,0,LOCATION_MZONE,1,nil) end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_COUNTER)
		Duel.SelectTarget(tp,s.pfilter,tp,0,LOCATION_MZONE,1,1,nil)
		Duel.SetOperationInfo(0,CATEGORY_COIN,nil,0,tp,1)
	end)
	e4:SetOperation(function(e,tp)
		local tc=Duel.GetFirstTarget()
		if Duel.CallCoin(tp) and tc and tc:IsRelateToEffect(e) and tc:IsFaceup() then tc:AddCounter(COUNTER_POISON,1) end
	end)
	c:RegisterEffect(e4)
end
s.listed_names={id,TENTACRUEL}
s.toss_coin=true
function s.spfilter(c,e,tp) return c:IsCode(id,TENTACRUEL) and c:IsCanBeSpecialSummoned(e,0,tp,false,false) end
function s.pfilter(c) return c:IsFaceup() and c:IsCanAddCounter(COUNTER_POISON,1) end
