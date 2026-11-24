-- Tentacruel
-- Evolution Summon from "Tentacool" (hard once per turn).
-- Your opponent cannot target Level 4 or lower Aqua monsters you control for attacks.
-- Any effect that would make your opponent gain LP inflicts that much damage to them instead.
-- You can only use each of these effects of "Tentacruel" once per turn:
-- * During your Main Phase: You can place 1 Poison Counter on a monster your opponent controls.
-- * If this card is Summoned: You can add 1 "Toxic Spikes" from your Deck to your hand.
-- PATTERN: "each effect once per turn" = SetCountLimit(1,id) on one and SetCountLimit(1,{id,1}) on the other,
-- so each has its own counter (the same counter on both would mean "only 1 of these effects").
-- "gaining LP becomes damage" = EFFECT_REVERSE_RECOVER (like the real "Bad Reaction to Simochi").
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000118)   -- from Tentacool
	Pokemon.EnablePoisonRule()

	-- Small Aqua monsters can't be attacked
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_CANNOT_SELECT_BATTLE_TARGET)
	e1:SetRange(LOCATION_MZONE)
	e1:SetTargetRange(0,LOCATION_MZONE)
	e1:SetValue(function(e,tc) return tc:IsFaceup() and tc:IsRace(RACE_AQUA) and tc:IsLevelBelow(4) end)
	c:RegisterEffect(e1)
	-- Opponent's LP gains become damage
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD)
	e2:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
	e2:SetCode(EFFECT_REVERSE_RECOVER)
	e2:SetRange(LOCATION_MZONE)
	e2:SetTargetRange(0,1)
	e2:SetValue(1)
	c:RegisterEffect(e2)
	-- Poison Counter (shared limit)
	local e3=Effect.CreateEffect(c)
	e3:SetDescription(aux.Stringid(id,0))
	e3:SetCategory(CATEGORY_COUNTER)
	e3:SetType(EFFECT_TYPE_IGNITION)
	e3:SetRange(LOCATION_MZONE)
	e3:SetCountLimit(1,id)
	e3:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(s.pfilter,tp,0,LOCATION_MZONE,1,nil) end
		Duel.SetOperationInfo(0,CATEGORY_COUNTER,nil,1,0,COUNTER_POISON)
	end)
	e3:SetOperation(function(e,tp)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_COUNTER)
		local tc=Duel.SelectMatchingCard(tp,s.pfilter,tp,0,LOCATION_MZONE,1,1,nil):GetFirst()
		if tc then tc:AddCounter(COUNTER_POISON,1) end
	end)
	c:RegisterEffect(e3)
	-- Search Toxic Spikes when Summoned (shared limit)
	local e4=Effect.CreateEffect(c)
	e4:SetDescription(aux.Stringid(id,1))
	e4:SetCategory(CATEGORY_TOHAND+CATEGORY_SEARCH)
	e4:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e4:SetProperty(EFFECT_FLAG_DELAY)
	e4:SetCode(EVENT_SUMMON_SUCCESS)
	e4:SetCountLimit(1,{id,1})
	e4:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(s.thfilter,tp,LOCATION_DECK,0,1,nil) end
		Duel.SetOperationInfo(0,CATEGORY_TOHAND,nil,1,tp,LOCATION_DECK)
	end)
	e4:SetOperation(function(e,tp)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATOHAND)
		local g=Duel.SelectMatchingCard(tp,s.thfilter,tp,LOCATION_DECK,0,1,1,nil)
		if #g>0 then
			Duel.SendtoHand(g,nil,REASON_EFFECT)
			Duel.ConfirmCards(1-tp,g)
		end
	end)
	c:RegisterEffect(e4)
	local e5=e4:Clone() e5:SetCode(EVENT_SPSUMMON_SUCCESS) c:RegisterEffect(e5)
	local e6=e4:Clone() e6:SetCode(EVENT_FLIP_SUMMON_SUCCESS) c:RegisterEffect(e6)
end
s.listed_names={1900000118,CARD_TOXIC_SPIKES}
function s.pfilter(c) return c:IsFaceup() and c:IsCanAddCounter(COUNTER_POISON,1) end
function s.thfilter(c) return c:IsCode(CARD_TOXIC_SPIKES) and c:IsAbleToHand() end
